import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';

class SpendingChartWidget extends StatelessWidget {
  final List<double> dailySpending; // 7 items, index 0 = 6 days ago
  const SpendingChartWidget({super.key, required this.dailySpending});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final maxY = dailySpending.reduce((a, b) => a > b ? a : b);
    final adjustedMax = maxY == 0 ? 1000.0 : maxY * 1.3;

    final spots = <FlSpot>[];
    for (int i = 0; i < dailySpending.length; i++) {
      spots.add(FlSpot(i.toDouble(), dailySpending[i]));
    }

    final dayLabels = _buildDayLabels();

    return Container(
      padding: EdgeInsets.all(R.s(20)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.s(20)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Last 7 Days',
                style: TextStyle(
                  fontSize: R.t(15),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.trending_down_rounded,
                color: AppColors.primary,
                size: R.s(18),
              ),
              SizedBox(width: R.xs),
              Text(
                CurrencyFormatter.compact(
                    dailySpending.fold(0.0, (a, b) => a + b)),
                style: TextStyle(
                  fontSize: R.t(13),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: R.s(20)),
          SizedBox(
            height: R.s(140),
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: adjustedMax,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= dayLabels.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          dayLabels[idx],
                          style: TextStyle(
                            fontSize: R.t(10),
                            color: AppColors.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              CurrencyFormatter.compact(s.y),
                              TextStyle(
                                color: Colors.white,
                                fontSize: R.t(11),
                                fontWeight: FontWeight.w600,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) =>
                          FlDotCirclePainter(
                        radius: 3.5,
                        color: AppColors.primary,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.18),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _buildDayLabels() {
    final now = DateTime.now();
    const short = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      if (i == 6) return 'Today';
      return short[day.weekday - 1];
    });
  }
}
