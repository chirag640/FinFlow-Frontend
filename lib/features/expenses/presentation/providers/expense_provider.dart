import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../../core/services/recurring_engine_service.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';
import '../../data/datasources/expense_local_datasource.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';

final expenseDatasourceProvider = Provider<ExpenseLocalDatasource>(
  (ref) => ExpenseLocalDatasource(),
);

// ── Expense Filters ───────────────────────────────────────────────────────────
class ExpenseFilters {
  final Set<ExpenseCategory> categories; // empty = all
  final bool? incomeOnly; // null = both, true = income, false = expenses
  final DateTime? dateFrom; // inclusive
  final DateTime? dateTo; // inclusive
  final double? minAmount;
  final double? maxAmount;

  const ExpenseFilters({
    this.categories = const {},
    this.incomeOnly,
    this.dateFrom,
    this.dateTo,
    this.minAmount,
    this.maxAmount,
  });

  bool get _hasDateRange => dateFrom != null || dateTo != null;
  bool get _hasAmountRange => minAmount != null || maxAmount != null;

  bool get isEmpty =>
      categories.isEmpty &&
      incomeOnly == null &&
      !_hasDateRange &&
      !_hasAmountRange;

  int get activeCount =>
      (categories.isEmpty ? 0 : 1) +
      (incomeOnly == null ? 0 : 1) +
      (_hasDateRange ? 1 : 0) +
      (_hasAmountRange ? 1 : 0);

  ExpenseFilters copyWith({
    Set<ExpenseCategory>? categories,
    Object? incomeOnly = _sentinel, // use sentinel to allow explicit null
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
    Object? minAmount = _sentinel,
    Object? maxAmount = _sentinel,
  }) =>
      ExpenseFilters(
        categories: categories ?? this.categories,
        incomeOnly:
            incomeOnly == _sentinel ? this.incomeOnly : incomeOnly as bool?,
        dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as DateTime?,
        dateTo: dateTo == _sentinel ? this.dateTo : dateTo as DateTime?,
        minAmount:
            minAmount == _sentinel ? this.minAmount : minAmount as double?,
        maxAmount:
            maxAmount == _sentinel ? this.maxAmount : maxAmount as double?,
      );

  static const _sentinel = Object();
}

// ── Expense State ─────────────────────────────────────────────────────────────
class ExpenseState {
  final List<Expense> expenses;
  final bool isLoading;
  final int selectedYear;
  final int selectedMonth;
  final String searchQuery;
  final ExpenseFilters activeFilters;
  final String? error;

  const ExpenseState({
    this.expenses = const [],
    this.isLoading = false,
    required this.selectedYear,
    required this.selectedMonth,
    this.searchQuery = '',
    this.activeFilters = const ExpenseFilters(),
    this.error,
  });

  ExpenseState copyWith({
    List<Expense>? expenses,
    bool? isLoading,
    int? selectedYear,
    int? selectedMonth,
    String? searchQuery,
    ExpenseFilters? activeFilters,
    Object? error = _sentinel,
  }) =>
      ExpenseState(
        expenses: expenses ?? this.expenses,
        isLoading: isLoading ?? this.isLoading,
        selectedYear: selectedYear ?? this.selectedYear,
        selectedMonth: selectedMonth ?? this.selectedMonth,
        searchQuery: searchQuery ?? this.searchQuery,
        activeFilters: activeFilters ?? this.activeFilters,
        error: identical(error, _sentinel) ? this.error : error as String?,
      );

  static const _sentinel = Object();

  List<Expense> get filteredExpenses {
    // 1. Search overrides everything
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      return expenses
          .where((e) =>
              e.description.toLowerCase().contains(q) ||
              e.category.label.toLowerCase().contains(q))
          .toList();
    }

    // 2. Date slice (explicit range overrides month slice)
    Iterable<Expense> result = expenses;
    if (activeFilters.dateFrom != null || activeFilters.dateTo != null) {
      final from = activeFilters.dateFrom == null
          ? null
          : DateTime(
              activeFilters.dateFrom!.year,
              activeFilters.dateFrom!.month,
              activeFilters.dateFrom!.day,
            );
      final to = activeFilters.dateTo == null
          ? null
          : DateTime(
              activeFilters.dateTo!.year,
              activeFilters.dateTo!.month,
              activeFilters.dateTo!.day,
              23,
              59,
              59,
              999,
            );

      result = result.where((e) {
        if (from != null && e.date.isBefore(from)) return false;
        if (to != null && e.date.isAfter(to)) return false;
        return true;
      });
    } else {
      result = result.where(
        (e) => e.date.year == selectedYear && e.date.month == selectedMonth,
      );
    }

