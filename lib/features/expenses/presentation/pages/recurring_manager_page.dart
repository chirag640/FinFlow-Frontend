// Figma: Screen/RecurringManager
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/design/components/ds_empty_state.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/recurring_engine_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_provider.dart';

class RecurringManagerPage extends ConsumerWidget {
  const RecurringManagerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final colorScheme = Theme.of(context).colorScheme;
    final all = ref.watch(expenseProvider).expenses;
    final templates = all.where((e) => e.isRecurring && !e.isIncome).toList()
      ..sort((a, b) => a.category.name.compareTo(b.category.name));

    return Scaffold(
      backgroundColor: colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: colorScheme.onSurface),
        title: Text(
          'Recurring Expenses',
          style: TextStyle(
            fontSize: R.t(18),
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: templates.isEmpty
          ? const DSEmptyState(
              emoji: '🔁',
              title: 'No recurring expenses',
              subtitle:
                  'Mark an expense as recurring when adding or editing it.',
            )
          : Column(
              children: [
                _InfoBanner(count: templates.length),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(R.md, R.s(12), R.md, R.s(80)),
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => SizedBox(height: R.sm),
                    itemBuilder: (context, i) => _RecurringTile(
                      expense: templates[i],
                      index: i,
                    )
                        .animate(delay: Duration(milliseconds: 40 * i))
                        .fadeIn(duration: 280.ms)
                        .slideX(begin: 0.05, end: 0),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Info Banner ───────────────────────────────────────────────────────────────
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      width: double.infinity,
      color: AppColors.primaryExtraLight,
      padding: EdgeInsets.symmetric(horizontal: R.s(20), vertical: R.s(12)),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              size: R.s(16), color: AppColors.primary),
          SizedBox(width: R.s(10)),
          Expanded(
            child: Text(
              '$count recurring template${count == 1 ? '' : 's'} found. '
              'Swipe left to delete, tap to edit.',
              style: TextStyle(
                fontSize: R.t(12),
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recurring Template Tile ───────────────────────────────────────────────────
class _RecurringTile extends ConsumerWidget {
  const _RecurringTile({required this.expense, required this.index});
  final Expense expense;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final freq = expense.recurringFrequency;
    final nextDue = RecurringEngineService.nextDueFor(expense);
    final due = RecurringEngineService.isDue(expense);

    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        ref.read(expenseProvider.notifier).deleteExpense(expense.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '"${expense.description}" removed from recurring templates.'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: R.s(24)),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(R.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: R.s(22)),
            SizedBox(height: R.xs),
            Text('Delete',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(R.md),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(R.md),
          onTap: () => context.push(AppRoutes.editExpense, extra: expense),
          child: Container(
            padding: EdgeInsets.all(R.md),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(R.md),
            ),
            child: Row(
              children: [
                // Category icon bubble
                Container(
                  width: R.s(48),
                  height: R.s(48),
                  decoration: BoxDecoration(
                    color: expense.category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(R.s(12)),
                  ),
                  child: Center(
                    child: Text(expense.category.emoji,
                        style: TextStyle(fontSize: R.t(22))),
                  ),
                ),
                SizedBox(width: R.s(14)),

                // Labels
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: R.t(15),
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: R.s(3)),
                      Row(
                        children: [
                          Text(
                            expense.category.label,
                            style: TextStyle(
                              fontSize: R.t(12),
                              color: AppColors.textTertiary,
                            ),
                          ),
                          if (freq != null) ...[
                            SizedBox(width: R.s(6)),
                            Text('·',
                                style: TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: R.t(12))),
                            SizedBox(width: R.s(6)),
                            _FrequencyBadge(freq: freq),
                          ],
                        ],
                      ),
                      SizedBox(height: R.xs),
                      Text(
                        'Last: ${DateFormat('MMM d, yyyy').format(expense.date)}',
                        style: TextStyle(
                          fontSize: R.t(11),
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(height: R.s(2)),
                      Row(
                        children: [
                          Text(
                            due
                                ? 'Due today'
                                : 'Next: ${DateFormat('MMM d').format(nextDue)}',
                            style: TextStyle(
                              fontSize: R.t(11),
                              fontWeight: FontWeight.w600,
                              color: due
                                  ? AppColors.error
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Amount + actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(expense.amount),
                      style: TextStyle(
                        fontSize: R.t(15),
                        fontWeight: FontWeight.w700,
                        color: AppColors.expense,
                      ),
                    ),
                    SizedBox(height: R.xs),
                    if (due)
                      GestureDetector(
                        onTap: () => _generateNow(context, ref),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: R.sm, vertical: R.s(3)),
                          decoration: BoxDecoration(
                            color: AppColors.primaryExtraLight,
                            borderRadius: BorderRadius.circular(R.s(20)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  size: R.s(12), color: AppColors.primary),
                              SizedBox(width: R.s(3)),
                              Text(
                                'Log now',
                                style: TextStyle(
                                  fontSize: R.t(10),
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.textDisabled, size: R.s(18)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateNow(BuildContext context, WidgetRef ref) async {
    await RecurringEngineService.run(
      ref.read(expenseProvider.notifier),
      [expense],
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${expense.description}" logged for today.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return DSConfirmDialog.show(
      context: context,
      title: 'Delete recurring template?',
      message:
          '"${expense.description}" will be removed as a recurring template. '
          'Past expenses logged from this template will not be affected.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
  }
}

// ── Frequency Badge ────────────────────────────────────────────────────────────
class _FrequencyBadge extends StatelessWidget {
  const _FrequencyBadge({required this.freq});
  final RecurringFrequency freq;

  Color get _bg => switch (freq) {
        RecurringFrequency.daily => AppColors.warningLight,
        RecurringFrequency.weekly => AppColors.primaryExtraLight,
        RecurringFrequency.monthly => AppColors.accentLight,
        RecurringFrequency.yearly => AppColors.successLight,
      };

  Color get _fg => switch (freq) {
        RecurringFrequency.daily => AppColors.warning,
        RecurringFrequency.weekly => AppColors.primary,
        RecurringFrequency.monthly => AppColors.accent,
        RecurringFrequency.yearly => AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.sm, vertical: R.s(2)),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(R.s(20)),
      ),
      child: Text(
        freq.label,
        style: TextStyle(
          fontSize: R.t(10),
          fontWeight: FontWeight.w700,
          color: _fg,
        ),
      ),
    );
  }
}
