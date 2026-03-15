import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../domain/entities/group_member.dart';
import '../../data/datasources/group_local_datasource.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';

final groupDatasourceProvider = Provider<GroupLocalDatasource>(
  (ref) => GroupLocalDatasource(),
);

// ── Group State ───────────────────────────────────────────────────────────────
class GroupState {
  final List<Group> groups;
  final bool isLoading;
  final String? error;

  const GroupState(
      {this.groups = const [], this.isLoading = false, this.error});

  GroupState copyWith({
    List<Group>? groups,
    bool? isLoading,
    Object? error = _sentinel,
  }) =>
      GroupState(
        groups: groups ?? this.groups,
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

class GroupNotifier extends StateNotifier<GroupState> {
  final GroupLocalDatasource _ds;

  /// The cloud user ID (JWT sub) when connected; otherwise the local user name.
  final String _cloudUserId;
  final Ref _ref;
  static const _uuid = Uuid();

  GroupNotifier(this._ds, this._cloudUserId, this._ref)
      : super(const GroupState()) {
    _load();
    _syncFromCloud();
  }

  void _load() {
    state = state.copyWith(isLoading: true);
    state = state.copyWith(groups: _ds.getAllGroups(), isLoading: false);
  }

  bool get _isConnected {
    final hasNetwork = _ref.read(connectivityProvider);
    final isAuthenticated = _ref.read(cloudAuthProvider).isConnected;
    return hasNetwork && isAuthenticated;
  }

  /// Fetch all groups from the backend and replace local cache.
  Future<void> _syncFromCloud() async {
    if (!_isConnected) return;
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.groups);
      final list = (res.data['data'] as List?) ?? [];
      final serverGroups = list
          .map((raw) =>
              Group.fromServerJson(raw as Map<String, dynamic>, _cloudUserId))
          .toList();
      for (final g in serverGroups) {
        await _ds.saveGroup(g);
      }
      if (mounted) {
        state = state.copyWith(groups: serverGroups, error: null);
      }
    } on DioException catch (e) {
      // Network unavailable — keep local cache
      if (mounted) {
        state = state.copyWith(error: formatDioError(e));
      }
    }
  }

  Future<void> createGroup({
    required String name,
    required String emoji,
    List<String> memberNames = const [],
    List<Map<String, String>> memberUsers = const [],
  }) async {
    if (!_isConnected) {
      throw Exception('You need to be online to create a group.');
    }
    await _createGroupCloud(
        name: name,
        emoji: emoji,
        memberNames: memberNames,
        memberUsers: memberUsers);
  }

  Future<void> _createGroupCloud({
    required String name,
    required String emoji,
    List<String> memberNames = const [],
    List<Map<String, String>> memberUsers = const [],
  }) async {
    try {
      final dio = _ref.read(dioProvider);
      // 1 — Create the group (server assigns ID, adds owner as first member)
      final createRes = await dio
          .post(ApiEndpoints.groups, data: {'name': name, 'emoji': emoji});
      final serverGroup = createRes.data['data'] as Map<String, dynamic>;
      final groupId = (serverGroup['id'] ?? serverGroup['_id']) as String;

      // 2 — Collect the owner member returned by the server
      final rawMembers = (serverGroup['members'] as List?) ?? [];
      final members = rawMembers
          .map((m) => GroupMember.fromServerJson(m as Map<String, dynamic>))
          .toList();

      // 3 — Add extra members by name (fallback / offline-created names)
      for (final mName in memberNames.where((n) => n.trim().isNotEmpty)) {
        final addRes = await dio.post(ApiEndpoints.groupMembers(groupId),
            data: {'name': mName.trim()});
        final memberData = addRes.data['data'] as Map<String, dynamic>;
        members.add(GroupMember.fromServerJson(memberData));
      }

      // 4 — Add registered users by userId
      for (final mu in memberUsers) {
        final addRes = await dio.post(ApiEndpoints.groupMembers(groupId),
            data: {'userId': mu['userId']});
        final memberData = addRes.data['data'] as Map<String, dynamic>;
        members.add(GroupMember.fromServerJson(memberData));
      }

      // Identify which member represents the current user
      final ownerRaw = rawMembers.cast<Map<String, dynamic>>().firstWhere(
          (m) => m['userId'] == _cloudUserId,
          orElse: () => rawMembers.isEmpty
              ? <String, dynamic>{}
              : rawMembers.first as Map<String, dynamic>);
      final ownerMemberId = ownerRaw.isNotEmpty
          ? (ownerRaw['_id'] ?? ownerRaw['id']) as String
          : (members.isNotEmpty ? members.first.id : _cloudUserId);

      final group = Group(
        id: groupId,
        name: name,
        emoji: emoji,
        members: members,
        currentUserId: ownerMemberId,
        createdAt: serverGroup['createdAt'] != null
            ? DateTime.parse(serverGroup['createdAt'] as String)
            : DateTime.now(),
      );
      await _ds.saveGroup(group);
      if (mounted) {
        state = state.copyWith(groups: [group, ...state.groups], error: null);
      }
    } on DioException catch (e) {
      if (mounted) {
        state = state.copyWith(error: formatDioError(e));
      }
      throw Exception(formatDioError(
        e,
        fallback:
            'Failed to create group. Check your connection and try again.',
      ));
    }
  }

