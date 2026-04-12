import 'package:finflow/features/expenses/domain/entities/expense.dart';
import 'package:finflow/features/expenses/domain/entities/expense_category.dart';
import 'package:finflow/features/expenses/presentation/services/transaction_entry_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Expense buildExpense({
    required String id,
    required String description,
    required double amount,
    required ExpenseCategory category,
    required DateTime date,
    required bool isIncome,
  }) {
    return Expense(
      id: id,
      amount: amount,
      description: description,
      category: category,
      date: date,
      isIncome: isIncome,
    );
  }

  group('TransactionEntrySuggestionService', () {
    final now = DateTime(2026, 4, 12);

    final history = <Expense>[
      buildExpense(
        id: '1',
        description: 'Coffee at Third Wave',
        amount: 240,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(days: 1)),
        isIncome: false,
      ),
      buildExpense(
        id: '2',
        description: 'Coffee at Third Wave',
        amount: 260,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(days: 3)),
        isIncome: false,
      ),
      buildExpense(
        id: '3',
        description: 'Uber ride to office',
        amount: 410,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 2)),
        isIncome: false,
      ),
      buildExpense(
        id: '4',
        description: 'Salary April',
        amount: 50000,
        category: ExpenseCategory.other,
        date: now.subtract(const Duration(days: 4)),
        isIncome: true,
      ),
      buildExpense(
        id: '5',
        description: 'Freelance payout',
        amount: 12000,
        category: ExpenseCategory.other,
        date: now.subtract(const Duration(days: 6)),
        isIncome: true,
      ),
    ];

    test('returns expense-only suggestions in expense mode', () {
      final suggestions = TransactionEntrySuggestionService.suggest(
        history: history,
        isIncome: false,
        descriptionInput: 'coffee',
      );

      expect(suggestions, isNotEmpty);
      expect(suggestions.first.isIncome, isFalse);
      expect(
        suggestions.first.description.toLowerCase(),
        contains('coffee'),
      );
    });

    test('returns income-only suggestions in income mode', () {
      final suggestions = TransactionEntrySuggestionService.suggest(
        history: history,
        isIncome: true,
        descriptionInput: 'salary',
      );

      expect(suggestions, isNotEmpty);
      expect(suggestions.first.isIncome, isTrue);
      expect(
        suggestions.first.description.toLowerCase(),
        contains('salary'),
      );
    });

    test('uses history to infer category with confidence gate', () {
      final inferred =
          TransactionEntrySuggestionService.inferCategoryFromHistory(
        history: history,
        isIncome: false,
        descriptionInput: 'uber office',
      );

      expect(inferred, ExpenseCategory.transport);
    });

    test('favors amount-similar candidates when amount is typed', () {
      final suggestions = TransactionEntrySuggestionService.suggest(
        history: history,
        isIncome: true,
        descriptionInput: '',
        amountInput: '50000',
      );

      expect(suggestions, isNotEmpty);
      expect(suggestions.first.description.toLowerCase(), contains('salary'));
      expect(suggestions.first.amount, closeTo(50000, 0.001));
    });
  });
}