    // 3. Apply active category filters
    if (activeFilters.categories.isNotEmpty) {
      result =
          result.where((e) => activeFilters.categories.contains(e.category));
    }

    // 4. Apply income/expense filter
    if (activeFilters.incomeOnly != null) {
      result = result.where((e) => e.isIncome == activeFilters.incomeOnly);
    }

    // 5. Apply amount range
    if (activeFilters.minAmount != null) {
      result = result.where((e) => e.amount >= activeFilters.minAmount!);
    }
    if (activeFilters.maxAmount != null) {
      result = result.where((e) => e.amount <= activeFilters.maxAmount!);
    }

    return result.toList();
  }

  double get totalSpent => filteredExpenses
      .where((e) => !e.isIncome)
      .fold(0.0, (s, e) => s + e.amount);

  double get totalIncome => filteredExpenses
      .where((e) => e.isIncome)
      .fold(0.0, (s, e) => s + e.amount);

  Map<ExpenseCategory, double> get byCategory {
    final map = <ExpenseCategory, double>{};
    for (final e in filteredExpenses.where((e) => !e.isIncome)) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }

  /// Daily spending for the last [days] days
  List<double> dailySpending(int days) {
    final now = DateTime.now();
    return List.generate(days, (i) {
      final day = now.subtract(Duration(days: days - 1 - i));
      return expenses
          .where(
            (e) =>
                !e.isIncome &&
                e.date.year == day.year &&
                e.date.month == day.month &&
                e.date.day == day.day,
          )
          .fold(0.0, (s, e) => s + e.amount);
    });
  }
}

// ── Expense Notifier ──────────────────────────────────────────────────────────
class ExpenseNotifier extends StateNotifier<ExpenseState> {
  final ExpenseLocalDatasource _ds;
  final Ref _ref;
  static const _uuid = Uuid();

  ExpenseNotifier(this._ds, this._ref)
      : super(
          ExpenseState(
            selectedYear: DateTime.now().year,
            selectedMonth: DateTime.now().month,
          ),
        ) {
    _load();
  }

  /// True when the device has network connectivity AND the user is authenticated.
  /// Synchronous — reads live Riverpod state; no async storage round-trip needed.
  bool get _isOnline {
    final hasNetwork = _ref.read(connectivityProvider);
    final isAuthenticated = _ref.read(cloudAuthProvider).isConnected;
    return hasNetwork && isAuthenticated;
  }

  void _load() {
    state = state.copyWith(isLoading: true);
    final allExpenses = _ds.getAll();
    state = state.copyWith(expenses: allExpenses, isLoading: false);
    _runRecurringEngine();
  }

  Future<void> _runRecurringEngine() async {
    final templates =
        state.expenses.where((e) => e.isRecurring && !e.isIncome).toList();
    if (templates.isEmpty) return;
    await RecurringEngineService.run(this, templates);
  }

