import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/finflow_app_bar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../budgets/presentation/providers/budget_provider.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../sync/presentation/providers/sync_provider.dart';
import '../../../goals/domain/entities/savings_goal.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../providers/dashboard_provider.dart';

import '../widgets/balance_hero_card.dart';
import '../widgets/quick_stats_row.dart';
import '../widgets/recent_transactions_list.dart';
import '../widgets/spending_chart_widget.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final summary = ref.watch(dashboardProvider);
    final user = ref.watch(currentUserProvider);
    final expState = ref.watch(expenseProvider);
    final budgetState = ref.watch(budgetProvider);
    final goalsState = ref.watch(goalsProvider);
    final syncState = ref.watch(syncProvider);
    final firstName = user?.name.split(' ').first ?? 'there';
    final now = DateTime.now();
    final greeting = _greeting(now.hour);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FinFlowAppBar(
        title: 'FinFlow',
        showLogo: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () => context.push(AppRoutes.aiInsights),
            tooltip: 'AI Insights',
          ),
          IconButton(
            icon: const Icon(Icons.savings_rounded),
            onPressed: () => context.push(AppRoutes.goals),
            tooltip: 'Savings Goals',
          ),
          // Sync status button — tap to force sync, icon shows sync state
          IconButton(
            icon: syncState.isSyncing
                ? SizedBox(
                    width: R.s(18),
                    height: R.s(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : syncState.error != null
                    ? const Icon(Icons.sync_problem_rounded,
                        color: AppColors.error)
                    : Icon(
                        syncState.lastSyncTime != null
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_upload_rounded,
                        color: syncState.lastSyncTime != null
                            ? AppColors.success
                            : AppColors.textTertiary,
                      ),
            onPressed: syncState.isSyncing
                ? null
                : () => ref.read(syncProvider.notifier).sync(),
            tooltip: syncState.error != null
                ? 'Sync error — tap to retry'
                : syncState.lastSyncTime != null
                    ? 'Synced — tap to sync again'
                    : 'Tap to sync with cloud',
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAdd(context, ref),
        tooltip: 'Quick Add',
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(expenseProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.fluid(context, min: 16, max: 24),
                  R.md,
                  Responsive.fluid(context, min: 16, max: 24),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting
                    Text(
                      '$greeting, $firstName 👋',
                      style: TextStyle(
                        fontSize: R.t(26),
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.2, end: 0, duration: 400.ms),
                    SizedBox(height: R.xs),
                    Text(
                      _monthLabel(now),
                      style: TextStyle(
                        fontSize: R.t(14),
                        color: AppColors.textTertiary,
                      ),
                    ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
                    SizedBox(height: R.s(24)),

                    // Hero balance card
                    BalanceHeroCard(summary: summary)
                        .animate()
                        .fadeIn(delay: 150.ms, duration: 400.ms)
                        .slideY(begin: 0.1, end: 0, delay: 150.ms),
                    SizedBox(height: R.s(14)),

                    // Smart summary chips
                    _SummaryChipsRow(
                      expState: expState,
                      budgetState: budgetState,
                    ).animate().fadeIn(delay: 190.ms, duration: 350.ms),

                    // Goals preview card
                    if (goalsState.active.isNotEmpty) ...[
                      SizedBox(height: R.s(10)),
                      _GoalsPreviewCard(
                        goals: goalsState.active.take(2).toList(),
                      ).animate().fadeIn(delay: 210.ms, duration: 350.ms),
                    ],
                    SizedBox(height: R.s(10)),
                    // Smart insights
                    _SmartInsightsRow(expState: expState)
                        .animate()
                        .fadeIn(delay: 230.ms, duration: 350.ms),
                    // Quick stats
                    QuickStatsRow(summary: summary)
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 400.ms),
                    SizedBox(height: R.lg),

                    // Spending chart
                    if (summary.last7DaysSpending.any((v) => v > 0)) ...[
                      SpendingChartWidget(
                        dailySpending: summary.last7DaysSpending,
                      ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                      SizedBox(height: R.lg),
                    ],

                    // Recent transactions
                    RecentTransactionsList(
                      expenses: expState.filteredExpenses.take(5).toList(),
                      onSeeAll: () => context.go(AppRoutes.expenses),
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                    SizedBox(height: R.s(100)), // FAB clearance
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _monthLabel(DateTime now) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${months[now.month - 1]} ${now.year} summary';
  }
}

// ── Smart Summary Chips Row ───────────────────────────────────────────────────
// Figma: Card/SummaryChips
class _SummaryChipsRow extends StatelessWidget {
  final ExpenseState expState;
  final BudgetState budgetState;

  const _SummaryChipsRow({
    required this.expState,
    required this.budgetState,
  });

  @override
  Widget build(BuildContext context) {
    final recurringCount =
        expState.expenses.where((e) => e.isRecurring && !e.isIncome).length;
    final overBudgetCount =
        budgetState.envelopes.where((e) => e.isOverBudget).length;
    final nearLimitCount = budgetState.envelopes
        .where((e) => !e.isOverBudget && e.progressPercent >= 0.8)
        .length;

    final chips = <Widget>[];

    // Recurring chip
    if (recurringCount > 0) {
      chips.add(
        _SummaryChip(
          icon: Icons.repeat_rounded,
          label: '$recurringCount recurring',
          color: AppColors.primary,
          bgColor: AppColors.primaryExtraLight,
          onTap: () => context.push(AppRoutes.recurringManager),
        ),
      );
    }

    // Over-budget chip (higher urgency — error)
    if (overBudgetCount > 0) {
      chips.add(
        _SummaryChip(
          icon: Icons.warning_rounded,
          label: '$overBudgetCount over budget',
          color: AppColors.error,
          bgColor: AppColors.errorLight,
          onTap: () => context.go(AppRoutes.budgets),
        ),
      );
    } else if (nearLimitCount > 0) {
      // Near-limit chip (lower urgency — warning)
      chips.add(
        _SummaryChip(
          icon: Icons.bar_chart_rounded,
          label: '$nearLimitCount near limit',
          color: AppColors.warning,
          bgColor: AppColors.warningLight,
          onTap: () => context.go(AppRoutes.budgets),
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: chips
            .asMap()
            .entries
            .map((e) => Padding(
                  padding:
                      EdgeInsets.only(right: e.key < chips.length - 1 ? 8 : 0),
                  child: e.value,
                ))
            .toList(),
      ),
    );
  }
}

// ── Goals Preview Card ────────────────────────────────────────────────────────
// Figma: Card/GoalsPreview
class _GoalsPreviewCard extends StatelessWidget {
  final List<SavingsGoal> goals;
  const _GoalsPreviewCard({required this.goals});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.all(R.s(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.savings_rounded,
                  size: R.s(16), color: AppColors.primary),
              SizedBox(width: R.s(6)),
              Text(
                'Savings Goals',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.goals),
                child: Text(
                  'See all →',
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: R.s(10)),
          ...goals.map((g) => _GoalMiniRow(goal: g)),
        ],
      ),
    );
  }
}

class _GoalMiniRow extends StatelessWidget {
  final SavingsGoal goal;
  const _GoalMiniRow({required this.goal});

  @override
  Widget build(BuildContext context) {
    final color = GoalColors.at(goal.colorIndex);
    final pct = goal.progressPercent;
    String fmt(double v) =>
        NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹').format(v);
    return Padding(
      padding: EdgeInsets.only(bottom: R.s(10)),
      child: Row(
        children: [
          Container(
            width: R.s(30),
            height: R.s(30),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(R.sm),
            ),
            alignment: Alignment.center,
            child: Text(goal.emoji, style: TextStyle(fontSize: R.t(16))),
          ),
          SizedBox(width: R.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      goal.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: R.t(13),
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${(pct * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: R.t(11),
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: R.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(R.xs),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: R.s(5),
                    backgroundColor: color.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                SizedBox(height: R.s(2)),
                Text(
                  '${fmt(goal.currentAmount)} / ${fmt(goal.targetAmount)}',
                  style: TextStyle(
                    fontSize: R.t(11),
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(R.s(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(R.s(20)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(R.s(10), R.s(7), R.s(14), R.s(7)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: R.s(14), color: color),
              SizedBox(width: R.s(6)),
              Text(
                label,
                style: TextStyle(
                  fontSize: R.t(12),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Smart Insights Row ───────────────────────────────────────────────────────────
// Figma: Card/SmartInsights
class _SmartInsightsRow extends StatelessWidget {
  final ExpenseState expState;

  const _SmartInsightsRow({required this.expState});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final thisMonth = expState.expenses
        .where((e) =>
            !e.isIncome && e.date.year == now.year && e.date.month == now.month)
        .toList();

    if (thisMonth.isEmpty) return const SizedBox.shrink();

    // ── Compute insight values ────────────────────────────────────────────
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = daysInMonth - now.day;
    final monthTotal = thisMonth.fold(0.0, (s, e) => s + e.amount);
    final dailyAvg = now.day > 0 ? monthTotal / now.day : 0.0;

    // Today's spend
    final todayTotal = thisMonth
        .where((e) => e.date.day == now.day)
        .fold(0.0, (s, e) => s + e.amount);

    // Top spending category
    final catMap = <String, double>{};
    for (final e in thisMonth) {
      catMap[e.category.label] = (catMap[e.category.label] ?? 0) + e.amount;
    }
    final topCat = catMap.isEmpty
        ? null
        : catMap.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // vs last month spending
    final prevMonth = now.month == 1 ? 12 : now.month - 1;
    final prevYear = now.month == 1 ? now.year - 1 : now.year;
    final prevTotal = expState.expenses
        .where((e) =>
            !e.isIncome && e.date.year == prevYear && e.date.month == prevMonth)
        .fold(0.0, (s, e) => s + e.amount);
    final delta =
        prevTotal > 0 ? (monthTotal - prevTotal) / prevTotal * 100 : null;

    // ── Build tile list ───────────────────────────────────────────────────
    final tiles = <_InsightTile>[
      _InsightTile(
        icon: Icons.today_rounded,
        label: 'Today',
        value: CurrencyFormatter.format(todayTotal),
        iconColor: AppColors.primary,
        bgColor: AppColors.primaryExtraLight,
      ),
      _InsightTile(
        icon: Icons.show_chart_rounded,
        label: 'Daily Avg',
        value: CurrencyFormatter.format(dailyAvg),
        iconColor: AppColors.warning,
        bgColor: AppColors.warningLight,
      ),
      if (topCat != null)
        _InsightTile(
          icon: Icons.pie_chart_rounded,
          label: 'Top Spend',
          value: topCat,
          iconColor: AppColors.accent,
          bgColor: AppColors.accentLight,
        ),
      _InsightTile(
        icon: Icons.calendar_today_rounded,
        label: 'Month End',
        value: '$daysLeft day${daysLeft == 1 ? '' : 's'} left',
        iconColor: AppColors.textSecondary,
        bgColor: AppColors.surfaceVariant,
      ),
      if (delta != null)
        _InsightTile(
          icon: delta >= 0
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          label: 'vs Last Month',
          value: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}%',
          iconColor: delta >= 0 ? AppColors.error : AppColors.success,
          bgColor: delta >= 0 ? AppColors.errorLight : AppColors.successLight,
        ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: R.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS MONTH',
            style: TextStyle(
              fontSize: R.t(12),
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          SizedBox(height: R.sm),
          SizedBox(
            height: R.s(116),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: tiles.length,
              separatorBuilder: (_, __) => SizedBox(width: R.sm),
              itemBuilder: (_, i) => _InsightCard(tile: tiles[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color bgColor;

  const _InsightTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    required this.bgColor,
  });
}

// Figma: Card/InsightCard
class _InsightCard extends StatelessWidget {
  final _InsightTile tile;

  const _InsightCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      width: R.s(130),
      padding: EdgeInsets.all(R.s(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(R.s(7)),
            decoration: BoxDecoration(
              color: tile.bgColor,
              borderRadius: BorderRadius.circular(R.sm),
            ),
            child: Icon(tile.icon, size: R.s(16), color: tile.iconColor),
          ),
          SizedBox(height: R.s(10)),
          Text(
            tile.value,
            style: TextStyle(
              fontSize: R.t(14),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            tile.label,
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Quick Add Sheet ───────────────────────────────────────────────────────────
void _showQuickAdd(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickAddSheet(
      onMoreOptions: () {
        Navigator.of(context).pop();
        context.push(AppRoutes.addExpense);
      },
    ),
  );
}

// Figma: Card/QuickAddSheet
class _QuickAddSheet extends ConsumerStatefulWidget {
  final VoidCallback onMoreOptions;
  const _QuickAddSheet({required this.onMoreOptions});

  @override
  ConsumerState<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<_QuickAddSheet> {
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.food;
  bool _isIncome = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _amountCtrl.text.trim().replaceAll(',', '');
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a description')),
      );
      return;
    }
    // Capture notifiers BEFORE any await — prevents ref-after-dispose crash
    final expenseNotifier = ref.read(expenseProvider.notifier);
    final syncNotifier = ref.read(syncProvider.notifier);

    setState(() => _isSaving = true);
    await expenseNotifier.addExpense(
      amount: amount,
      description: desc,
      category: _category,
      date: DateTime.now(),
      isIncome: _isIncome,
    );
    // Trigger cloud sync immediately after local save (fire-and-forget)
    syncNotifier.sync();
    if (mounted) {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Title + more options
            Row(
              children: [
                const Text(
                  'Quick Add',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: widget.onMoreOptions,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'More options →',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Expense / Income toggle
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _TypeToggle(
                    label: '💸  Expense',
                    selected: !_isIncome,
                    onTap: () => setState(() => _isIncome = false),
                  ),
                  _TypeToggle(
                    label: '💰  Income',
                    selected: _isIncome,
                    onTap: () => setState(() => _isIncome = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Amount field
            TextField(
              controller: _amountCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              textInputAction: TextInputAction.next,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                prefixText: '₹  ',
                hintStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDisabled,
                ),
                prefixStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 10),
            // Description field
            TextField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'What was this for?',
                hintStyle: const TextStyle(color: AppColors.textDisabled),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 12),
            // Category chips — horizontal scroll
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ExpenseCategory.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final cat = ExpenseCategory.values[i];
                  final isSel = cat == _category;
                  return GestureDetector(
                    onTap: () => setState(() => _category = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: isSel
                            ? cat.color.withValues(alpha: 0.14)
                            : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSel ? cat.color : AppColors.border,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(cat.emoji, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          cat.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSel ? cat.color : AppColors.textSecondary,
                          ),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _isIncome ? AppColors.success : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isIncome ? 'Save Income' : 'Save Expense',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Figma: Chip/TypeToggle
class _TypeToggle extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeToggle(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    selected ? AppColors.textPrimary : AppColors.textTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
