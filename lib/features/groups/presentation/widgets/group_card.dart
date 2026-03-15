import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/group.dart';

class GroupCard extends StatelessWidget {
  final Group group;
  final double myNetBalance; // positive = owed to me, negative = I owe
  final VoidCallback onTap;

  const GroupCard({
    super.key,
    required this.group,
    required this.myNetBalance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final hasBalance = myNetBalance.abs() > 0.01;
    final isOwed = myNetBalance > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: R.s(12)),
        padding: EdgeInsets.all(R.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Emoji avatar
            Container(
              width: R.s(52),
              height: R.s(52),
              decoration: BoxDecoration(
                color: AppColors.primaryExtraLight,
                borderRadius: BorderRadius.circular(R.md),
              ),
              child: Center(
                child: Text(
                  group.emoji,
                  style: TextStyle(fontSize: R.t(26)),
                ),
              ),
            ),
            SizedBox(width: R.s(14)),

            // Name + member count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: TextStyle(
                      fontSize: R.t(15),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: R.s(3)),
                  Text(
                    '${group.members.length} member${group.members.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: R.t(12),
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // Balance indicator
            if (hasBalance) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isOwed ? 'you get back' : 'you owe',
                    style: TextStyle(
                      fontSize: R.t(10),
                      color: isOwed ? AppColors.income : AppColors.expense,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: R.s(2)),
                  Text(
                    CurrencyFormatter.format(myNetBalance.abs()),
                    style: TextStyle(
                      fontSize: R.t(15),
                      fontWeight: FontWeight.w800,
                      color: isOwed ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: R.s(10), vertical: R.s(5)),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(R.s(20)),
                ),
                child: Text(
                  'Settled',
                  style: TextStyle(
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w600,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
            SizedBox(width: R.xs),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textTertiary,
              size: R.s(20),
            ),
          ],
        ),
      ),
    );
  }
}