  Future<void> deleteGroup(String id) async {
    if (_isConnected) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.delete(ApiEndpoints.group(id));
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        // Continue with local deletion even if API fails
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
    await _ds.deleteGroup(id);
    if (mounted) {
      state = state.copyWith(
          groups: state.groups.where((g) => g.id != id).toList());
    }
  }

  /// Add a registered user as a group member by their userId (cloud + local).
  Future<void> addMemberByUserId(
      String groupId, String userId, String displayName) async {
    if (!_isConnected) {
      throw Exception('You need to be online to add members to a group.');
    }
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio
          .post(ApiEndpoints.groupMembers(groupId), data: {'userId': userId});
      final data = res.data['data'] as Map<String, dynamic>;
      final memberId = (data['_id'] ?? data['id']) as String;
      final serverName = (data['name'] as String?) ?? displayName;

      final idx = state.groups.indexWhere((g) => g.id == groupId);
      if (idx < 0) return;
      final updated = state.groups[idx].copyWith(
        members: [
          ...state.groups[idx].members,
          GroupMember(id: memberId, name: serverName),
        ],
      );
      await _ds.saveGroup(updated);
      if (mounted) {
        final groups = [...state.groups];
        groups[idx] = updated;
        state = state.copyWith(groups: groups, error: null);
      }
    } on DioException catch (e) {
      if (mounted) {
        state = state.copyWith(error: formatDioError(e));
      }
      throw Exception(formatDioError(
        e,
        fallback: 'Failed to add member. Check your connection and try again.',
      ));
    }
  }

  /// Add a name-only member to an existing group (cloud + local).
  Future<void> addMember(String groupId, String memberName) async {
    if (!_isConnected) {
      if (mounted) {
        state = state.copyWith(
          error: 'You need to be online to add members to a group.',
        );
      }
      throw Exception('You need to be online to add members to a group.');
    }
    String memberId = _uuid.v4();
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.groupMembers(groupId),
          data: {'name': memberName.trim()});
      final data = res.data['data'] as Map<String, dynamic>;
      memberId = (data['_id'] ?? data['id']) as String;
    } on DioException catch (e) {
      if (mounted) {
        state = state.copyWith(error: formatDioError(e));
      }
      throw Exception(formatDioError(
        e,
        fallback: 'Failed to add member. Check your connection and try again.',
      ));
    }
    final idx = state.groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    final updated = state.groups[idx].copyWith(
      members: [
        ...state.groups[idx].members,
        GroupMember(id: memberId, name: memberName.trim()),
      ],
    );
    await _ds.saveGroup(updated);
    if (mounted) {
      final groups = [...state.groups];
      groups[idx] = updated;
      state = state.copyWith(groups: groups, error: null);
    }
  }
}

final groupProvider = StateNotifierProvider<GroupNotifier, GroupState>((ref) {
  final ds = ref.watch(groupDatasourceProvider);
  final cloudUser = ref.watch(cloudAuthProvider).user;
  final localUser = ref.watch(currentUserProvider);
  // Use cloud user ID when connected; otherwise fall back to local user name
  final userId = cloudUser?.id ?? localUser?.name ?? 'Me';
  return GroupNotifier(ds, userId, ref);
});

// ── Group Expense State ───────────────────────────────────────────────────────
class GroupExpenseState {
  final List<GroupExpense> expenses;
  final bool isLoading;
  final String? error;

  const GroupExpenseState({
    this.expenses = const [],
    this.isLoading = false,
    this.error,
  });

  GroupExpenseState copyWith({
    List<GroupExpense>? expenses,
    bool? isLoading,
    Object? error = _sentinel,
  }) =>
      GroupExpenseState(
        expenses: expenses ?? this.expenses,
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();

  Map<String, double> netBalances(String currentUserId) {
    final balances = <String, double>{};
    for (final e in expenses) {
      final payer = e.paidByMemberId;
      for (final share in e.shares) {
        if (share.memberId == payer) continue;
        if (share.memberId == currentUserId) {
          balances[payer] = (balances[payer] ?? 0) - share.amount;
        } else if (payer == currentUserId) {
          balances[share.memberId] =
              (balances[share.memberId] ?? 0) + share.amount;
        }
      }
    }
    return balances;
  }

  double myTotalOwed(String currentUserId) {
    final b = netBalances(currentUserId);
    return b.values.where((v) => v < 0).fold(0.0, (s, v) => s + (-v));
  }

  double myTotalOwing(String currentUserId) {
    final b = netBalances(currentUserId);
    return b.values.where((v) => v > 0).fold(0.0, (s, v) => s + v);
  }
}

class GroupExpenseNotifier extends StateNotifier<GroupExpenseState> {
  final GroupLocalDatasource _ds;
  final String _groupId;
  final Ref _ref;
  static const _uuid = Uuid();

