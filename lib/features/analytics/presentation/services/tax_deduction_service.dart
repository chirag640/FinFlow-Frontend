import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/domain/entities/expense_category.dart';

class TaxDeductionSummary {
  final double totalSpend;
  final double estimatedDeductible;
  final Map<ExpenseCategory, double> deductibleByCategory;

  const TaxDeductionSummary({
    required this.totalSpend,
    required this.estimatedDeductible,
    required this.deductibleByCategory,
  });

  double get deductibleRatio {
    if (totalSpend <= 0) return 0;
    return (estimatedDeductible / totalSpend).clamp(0.0, 1.0);
  }
}

abstract class TaxDeductionService {
  static TaxDeductionSummary summarize(List<Expense> expenses) {
    final spendOnly = expenses.where((e) => !e.isIncome);
    var totalSpend = 0.0;
    var estimatedDeductible = 0.0;
    final deductibleByCategory = <ExpenseCategory, double>{};

    for (final expense in spendOnly) {
      totalSpend += expense.amount;
      final ratio = _deductionRatio(expense.category);
      if (ratio <= 0) continue;

      final deductible = expense.amount * ratio;
      estimatedDeductible += deductible;
      deductibleByCategory[expense.category] =
          (deductibleByCategory[expense.category] ?? 0) + deductible;
    }

    return TaxDeductionSummary(
      totalSpend: totalSpend,
      estimatedDeductible: estimatedDeductible,
      deductibleByCategory: deductibleByCategory,
    );
  }

  static double _deductionRatio(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.education:
        return 0.8;
      case ExpenseCategory.health:
        return 0.7;
      case ExpenseCategory.rent:
        return 0.5;
      case ExpenseCategory.travel:
        return 0.25;
      case ExpenseCategory.bills:
        return 0.2;
      case ExpenseCategory.food:
      case ExpenseCategory.transport:
      case ExpenseCategory.shopping:
      case ExpenseCategory.entertainment:
      case ExpenseCategory.groceries:
      case ExpenseCategory.subscriptions:
      case ExpenseCategory.other:
        return 0;
    }
  }
}
