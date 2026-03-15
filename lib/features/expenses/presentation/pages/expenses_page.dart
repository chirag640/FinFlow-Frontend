import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/design/components/ds_skeleton.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/ui/error_feedback.dart';
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
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    // Clear search query when leaving page
    ref.read(expenseProvider.notifier).clearSearch();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(expenseProvider.notifier).clearSearch();
    }
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
    listenForProviderError<ExpenseState>(
      ref: ref,
      context: context,
      provider: expenseProvider,
      errorSelector: (s) => s.error,
    );
    final state = ref.watch(expenseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.surface,
            floating: true,
            snap: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            titleSpacing: 20,
            actionsPadding: const EdgeInsets.only(right: 8),
            title: _searchActive
                ? TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'Search expenses...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 16,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                    onChanged: (q) =>
                        ref.read(expenseProvider.notifier).setSearch(q),
                  )
                : const Text(
                    'Expenses',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
            actions: [
              if (!_searchActive) ...[
                IconButton(
                  icon: const Icon(Icons.bar_chart_rounded,
                      color: AppColors.primary),
                  onPressed: () => context.push(AppRoutes.analytics),
                  tooltip: 'View Analytics',
                ),
                // Filter icon with active-count badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: Icon(
                        state.activeFilters.isEmpty
                            ? Icons.tune_rounded
                            : Icons.tune_rounded,
                        color: state.activeFilters.isEmpty
                            ? AppColors.textSecondary
                            : AppColors.primary,
                      ),
                      onPressed: () => _showFilterSheet(context, ref, state),
                      tooltip: 'Filter',
                    ),
                    if (state.activeFilters.activeCount > 0)
                      Positioned(
                        right: 6,
                        top: 6,
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
                  ],
                ),
              ],
              IconButton(
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _searchActive
                      ? const Icon(Icons.close_rounded,
                          key: ValueKey('close'), color: AppColors.textPrimary)
                      : const Icon(Icons.search_rounded,
                          key: ValueKey('search'),
                          color: AppColors.textSecondary),
                ),
                onPressed: _toggleSearch,
                tooltip: _searchActive ? 'Close search' : 'Search',
              ),
            ],
            bottom: _searchActive
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
        body: state.isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: DSSkeletonList(count: 7),
              )
            : state.filteredExpenses.isEmpty
                ? _searchActive
                    ? const _NoResultsView()
                    : DSEmptyState(
                        emoji: '💸',
                        title: 'No expenses yet',
                        subtitle:
                            'Tap the + button to log your first expense for ${DateFormat('MMMM').format(DateTime(state.selectedYear, state.selectedMonth))}.',
                        actionLabel: 'Add Expense',
                        onAction: () => context.push(AppRoutes.addExpense),
                      )
                : _ExpenseGroupedList(expenses: state.filteredExpenses),
      ),
      floatingActionButton: FloatingActionButton.extended(
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

// ── No Results View ───────────────────────────────────────────────────────────
class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🔍', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'No expenses found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Try a different keyword',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: R.s(36),
        height: R.s(36),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(R.s(10)),
        ),
        child: Icon(
          icon,
          size: R.s(20),
          color:
              onTap == null ? AppColors.textDisabled : AppColors.textSecondary,
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
    return Container(
      margin: EdgeInsets.fromLTRB(R.md, 0, R.md, R.s(8)),
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(10)),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(R.s(14)),
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
    return Expanded(
      flex: 3,
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
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
  const _ExpenseGroupedList({required this.expenses});

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
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(R.md),
                border: Border.all(color: AppColors.border),
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
                itemBuilder: (context, i) => ExpenseListTile(expense: group[i])
                    .animate(delay: Duration(milliseconds: 40 * i))
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: 0.05, end: 0),
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

  @override
  void initState() {
    super.initState();
    _categories = Set.from(widget.current.categories);
    _incomeOnly = widget.current.incomeOnly;
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
    widget.onApply(
      ExpenseFilters(
          categories: Set.from(_categories), incomeOnly: _incomeOnly),
    );
    Navigator.of(context).pop();
  }

  void _reset() {
    widget.onClear();
    Navigator.of(context).pop();
  }

  int get _pendingCount =>
      (_categories.isEmpty ? 0 : 1) + (_incomeOnly == null ? 0 : 1);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
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
                    borderRadius: BorderRadius.circular(R.s(2)),
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
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textTertiary,
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
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? cat.color : AppColors.border,
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
                                        : AppColors.textSecondary,
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
                          borderRadius: BorderRadius.circular(14),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? activeColor : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: selected ? activeColor : AppColors.textTertiary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? activeColor : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
