import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';

// ── Insight severity ──────────────────────────────────────────────────────────
enum InsightType { good, warning, danger, neutral }

// ── Individual insight card data ──────────────────────────────────────────────
class Insight {
  final String emoji;
  final String title;
  final String detail;
  final InsightType type;

  const Insight({
    required this.emoji,
    required this.title,
    required this.detail,
    required this.type,
  });
}

// ── Monthly Report Grade ──────────────────────────────────────────────────────
class MonthlyReport {
  final String grade; // A+ | A | B | C | D | F
  final String headline;
  final String subtext;
  final double savingsRate; // 0–1
  final double budgetAdherence; // 0–1  (1 = all within budget)
  final double avgDailySpend;
  final double thisMonthTotal;
  final double thisMonthIncome;
  final ExpenseCategory? topCategory;
  final double topCategoryAmount;

  const MonthlyReport({
    required this.grade,
    required this.headline,
    required this.subtext,
    required this.savingsRate,
    required this.budgetAdherence,
    required this.avgDailySpend,
    required this.thisMonthTotal,
    required this.thisMonthIncome,
    this.topCategory,
    required this.topCategoryAmount,
  });

  Color get gradeColor {
    return switch (grade.substring(0, 1)) {
      'A' => const Color(0xFF10B981), // success green
      'B' => const Color(0xFF3B82F6), // blue
      'C' => const Color(0xFFF59E0B), // amber
      'D' => const Color(0xFFF97316), // orange
      _ => const Color(0xFFEF4444), // red
    };
  }
}

// ── Full AI state ─────────────────────────────────────────────────────────────
class AiInsightsState {
  final MonthlyReport report;
  final List<Insight> insights;
  final List<AnomalyData> anomalies;
  final double weekendSpendPercent;
  final int habitStreakDays;
  final Map<int, double> hourlyPattern; // hour → avg spend that hour of day

  const AiInsightsState({
    required this.report,
    required this.insights,
    required this.anomalies,
    required this.weekendSpendPercent,
    required this.habitStreakDays,
    required this.hourlyPattern,
  });

  bool get hasAnomalies => anomalies.isNotEmpty;
  bool get hasData => report.thisMonthTotal > 0 || report.thisMonthIncome > 0;
}

class AnomalyData {
  final ExpenseCategory category;
  final double thisMonth;
  final double rollingAvg;
  final double ratio; // thisMonth / rollingAvg

  const AnomalyData({
    required this.category,
    required this.thisMonth,
    required this.rollingAvg,
    required this.ratio,
  });
}

// ── Provider ──────────────────────────────────────────────────────────────────
final aiInsightsProvider = Provider<AiInsightsState>((ref) {
  final expState = ref.watch(expenseProvider);
  return _compute(expState);
});

