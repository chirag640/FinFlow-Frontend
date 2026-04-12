import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_async_state.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../shared/widgets/finflow_app_bar.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../providers/budget_provider.dart';
import '../widgets/budget_envelope_card.dart';

class BudgetsPage extends ConsumerWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    final state = ref.watch(budgetProvider);

    // Determine how many prev-month envelopes can be copied this month
    final ds = ref.read(budgetDatasourceProvider);
    final prevMonth = state.month == 1 ? 12 : state.month - 1;
    final prevYear = state.month == 1 ? state.year - 1 : state.year;
    final prevBudgets = ds.getBudgetsForMonth(prevMonth, prevYear);
    final currentKeys =
        state.envelopes.map((e) => e.budget.categoryKey).toSet();
    final copyableCount =
        prevBudgets.where((b) => !currentKeys.contains(b.categoryKey)).length;

    void doCopy() => ref.read(budgetProvider.notifier).copyFromPreviousMonth();
    void retryCloudLoad() {
      ref.read(budgetProvider.notifier).reloadFromCloud();
    }

    Widget buildBody() {
      if (state.isLoading) {
        return const DSAsyncState.loading(
          title: 'Loading budgets',
          message: 'Fetching your envelopes...',
        );
      }

      if (state.envelopes.isEmpty) {
        if (state.error != null && state.error!.trim().isNotEmpty) {
          return DSAsyncState.error(
            title: 'Unable to load budgets',
            message: state.error,
            onRetry: retryCloudLoad,
          );
        }

        final emptyState = DSAsyncState.empty(
          emoji: '🗂️',
          title: 'No budgets set',
          message:
              'Create budget envelopes for each spending category to stay on track.',
          actionLabel: 'Add Budget',
          onAction: () => context.push(AppRoutes.addBudget),
        );

        if (copyableCount > 0) {
          return Column(
            children: [
              Expanded(child: emptyState),
              Padding(
                padding: EdgeInsets.fromLTRB(R.s(20), 0, R.s(20), R.lg),
                child: _CopyLastMonthBanner(
                  prevMonth: prevMonth,
                  prevYear: prevYear,
                  onCopy: doCopy,
                ).animate().fadeIn(delay: 200.ms),
              ),
            ],
          );
        }

        return emptyState;
      }

      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.all(R.s(20)),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (state.error != null && state.error!.trim().isNotEmpty) ...[
                  DSAsyncState.error(
                    compact: true,
                    title: 'Sync warning',
                    message: state.error,
                    onRetry: retryCloudLoad,
                  ).animate().fadeIn(delay: 40.ms),
                  SizedBox(height: R.md),
                ],

                // Copy-from-last-month quick action
                if (copyableCount > 0) ...[
                  _CopyLastMonthBanner(
                    prevMonth: prevMonth,
                    prevYear: prevYear,
                    onCopy: doCopy,
                  ).animate().fadeIn(delay: 50.ms),
                  SizedBox(height: R.md),
                ],
                const _CarryForwardStrategyPanel(),
                SizedBox(height: R.md),
                _BudgetSummaryBar(
                  totalAllocated: state.totalAllocated,
                  totalSpent: state.totalSpent,
                ),
                // At-risk alert banner
                _BudgetAlertBanner(envelopes: state.envelopes),
                // Budget vs Actual breakdown
                if (state.envelopes.isNotEmpty)
                  _BudgetVsActualSection(envelopes: state.envelopes)
                      .animate(delay: 100.ms)
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.06, end: 0),
                SizedBox(height: R.s(20)),
                Text(
                  'ENVELOPES',
                  style: TextStyle(
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w700,
                    color: colors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: R.s(12)),
                ...state.envelopes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final env = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: R.s(12)),
                    child: BudgetEnvelopeCard(
                      envelope: env,
                      onDelete: () async {
                        final confirm = await DSConfirmDialog.show(
                          context: context,
                          title: 'Delete budget?',
                          message:
                              'This will remove the budget for ${env.budget.categoryKey}.',
                          confirmLabel: 'Delete',
                          isDestructive: true,
                        );
                        if (confirm == true) {
                          ref
                              .read(budgetProvider.notifier)
                              .deleteBudget(env.budget.id);
                        }
                      },
                    )
                        .animate(delay: Duration(milliseconds: 60 * i))
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0),
                  );
                }),
                SizedBox(height: R.s(80)),
              ]),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: FinFlowAppBar(
        title: 'Budgets',
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push(AppRoutes.addBudget),
            tooltip: 'Add budget',
          ),
        ],
        bottom: _MonthSelector(
          month: state.month,
          year: state.year,
          onPrevious: () => ref.read(budgetProvider.notifier).previousMonth(),
          onNext: () => ref.read(budgetProvider.notifier).nextMonth(),
        ),
        bottomHeight: 52,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.addBudget),
        tooltip: 'Add Budget Envelope',
        child: const Icon(Icons.add_rounded),
      ),
      body: buildBody(),
    );
  }
}