  GroupExpenseNotifier(this._ds, this._groupId, this._ref)
      : super(const GroupExpenseState()) {
    _load();
    _syncExpensesFromCloud();
  }

  bool get _isConnected {
    final hasNetwork = _ref.read(connectivityProvider);
    final isAuthenticated = _ref.read(cloudAuthProvider).isConnected;
    return hasNetwork && isAuthenticated;
  }

  void _load() {
    state = state.copyWith(
      expenses: _ds.getExpensesForGroup(_groupId),
      isLoading: false,
    );
  }

  Future<void> _syncExpensesFromCloud() async {
    if (!_isConnected) return;
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.group(_groupId));
      final data = res.data['data'] as Map<String, dynamic>;
      final serverExpenses = (data['expenses'] as List?) ?? [];
      for (final e in serverExpenses) {
        final exp = GroupExpense.fromServerJson(e as Map<String, dynamic>);
        await _ds.saveGroupExpense(exp);
      }
      if (mounted) {
        _load();
        state = state.copyWith(error: null);
      }
    } on DioException catch (e) {
      if (mounted) {
        state = state.copyWith(error: formatDioError(e));
      }
    }
  }

  Future<void> addExpense({
    required double amount,
    required String description,
    required String paidByMemberId,
    required SplitType splitType,
    required List<SplitShare> shares,
    DateTime? date,
    String? note,
  }) async {
    final expenseId = _uuid.v4();
    if (_isConnected) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.post(ApiEndpoints.groupExpenses(_groupId), data: {
          'amount': amount,
          'description': description,
          'paidByMemberId': paidByMemberId,
          'splitType': splitType.name,
          'shares': shares
              .map((s) => {'memberId': s.memberId, 'amount': s.amount})
              .toList(),
          'date': (date ?? DateTime.now()).toIso8601String(),
          if (note != null) 'note': note,
        });
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
    final expense = GroupExpense(
      id: expenseId,
      groupId: _groupId,
      amount: amount,
      description: description,
      paidByMemberId: paidByMemberId,
      splitType: splitType,
      shares: shares,
      date: date ?? DateTime.now(),
      note: note,
    );
    await _ds.saveGroupExpense(expense);
    if (mounted) {
      state = state.copyWith(expenses: [expense, ...state.expenses]);
    }
  }

  /// Re-fetches expenses from the server (call after a failed mutation).
  Future<void> refresh() => _syncExpensesFromCloud();

  Future<void> deleteExpense(String expenseId) async {
    if (!_isConnected) {
      if (mounted) {
        state = state.copyWith(
          error: 'You need to be online to delete a group expense.',
        );
      }
      throw Exception('You need to be online to delete a group expense.');
    }
    try {
      final dio = _ref.read(dioProvider);
      await dio.delete(ApiEndpoints.groupExpense(_groupId, expenseId));
    } on DioException catch (e) {
      if (e.response?.statusCode != null && e.response!.statusCode! >= 400) {
        if (mounted) {
          state = state.copyWith(
            error: formatDioError(
              e,
              fallback: 'Failed to delete expense. Please try again.',
            ),
          );
        }
        throw Exception(formatDioError(
          e,
          fallback: 'Failed to delete expense. Please try again.',
        ));
      }
    }
    await _ds.deleteGroupExpense(_groupId, expenseId);
    if (mounted) {
      state = state.copyWith(
        expenses: state.expenses.where((e) => e.id != expenseId).toList(),
        error: null,
      );
    }
  }

  /// Records a settlement payment as a group expense so all members can see it
  /// and future balance calculations automatically go to ₹0 for this pair.
  Future<void> settleUp({
    required String fromMemberId,
    required String toMemberId,
    required double amount,
  }) async {
    if (!_isConnected) {
      if (mounted) {
        state = state.copyWith(
          error: 'You need to be online to record a settlement.',
        );
      }
      throw Exception('You need to be online to record a settlement.');
    }
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.groupSettle(_groupId), data: {
        'fromMemberId': fromMemberId,
        'toMemberId': toMemberId,
        'amount': amount,
      });
      final data = res.data['data'] as Map<String, dynamic>;
      final expense = GroupExpense.fromServerJson(data);
      await _ds.saveGroupExpense(expense);
      if (mounted) {
        state =
            state.copyWith(expenses: [expense, ...state.expenses], error: null);
      }
    } on DioException catch (e) {
      if (mounted) {
        state = state.copyWith(
            error: formatDioError(
          e,
          fallback: 'Failed to record settlement. Check your connection.',
        ));
      }
      throw Exception(formatDioError(
        e,
        fallback: 'Failed to record settlement. Check your connection.',
      ));
    }
  }
}

final groupExpenseProvider = StateNotifierProvider.family<GroupExpenseNotifier,
    GroupExpenseState, String>((ref, groupId) {
  final ds = ref.watch(groupDatasourceProvider);
  return GroupExpenseNotifier(ds, groupId, ref);
});
