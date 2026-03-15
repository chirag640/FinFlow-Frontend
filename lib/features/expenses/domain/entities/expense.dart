import 'package:equatable/equatable.dart';
import 'expense_category.dart';

/// How often a recurring expense repeats.
enum RecurringFrequency {
  daily,
  weekly,
  monthly,
  yearly;

  String get label => switch (this) {
        RecurringFrequency.daily => 'Daily',
        RecurringFrequency.weekly => 'Weekly',
        RecurringFrequency.monthly => 'Monthly',
        RecurringFrequency.yearly => 'Yearly',
      };

  static RecurringFrequency fromString(String s) =>
      RecurringFrequency.values.firstWhere(
        (f) => f.name == s,
        orElse: () => RecurringFrequency.monthly,
      );
}

class Expense extends Equatable {
  final String id;
  final double amount;
  final String description;
  final ExpenseCategory category;
  final DateTime date;
  final String? note;
  final bool isIncome;
  final bool isRecurring;
  final RecurringFrequency? recurringFrequency;

  const Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    this.note,
    this.isIncome = false,
    this.isRecurring = false,
    this.recurringFrequency,
  });

  Expense copyWith({
    double? amount,
    String? description,
    ExpenseCategory? category,
    DateTime? date,
    String? note,
    bool? isIncome,
    bool? isRecurring,
    RecurringFrequency? recurringFrequency,
    bool clearRecurring = false,
  }) =>
      Expense(
        id: id,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        category: category ?? this.category,
        date: date ?? this.date,
        note: note ?? this.note,
        isIncome: isIncome ?? this.isIncome,
        isRecurring: isRecurring ?? this.isRecurring,
        recurringFrequency: clearRecurring
            ? null
            : recurringFrequency ?? this.recurringFrequency,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'description': description,
        'category': category.name,
        'date': date.toIso8601String(),
        'note': note,
        'isIncome': isIncome,
        'isRecurring': isRecurring,
        'recurringFrequency': recurringFrequency?.name,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        description: j['description'] as String,
        category: ExpenseCategory.fromString(j['category'] as String),
        date: DateTime.parse(j['date'] as String),
        note: j['note'] as String?,
        isIncome: (j['isIncome'] as bool?) ?? false,
        isRecurring: (j['isRecurring'] as bool?) ?? false,
        recurringFrequency: j['recurringFrequency'] != null
            ? RecurringFrequency.fromString(j['recurringFrequency'] as String)
            : null,
      );

  @override
  List<Object?> get props => [
        id,
        amount,
        description,
        category,
        date,
        note,
        isIncome,
        isRecurring,
        recurringFrequency,
      ];
}
