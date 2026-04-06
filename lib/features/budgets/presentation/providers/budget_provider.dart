import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../data/datasources/budget_local_datasource.dart';
import '../../domain/entities/budget.dart';

// Enriched budget: adds spent amount
class BudgetEnvelope {
  final Budget budget;
  final double spentAmount;
  final double
      carryForwardAmount; // unspent amount rolled over from previous month

  const BudgetEnvelope({
    required this.budget,
    required this.spentAmount,
    this.carryForwardAmount = 0.0,
  });

  double get allocatedAmount => budget.allocatedAmount; // base allocation
  double get effectiveAllocated =>
      budget.allocatedAmount + carryForwardAmount; // base + carry
  double get remainingAmount => effectiveAllocated - spentAmount;
  double get progressPercent => effectiveAllocated > 0
      ? (spentAmount / effectiveAllocated).clamp(0.0, 1.2)
      : 0.0;
  bool get isOverBudget => spentAmount > effectiveAllocated;
}

class BudgetState {
  final List<BudgetEnvelope> envelopes;
  final int month;
  final int year;
  final bool isLoading;
  final String? error;

  const BudgetState({
    this.envelopes = const [],
    required this.month,
    required this.year,
    this.isLoading = false,
    this.error,
  });

  double get totalAllocated =>
      envelopes.fold(0.0, (s, e) => s + e.allocatedAmount);
  double get totalSpent => envelopes.fold(0.0, (s, e) => s + e.spentAmount);

  BudgetState copyWith({
    List<BudgetEnvelope>? envelopes,
    int? month,
    int? year,
    bool? isLoading,
    Object? error = _sentinel,
  }) =>
      BudgetState(
        envelopes: envelopes ?? this.envelopes,
        month: month ?? this.month,
        year: year ?? this.year,
        isLoading: isLoading ?? this.isLoading,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();
}

class BudgetNotifier extends StateNotifier<BudgetState> {
  final BudgetLocalDatasource _ds;
  final Ref _ref;

  BudgetNotifier(this._ds, this._ref)
      : super(BudgetState(
          month: DateTime.now().month,
          year: DateTime.now().year,
        )) {
    _load();
    _syncFromCloud();
  }

  bool _initialLoadDone = false;

  bool get _isConnected {
    final hasNetwork = _ref.read(connectivityProvider);
    final isAuthenticated = _ref.read(cloudAuthProvider).isConnected;
    return hasNetwork && isAuthenticated;
  }

  /// Fetch budgets from server and hydrate local store for current month.
  Future<void> _syncFromCloud() async {
    if (!_isConnected) return;
    try {
      final dio = _ref.read(dioProvider);
      final res = await dio.get(
        ApiEndpoints.budgets,
        queryParameters: {'month': state.month, 'year': state.year},
      );
      final list = (res.data['data'] as List?) ?? [];
      for (final raw in list.cast<Map<String, dynamic>>()) {
        final b = Budget(
          id: (raw['id'] ?? raw['_id']) as String,
          categoryKey: raw['categoryKey'] as String,
          allocatedAmount: ((raw['allocatedAmount'] as num?) ?? 0).toDouble(),
          month: raw['month'] as int,
          year: raw['year'] as int,
          carryForward: raw['carryForward'] as bool? ?? false,
          updatedAt: _parseDateTime(raw['updatedAt']) ?? DateTime.now(),
        );
        await _ds.saveBudget(b, trackPending: false);
      }
      if (mounted) {
        state = state.copyWith(error: null);
      }
      if (mounted) _load();
    } on DioException catch (e) {
      // Network unavailable — keep local data
      if (mounted) {
        state = state.copyWith(error: formatDioError(e));
      }
    }
  }

