// Figma: Screen/AiInsights
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/responsive.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../providers/ai_insights_provider.dart';

class AiInsightsPage extends ConsumerWidget {
  const AiInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    R.init(context);
    final state = ref.watch(aiInsightsProvider);

    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'AI Insights',
          style: TextStyle(
            fontSize: R.t(18),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: !state.hasData
          ? _EmptyState()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(R.s(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Month label ─────────────────────────────────
                        Text(
                          monthLabel,
                          style: TextStyle(
                            fontSize: R.t(13),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.4,
                          ),
                        ).animate().fadeIn(duration: 300.ms),
                        SizedBox(height: R.s(12)),

                        // ── GRADE CARD ───────────────────────────────────
                        _GradeCard(report: state.report)
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(begin: 0.1, end: 0, duration: 400.ms),
                        SizedBox(height: R.s(16)),

                        // ── STATS ROW ────────────────────────────────────
                        _StatsRow(report: state.report)
                            .animate()
                            .fadeIn(delay: 80.ms, duration: 350.ms),
                        SizedBox(height: R.s(20)),

                        // ── ANOMALIES SECTION ────────────────────────────
                        if (state.hasAnomalies) ...[
                          _SectionHeader(
                            icon: Icons.warning_amber_rounded,
                            label: 'Spending Anomalies',
                            color: AppColors.warning,
                          ),
                          SizedBox(height: R.s(10)),
                          ...state.anomalies
                              .take(5)
                              .toList()
                              .asMap()
                              .entries
                              .map(
                                (e) => _AnomalyCard(
                                  category: e.value.category,
                                  thisMonth: e.value.thisMonth,
                                  rollingAvg: e.value.rollingAvg,
                                  ratio: e.value.ratio,
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: Duration(
                                            milliseconds: 100 + e.key * 60),
                                        duration: 350.ms)
                                    .slideX(
                                        begin: 0.05,
                                        end: 0,
                                        delay: Duration(
                                            milliseconds: 100 + e.key * 60)),
                              ),
                          SizedBox(height: R.s(10)),
                        ],

                        // ── HABITS ───────────────────────────────────────
                        _SectionHeader(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Habits & Patterns',
                          color: AppColors.primary,
                        ),
                        SizedBox(height: R.s(10)),
                        _HabitsRow(state: state)
                            .animate()
                            .fadeIn(delay: 150.ms, duration: 350.ms),
                        SizedBox(height: R.s(20)),

                        // ── INSIGHTS LIST ────────────────────────────────
                        _SectionHeader(
                          icon: Icons.lightbulb_outline_rounded,
                          label: 'Insights',
                          color: AppColors.primary,
                        ),
                        SizedBox(height: R.s(10)),
                        ...state.insights.asMap().entries.map(
                              (entry) => _InsightCard(insight: entry.value)
                                  .animate()
                                  .fadeIn(
                                      delay: Duration(
                                          milliseconds: 200 + entry.key * 70),
                                      duration: 350.ms)
                                  .slideY(
                                      begin: 0.08,
                                      end: 0,
                                      delay: Duration(
                                          milliseconds: 200 + entry.key * 70)),
                            ),
                        SizedBox(height: R.s(80)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Grade Card ─────────────────────────────────────────────────────────────────
// Figma: Card/AIGrade
class _GradeCard extends StatelessWidget {
  final MonthlyReport report;
  const _GradeCard({required this.report});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final gradeColor = report.gradeColor;

    return Container(
      padding: EdgeInsets.all(R.s(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            gradeColor.withValues(alpha: 0.12),
            gradeColor.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.s(16)),
        border:
            Border.all(color: gradeColor.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Row(
        children: [
          // Grade badge
          Container(
            width: R.s(72),
            height: R.s(72),
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: gradeColor, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              report.grade,
              style: TextStyle(
                fontSize: R.t(report.grade.length == 2 ? 22 : 28),
                fontWeight: FontWeight.w900,
                color: gradeColor,
              ),
            ),
          ),
          SizedBox(width: R.s(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.headline,
                  style: TextStyle(
                    fontSize: R.t(16),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: R.xs),
                Text(
                  report.subtext,
                  style: TextStyle(
                    fontSize: R.t(12),
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: R.s(10)),
                // Savings-rate progress bar
                if (report.thisMonthIncome > 0) ...[
                  Row(
                    children: [
                      Text(
                        'Savings rate',
                        style: TextStyle(
                          fontSize: R.t(11),
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(report.savingsRate * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: R.t(11),
                          fontWeight: FontWeight.w700,
                          color: gradeColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: R.xs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(R.xs),
                    child: LinearProgressIndicator(
                      value: report.savingsRate.clamp(0.0, 1.0),
                      minHeight: R.s(5),
                      backgroundColor: gradeColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────
// Figma: Card/AIStatsRow
class _StatsRow extends StatelessWidget {
  final MonthlyReport report;
  const _StatsRow({required this.report});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Spent',
            value: CurrencyFormatter.compact(report.thisMonthTotal),
            icon: Icons.trending_down_rounded,
            color: AppColors.expense,
          ),
        ),
        SizedBox(width: R.sm),
        Expanded(
          child: _StatTile(
            label: 'Income',
            value: CurrencyFormatter.compact(report.thisMonthIncome),
            icon: Icons.trending_up_rounded,
            color: AppColors.income,
          ),
        ),
        SizedBox(width: R.sm),
        Expanded(
          child: _StatTile(
            label: 'Daily avg',
            value: CurrencyFormatter.compact(report.avgDailySpend),
            icon: Icons.calendar_today_rounded,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.all(R.s(12)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(R.xs),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(R.xs),
                ),
                child: Icon(icon, size: R.s(13), color: color),
              ),
            ],
          ),
          SizedBox(height: R.s(8)),
          Text(
            value,
            style: TextStyle(
              fontSize: R.t(15),
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: R.xs),
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

// ── Anomaly Card ──────────────────────────────────────────────────────────────
// Figma: Card/AnomalyCard
class _AnomalyCard extends StatelessWidget {
  final ExpenseCategory category;
  final double thisMonth;
  final double rollingAvg;
  final double ratio;
  const _AnomalyCard({
    required this.category,
    required this.thisMonth,
    required this.rollingAvg,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final isHigh = ratio >= 2.5;
    final alertColor = isHigh ? AppColors.error : AppColors.warning;
    final alertBg = isHigh ? AppColors.errorLight : AppColors.warningLight;

    return Container(
      margin: EdgeInsets.only(bottom: R.s(8)),
      padding: EdgeInsets.all(R.s(12)),
      decoration: BoxDecoration(
        color: alertBg,
        borderRadius: BorderRadius.circular(R.s(12)),
        border: Border.all(color: alertColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(category.emoji, style: TextStyle(fontSize: R.t(24))),
          SizedBox(width: R.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.label,
                  style: TextStyle(
                    fontSize: R.t(14),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: R.xs),
                Text(
                  '₹${_fmtNum(thisMonth)} this month  ·  avg ₹${_fmtNum(rollingAvg)}',
                  style: TextStyle(
                    fontSize: R.t(12),
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.s(8), vertical: R.s(4)),
            decoration: BoxDecoration(
              color: alertColor,
              borderRadius: BorderRadius.circular(R.s(20)),
            ),
            child: Text(
              '${ratio.toStringAsFixed(1)}×',
              style: TextStyle(
                fontSize: R.t(11),
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fmtNum(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Habits Row ────────────────────────────────────────────────────────────────
// Figma: Card/HabitsRow
class _HabitsRow extends StatelessWidget {
  final AiInsightsState state;
  const _HabitsRow({required this.state});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Row(
      children: [
        Expanded(
          child: _HabitTile(
            emoji: '🔥',
            label: 'Streak',
            value: '${state.habitStreakDays}d',
            subtitle: 'Under daily avg',
            good: state.habitStreakDays >= 5,
          ),
        ),
        SizedBox(width: R.sm),
        Expanded(
          child: _HabitTile(
            emoji: '🎉',
            label: 'Weekend spend',
            value: '${state.weekendSpendPercent.toStringAsFixed(0)}%',
            subtitle: 'Of total spend',
            good: state.weekendSpendPercent < 35,
          ),
        ),
        SizedBox(width: R.sm),
        Expanded(
          child: _HabitTile(
            emoji: '🎯',
            label: 'Anomalies',
            value: '${state.anomalies.length}',
            subtitle: 'Categories spiked',
            good: state.anomalies.isEmpty,
          ),
        ),
      ],
    );
  }
}

class _HabitTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final String subtitle;
  final bool good;
  const _HabitTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.good,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final color = good ? AppColors.income : AppColors.warning;
    final bgColor = good ? AppColors.incomeLight : AppColors.warningLight;

    return Container(
      padding: EdgeInsets.all(R.s(12)),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(R.s(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: TextStyle(fontSize: R.t(20))),
          SizedBox(height: R.s(6)),
          Text(
            value,
            style: TextStyle(
              fontSize: R.t(18),
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          SizedBox(height: R.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: R.t(10),
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Insight Card ──────────────────────────────────────────────────────────────
// Figma: Card/InsightItem
class _InsightCard extends StatelessWidget {
  final Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final (color, bgColor) = switch (insight.type) {
      InsightType.good => (AppColors.income, AppColors.incomeLight),
      InsightType.warning => (AppColors.warning, AppColors.warningLight),
      InsightType.danger => (AppColors.error, AppColors.errorLight),
      InsightType.neutral => (AppColors.primary, AppColors.primaryExtraLight),
    };

    return Container(
      margin: EdgeInsets.only(bottom: R.s(8)),
      padding: EdgeInsets.all(R.s(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: R.s(40),
            height: R.s(40),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(R.s(10)),
            ),
            alignment: Alignment.center,
            child: Text(insight.emoji, style: TextStyle(fontSize: R.t(18))),
          ),
          SizedBox(width: R.s(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight.title,
                  style: TextStyle(
                    fontSize: R.t(13),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: R.xs),
                Text(
                  insight.detail,
                  style: TextStyle(
                    fontSize: R.t(12),
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: R.sm),
          Container(
            width: R.s(4),
            height: R.s(40),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(R.xs),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ─────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Row(
      children: [
        Icon(icon, size: R.s(15), color: color),
        SizedBox(width: R.s(6)),
        Text(
          label,
          style: TextStyle(
            fontSize: R.t(13),
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.s(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🤔', style: TextStyle(fontSize: R.t(56))),
            SizedBox(height: R.md),
            Text(
              'Not enough data yet',
              style: TextStyle(
                fontSize: R.t(18),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: R.sm),
            Text(
              'Add some expenses and income entries this month and AI Insights will generate a personalised report for you.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: R.t(13),
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
