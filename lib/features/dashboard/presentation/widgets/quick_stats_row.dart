import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../domain/entities/financial_summary.dart';

class QuickStatsRow extends StatelessWidget {
  final FinancialSummary summary;
  const QuickStatsRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final topCategory = _topCategory(summary.spendingByCategory);
    final avgDaily = summary.totalExpenses > 0
        ? summary.totalExpenses / DateTime.now().day
        : 0.0;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            emoji: '📊',
            label: 'Daily Avg',
            value: CurrencyFormatter.compact(avgDaily),
          ),
        ),
        SizedBox(width: R.s(12)),
        Expanded(
          child: _StatCard(
            emoji: '🏆',
            label: 'Top Spend',
            value: topCategory,
          ),
        ),
        SizedBox(width: R.s(12)),
        Expanded(
          child: _StatCard(
            emoji: '🧾',
            label: 'Transactions',
            value: summary.totalTransactions.toString(),
          ),
        ),
      ],
    );
  }

  String _topCategory(Map<String, double> byCategory) {
    if (byCategory.isEmpty) return '—';
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final key = sorted.first.key;
    // Capitalize first letter, trim to fit
    return key.length > 8
        ? '${key[0].toUpperCase()}${key.substring(1, 8)}..'
        : '${key[0].toUpperCase()}${key.substring(1)}';
  }
}

class _StatCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatCard({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.all(R.s(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.s(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: R.t(20))),
          SizedBox(height: R.sm),
          Text(
            value,
            style: TextStyle(
              fontSize: R.t(16),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: R.s(2)),
          Text(
            label,
            style: TextStyle(
              fontSize: R.t(11),
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