AiInsightsState _compute(ExpenseState expState) {
  final now = DateTime.now();
  final allExpenses = expState.expenses;

  // ── This-month expenses / income ─────────────────────────────────────────
  final thisMonthExp = allExpenses
      .where((e) => e.date.year == now.year && e.date.month == now.month)
      .toList();
  final spending = thisMonthExp.where((e) => !e.isIncome).toList();
  final income = thisMonthExp.where((e) => e.isIncome).toList();

  final totalSpent = spending.fold(0.0, (s, e) => s + e.amount);
  final totalIncome = income.fold(0.0, (s, e) => s + e.amount);

  // ── Savings rate ──────────────────────────────────────────────────────────
  final savingsRate = totalIncome > 0
      ? ((totalIncome - totalSpent) / totalIncome).clamp(0.0, 1.0)
      : 0.0;

  // ── Days elapsed in month ─────────────────────────────────────────────────
  final daysElapsed = now.day;
  final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
  final avgDailySpend = daysElapsed > 0 ? totalSpent / daysElapsed : 0.0;

  // ── Top category ──────────────────────────────────────────────────────────
  final catTotals = <ExpenseCategory, double>{};
  for (final e in spending) {
    catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
  }
  ExpenseCategory? topCat;
  double topAmt = 0;
  catTotals.forEach((cat, amt) {
    if (amt > topAmt) {
      topAmt = amt;
      topCat = cat;
    }
  });

  // ── Rolling 3-month average per category ─────────────────────────────────
  final anomalies = <AnomalyData>[];
  final rollMonths = [
    DateTime(now.year, now.month - 1),
    DateTime(now.year, now.month - 2),
    DateTime(now.year, now.month - 3),
  ];

  for (final cat in ExpenseCategory.values) {
    final thisMonthAmt = catTotals[cat] ?? 0;
    if (thisMonthAmt == 0) continue;

    // 3-month rolling avg
    double rollTotal = 0;
    int rollCount = 0;
    for (final d in rollMonths) {
      final monthAmt = allExpenses
          .where((e) =>
              !e.isIncome &&
              e.date.year == d.year &&
              e.date.month == d.month &&
              e.category == cat)
          .fold(0.0, (s, e) => s + e.amount);
      if (monthAmt > 0) {
        rollTotal += monthAmt;
        rollCount++;
      }
    }
    if (rollCount == 0) continue; // no history → no anomaly
    final rollAvg = rollTotal / rollCount;
    if (rollAvg <= 0) continue;

    final ratio = thisMonthAmt / rollAvg;
    if (ratio >= 1.8) {
      // spending ≥ 1.8× rolling avg = anomaly
      anomalies.add(AnomalyData(
        category: cat,
        thisMonth: thisMonthAmt,
        rollingAvg: rollAvg,
        ratio: ratio,
      ));
    }
  }
  anomalies.sort((a, b) => b.ratio.compareTo(a.ratio));

  // ── Weekend spend % ───────────────────────────────────────────────────────
  final weekendSpend = spending
      .where((e) =>
          e.date.weekday == DateTime.saturday ||
          e.date.weekday == DateTime.sunday)
      .fold(0.0, (s, e) => s + e.amount);
  final weekendPct = totalSpent > 0 ? (weekendSpend / totalSpent * 100) : 0.0;

  // ── Habit streak — days under daily avg ──────────────────────────────────
  // Count consecutive days ending today where daily spend ≤ overal avg
  int streakDays = 0;
  if (avgDailySpend > 0) {
    for (int d = 0; d < daysElapsed; d++) {
      final day = DateTime(now.year, now.month, daysElapsed - d);
      final daySpend = spending
          .where((e) =>
              e.date.year == day.year &&
              e.date.month == day.month &&
              e.date.day == day.day)
          .fold(0.0, (s, e) => s + e.amount);
      if (daySpend <= avgDailySpend) {
        streakDays++;
      } else {
        break; // streak broken
      }
    }
  }

  // ── Hourly spend pattern ─────────────────────────────────────────────────
  // (Would need time-of-day in Expense entity — using date.hour as proxy;
  //  all expenses have date at midnight so this is future-ready but blank now)
  final hourlyPattern = <int, double>{};

  // ── Grade computation ─────────────────────────────────────────────────────
  // Score 0–100 from savings rate + anomaly count + streak
  double score = 0;
  // Savings rate (0–50 pts): 30%+ = full 50, scales down linearly
  score += (savingsRate * 100).clamp(0, 30) / 30 * 50;
  // No anomalies (+20 pts)
  if (anomalies.isEmpty) score += 20;
  // Weekend spend < 30% (+15 pts when controlled)
  if (weekendPct < 30) score += 15;
  // Streak (+15 pts if ≥ 7 days)
  if (streakDays >= 7) score += 15;

  final grade = score >= 90
      ? 'A+'
      : score >= 80
          ? 'A'
          : score >= 70
              ? 'B'
              : score >= 55
                  ? 'C'
                  : score >= 40
                      ? 'D'
                      : 'F';

  final gradeHeadlines = {
    'A+': 'Outstanding! You\'re crushing it 🎯',
    'A': 'Great job! Solid financial habits',
    'B': 'Good month with room to improve',
    'C': 'Average — a few things to address',
    'D': 'Below target — attention needed',
    'F': 'Tough month — let\'s course-correct',
  };
  final gradeSubtext = {
    'A+':
        'Savings rate ${(savingsRate * 100).toStringAsFixed(0)}% · No overspends detected',
    'A': 'Keep it up and you\'re on track for an A+ next month',
    'B': 'A bit more discipline on a few categories would push you to A',
    'C':
        '${anomalies.length} category overspend${anomalies.length == 1 ? '' : 's'} detected',
    'D': 'Spending outpaced income this month',
    'F': 'High overspend in multiple categories — review insights below',
  };

  final report = MonthlyReport(
    grade: grade,
    headline: gradeHeadlines[grade]!,
    subtext: gradeSubtext[grade]!,
    savingsRate: savingsRate,
    budgetAdherence:
        anomalies.isEmpty ? 1.0 : (1 - anomalies.length / 5).clamp(0, 1),
    avgDailySpend: avgDailySpend,
    thisMonthTotal: totalSpent,
    thisMonthIncome: totalIncome,
    topCategory: topCat,
    topCategoryAmount: topAmt,
  );

  // ── Build insight list ────────────────────────────────────────────────────
  final insights = <Insight>[];

  // Savings insight
  if (totalIncome > 0) {
    final pct = (savingsRate * 100).toStringAsFixed(0);
    if (savingsRate >= 0.2) {
      insights.add(Insight(
        emoji: '💰',
        title: 'Saving $pct% of income',
        detail:
            'You\'re saving ${CurrencyFormatter.compact(totalIncome - totalSpent)} this month. Target: 20%+.',
        type: InsightType.good,
      ));
    } else {
      insights.add(Insight(
        emoji: '⚠️',
        title: 'Savings below 20%',
        detail:
            'You\'ve saved only $pct% this month. Try to reduce ${topCat?.label ?? 'discretionary'} spending.',
        type: savingsRate < 0.05 ? InsightType.danger : InsightType.warning,
      ));
    }
  }

  // Projected month-end
  if (daysElapsed > 0 && daysElapsed < daysInMonth) {
    final projected = avgDailySpend * daysInMonth;
    final daysLeft = daysInMonth - daysElapsed;
    insights.add(Insight(
      emoji: '📅',
      title: 'Projected ${CurrencyFormatter.compact(projected)} by month end',
      detail:
          '$daysLeft days left · ${CurrencyFormatter.compact(avgDailySpend)}/day average · stay on track.',
      type: totalIncome > 0 && projected < totalIncome
          ? InsightType.good
          : InsightType.warning,
    ));
  }

  // Weekend pattern
  if (spending.isNotEmpty) {
    if (weekendPct > 40) {
      insights.add(Insight(
        emoji: '🎉',
        title: '${weekendPct.toStringAsFixed(0)}% of spending on weekends',
        detail:
            'Weekend spending is high. Consider planning weekend activities on a fixed budget.',
        type: InsightType.warning,
      ));
    } else if (weekendPct < 20) {
      insights.add(Insight(
        emoji: '🗓️',
        title: 'Controlled weekend spending',
        detail:
            'Only ${weekendPct.toStringAsFixed(0)}% of this month\'s spend happened on weekends.',
        type: InsightType.good,
      ));
    }
  }

  // Streak insight
  if (streakDays >= 3) {
    insights.add(Insight(
      emoji: '🔥',
      title: '$streakDays-day under-budget streak',
      detail: streakDays >= 7
          ? 'A week straight under your daily average — excellent discipline!'
          : 'You\'re on a roll. Hit 7 days to unlock an A+ grade bonus.',
      type: InsightType.good,
    ));
  }

  // Anomaly insights
  for (final a in anomalies.take(3)) {
    insights.add(Insight(
      emoji: a.category.emoji,
      title: '${a.category.label} spiked ${a.ratio.toStringAsFixed(1)}×',
      detail:
          '${CurrencyFormatter.compact(a.thisMonth)} this month vs ${CurrencyFormatter.compact(a.rollingAvg)} average. Worth reviewing.',
      type: a.ratio >= 2.5 ? InsightType.danger : InsightType.warning,
    ));
  }

  // Top category context
  if (topCat != null && topAmt > 0) {
    final pct =
        totalSpent > 0 ? (topAmt / totalSpent * 100).toStringAsFixed(0) : '0';
    insights.add(Insight(
      emoji: '📊',
      title: '${topCat!.label} is your top category',
      detail:
          '${CurrencyFormatter.compact(topAmt)} — $pct% of total spending this month.',
      type: InsightType.neutral,
    ));
  }

  // Income source insight
  if (income.length > 1) {
    insights.add(Insight(
      emoji: '💼',
      title: '${income.length} income entries this month',
      detail:
          'Multiple income sources recorded. Total: ${CurrencyFormatter.compact(totalIncome)}.',
      type: InsightType.good,
    ));
  }

  return AiInsightsState(
    report: report,
    insights: insights,
    anomalies: anomalies,
    weekendSpendPercent: weekendPct,
    habitStreakDays: streakDays,
    hourlyPattern: hourlyPattern,
  );
}
