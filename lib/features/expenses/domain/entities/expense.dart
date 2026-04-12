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
  static const _sentinel = Object();
  final ExpenseCategory category;
  final DateTime date;
  final String? note;
  final bool isIncome;
  final bool isRecurring;
  final RecurringFrequency? recurringFrequency;
  final int? recurringDueDay;
  final String? receiptImageBase64;
  final String? receiptImageMimeType;
  final String? receiptImageUrl;
  final String? receiptStorageKey;
  final String? receiptOcrText;
  final DateTime updatedAt;

  Expense({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.date,
    this.note,
    this.isIncome = false,
    this.isRecurring = false,
    this.recurringFrequency,
    this.recurringDueDay,
    this.receiptImageBase64,
    this.receiptImageMimeType,
    this.receiptImageUrl,
    this.receiptStorageKey,
    this.receiptOcrText,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Expense copyWith({
    double? amount,
    String? description,
    ExpenseCategory? category,
    DateTime? date,
    Object? note = _sentinel,
    bool? isIncome,
    bool? isRecurring,
    Object? recurringFrequency = _sentinel,
    Object? recurringDueDay = _sentinel,
    Object? receiptImageBase64 = _sentinel,
    Object? receiptImageMimeType = _sentinel,
    Object? receiptImageUrl = _sentinel,
    Object? receiptStorageKey = _sentinel,
    Object? receiptOcrText = _sentinel,
    DateTime? updatedAt,
    bool clearRecurring = false,
    bool clearRecurringDueDay = false,
  }) =>
      Expense(
        id: id,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        category: category ?? this.category,
        date: date ?? this.date,
        note: identical(note, _sentinel) ? this.note : note as String?,
        isIncome: isIncome ?? this.isIncome,
        isRecurring: isRecurring ?? this.isRecurring,
        recurringFrequency: clearRecurring
            ? null
            : identical(recurringFrequency, _sentinel)
                ? this.recurringFrequency
                : recurringFrequency as RecurringFrequency?,
        recurringDueDay: clearRecurringDueDay
            ? null
            : identical(recurringDueDay, _sentinel)
                ? this.recurringDueDay
                : recurringDueDay as int?,
        receiptImageBase64: identical(receiptImageBase64, _sentinel)
            ? this.receiptImageBase64
            : receiptImageBase64 as String?,
        receiptImageMimeType: identical(receiptImageMimeType, _sentinel)
            ? this.receiptImageMimeType
            : receiptImageMimeType as String?,
        receiptImageUrl: identical(receiptImageUrl, _sentinel)
            ? this.receiptImageUrl
            : receiptImageUrl as String?,
        receiptStorageKey: identical(receiptStorageKey, _sentinel)
            ? this.receiptStorageKey
            : receiptStorageKey as String?,
        receiptOcrText: identical(receiptOcrText, _sentinel)
            ? this.receiptOcrText
            : receiptOcrText as String?,
        updatedAt: updatedAt ?? DateTime.now(),
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
        'recurringDueDay': recurringDueDay,
        'receiptImageBase64': receiptImageBase64,
        'receiptImageMimeType': receiptImageMimeType,
        'receiptImageUrl': receiptImageUrl,
        'receiptStorageKey': receiptStorageKey,
        'receiptOcrText': receiptOcrText,
        'updatedAt': updatedAt.toIso8601String(),
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
        recurringDueDay: (j['recurringDueDay'] as num?)?.toInt(),
        receiptImageBase64: j['receiptImageBase64'] as String?,
        receiptImageMimeType: j['receiptImageMimeType'] as String?,
        receiptImageUrl: j['receiptImageUrl'] as String?,
        receiptStorageKey: j['receiptStorageKey'] as String?,
        receiptOcrText: j['receiptOcrText'] as String?,
        updatedAt: _parseDateTime(j['updatedAt']) ??
            _parseDateTime(j['date']) ??
            DateTime.now(),
      );

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

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
        recurringDueDay,
        receiptImageBase64,
        receiptImageMimeType,
        receiptImageUrl,
        receiptStorageKey,
        receiptOcrText,
        updatedAt,
      ];
}
