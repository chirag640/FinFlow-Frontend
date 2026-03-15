import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/financial_summary.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';

final dashboardProvider = Provider<FinancialSummary>((ref) {
  final expState = ref.watch(expenseProvider);
  final dailySpending = expState.dailySpending(7);
  // Convert Map<ExpenseCategory, double> to Map<String, double>
  final spendingByCategory = expState.byCategory.map(
    (cat, amount) => MapEntry(cat.key, amount),
  );

  return FinancialSummary(
    totalIncome: expState.totalIncome,
    totalExpenses: expState.totalSpent,
    netBalance: expState.totalIncome - expState.totalSpent,
    savingsRate: expState.totalIncome > 0
        ? ((expState.totalIncome - expState.totalSpent) / expState.totalIncome)
            .clamp(0.0, 1.0)
        : 0.0,
    spendingByCategory: spendingByCategory,
    last7DaysSpending: dailySpending,
    totalTransactions: expState.filteredExpenses.length,
  );
});