class _CarryForwardStrategyPanel extends ConsumerWidget {
  const _CarryForwardStrategyPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final capSliderMax = settings.carryForwardCap < 5000
        ? 5000.0
        : (settings.carryForwardCap * 2).clamp(5000, 500000).toDouble();

    String strategyHint() {
      switch (settings.carryForwardStrategy) {
        case CarryForwardStrategy.full:
          return 'Roll over 100% of unspent amount to next month.';
        case CarryForwardStrategy.percentage:
          return 'Roll over ${settings.carryForwardPercent.toStringAsFixed(0)}% of unspent amount.';
        case CarryForwardStrategy.capped:
          return 'Roll over up to ${CurrencyFormatter.format(settings.carryForwardCap)} from unspent amount.';
        case CarryForwardStrategy.none:
          return 'Do not roll over unspent balances.';
      }
    }

    return Container(
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Carry-Forward Strategy',
            style: TextStyle(
              fontSize: R.t(13),
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: R.xs),
          Text(
            strategyHint(),
            style: TextStyle(
              fontSize: R.t(11),
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: R.sm),
          DropdownButtonFormField<CarryForwardStrategy>(
            initialValue: settings.carryForwardStrategy,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: CarryForwardStrategy.full,
                child: Text('Full rollover'),
              ),
              DropdownMenuItem(
                value: CarryForwardStrategy.percentage,
                child: Text('Percentage rollover'),
              ),
              DropdownMenuItem(
                value: CarryForwardStrategy.capped,
                child: Text('Capped rollover'),
              ),
              DropdownMenuItem(
                value: CarryForwardStrategy.none,
                child: Text('No rollover'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              settingsNotifier.setCarryForwardStrategy(value);
            },
          ),
          if (settings.carryForwardStrategy == CarryForwardStrategy.percentage)
            Padding(
              padding: EdgeInsets.only(top: R.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rollover Percentage: ${settings.carryForwardPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: R.t(11),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Slider(
                    value: settings.carryForwardPercent,
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label:
                        '${settings.carryForwardPercent.toStringAsFixed(0)}%',
                    onChanged: settingsNotifier.setCarryForwardPercent,
                  ),
                ],
              ),
            ),
          if (settings.carryForwardStrategy == CarryForwardStrategy.capped)
            Padding(
              padding: EdgeInsets.only(top: R.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rollover Cap: ${CurrencyFormatter.format(settings.carryForwardCap)}',
                    style: TextStyle(
                      fontSize: R.t(11),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Slider(
                    value: settings.carryForwardCap.clamp(0, capSliderMax),
                    min: 0,
                    max: capSliderMax,
                    divisions: 20,
                    label: CurrencyFormatter.format(settings.carryForwardCap),
                    onChanged: settingsNotifier.setCarryForwardCap,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final int month;
  final int year;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSelector({
    required this.month,
    required this.year,
    required this.onPrevious,
    required this.onNext,
  });

  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      height: R.s(52),
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: R.s(12)),
          Text(
            '${_months[month - 1]} $year',
            style: TextStyle(
              fontSize: R.t(15),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: R.s(12)),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummaryBar extends StatelessWidget {
  final double totalAllocated;
  final double totalSpent;

  const _BudgetSummaryBar({
    required this.totalAllocated,
    required this.totalSpent,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final overallProgress = totalAllocated > 0
        ? (totalSpent / totalAllocated).clamp(0.0, 1.2)
        : 0.0;
    final isOver = totalSpent > totalAllocated && totalAllocated > 0;

    return Container(
      padding: EdgeInsets.all(R.s(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOver
              ? [
                  AppColors.error.withValues(alpha: 0.9),
                  AppColors.error.withValues(alpha: 0.7),
                ]
              : [
                  AppColors.primary,
                  const Color(0xFF3730A3),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.s(18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Budget',
                      style:
                          TextStyle(fontSize: R.t(12), color: Colors.white60),
                    ),
                    SizedBox(height: R.s(2)),
                    Text(
                      CurrencyFormatter.format(totalAllocated),
                      style: TextStyle(
                        fontSize: R.t(22),
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Spent',
                    style: TextStyle(fontSize: R.t(12), color: Colors.white60),
                  ),
                  SizedBox(height: R.s(2)),
                  Text(
                    CurrencyFormatter.format(totalSpent),
                    style: TextStyle(
                      fontSize: R.t(22),
                      fontWeight: FontWeight.w800,
                      color: isOver ? Colors.redAccent.shade100 : Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: R.s(14)),
          ClipRRect(
            borderRadius: BorderRadius.circular(R.sm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: overallProgress.clamp(0, 1.0)),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: R.s(8),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation(
                    isOver ? Colors.redAccent.shade100 : Colors.white),
              ),
            ),
          ),
          SizedBox(height: R.sm),
          Text(
            isOver
                ? 'Over budget by ${CurrencyFormatter.format(totalSpent - totalAllocated)}'
                : '${CurrencyFormatter.format(totalAllocated - totalSpent)} remaining',
            style: TextStyle(
              fontSize: R.t(12),
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget Alert Banner ───────────────────────────────────────────────────────
class _BudgetAlertBanner extends StatelessWidget {
  final List<BudgetEnvelope> envelopes;

  const _BudgetAlertBanner({required this.envelopes});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final overBudget = envelopes.where((e) => e.isOverBudget).toList();
    final nearLimit = envelopes
        .where((e) => !e.isOverBudget && e.progressPercent >= 0.8)
        .toList();

    if (overBudget.isEmpty && nearLimit.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: R.md),
      child: Container(
        padding: EdgeInsets.all(R.s(14)),
        decoration: BoxDecoration(
          color: overBudget.isNotEmpty
              ? AppColors.errorLight
              : AppColors.warningLight,
          borderRadius: BorderRadius.circular(R.s(14)),
          border: Border.all(
            color: overBudget.isNotEmpty
                ? AppColors.error.withValues(alpha: 0.3)
                : AppColors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              overBudget.isNotEmpty
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              size: R.s(18),
              color:
                  overBudget.isNotEmpty ? AppColors.error : AppColors.warning,
            ),
            SizedBox(width: R.s(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    overBudget.isNotEmpty
                        ? '${overBudget.length} envelope${overBudget.length > 1 ? 's' : ''} exceeded'
                        : '${nearLimit.length} envelope${nearLimit.length > 1 ? 's' : ''} near limit',
                    style: TextStyle(
                      fontSize: R.t(13),
                      fontWeight: FontWeight.w700,
                      color: overBudget.isNotEmpty
                          ? AppColors.error
                          : AppColors.warning,
                    ),
                  ),
                  SizedBox(height: R.s(2)),
                  Text(
                    overBudget.isNotEmpty
                        ? overBudget.map((e) => e.budget.categoryKey).join(', ')
                        : nearLimit.map((e) => e.budget.categoryKey).join(', '),
                    style: TextStyle(
                      fontSize: R.t(11),
                      color: overBudget.isNotEmpty
                          ? AppColors.error
                          : AppColors.warning,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Budget vs Actual Section ──────────────────────────────────────────────────
// Figma: Card/BudgetVsActual
class _BudgetVsActualSection extends StatelessWidget {
  final List<BudgetEnvelope> envelopes;

  const _BudgetVsActualSection({required this.envelopes});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      margin: EdgeInsets.only(top: R.md),
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(R.s(18)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: R.sm, vertical: R.s(3)),
                decoration: BoxDecoration(
                  color: AppColors.primaryExtraLight,
                  borderRadius: BorderRadius.circular(R.s(6)),
                ),
                child: Text(
                  'BUDGET vs ACTUAL',
                  style: TextStyle(
                    fontSize: R.t(10),
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Allocated  |  Spent',
                style: TextStyle(
                  fontSize: R.t(10),
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: R.s(14)),
          ...envelopes.asMap().entries.map((entry) {
            final i = entry.key;
            final env = entry.value;
            return _BudgetVsActualRow(envelope: env, animDelay: i)
                .animate(delay: Duration(milliseconds: 60 * i))
                .fadeIn(duration: 250.ms)
                .slideX(begin: 0.04, end: 0);
          }),
        ],
      ),
    );
  }
}

class _BudgetVsActualRow extends StatelessWidget {
  final BudgetEnvelope envelope;
  final int animDelay;

  const _BudgetVsActualRow({required this.envelope, required this.animDelay});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final category = ExpenseCategory.fromString(envelope.budget.categoryKey);
    final pct = envelope.progressPercent.clamp(0.0, 1.0);
    final isOver = envelope.isOverBudget;
    final barColor = isOver
        ? AppColors.error
        : pct >= 0.8
            ? AppColors.warning
            : AppColors.success;

    return Padding(
      padding: EdgeInsets.only(bottom: R.s(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(category.emoji, style: TextStyle(fontSize: R.t(14))),
              SizedBox(width: R.s(6)),
              Expanded(
                child: Text(
                  category.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                CurrencyFormatter.format(envelope.allocatedAmount),
                style: TextStyle(
                  fontSize: R.t(11),
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                '  |  ',
                style:
                    TextStyle(fontSize: R.t(11), color: AppColors.textDisabled),
              ),
              Text(
                CurrencyFormatter.format(envelope.spentAmount),
                style: TextStyle(
                  fontSize: R.t(11),
                  fontWeight: FontWeight.w700,
                  color: isOver ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: R.s(6)),
          ClipRRect(
            borderRadius: BorderRadius.circular(R.s(6)),
            child: Stack(
              children: [
                // Track
                Container(
                  height: R.s(7),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                // Fill
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (_, val, __) => FractionallySizedBox(
                    widthFactor: val,
                    child: Container(
                      height: R.s(7),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(R.s(6)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: R.s(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                isOver
                    ? '▲ ${CurrencyFormatter.format(envelope.spentAmount - envelope.allocatedAmount)} over'
                    : '${(pct * 100).toStringAsFixed(0)}% used',
                style: TextStyle(
                  fontSize: R.t(10),
                  color: isOver
                      ? AppColors.error
                      : pct >= 0.8
                          ? AppColors.warning
                          : AppColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Copy Last Month Banner ────────────────────────────────────────────────────
// Figma: Card/CopyLastMonthBanner
class _CopyLastMonthBanner extends StatelessWidget {
  final int prevMonth;
  final int prevYear;
  final VoidCallback onCopy;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  const _CopyLastMonthBanner({
    required this.prevMonth,
    required this.prevYear,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final monthName = _months[prevMonth - 1];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.s(14)),
      decoration: BoxDecoration(
        color: AppColors.primaryExtraLight,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(R.sm),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(R.s(10)),
            ),
            child: Icon(
              Icons.copy_all_rounded,
              size: R.s(18),
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: R.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copy $monthName $prevYear budgets',
                  style: TextStyle(
                    fontSize: R.t(13),
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: R.s(2)),
                Text(
                  'Reuse last month\'s envelope setup',
                  style: TextStyle(
                    fontSize: R.t(11),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCopy,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding:
                  EdgeInsets.symmetric(horizontal: R.s(12), vertical: R.sm),
            ),
            child: const Text(
              'Copy',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
