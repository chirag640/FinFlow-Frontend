// Figma: Screen/Analytics
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/entities/expense_category.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});
  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  int _touchedIndex = -1;
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final expState = ref.watch(expenseProvider);

    // All non-income expenses for the selected year
    final yearExpenses = expState.expenses
        .where((e) => !e.isIncome && e.date.year == _selectedYear)
        .toList();

    // Category totals
    final catTotals = <ExpenseCategory, double>{};
    for (final e in yearExpenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final totalSpent = catTotals.values.fold(0.0, (s, v) => s + v);
    final sorted = catTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Monthly totals (Jan–Dec) — expenses
    final monthly = List.generate(12, (i) {
      return yearExpenses
          .where((e) => e.date.month == i + 1)
          .fold<double>(0, (s, e) => s + e.amount);
    });
    final maxMonthly = monthly.isEmpty
        ? 1.0
        : monthly.fold<double>(0, (a, b) => a > b ? a : b);

    // Monthly income for selected year
    final monthlyIncome = List.generate(12, (i) {
      return expState.expenses
          .where((e) =>
              e.isIncome &&
              e.date.year == _selectedYear &&
              e.date.month == i + 1)
          .fold<double>(0, (s, e) => s + e.amount);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 64,
            titleSpacing: 4,
            actionsPadding: const EdgeInsets.only(right: 8),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            ),
            centerTitle: true,
            title: Text(
              'Finance Analytics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
            ),
            actions: [
              // Year picker
              PopupMenuButton<int>(
                initialValue: _selectedYear,
                onSelected: (y) => setState(() => _selectedYear = y),
                itemBuilder: (_) => List.generate(5, (i) {
                  final y = DateTime.now().year - i;
                  return PopupMenuItem(value: y, child: Text('$y'));
                }),
                child: Container(
                  margin: EdgeInsets.only(right: R.s(12)),
                  padding: EdgeInsets.symmetric(
                      horizontal: R.s(12), vertical: R.s(6)),
                  decoration: BoxDecoration(
                    color: AppColors.primaryExtraLight,
                    borderRadius: BorderRadius.circular(R.sm),
                  ),
                  child: Row(children: [
                    Text('$_selectedYear',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    Gap(R.xs),
                    Icon(Icons.expand_more_rounded,
                        size: R.s(18), color: AppColors.primary),
                  ]),
                ),
              ),
            ],
          ),

          // ── Content ───────────────────────────────────────────────────────
          SliverPadding(
            padding: EdgeInsets.all(R.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Total card
                _TotalCard(total: totalSpent, year: _selectedYear)
                    .animate()
                    .fadeIn()
                    .slideY(begin: 0.1),
                const Gap(20),

                // Pie chart + legend
                if (sorted.isNotEmpty) ...[
                  _SectionHeader(title: 'Spending by Category'),
                  const Gap(12),
                  _CategoryPieSection(
                    sorted: sorted,
                    totalSpent: totalSpent,
                    touchedIndex: _touchedIndex,
                    onTouch: (i) => setState(() => _touchedIndex = i),
                  ).animate().fadeIn(delay: 100.ms),
                  const Gap(20),
                ],

                // Monthly bar chart
                _SectionHeader(title: 'Monthly Spending'),
                const Gap(12),
                _MonthlyBarChart(
                  monthly: monthly,
                  maxVal: maxMonthly > 0 ? maxMonthly : 1,
                ).animate().fadeIn(delay: 200.ms),
                const Gap(20),

                // Income vs Expenses comparison
                _SectionHeader(title: 'Income vs Expenses'),
                const Gap(12),
                _IncomeVsExpenseChart(
                  income: monthlyIncome,
                  expenses: monthly,
                ).animate().fadeIn(delay: 230.ms),
                const Gap(20),

                // Recurring vs one-off breakdown
                if (yearExpenses.isNotEmpty) ...[
                  _SectionHeader(title: 'Recurring vs One-off'),
                  const Gap(12),
                  _RecurringBreakdown(expenses: yearExpenses)
                      .animate()
                      .fadeIn(delay: 250.ms),
                  const Gap(20),
                ],

                // Category breakdown list
                if (sorted.isNotEmpty) ...[
                  _SectionHeader(title: 'Category Breakdown'),
                  const Gap(12),
                  ...sorted.asMap().entries.map((entry) {
                    final i = entry.key;
                    final data = entry.value;
                    final pct = totalSpent > 0
                        ? (data.value / totalSpent * 100).toStringAsFixed(1)
                        : '0';
                    return _CategoryRow(
                      category: data.key,
                      amount: data.value,
                      pct: pct,
                    ).animate().fadeIn(delay: (300 + i * 50).ms);
                  }),
                  const Gap(20),
                ],

                // Category trend lines — last 6 rolling months
                _SectionHeader(title: 'Category Trends'),
                const Gap(4),
                Text(
                  'Top 3 categories · last 6 months',
                  style: TextStyle(
                      fontSize: R.t(11), color: AppColors.textTertiary),
                ),
                const Gap(12),
                _CategoryTrendChart(allExpenses: expState.expenses)
                    .animate()
                    .fadeIn(delay: 500.ms),
                const Gap(20),

                // Daily spending heatmap
                _SectionHeader(title: 'Daily Spending Heatmap'),
                const Gap(4),
                Text(
                  '$_selectedYear · tap a cell to see the day\'s total',
                  style: TextStyle(
                      fontSize: R.t(11), color: AppColors.textTertiary),
                ),
                const Gap(12),
                _SpendingHeatmap(
                  expenses: expState.expenses,
                  year: _selectedYear,
                ).animate().fadeIn(delay: 600.ms),
                const Gap(20),

                // Day-of-week spending pattern
                _SectionHeader(title: 'Spending by Day of Week'),
                const Gap(4),
                Text(
                  '$_selectedYear · avg spend per day',
                  style: TextStyle(
                      fontSize: R.t(11), color: AppColors.textTertiary),
                ),
                const Gap(12),
                _DayOfWeekChart(expenses: yearExpenses)
                    .animate()
                    .fadeIn(delay: 700.ms),

                const Gap(24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Total Card ────────────────────────────────────────────────────────────────
class _TotalCard extends StatelessWidget {
  final double total;
  final int year;
  const _TotalCard({required this.total, required this.year});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      padding: EdgeInsets.all(R.s(20)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(R.s(20)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total spent in $year',
            style: TextStyle(color: Colors.white70, fontSize: R.t(13))),
        Gap(R.xs),
        Text(fmt.format(total),
            style: TextStyle(
                color: Colors.white,
                fontSize: R.t(32),
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
      );
}

// ── Category Pie Section ──────────────────────────────────────────────────────
class _CategoryPieSection extends StatelessWidget {
  final List<MapEntry<ExpenseCategory, double>> sorted;
  final double totalSpent;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _CategoryPieSection({
    required this.sorted,
    required this.totalSpent,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        SizedBox(
          height: R.s(200),
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, resp) {
                  if (!event.isInterestedForInteractions ||
                      resp?.touchedSection == null) {
                    onTouch(-1);
                    return;
                  }
                  onTouch(resp!.touchedSection!.touchedSectionIndex);
                },
              ),
              sections: sorted.asMap().entries.map((entry) {
                final i = entry.key;
                final cat = entry.value.key;
                final amount = entry.value.value;
                final isTouched = i == touchedIndex;
                return PieChartSectionData(
                  value: amount,
                  color: cat.color,
                  radius: isTouched ? 90 : 80,
                  title: isTouched
                      ? '${(amount / totalSpent * 100).toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                  badgeWidget: isTouched
                      ? Container(
                          padding: EdgeInsets.all(R.s(6)),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4)
                            ],
                          ),
                          child: Text(cat.emoji,
                              style: TextStyle(fontSize: R.t(14))),
                        )
                      : null,
                  badgePositionPercentageOffset: 1.1,
                );
              }).toList(),
              centerSpaceRadius: 50,
              sectionsSpace: 2,
            ),
          ),
        ),
        const Gap(16),
        // Mini legend (top 5)
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: sorted.take(5).map((entry) {
            return Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: R.s(10),
                  height: R.s(10),
                  decoration: BoxDecoration(
                      color: entry.key.color, shape: BoxShape.circle)),
              Gap(R.xs),
              Text(entry.key.label,
                  style: TextStyle(
                      fontSize: R.t(11), color: AppColors.textSecondary)),
            ]);
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Monthly Bar Chart ─────────────────────────────────────────────────────────
class _MonthlyBarChart extends StatelessWidget {
  final List<double> monthly; // 12 values
  final double maxVal;
  const _MonthlyBarChart({required this.monthly, required this.maxVal});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
    return Container(
      height: R.s(200),
      padding: EdgeInsets.fromLTRB(R.sm, R.md, R.sm, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.border,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) => Text(
                  months[v.toInt()],
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ),
            ),
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: List.generate(12, (i) {
            final isCurrentMonth = i == DateTime.now().month - 1;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: monthly[i],
                  color: isCurrentMonth
                      ? AppColors.primary
                      : AppColors.primaryExtraLight,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.darkSurface,
              getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                '₹${NumberFormat.compact().format(rod.toY)}',
                const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Income vs Expense Chart ───────────────────────────────────────────────────
// Figma: Card/IncomeVsExpense
class _IncomeVsExpenseChart extends StatelessWidget {
  final List<double> income; // 12 monthly values
  final List<double> expenses; // 12 monthly values

  const _IncomeVsExpenseChart({
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    const incomeColor = Color(0xFF10B981); // emerald
    const expenseColor = AppColors.primary; // indigo

    final months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

    final allValues = [...income, ...expenses];
    final maxVal =
        allValues.isEmpty ? 1.0 : allValues.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.fromLTRB(R.sm, R.md, R.sm, R.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: incomeColor, label: 'Income'),
              const Gap(20),
              _LegendDot(color: expenseColor, label: 'Expenses'),
            ],
          ),
          const Gap(12),
          SizedBox(
            height: R.s(200),
            child: BarChart(
              BarChartData(
                maxY: maxVal * 1.2 == 0 ? 1 : maxVal * 1.2,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal > 0 ? maxVal / 4 : 1,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        months[v.toInt()],
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                groupsSpace: 4,
                barGroups: List.generate(12, (i) {
                  return BarChartGroupData(
                    x: i,
                    groupVertically: false,
                    barRods: [
                      BarChartRodData(
                        toY: income[i],
                        color: incomeColor,
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      BarChartRodData(
                        toY: expenses[i],
                        color: expenseColor,
                        width: 8,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.darkSurface,
                    getTooltipItem: (group, _, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Income' : 'Expense';
                      return BarTooltipItem(
                        '$label\n₹${NumberFormat.compact().format(rod.toY)}',
                        const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: R.s(10),
        height: R.s(10),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      Gap(R.s(5)),
      Text(label,
          style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
    ]);
  }
}

// ── Category Row ──────────────────────────────────────────────────────────────
class _CategoryRow extends StatelessWidget {
  final ExpenseCategory category;
  final double amount;
  final String pct;
  const _CategoryRow({
    required this.category,
    required this.amount,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return Container(
      margin: EdgeInsets.only(bottom: R.sm),
      padding: EdgeInsets.symmetric(horizontal: R.s(14), vertical: R.s(12)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.s(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: R.s(36),
          height: R.s(36),
          decoration: BoxDecoration(
            color: category.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(R.s(10)),
          ),
          child: Center(
              child: Text(category.emoji, style: TextStyle(fontSize: R.t(18)))),
        ),
        Gap(R.s(12)),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category.label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: R.t(14))),
            Gap(R.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(R.xs),
              child: LinearProgressIndicator(
                value: double.parse(pct) / 100,
                minHeight: R.xs,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(category.color),
              ),
            ),
          ]),
        ),
        Gap(R.s(12)),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmt.format(amount),
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontSize: R.t(14))),
          Text('$pct%',
              style:
                  TextStyle(fontSize: R.t(11), color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

// ── Recurring Breakdown ───────────────────────────────────────────────────────
class _RecurringBreakdown extends StatelessWidget {
  final List<dynamic> expenses; // List<Expense>
  const _RecurringBreakdown({required this.expenses});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final typed = expenses.cast<Expense>();
    final recurring = typed.where((e) => e.isRecurring);
    final oneOff = typed.where((e) => !e.isRecurring);

    final recurringTotal = recurring.fold(0.0, (s, e) => s + e.amount);
    final oneOffTotal = oneOff.fold(0.0, (s, e) => s + e.amount);
    final grandTotal = recurringTotal + oneOffTotal;
    final recurringPct = grandTotal > 0 ? recurringTotal / grandTotal : 0.0;

    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Two stat tiles
        Row(children: [
          _MiniStatTile(
            icon: Icons.repeat_rounded,
            label: 'Recurring',
            value: fmt.format(recurringTotal),
            count: recurring.length,
            color: AppColors.primary,
          ),
          Gap(R.s(12)),
          _MiniStatTile(
            icon: Icons.receipt_long_rounded,
            label: 'One-off',
            value: fmt.format(oneOffTotal),
            count: oneOff.length,
            color: AppColors.accent,
          ),
        ]),
        Gap(R.s(14)),
        // Split bar
        ClipRRect(
          borderRadius: BorderRadius.circular(R.s(6)),
          child: SizedBox(
            height: R.s(10),
            child: Row(children: [
              Flexible(
                flex: (recurringPct * 1000).round(),
                child: Container(color: AppColors.primary),
              ),
              Flexible(
                flex: ((1 - recurringPct) * 1000).round(),
                child:
                    Container(color: AppColors.accent.withValues(alpha: 0.5)),
              ),
            ]),
          ),
        ),
        Gap(R.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                  width: R.s(8),
                  height: R.s(8),
                  decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
              Gap(R.xs),
              Text(
                'Recurring ${(recurringPct * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: R.t(11), color: AppColors.textSecondary),
              ),
            ]),
            Row(children: [
              Container(
                  width: R.s(8),
                  height: R.s(8),
                  decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.5),
                      shape: BoxShape.circle)),
              Gap(R.xs),
              Text(
                'One-off ${((1 - recurringPct) * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: R.t(11), color: AppColors.textSecondary),
              ),
            ]),
          ],
        ),
      ]),
    );
  }
}

class _MiniStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int count;
  final Color color;

  const _MiniStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(R.s(12)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(R.s(12)),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: R.s(16), color: color),
            Gap(R.s(6)),
            Text(label,
                style: TextStyle(
                    fontSize: R.t(11),
                    fontWeight: FontWeight.w600,
                    color: color)),
          ]),
          Gap(R.s(6)),
          Text(value,
              style: TextStyle(
                  fontSize: R.t(16),
                  fontWeight: FontWeight.w800,
                  color: color)),
          Text('$count transaction${count == 1 ? '' : 's'}',
              style:
                  TextStyle(fontSize: R.t(10), color: AppColors.textTertiary)),
        ]),
      ),
    );
  }
}

