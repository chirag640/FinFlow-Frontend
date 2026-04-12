import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_async_state.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/radius.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../providers/expense_provider.dart';
import '../widgets/expense_list_tile.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  bool _searchActive = false;
  bool _selectionMode = false;
  bool _isBulkActionInProgress = false;
  final Set<String> _selectedExpenseIds = <String>{};
  final _searchCtrl = TextEditingController();
  late final ExpenseNotifier _expenseNotifier;

  @override
  void initState() {
    super.initState();
    _expenseNotifier = ref.read(expenseProvider.notifier);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    // Clear search query when leaving page
    _expenseNotifier.clearSearch();
    super.dispose();
  }

  void _toggleSearch() {
    if (_selectionMode) {
      _setSelectionMode(false);
    }
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      _expenseNotifier.clearSearch();
    }
  }

  void _setSelectionMode(bool enabled) {
    setState(() {
      _selectionMode = enabled;
      if (!enabled) {
        _selectedExpenseIds.clear();
      } else {
        _searchActive = false;
        _searchCtrl.clear();
        _expenseNotifier.clearSearch();
      }
    });
  }

  void _toggleExpenseSelection(String expenseId) {
    setState(() {
      if (_selectedExpenseIds.contains(expenseId)) {
        _selectedExpenseIds.remove(expenseId);
      } else {
        _selectedExpenseIds.add(expenseId);
      }
      _selectionMode = _selectedExpenseIds.isNotEmpty;
    });
  }

  Future<void> _applyBatchDelete(WidgetRef ref) async {
    if (_selectedExpenseIds.isEmpty || _isBulkActionInProgress) return;
    final selected = _selectedExpenseIds.toList(growable: false);
    final confirmed = await DSConfirmDialog.show(
      context: context,
      title: 'Delete selected expenses?',
      message:
          'This will remove ${selected.length} selected transaction(s) from your records.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (confirmed != true) return;

    setState(() => _isBulkActionInProgress = true);
    await ref.read(expenseProvider.notifier).deleteExpensesBulk(selected);
    if (!mounted) return;
    setState(() {
      _isBulkActionInProgress = false;
      _selectionMode = false;
      _selectedExpenseIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${selected.length} expense(s)')),
    );
  }

  Future<ExpenseCategory?> _pickBatchCategory() {
    return showModalBottomSheet<ExpenseCategory>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Select category',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...ExpenseCategory.values.map(
              (category) => ListTile(
                leading:
                    Text(category.emoji, style: const TextStyle(fontSize: 20)),
                title: Text(category.label),
                onTap: () => Navigator.of(ctx).pop(category),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyBatchCategory(WidgetRef ref) async {
    if (_selectedExpenseIds.isEmpty || _isBulkActionInProgress) return;
    final category = await _pickBatchCategory();
    if (category == null) return;

    final selected = _selectedExpenseIds.toList(growable: false);
    setState(() => _isBulkActionInProgress = true);
    await ref.read(expenseProvider.notifier).updateExpensesCategoryBulk(
          ids: selected,
          category: category,
        );
    if (!mounted) return;
    setState(() {
      _isBulkActionInProgress = false;
      _selectionMode = false;
      _selectedExpenseIds.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Updated ${selected.length} expense(s) to ${category.label}',
        ),
      ),
    );
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, ExpenseState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterSheet(
        current: state.activeFilters,
        onApply: (filters) =>
            ref.read(expenseProvider.notifier).setFilters(filters),
        onClear: () => ref.read(expenseProvider.notifier).clearFilters(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(expenseProvider);
    final monthLabel = DateFormat('MMMM')
        .format(DateTime(state.selectedYear, state.selectedMonth));

    Widget buildBody() {
      if (state.isLoading) {
        return const DSAsyncState.loading(
          title: 'Loading expenses',
          message: 'Fetching your latest entries...',
        );
      }

      if (state.filteredExpenses.isEmpty) {
        if (state.error != null && state.error!.trim().isNotEmpty) {
          return DSAsyncState.error(
            title: 'Unable to load expenses',
            message: state.error,
            onRetry: () => ref.read(expenseProvider.notifier).refresh(),
          );
        }

        if (_searchActive || state.searchQuery.trim().isNotEmpty) {
          return const DSAsyncState.empty(
            emoji: '🔍',
            title: 'No expenses found',
            message: 'Try a different keyword',
          );
        }

        return DSAsyncState.empty(
          emoji: '💸',
          title: 'No expenses yet',
          message:
              'Tap the + button to log your first expense for $monthLabel.',
          actionLabel: 'Add Expense',
          onAction: () => context.push(AppRoutes.addExpense),
        );
      }

      return Column(
        children: [
          if (state.error != null && state.error!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: DSAsyncState.error(
                compact: true,
                title: 'Sync warning',
                message: state.error,
                onRetry: () => ref.read(expenseProvider.notifier).refresh(),
              ),
            ),
          Expanded(
              child: _ExpenseGroupedList(
            expenses: state.filteredExpenses,
            selectionMode: _selectionMode,
            selectedIds: _selectedExpenseIds,
            onToggleSelection: _toggleExpenseSelection,
            onStartSelection: (id) {
              if (_selectionMode) {
                _toggleExpenseSelection(id);
                return;
              }
              _setSelectionMode(true);
              _toggleExpenseSelection(id);
            },
          )),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            floating: true,
            snap: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            titleSpacing: 20,
            actionsPadding: const EdgeInsets.only(right: 8),
            title: _selectionMode
                ? Text(
                    '${_selectedExpenseIds.length} selected',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  )
                : _searchActive
                    ? TextField(
                        controller: _searchCtrl,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search expenses...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 16,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                        onChanged: (q) =>
                            ref.read(expenseProvider.notifier).setSearch(q),
                      )
                    : Text(
                        'Expenses',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
            actions: [
              if (_selectionMode) ...[
                Semantics(
                  label: 'Change category for selected expenses',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.label_outline_rounded),
                    onPressed:
                        _selectedExpenseIds.isEmpty || _isBulkActionInProgress
                            ? null
                            : () => _applyBatchCategory(ref),
                    tooltip: 'Change Category',
                  ),
                ),
                Semantics(
                  label: 'Delete selected expenses',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.error),
                    onPressed:
                        _selectedExpenseIds.isEmpty || _isBulkActionInProgress
                            ? null
                            : () => _applyBatchDelete(ref),
                    tooltip: 'Delete Selected',
                  ),
                ),
                Semantics(
                  label: 'Exit selection mode',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isBulkActionInProgress
                        ? null
                        : () => _setSelectionMode(false),
                    tooltip: 'Done',
                  ),
                ),
              ] else if (!_searchActive) ...[
                Semantics(
                  label: 'Open expense analytics',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.bar_chart_rounded,
                        color: AppColors.primary),
                    onPressed: () => context.push(AppRoutes.analytics),
                    tooltip: 'View Analytics',
                  ),
                ),
                // Filter icon with active-count badge
                Semantics(
                  label: state.activeFilters.isEmpty
                      ? 'Filter expenses'
                      : '${state.activeFilters.activeCount} filters active, tap to change filters',
                  button: true,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        icon: Icon(
                          state.activeFilters.isEmpty
                              ? Icons.tune_rounded
                              : Icons.tune_rounded,
                          color: state.activeFilters.isEmpty
                              ? colors.onSurfaceVariant
                              : AppColors.primary,
                        ),
                        onPressed: () => _showFilterSheet(context, ref, state),
                        tooltip: 'Filter',
                      ),
                      if (state.activeFilters.activeCount > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: ExcludeSemantics(
                            child: Container(
                              width: R.s(16),
                              height: R.s(16),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${state.activeFilters.activeCount}',
                                  style: TextStyle(
                                    fontSize: R.t(10),
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Select multiple expenses',
                  button: true,
                  child: IconButton(
                    icon: Icon(
                      Icons.checklist_rtl_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: () => _setSelectionMode(true),
                    tooltip: 'Select Multiple',
                  ),
                ),
              ],
              if (!_selectionMode)
                Semantics(
                  label: _searchActive ? 'Close search' : 'Search expenses',
                  button: true,
                  child: IconButton(
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _searchActive
                          ? Icon(
                              Icons.close_rounded,
                              key: const ValueKey('close'),
                              color: colors.onSurface,
                            )
                          : Icon(Icons.search_rounded,
                              key: const ValueKey('search'),
                              color: colors.onSurfaceVariant),
                    ),
                    onPressed: _toggleSearch,
                    tooltip: _searchActive ? 'Close search' : 'Search',
                  ),
                ),
            ],
            bottom: _searchActive || _selectionMode
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(144),
                    child: Column(
                      children: [
                        _MonthSelector(state: state),
                        _MonthSummaryBar(state: state),
                      ],
                    ),
                  ),
          ),
        ],
        body: buildBody(),
      ),
      floatingActionButton: _selectionMode
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.push(AppRoutes.addExpense),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add Expense',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
    );
  }
}

