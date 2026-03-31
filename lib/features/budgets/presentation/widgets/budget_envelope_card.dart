import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../providers/budget_provider.dart';

class BudgetEnvelopeCard extends StatelessWidget {
  final BudgetEnvelope envelope;
  final VoidCallback? onDelete;

  const BudgetEnvelopeCard({
    super.key,
    required this.envelope,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    final budget = envelope.budget;
    final cat = ExpenseCategory.values.firstWhere(
      (c) => c.key == budget.categoryKey,
      orElse: () => ExpenseCategory.other,
    );
    final progress = envelope.progressPercent;
    final isOver = envelope.isOverBudget;
    final Color progressColor = isOver
        ? AppColors.error
        : progress >= 0.9
            ? AppColors.warning
            : AppColors.primary;

    return Container(
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(
          color: isOver ? AppColors.errorLight : colors.outlineVariant,
          width: isOver ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: R.s(40),
                height: R.s(40),
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(R.s(12)),
                ),
                child: Center(
                  child: Text(
                    cat.emoji,
                    style: TextStyle(fontSize: R.t(20)),
                  ),
                ),
              ),
              SizedBox(width: R.s(12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: R.t(14),
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      isOver
                          ? 'Over budget!'
                          : '${((1 - progress) * 100).toStringAsFixed(0)}% remaining',
                      style: TextStyle(
                        fontSize: R.t(11),
                        color:
                            isOver ? AppColors.error : AppColors.textTertiary,
                        fontWeight: isOver ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: R.s(18)),
                  color: AppColors.textTertiary,
                  onPressed: onDelete,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: R.s(12)),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(R.sm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0, 1.0)),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (_, val, __) => LinearProgressIndicator(
                value: val,
                minHeight: R.s(7),
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(progressColor),
              ),
            ),
          ),
          SizedBox(height: R.s(10)),

          // Amount row
          Row(
            children: [
              Text(
                CurrencyFormatter.format(envelope.spentAmount),
                style: TextStyle(
                  fontSize: R.t(14),
                  fontWeight: FontWeight.w700,
                  color: isOver ? AppColors.error : AppColors.textPrimary,
                ),
              ),
              Text(
                ' spent of ',
                style: TextStyle(
                  fontSize: R.t(13),
                  color: AppColors.textTertiary,
                ),
              ),
              Text(
                CurrencyFormatter.format(envelope.effectiveAllocated),
                style: TextStyle(
                  fontSize: R.t(14),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (!isOver)
                Text(
                  '${CurrencyFormatter.format(envelope.remainingAmount)} left',
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                )
              else
                Text(
                  '${CurrencyFormatter.format(envelope.spentAmount - budget.allocatedAmount)} over',
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),

          // Threshold alert chip
          if (envelope.carryForwardAmount > 0) ...[
            SizedBox(height: R.sm),
            Row(
              children: [
                Icon(
                  Icons.keyboard_return_rounded,
                  size: R.s(12),
                  color: AppColors.success,
                ),
                SizedBox(width: R.xs),
                Text(
                  '+${CurrencyFormatter.format(envelope.carryForwardAmount)} rolled over from ${_prevMonthName(budget.month)}',
                  style: TextStyle(
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],

          // Threshold alert chip
          if (progress >= 0.8) ...[
            SizedBox(height: R.s(10)),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: R.s(10), vertical: R.s(5)),
              decoration: BoxDecoration(
                color: isOver
                    ? AppColors.errorLight
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(R.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOver
                        ? Icons.error_outline_rounded
                        : Icons.warning_amber_rounded,
                    size: R.s(13),
                    color: isOver ? AppColors.error : AppColors.warning,
                  ),
                  SizedBox(width: R.s(5)),
                  Text(
                    isOver
                        ? 'Budget exceeded'
                        : 'Only ${((1 - progress) * 100).toStringAsFixed(0)}% remaining',
                    style: TextStyle(
                      fontSize: R.t(11),
                      fontWeight: FontWeight.w600,
                      color: isOver ? AppColors.error : AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _prevMonthName(int month) {
  const months = [
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
  // month is 1-based; previous month index in 0-based array
  return months[(month - 2 + 12) % 12];
}
