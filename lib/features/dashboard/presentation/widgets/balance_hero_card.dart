import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/financial_summary.dart';

class BalanceHeroCard extends StatelessWidget {
  final FinancialSummary summary;
  const BalanceHeroCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final isPositive = summary.netBalance >= 0;
    final savingsPct = (summary.savingsRate * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(R.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: R.lg,
            offset: Offset(0, R.sm),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Text(
                'This Month',
                style: TextStyle(
                  fontSize: R.t(13),
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (summary.totalIncome > 0)
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: R.s(10), vertical: R.xs),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(R.s(20)),
                  ),
                  child: Text(
                    '$savingsPct% saved',
                    style: TextStyle(
                      fontSize: R.t(11),
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: R.s(12)),

          // Net balance
          Text(
            CurrencyFormatter.format(summary.netBalance.abs()),
            style: TextStyle(
              fontSize: R.t(38),
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.0,
            ),
          ),
          SizedBox(height: R.xs),
          Text(
            isPositive ? '✓ Surplus balance' : '! Overspent',
            style: TextStyle(
              fontSize: R.t(13),
              color: isPositive ? AppColors.successLight : AppColors.errorLight,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: R.lg),

          // Income / Expenses row
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Income',
                  value: CurrencyFormatter.format(summary.totalIncome),
                  icon: Icons.arrow_downward_rounded,
                  color: AppColors.successLight,
                ),
              ),
              Container(
                width: 1,
                height: R.s(40),
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Expenses',
                  value: CurrencyFormatter.format(summary.totalExpenses),
                  icon: Icons.arrow_upward_rounded,
                  color: AppColors.errorLight,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool alignEnd;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Padding(
      padding: EdgeInsets.only(
          left: alignEnd ? R.md : 0, right: alignEnd ? 0 : R.md),
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Icon(icon, size: R.s(12), color: color),
              SizedBox(width: R.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: R.t(11),
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          SizedBox(height: R.s(3)),
          Text(
            value,
            style: TextStyle(
              fontSize: R.t(15),
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
