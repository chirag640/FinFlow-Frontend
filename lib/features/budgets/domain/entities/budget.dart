import 'package:equatable/equatable.dart';

class Budget extends Equatable {
  final String id;
  final String categoryKey; // matches ExpenseCategory.key
  final double allocatedAmount;
  final int month; // 1-12
  final int year;
  final bool carryForward;
  final DateTime updatedAt;

  Budget({
    required this.id,
    required this.categoryKey,
    required this.allocatedAmount,
    required this.month,
    required this.year,
    this.carryForward = false,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  Budget copyWith({
    String? id,
    String? categoryKey,
    double? allocatedAmount,
    int? month,
    int? year,
    bool? carryForward,
    DateTime? updatedAt,
  }) =>
      Budget(
        id: id ?? this.id,
        categoryKey: categoryKey ?? this.categoryKey,
        allocatedAmount: allocatedAmount ?? this.allocatedAmount,
        month: month ?? this.month,
        year: year ?? this.year,
        carryForward: carryForward ?? this.carryForward,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'categoryKey': categoryKey,
        'allocatedAmount': allocatedAmount,
        'month': month,
        'year': year,
        'carryForward': carryForward,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
        id: json['id'] as String,
        categoryKey: json['categoryKey'] as String,
        allocatedAmount: (json['allocatedAmount'] as num).toDouble(),
        month: json['month'] as int,
        year: json['year'] as int,
        carryForward: json['carryForward'] as bool? ?? false,
        updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
      );

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  List<Object?> get props =>
      [id, categoryKey, allocatedAmount, month, year, carryForward, updatedAt];
}