// ── Month Selector ────────────────────────────────────────────────────────────
class _MonthSelector extends ConsumerWidget {
  final ExpenseState state;
  const _MonthSelector({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final monthLabel = DateFormat(
      'MMMM yyyy',
    ).format(DateTime(state.selectedYear, state.selectedMonth));
    final isCurrentMonth = state.selectedYear == DateTime.now().year &&
        state.selectedMonth == DateTime.now().month;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _NavButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => ref.read(expenseProvider.notifier).previousMonth(),
          ),
          Expanded(
            child: Text(
              monthLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
          ),
          _NavButton(
            icon: Icons.chevron_right_rounded,
            onTap: isCurrentMonth
                ? null
                : () => ref.read(expenseProvider.notifier).nextMonth(),
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: R.s(36),
        height: R.s(36),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: AppRadius.smPlus,
        ),
        child: Icon(
          icon,
          size: R.s(20),
          color: onTap == null
              ? colors.onSurface.withValues(alpha: 0.38)
              : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MonthSummaryBar extends StatelessWidget {
  final ExpenseState state;
  const _MonthSummaryBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: EdgeInsets.fromLTRB(R.md, 0, R.md, R.s(8)),
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(10)),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: AppRadius.mdPlus,
      ),
      child: Row(
        children: [
          _SummaryItem(
            label: 'Spent',
            amount: state.totalSpent,
            color: AppColors.expense,
          ),
          const Expanded(
            child: VerticalDivider(
              width: 1,
              color: AppColors.border,
              indent: 4,
              endIndent: 4,
            ),
          ),
          _SummaryItem(
            label: 'Income',
            amount: state.totalIncome,
            color: AppColors.income,
          ),
          const Expanded(
            child: VerticalDivider(
              width: 1,
              color: AppColors.border,
              indent: 4,
              endIndent: 4,
            ),
          ),
          _SummaryItem(
            label: 'Balance',
            amount: state.totalIncome - state.totalSpent,
            color: (state.totalIncome - state.totalSpent) >= 0
                ? AppColors.income
                : AppColors.expense,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      flex: 3,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w500,
              color: colors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: R.s(2)),
          Text(
            CurrencyFormatter.compact(amount.abs()),
            style: TextStyle(
              fontSize: R.t(14),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseGroupedList extends StatelessWidget {
  final List<Expense> expenses;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<String> onStartSelection;

  const _ExpenseGroupedList({
    required this.expenses,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelection,
    required this.onStartSelection,
  });

  Map<String, List<Expense>> get _grouped {
    final map = <String, List<Expense>>{};
    for (final e in expenses) {
      final key = e.date.relativeLabel;
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groups = _grouped;
    final keys = groups.keys.toList();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(R.s(20), 0, R.s(20), R.sm),
      itemCount: keys.length,
      itemBuilder: (context, groupIdx) {
        final group = groups[keys[groupIdx]]!;
        final dayTotal =
            group.where((e) => !e.isIncome).fold(0.0, (s, e) => s + e.amount);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                groupIdx == 0 ? R.s(4) : R.s(12),
                0,
                R.s(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    keys[groupIdx],
                    style: TextStyle(
                      fontSize: R.t(13),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (dayTotal > 0)
                    Text(
                      CurrencyFormatter.format(dayTotal),
                      style: TextStyle(
                        fontSize: R.t(13),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: ListView.separated(
                primary: false,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: group.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: AppColors.border,
                ),
                itemBuilder: (context, i) {
                  final expense = group[i];
                  return ExpenseListTile(
                    expense: expense,
                    selectionMode: selectionMode,
                    selected: selectedIds.contains(expense.id),
                    onSelectionChanged: (_) => onToggleSelection(expense.id),
                    onLongPress: () => onStartSelection(expense.id),
                  )
                      .animate(delay: Duration(milliseconds: 40 * i))
                      .fadeIn(duration: 300.ms)
                      .slideX(begin: 0.05, end: 0);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Figma: Sheet/ExpenseFilter
// ─────────────────────────────────────────────────────────────────────────────
class _FilterSheet extends StatefulWidget {
  final ExpenseFilters current;
  final ValueChanged<ExpenseFilters> onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.current,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late Set<ExpenseCategory> _categories;
  bool? _incomeOnly; // null = both, true = income, false = expenses
  DateTime? _dateFrom;
  DateTime? _dateTo;
  late final TextEditingController _minAmountCtrl;
  late final TextEditingController _maxAmountCtrl;

  @override
  void initState() {
    super.initState();
    _categories = Set.from(widget.current.categories);
    _incomeOnly = widget.current.incomeOnly;
    _dateFrom = widget.current.dateFrom;
    _dateTo = widget.current.dateTo;
    _minAmountCtrl = TextEditingController(
      text: widget.current.minAmount?.toStringAsFixed(2) ?? '',
    );
    _maxAmountCtrl = TextEditingController(
      text: widget.current.maxAmount?.toStringAsFixed(2) ?? '',
    );
  }

  @override
  void dispose() {
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    super.dispose();
  }

  void _toggleCategory(ExpenseCategory cat) {
    setState(() {
      if (_categories.contains(cat)) {
        _categories.remove(cat);
      } else {
        _categories.add(cat);
      }
    });
  }

  void _apply() {
    final minAmount = _parseOptionalAmount(_minAmountCtrl.text);
    final maxAmount = _parseOptionalAmount(_maxAmountCtrl.text);
    if (minAmount != null && maxAmount != null && minAmount > maxAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Minimum amount cannot be greater than maximum amount.'),
        ),
      );
      return;
    }
    if (_dateFrom != null && _dateTo != null && _dateFrom!.isAfter(_dateTo!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Start date cannot be after end date.'),
        ),
      );
      return;
    }

    widget.onApply(
      ExpenseFilters(
        categories: Set.from(_categories),
        incomeOnly: _incomeOnly,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        minAmount: minAmount,
        maxAmount: maxAmount,
      ),
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    widget.onClear();
    Navigator.of(context).pop();
  }

  int get _pendingCount =>
      (_categories.isEmpty ? 0 : 1) +
      (_incomeOnly == null ? 0 : 1) +
      (_dateFrom == null && _dateTo == null ? 0 : 1) +
      (_minAmountCtrl.text.trim().isEmpty && _maxAmountCtrl.text.trim().isEmpty
          ? 0
          : 1);

  double? _parseOptionalAmount(String raw) {
    final normalized = raw.replaceAll(',', '').trim();
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null || value < 0) return null;
    return value;
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final current = isFrom ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _dateFrom = picked;
      } else {
        _dateTo = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(R.lg)),
          ),
          child: Column(
            children: [
              // ── Handle bar
              Padding(
                padding: EdgeInsets.only(top: R.s(12), bottom: R.xs),
                child: Container(
                  width: R.s(36),
                  height: R.s(4),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: AppRadius.xxs,
                  ),
                ),
              ),
              // ── Header
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: R.s(20), vertical: R.s(12)),
                child: Row(
                  children: [
                    Text(
                      'Filter Expenses',
                      style: TextStyle(
                        fontSize: R.t(18),
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                        padding: EdgeInsets.symmetric(horizontal: R.sm),
                      ),
                      child: Text(
                        'Reset',
                        style: TextStyle(fontSize: R.t(14)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              // ── Scrollable body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: R.s(20)),
                  children: [
                    SizedBox(height: R.s(20)),
                    // ── Type section
                    Text(
                      'TYPE',
                      style: TextStyle(
                        fontSize: R.t(11),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _TypeChip(
                          label: 'All',
                          icon: Icons.swap_horiz_rounded,
                          selected: _incomeOnly == null,
                          onTap: () => setState(() => _incomeOnly = null),
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(
                          label: 'Expenses',
                          icon: Icons.arrow_upward_rounded,
                          selected: _incomeOnly == false,
                          onTap: () => setState(() => _incomeOnly = false),
                          activeColor: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        _TypeChip(
                          label: 'Income',
                          icon: Icons.arrow_downward_rounded,
                          selected: _incomeOnly == true,
                          onTap: () => setState(() => _incomeOnly = true),
                          activeColor: AppColors.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // ── Date range section
                    const Text(
                      'DATE RANGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: true),
                            icon: const Icon(Icons.event_available_rounded),
                            label: Text(
                              _dateFrom == null
                                  ? 'From'
                                  : DateFormat('dd MMM yyyy')
                                      .format(_dateFrom!),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDate(isFrom: false),
                            icon: const Icon(Icons.event_rounded),
                            label: Text(
                              _dateTo == null
                                  ? 'To'
                                  : DateFormat('dd MMM yyyy').format(_dateTo!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_dateFrom != null || _dateTo != null)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _dateFrom = null;
                            _dateTo = null;
                          }),
                          child: const Text('Clear date range'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // ── Amount range section
                    const Text(
                      'AMOUNT RANGE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minAmountCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              labelText: 'Min',
                              filled: true,
                              fillColor: colors.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.md,
                                borderSide:
                                    BorderSide(color: colors.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.md,
                                borderSide:
                                    BorderSide(color: colors.outlineVariant),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _maxAmountCtrl,
                            onChanged: (_) => setState(() {}),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d.]'),
                              ),
                            ],
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              labelText: 'Max',
                              filled: true,
                              fillColor: colors.surfaceContainerHighest,
                              border: OutlineInputBorder(
                                borderRadius: AppRadius.md,
                                borderSide:
                                    BorderSide(color: colors.outlineVariant),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.md,
                                borderSide:
                                    BorderSide(color: colors.outlineVariant),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_minAmountCtrl.text.isNotEmpty ||
                        _maxAmountCtrl.text.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => setState(() {
                            _minAmountCtrl.clear();
                            _maxAmountCtrl.clear();
                          }),
                          child: const Text('Clear amount range'),
                        ),
                      ),
                    const SizedBox(height: 24),
                    // ── Category section
                    Row(
                      children: [
                        const Text(
                          'CATEGORY',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const Spacer(),
                        if (_categories.isNotEmpty)
                          GestureDetector(
                            onTap: () => setState(() => _categories.clear()),
                            child: Text(
                              'Clear (${_categories.length})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ExpenseCategory.values.map((cat) {
                        final selected = _categories.contains(cat);
                        return GestureDetector(
                          onTap: () => _toggleCategory(cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? cat.color.withValues(alpha: 0.15)
                                  : colors.surfaceContainerHighest,
                              borderRadius: AppRadius.card,
                              border: Border.all(
                                color: selected
                                    ? cat.color
                                    : colors.outlineVariant,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(cat.emoji,
                                    style: const TextStyle(fontSize: 14)),
                                const SizedBox(width: 6),
                                Text(
                                  cat.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selected
                                        ? cat.color
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
              // ── Apply button
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _apply,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.mdPlus,
                        ),
                      ),
                      child: Text(
                        _pendingCount == 0
                            ? 'Apply Filters'
                            : 'Apply Filters ($_pendingCount active)',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final Color activeColor;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.activeColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : colors.surfaceContainerHighest,
          borderRadius: AppRadius.card,
          border: Border.all(
            color: selected ? activeColor : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? activeColor : colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? activeColor : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
