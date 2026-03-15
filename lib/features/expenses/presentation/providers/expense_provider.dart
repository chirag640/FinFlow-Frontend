import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/providers/connectivity_provider.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../../../core/services/recurring_engine_service.dart';
import '../../data/datasources/expense_local_datasource.dart';

final expenseDatasourceProvider = Provider<ExpenseLocalDatasource>(
  (ref) => ExpenseLocalDatasource(),
);

// ── Expense Filters ───────────────────────────────────────────────────────────
class ExpenseFilters {
  final Set<ExpenseCategory> categories; // empty = all
  final bool? incomeOnly; // null = both, true = income, false = expenses

  const ExpenseFilters({this.categories = const {}, this.incomeOnly});

  bool get isEmpty => categories.isEmpty && incomeOnly == null;
  int get activeCount =>
      (categories.isEmpty ? 0 : 1) + (incomeOnly == null ? 0 : 1);

  ExpenseFilters copyWith({
    Set<ExpenseCategory>? categories,
    Object? incomeOnly = _sentinel, // use sentinel to allow explicit null
  }) =>
      ExpenseFilters(
        categories: categories ?? this.categories,
        incomeOnly:
            incomeOnly == _sentinel ? this.incomeOnly : incomeOnly as bool?,
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

    // 2. Month slice
    Iterable<Expense> result = expenses.where(
      (e) => e.date.year == selectedYear && e.date.month == selectedMonth,
    );

    // 3. Apply active category filters
    if (activeFilters.categories.isNotEmpty) {
      result =
          result.where((e) => activeFilters.categories.contains(e.category));
    }

    // 4. Apply income/expense filter
    if (activeFilters.incomeOnly != null) {
      result = result.where((e) => e.isIncome == activeFilters.incomeOnly);
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
      isIncome: isIncome,
      isRecurring: isRecurring,
      recurringFrequency: recurringFrequency,
    );
    // Save locally first for instant UI feedback
    await _ds.save(expense);
    state = state.copyWith(expenses: [expense, ...state.expenses]);
    // Push to API immediately when online; batch sync handles offline fallback
    if (_isOnline) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.post(ApiEndpoints.expenses, data: {
          'id': expense
              .id, // client UUID — server uses it as _id (no duplicates on sync)
          'amount': amount,
          'description': description,
          'category': category.name,
          'date': date.toIso8601String(),
          if (note != null) 'notes': note,
          'isIncome': isIncome,
          'isRecurring': isRecurring,
          if (recurringFrequency != null)
            'recurringRule': recurringFrequency.name,
        });
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
    state = state.copyWith(
      expenses: state.expenses.where((e) => e.id != id).toList(),
    );
    if (_isOnline) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.delete(ApiEndpoints.expense(id));
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
    // Either offline or API failed — queue deletion for next sync push
    await _ds.addPendingDeletion(id);
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
      await _ds.save(e);
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
      await _ds.delete(id);
    }
    await Future.delayed(Duration.zero);
    if (!mounted) return;
    state = state.copyWith(
      expenses: state.expenses.where((e) => !ids.contains(e.id)).toList(),
    );
  }

  Future<void> updateExpense(Expense updated) async {
    await _ds.save(updated);
    state = state.copyWith(
      expenses:
          state.expenses.map((e) => e.id == updated.id ? updated : e).toList(),
    );
    if (_isOnline) {
      try {
        final dio = _ref.read(dioProvider);
        await dio.patch(ApiEndpoints.expense(updated.id), data: {
          'amount': updated.amount,
          'description': updated.description,
          'category': updated.category.name,
          'date': updated.date.toIso8601String(),
          'notes': updated.note,
          'isIncome': updated.isIncome,
          'isRecurring': updated.isRecurring,
          if (updated.recurringFrequency != null)
            'recurringRule': updated.recurringFrequency!.name,
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
