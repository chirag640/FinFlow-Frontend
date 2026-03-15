class FinancialSummary {
  final double totalIncome;
  final double totalExpenses;
  final double netBalance;
  final double savingsRate; // 0.0 - 1.0
  final Map<String, double> spendingByCategory;
  final List<double> last7DaysSpending; // index 0 = oldest
  final int totalTransactions;

  const FinancialSummary({
    required this.totalIncome,
    required this.totalExpenses,
    required this.netBalance,
    required this.savingsRate,
    required this.spendingByCategory,
    required this.last7DaysSpending,
    required this.totalTransactions,
  });

  factory FinancialSummary.empty() => FinancialSummary(
        totalIncome: 0,
        totalExpenses: 0,
        netBalance: 0,
        savingsRate: 0,
        spendingByCategory: {},
        last7DaysSpending: List.filled(7, 0.0),
        totalTransactions: 0,
      );
}