// ── Category Trend Chart ──────────────────────────────────────────────────────/// Line chart showing monthly spend for the top-3 categories over the last
/// 6 rolling months. Uses all expenses in state (not year-filtered).
class _CategoryTrendChart extends StatelessWidget {
  final List<dynamic> allExpenses;
  const _CategoryTrendChart({required this.allExpenses});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final expenses = allExpenses.cast<Expense>().where((e) => !e.isIncome);

    // Build last-6-months date range
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final offset = 5 - i;
      return DateTime(now.year, now.month - offset, 1);
    });

    // Total per category across 6 months — pick top 3
    final catTotals = <ExpenseCategory, double>{};
    for (final e in expenses) {
      catTotals[e.category] = (catTotals[e.category] ?? 0) + e.amount;
    }
    final top3 = (catTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => e.key)
        .toList();

    if (top3.isEmpty) {
      return SizedBox(
        height: R.s(160),
        child: const Center(
          child: Text('No expense data yet',
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
        ),
      );
    }

    // Monthly totals per top category
    double maxY = 0;
    final lineSeries = top3.map((cat) {
      final spots = months.asMap().entries.map((entry) {
        final i = entry.key;
        final m = entry.value;
        final total = expenses
            .where((e) =>
                e.category == cat &&
                e.date.year == m.year &&
                e.date.month == m.month)
            .fold(0.0, (s, e) => s + e.amount);
        if (total > maxY) maxY = total;
        return FlSpot(i.toDouble(), total);
      }).toList();
      return LineChartBarData(
        spots: spots,
        isCurved: true,
        curveSmoothness: 0.35,
        color: cat.color,
        barWidth: 2.5,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
            radius: 3,
            color: cat.color,
            strokeWidth: 1.5,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: cat.color.withValues(alpha: 0.06),
        ),
      );
    }).toList();

    final monthLabels = months.map((m) => DateFormat('MMM').format(m)).toList();

    return Container(
      padding: EdgeInsets.fromLTRB(R.sm, R.md, R.md, R.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: top3.map((cat) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: R.sm),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: R.s(12),
                    height: R.s(3),
                    decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(R.s(2)))),
                Gap(R.xs),
                Text(cat.label,
                    style: TextStyle(
                        fontSize: R.t(10), color: AppColors.textSecondary)),
              ]),
            );
          }).toList(),
        ),
        Gap(R.s(12)),
        SizedBox(
          height: R.s(180),
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 5,
              minY: 0,
              maxY: maxY * 1.25 == 0 ? 1 : maxY * 1.25,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= monthLabels.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(monthLabels[i],
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary));
                    },
                  ),
                ),
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.darkSurface,
                  getTooltipItems: (spots) => spots.map((s) {
                    return LineTooltipItem(
                      '₹${NumberFormat.compact().format(s.y)}',
                      TextStyle(
                          color: s.bar.color ?? Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: lineSeries,
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Spending Heatmap ──────────────────────────────────────────────────────────
// Figma: Card/SpendingHeatmap
// GitHub-style full-year contribution grid: 52-53 columns × 7 rows.
// Each cell = 1 calendar day; color intensity = daily spend ratio vs max day.
class _SpendingHeatmap extends StatefulWidget {
  final List<dynamic> expenses;
  final int year;

  const _SpendingHeatmap({required this.expenses, required this.year});

  @override
  State<_SpendingHeatmap> createState() => _SpendingHeatmapState();
}

class _SpendingHeatmapState extends State<_SpendingHeatmap> {
  DateTime? _tooltipDay;
  double _tooltipAmount = 0;

  static const double _cellSize = 10;
  static const double _cellGap = 3;
  static const double _dayLabelW = 18;

  @override
  Widget build(BuildContext context) {
    R.init(context);
    // Build daily spend totals (non-income only, selected year)
    final dailyTotals = <DateTime, double>{};
    for (final raw in widget.expenses) {
      final e = raw as Expense;
      if (e.isIncome || e.date.year != widget.year) continue;
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      dailyTotals[day] = (dailyTotals[day] ?? 0) + e.amount;
    }

    final maxDay = dailyTotals.values.isEmpty
        ? 1.0
        : dailyTotals.values.reduce((a, b) => a > b ? a : b);

    // Year layout
    final jan1 = DateTime(widget.year, 1, 1);
    // weekday: Mon=1 … Sun=7; offset so Mon = col 0
    final startOffset = jan1.weekday - 1; // 0–6
    final isLeap = (widget.year % 4 == 0) &&
        (widget.year % 100 != 0 || widget.year % 400 == 0);
    final totalDays = isLeap ? 366 : 365;
    final numWeeks = ((startOffset + totalDays) / 7).ceil();

    // Month label positions (column index of first day in each month)
    final monthLabels = <int, String>{};
    int curMonth = 0;
    for (int d = 0; d < totalDays; d++) {
      final date = jan1.add(Duration(days: d));
      if (date.month != curMonth) {
        curMonth = date.month;
        final col = (startOffset + d) ~/ 7;
        monthLabels[col] = DateFormat('MMM').format(date);
      }
    }

    // Grid dimensions
    const monthLabelH = 14.0;
    const step = _cellSize + _cellGap;
    final gridW = numWeeks * step - _cellGap;
    final totalW = gridW < 300 ? 300.0 : gridW;
    final totalH = monthLabelH + _cellGap + 7 * step - _cellGap;

    Color cellColor(double amount) {
      if (amount <= 0) return AppColors.border.withValues(alpha: 0.45);
      final r = (amount / maxDay).clamp(0.0, 1.0);
      if (r < 0.25) return AppColors.primary.withValues(alpha: 0.22);
      if (r < 0.50) return AppColors.primary.withValues(alpha: 0.45);
      if (r < 0.75) return AppColors.primary.withValues(alpha: 0.70);
      return AppColors.primary;
    }

    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    // Build all cell positioned widgets
    final cells = <Widget>[];

    // Month labels (top)
    monthLabels.forEach((col, label) {
      cells.add(Positioned(
        left: _dayLabelW + _cellGap + col * step,
        top: 0,
        child: Text(label,
            style:
                const TextStyle(fontSize: 8.5, color: AppColors.textTertiary)),
      ));
    });

    // Day-of-week micro-labels (Mon, Wed, Fri)
    const dowLabels = ['M', '', 'W', '', 'F', '', ''];
    for (int dow = 0; dow < 7; dow++) {
      if (dowLabels[dow].isEmpty) continue;
      cells.add(Positioned(
        left: 0,
        top: monthLabelH + _cellGap + dow * step + (_cellSize - 8.5) / 2,
        child: SizedBox(
          width: _dayLabelW - 2,
          child: Text(dowLabels[dow],
              textAlign: TextAlign.right,
              style:
                  const TextStyle(fontSize: 8, color: AppColors.textTertiary)),
        ),
      ));
    }

    // Day cells
    for (int week = 0; week < numWeeks; week++) {
      for (int dow = 0; dow < 7; dow++) {
        final dayIndex = week * 7 + dow - startOffset;
        if (dayIndex < 0 || dayIndex >= totalDays) continue;
        final date = jan1.add(Duration(days: dayIndex));
        final normalised = DateTime(date.year, date.month, date.day);
        final amount = dailyTotals[normalised] ?? 0;
        final isSelected = _tooltipDay != null &&
            _tooltipDay!.year == date.year &&
            _tooltipDay!.month == date.month &&
            _tooltipDay!.day == date.day;

        cells.add(Positioned(
          left: _dayLabelW + _cellGap + week * step,
          top: monthLabelH + _cellGap + dow * step,
          child: GestureDetector(
            onTap: () => setState(() {
              if (isSelected) {
                _tooltipDay = null;
              } else {
                _tooltipDay = date;
                _tooltipAmount = amount;
              }
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: cellColor(amount),
                borderRadius: BorderRadius.circular(2),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
            ),
          ),
        ));
      }
    }

    return Container(
      padding: EdgeInsets.all(R.s(14)),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scrollable grid
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: totalW,
              height: totalH,
              child: Stack(children: cells),
            ),
          ),

          // Tooltip row
          if (_tooltipDay != null) ...[
            Gap(R.s(10)),
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: R.s(12), vertical: R.sm),
              decoration: BoxDecoration(
                color: AppColors.darkSurface,
                borderRadius: BorderRadius.circular(R.s(10)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  DateFormat('d MMM y').format(_tooltipDay!),
                  style: TextStyle(color: Colors.white70, fontSize: R.t(12)),
                ),
                const Gap(10),
                Text(
                  _tooltipAmount > 0
                      ? fmt.format(_tooltipAmount)
                      : 'No spending',
                  style: TextStyle(
                    color: _tooltipAmount > 0 ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w700,
                    fontSize: R.t(12),
                  ),
                ),
              ]),
            ),
          ],

          // Colour legend
          Gap(R.s(12)),
          Row(children: [
            Text('Less',
                style: TextStyle(
                    fontSize: R.t(10), color: AppColors.textTertiary)),
            const Gap(6),
            for (int i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Container(
                  width: R.s(10),
                  height: R.s(10),
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AppColors.border.withValues(alpha: 0.45)
                        : AppColors.primary
                            .withValues(alpha: [0.22, 0.45, 0.70, 1.0][i - 1]),
                    borderRadius: BorderRadius.circular(R.s(2)),
                  ),
                ),
              ),
            const Gap(6),
            Text('More',
                style: TextStyle(
                    fontSize: R.t(10), color: AppColors.textTertiary)),
          ]),
        ],
      ),
    );
  }
}