  Future<void> addExpense({
    required double amount,
    required String description,
    required ExpenseCategory category,
    required DateTime date,
    String? note,
    int? recurringDueDay,
    String? receiptImageBase64,
    String? receiptImageMimeType,
    String? receiptImageUrl,
    String? receiptStorageKey,
    String? receiptOcrText,
    bool isIncome = false,
    bool isRecurring = false,
    RecurringFrequency? recurringFrequency,
  }) async {
    final expense = Expense(
      id: _uuid.v4(),
      amount: amount,
      description: description,
      category: category,
      date: date,
      note: note,
      recurringDueDay: recurringDueDay,
      receiptImageBase64: receiptImageBase64,
      receiptImageMimeType: receiptImageMimeType,
      receiptImageUrl: receiptImageUrl,
      receiptStorageKey: receiptStorageKey,
      receiptOcrText: receiptOcrText,
      isIncome: isIncome,
      isRecurring: isRecurring,
      recurringFrequency: recurringFrequency,
    );
    // Save locally first for instant UI feedback
    await _ds.save(expense);
    if (!mounted) return;
    state = state.copyWith(expenses: [expense, ...state.expenses]);
    // Push to API immediately when online; batch sync handles offline fallback
    if (_isOnline && mounted) {
      try {
        final dio = _ref.read(dioProvider);
        final hasExternalReceiptRef =
            (receiptImageUrl != null && receiptImageUrl.isNotEmpty) ||
                (receiptStorageKey != null && receiptStorageKey.isNotEmpty);
        await dio.post(ApiEndpoints.expenses, data: {
          'id': expense
              .id, // client UUID — server uses it as _id (no duplicates on sync)
          'amount': amount,
          'description': description,
          'category': category.name,
          'date': date.toIso8601String(),
          if (note != null) 'notes': note,
          if (!hasExternalReceiptRef && receiptImageBase64 != null)
            'receiptImageBase64': receiptImageBase64,
          if (receiptImageMimeType != null)
            'receiptImageMimeType': receiptImageMimeType,
          if (receiptImageUrl != null) 'receiptImageUrl': receiptImageUrl,
          if (receiptStorageKey != null) 'receiptStorageKey': receiptStorageKey,
          if (receiptOcrText != null) 'receiptOcrText': receiptOcrText,
          'isIncome': isIncome,
          'isRecurring': isRecurring,
          'recurringDueDay': recurringDueDay,
          if (recurringFrequency != null)
            'recurringRule': recurringFrequency.name,
        });
        if (!mounted) return;
        await _ds.clearPendingUpsert(expense.id);
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        // Offline or transient error — already in local storage,
        // batch sync will push it on next connection.
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
  }

  Future<void> deleteExpense(String id) async {
    await _ds.delete(id);
    if (!mounted) return;
    state = state.copyWith(
      expenses: state.expenses.where((e) => e.id != id).toList(),
    );
    if (_isOnline && mounted) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.delete(ApiEndpoints.expense(id));
        if (!mounted) return;
        await _ds.clearPendingDeletion(id);
        if (mounted) {
          state = state.copyWith(error: null);
        }
        return; // Server confirmed — no need to queue
      } on DioException catch (e) {
        // Network error during online attempt — fall through to queue
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
    // Either offline or API failed — queued deletion stays pending for sync push.
  }

  /// Batch-upsert expenses received from the server during sync.
  ///
  /// All local saves happen first, then a SINGLE `state =` fires after
  /// `Future.delayed(Duration.zero)` — which yields to the next Dart event-loop
  /// iteration. This ensures Flutter's element tree has fully committed any
  /// pending disposals (deactivate → unmount → Riverpod unsubscribe) before
  /// the notification fires, preventing the defunct-element assertion.
  Future<void> bulkUpsertFromSync(List<Expense> expenses) async {
    if (expenses.isEmpty) return;
    for (final e in expenses) {
      await _ds.save(e, trackPending: false);
    }
    // Yield past the current event to let Riverpod clean up disposed listeners.
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    var list = List<Expense>.from(state.expenses);
    for (final e in expenses) {
      final idx = list.indexWhere((x) => x.id == e.id);
      if (idx >= 0) {
        list[idx] = e;
      } else {
        list.insert(0, e);
      }
    }
    state = state.copyWith(expenses: list);
  }

  /// Batch-delete expenses received as deleted from server during sync.
  /// Same Future.delayed deferral as bulkUpsertFromSync.
  Future<void> bulkDeleteFromSync(List<String> ids) async {
    if (ids.isEmpty) return;
    for (final id in ids) {
      await _ds.delete(id, trackPending: false);
    }
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    state = state.copyWith(
      expenses: state.expenses.where((e) => !ids.contains(e.id)).toList(),
    );
  }

  Future<void> updateExpense(Expense updated) async {
    final localUpdated = updated.copyWith(updatedAt: DateTime.now());
    await _ds.save(localUpdated);
    if (!mounted) return;
    state = state.copyWith(
      expenses: state.expenses
          .map((e) => e.id == updated.id ? localUpdated : e)
          .toList(),
    );
    if (_isOnline && mounted) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.patch(ApiEndpoints.expense(localUpdated.id), data: {
          'amount': localUpdated.amount,
          'description': localUpdated.description,
          'category': localUpdated.category.name,
          'date': localUpdated.date.toIso8601String(),
          'notes': localUpdated.note,
          'receiptImageBase64': localUpdated.receiptImageBase64,
          'receiptImageMimeType': localUpdated.receiptImageMimeType,
          'receiptImageUrl': localUpdated.receiptImageUrl,
          'receiptStorageKey': localUpdated.receiptStorageKey,
          'receiptOcrText': localUpdated.receiptOcrText,
          'isIncome': localUpdated.isIncome,
          'isRecurring': localUpdated.isRecurring,
          'recurringRule': localUpdated.isRecurring
              ? localUpdated.recurringFrequency?.name
              : null,
          'recurringDueDay': localUpdated.isRecurring &&
                  localUpdated.recurringFrequency == RecurringFrequency.monthly
              ? localUpdated.recurringDueDay
              : null,
        });
        if (!mounted) return;
        await _ds.clearPendingUpsert(localUpdated.id);
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
  }

  Future<List<Expense>> findPotentialDuplicates({
    required double amount,
    required String description,
    required DateTime date,
    required bool isIncome,
  }) async {
    if (!_isOnline) return const [];

    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.post(
        ApiEndpoints.expenseDuplicateCheck,
        data: {
          'amount': amount,
          'description': description,
          'date': date.toUtc().toIso8601String(),
          'isIncome': isIncome,
        },
      );

      final data = response.data is Map<String, dynamic>
          ? response.data['data'] as Map<String, dynamic>?
          : null;
      final rawCandidates = (data?['candidates'] as List?) ?? const [];

      return rawCandidates
          .whereType<Map>()
          .map((raw) => _mapServerExpense(raw.cast<String, dynamic>()))
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<void> deleteExpensesBulk(List<String> ids) async {
    final uniqueIds = ids.toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return;
    final idSet = uniqueIds.toSet();

    for (final id in uniqueIds) {
      await _ds.delete(id);
    }

    if (!mounted) return;
    state = state.copyWith(
      expenses: state.expenses.where((e) => !idSet.contains(e.id)).toList(),
    );

    if (_isOnline && mounted) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.post(ApiEndpoints.expenseBatch, data: {
          'action': 'delete',
          'ids': uniqueIds,
        });
        if (!mounted) return;
        for (final id in uniqueIds) {
          await _ds.clearPendingDeletion(id);
        }
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
  }

  Future<void> updateExpensesCategoryBulk({
    required List<String> ids,
    required ExpenseCategory category,
  }) async {
    final uniqueIds = ids.toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return;
    final idSet = uniqueIds.toSet();
    final now = DateTime.now();

    final updatedExpenses = state.expenses
        .map((expense) => idSet.contains(expense.id)
            ? expense.copyWith(category: category, updatedAt: now)
            : expense)
        .toList(growable: false);

    for (final expense in updatedExpenses.where((e) => idSet.contains(e.id))) {
      await _ds.save(expense);
    }

    if (!mounted) return;
    state = state.copyWith(expenses: updatedExpenses);

    if (_isOnline && mounted) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.post(ApiEndpoints.expenseBatch, data: {
          'action': 'updateCategory',
          'ids': uniqueIds,
          'category': category.name,
        });
        if (!mounted) return;
        for (final id in uniqueIds) {
          await _ds.clearPendingUpsert(id);
        }
        if (mounted) {
          state = state.copyWith(error: null);
        }
      } on DioException catch (e) {
        if (mounted) {
          state = state.copyWith(error: formatDioError(e));
        }
      }
    }
  }

  Expense _mapServerExpense(Map<String, dynamic> raw) {
    return Expense.fromJson({
      'id': raw['id'],
      'amount': (raw['amount'] as num?)?.toDouble() ?? 0,
      'description': raw['description'] as String? ?? '',
      'category': raw['category'] as String? ?? ExpenseCategory.other.name,
      'date': raw['date']?.toString() ?? DateTime.now().toIso8601String(),
      'note': raw['notes'] ?? raw['note'],
      'isIncome': raw['isIncome'] == true,
      'isRecurring': raw['isRecurring'] == true,
      'recurringFrequency': raw['recurringRule'] ?? raw['recurringFrequency'],
      'recurringDueDay': (raw['recurringDueDay'] as num?)?.toInt(),
      'receiptImageBase64': raw['receiptImageBase64'],
      'receiptImageMimeType': raw['receiptImageMimeType'],
      'receiptImageUrl': raw['receiptImageUrl'],
      'receiptStorageKey': raw['receiptStorageKey'],
      'receiptOcrText': raw['receiptOcrText'],
      'updatedAt': (raw['updatedAt'] ?? raw['date'])?.toString() ??
          DateTime.now().toIso8601String(),
    });
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void clearSearch() {
    state = state.copyWith(searchQuery: '');
  }

  void setFilters(ExpenseFilters filters) {
    state = state.copyWith(activeFilters: filters);
  }

  void clearFilters() {
    state = state.copyWith(activeFilters: const ExpenseFilters());
  }

  void refresh() {
    state = state.copyWith(error: null);
    _load();
  }

  void setMonth(int year, int month) {
    state = state.copyWith(selectedYear: year, selectedMonth: month);
  }

  void previousMonth() {
    var m = state.selectedMonth - 1;
    var y = state.selectedYear;
    if (m < 1) {
      m = 12;
      y--;
    }
    state = state.copyWith(selectedYear: y, selectedMonth: m);
  }

  void nextMonth() {
    var m = state.selectedMonth + 1;
    var y = state.selectedYear;
    if (m > 12) {
      m = 1;
      y++;
    }
    state = state.copyWith(selectedYear: y, selectedMonth: m);
  }
}

final expenseProvider = StateNotifierProvider<ExpenseNotifier, ExpenseState>((
  ref,
) {
  final ds = ref.watch(expenseDatasourceProvider);
  return ExpenseNotifier(ds, ref);
});