  void _load() {
    final prev = _initialLoadDone ? state.envelopes : <BudgetEnvelope>[];
    final budgets = _ds.getBudgetsForMonth(state.month, state.year);
    final expState = _ref.read(expenseProvider);
    // Compute spending for THIS budget's month/year directly from all loaded
    // expenses, so navigating months in the budget page never reads spending
    // from the expense provider's own selectedMonth filter.
    final spendingByKey = <String, double>{};
    for (final e in expState.expenses) {
      if (!e.isIncome &&
          e.date.month == state.month &&
          e.date.year == state.year) {
        spendingByKey[e.category.key] =
            (spendingByKey[e.category.key] ?? 0) + e.amount;
      }
    }

    // ── Carry-forward: compute previous month remaining per category ────────
    final prevMonth = state.month == 1 ? 12 : state.month - 1;
    final prevYear = state.month == 1 ? state.year - 1 : state.year;
    final prevBudgets = _ds.getBudgetsForMonth(prevMonth, prevYear);
    final prevBudgetMap = {for (final b in prevBudgets) b.categoryKey: b};
    // Compute prev-month spending directly from all loaded expenses
    final prevSpendingByKey = <String, double>{};
    for (final e in expState.expenses) {
      if (!e.isIncome && e.date.month == prevMonth && e.date.year == prevYear) {
        prevSpendingByKey[e.category.key] =
            (prevSpendingByKey[e.category.key] ?? 0) + e.amount;
      }
    }

    final envelopes = budgets.map((b) {
      final spent = spendingByKey[b.categoryKey] ?? 0.0;
      var carry = 0.0;
      if (b.carryForward) {
        final pb = prevBudgetMap[b.categoryKey];
        if (pb != null) {
          final prevSpent = prevSpendingByKey[b.categoryKey] ?? 0.0;
          final remaining = pb.allocatedAmount - prevSpent;
          if (remaining > 0) carry = remaining;
        }
      }
      return BudgetEnvelope(
          budget: b, spentAmount: spent, carryForwardAmount: carry);
    }).toList();
    state = state.copyWith(envelopes: envelopes, isLoading: false);

    // ── Notification threshold detection ────────────────────────────────────
    if (_initialLoadDone && _ref.read(settingsProvider).notifBudgetAlerts) {
      for (final env in envelopes) {
        final prevEnv =
            prev.where((e) => e.budget.id == env.budget.id).firstOrNull;
        final prevPct = prevEnv?.progressPercent ?? 0.0;
        final newPct = env.progressPercent;
        final label = env.budget.categoryKey;
        if (prevPct < 1.0 && newPct >= 1.0) {
          NotificationService.showBudgetOverLimit(label);
        } else if (prevPct < 0.8 && newPct >= 0.8) {
          NotificationService.showBudgetWarning(label, newPct);
        }
      }
    }

    _initialLoadDone = true;
  }

  void setMonth(int month, int year) {
    state = state.copyWith(month: month, year: year);
    _load();
    _syncFromCloud();
  }

  void nextMonth() {
    int m = state.month + 1, y = state.year;
    if (m > 12) {
      m = 1;
      y++;
    }
    setMonth(m, y);
  }

  void previousMonth() {
    int m = state.month - 1, y = state.year;
    if (m < 1) {
      m = 12;
      y--;
    }
    setMonth(m, y);
  }

  Future<void> addBudget(Budget budget) async {
    final localBudget = budget.copyWith(updatedAt: DateTime.now());
    await _ds.saveBudget(localBudget);
    if (_isConnected) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.post(ApiEndpoints.budgets, data: {
          'id': localBudget.id,
          'categoryKey': localBudget.categoryKey,
          'allocatedAmount': localBudget.allocatedAmount,
          'month': localBudget.month,
          'year': localBudget.year,
          'carryForward': localBudget.carryForward,
        });
        await _ds.clearPendingUpsert(localBudget.id);
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        // Server sync failed — local data already saved, will sync next pull
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
    _load();
  }

  Future<void> deleteBudget(String id) async {
    await _ds.deleteBudget(id, state.month, state.year);
    if (_isConnected) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.delete(ApiEndpoints.budget(id));
        await _ds.clearPendingDeletion(id);
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        // Server sync failed — local data already deleted
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
    _load();
  }

  /// Copies all envelopes from the previous month into the current month,
  /// skipping any category that already has a budget this month.
  Future<void> copyFromPreviousMonth() async {
    final prevMonth = state.month == 1 ? 12 : state.month - 1;
    final prevYear = state.month == 1 ? state.year - 1 : state.year;
    final prevBudgets = _ds.getBudgetsForMonth(prevMonth, prevYear);
    if (prevBudgets.isEmpty) return;
    final existing = _ds.getBudgetsForMonth(state.month, state.year);
    final existingKeys = existing.map((b) => b.categoryKey).toSet();
    for (final pb in prevBudgets) {
      if (!existingKeys.contains(pb.categoryKey)) {
        await addBudget(Budget(
          id: const Uuid().v4(),
          categoryKey: pb.categoryKey,
          allocatedAmount: pb.allocatedAmount,
          month: state.month,
          year: state.year,
          carryForward: pb.carryForward,
        ));
      }
    }
  }

  /// Refresh spent amounts based on current expense state
  void refresh() => _load();

  Future<void> reloadFromCloud() async {
    state = state.copyWith(isLoading: true, error: null);
    await _syncFromCloud();
    if (!mounted) return;
    state = state.copyWith(isLoading: false);
  }

  DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}

final budgetDatasourceProvider = Provider<BudgetLocalDatasource>(
  (_) => BudgetLocalDatasource(),
);

final budgetProvider =
    StateNotifierProvider<BudgetNotifier, BudgetState>((ref) {
  final ds = ref.watch(budgetDatasourceProvider);
  final notifier = BudgetNotifier(ds, ref);

  // Refresh spent amounts when expenses change without recreating notifier.
  ref.listen<ExpenseState>(expenseProvider, (_, __) {
    notifier.refresh();
  });

  return notifier;
});