// ── Day-of-Week Spending Chart ────────────────────────────────────────────────
// Figma: Card/DayOfWeekChart
/// Bar chart showing average daily spend per weekday (Mon–Sun) for the
/// selected year. The highest-spend day is highlighted in primary colour.
class _DayOfWeekChart extends StatelessWidget {
  final List<Expense> expenses;
  const _DayOfWeekChart({required this.expenses});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const dayFull = [
      'Mondays',
      'Tuesdays',
      'Wednesdays',
      'Thursdays',
      'Fridays',
      'Saturdays',
      'Sundays',
    ];

    // Sum by weekday (0=Mon..6=Sun); count unique calendar days per weekday
    final totals = List.filled(7, 0.0);
    final uniqueDays = List.generate(7, (_) => <String>{});
    for (final e in expenses) {
      final dow = e.date.weekday - 1; // Mon=0 … Sun=6
      totals[dow] += e.amount;
      uniqueDays[dow].add('${e.date.year}-${e.date.month}-${e.date.day}');
    }

    final avgs = List.generate(7,
        (i) => uniqueDays[i].isEmpty ? 0.0 : totals[i] / uniqueDays[i].length);
    final maxAvg = avgs.reduce((a, b) => a > b ? a : b);

    if (maxAvg == 0) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            'No expense data yet',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ),
      );
    }

    final maxIdx = avgs.indexOf(maxAvg);
    final fmt =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Container(
      padding: EdgeInsets.fromLTRB(R.sm, R.md, R.md, R.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: R.sm, bottom: R.s(10)),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: 'You spend most on ',
                  style: TextStyle(
                      fontSize: R.t(12), color: AppColors.textSecondary),
                ),
                TextSpan(
                  text: dayFull[maxIdx],
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                TextSpan(
                  text: '  ·  avg ${fmt.format(maxAvg)}',
                  style: TextStyle(
                      fontSize: R.t(12), color: AppColors.textTertiary),
                ),
              ]),
            ),
          ),
          SizedBox(
            height: R.s(150),
            child: BarChart(
              BarChartData(
                maxY: maxAvg * 1.35,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxAvg * 1.35 / 4,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        dayLabels[v.toInt()],
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: List.generate(7, (i) {
                  final isMax = i == maxIdx;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: avgs[i],
                        color: isMax
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.28),
                        width: 26,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.darkSurface,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${dayLabels[group.x]}\n${fmt.format(rod.toY)} avg',
                      const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 11),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
