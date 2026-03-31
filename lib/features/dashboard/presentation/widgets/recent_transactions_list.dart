import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../expenses/domain/entities/expense.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<Expense> expenses;
  final VoidCallback onSeeAll;

  const RecentTransactionsList({
    super.key,
    required this.expenses,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: R.t(16),
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onSeeAll,
              child: Text(
                'See all',
                style: TextStyle(
                  fontSize: R.t(13),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: R.s(12)),
        if (expenses.isEmpty)
          Container(
            padding: EdgeInsets.symmetric(vertical: R.xl),
            width: double.infinity,
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              children: [
                Text('💸', style: TextStyle(fontSize: R.t(32))),
                SizedBox(height: R.sm),
                Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: R.t(14),
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  'Add your first expense to get started',
                  style: TextStyle(
                    fontSize: R.t(12),
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(R.md),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: expenses.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 16,
                color: AppColors.border,
              ),
              itemBuilder: (ctx, i) {
                final e = expenses[i];
                final cat = e.category;

                return ListTile(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: R.md, vertical: R.sm),
                  leading: Container(
                    width: R.s(44),
                    height: R.s(44),
                    decoration: BoxDecoration(
                      color: e.isIncome
                          ? AppColors.successLight
                          : cat.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(R.s(12)),
                    ),
                    child: Center(
                      child: Text(
                        e.isIncome ? '💰' : cat.emoji,
                        style: TextStyle(fontSize: R.t(20)),
                      ),
                    ),
                  ),
                  title: Text(
                    e.description,
                    style: TextStyle(
                      fontSize: R.t(14),
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    e.isIncome
                        ? 'Income · ${e.date.relativeLabel}'
                        : '${cat.label} · ${e.date.relativeLabel}',
                    style: TextStyle(
                      fontSize: R.t(12),
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    '${e.isIncome ? '+' : '-'} ${CurrencyFormatter.format(e.amount)}',
                    style: TextStyle(
                      fontSize: R.t(14),
                      fontWeight: FontWeight.w700,
                      color: e.isIncome ? AppColors.income : colors.onSurface,
                    ),
                  ),
                )
                    .animate(delay: Duration(milliseconds: 50 * i))
                    .fadeIn(duration: 250.ms);
              },
            ),
          ),
      ],
    );
  }
}
