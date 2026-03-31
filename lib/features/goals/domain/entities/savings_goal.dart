import 'package:equatable/equatable.dart';

class SavingsGoal extends Equatable {
  final String id;
  final String title;
  final String emoji;
  final double targetAmount;
  final double currentAmount;
  final DateTime? deadline;
  final int colorIndex; // indexes into GoalColors.palette
  final DateTime updatedAt;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.emoji,
    required this.targetAmount,
    this.currentAmount = 0,
    this.deadline,
    this.colorIndex = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  double get progressPercent =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => currentAmount >= targetAmount;

  double get remaining =>
      (targetAmount - currentAmount).clamp(0.0, double.infinity);

  SavingsGoal copyWith({
    String? title,
    String? emoji,
    double? targetAmount,
    double? currentAmount,
    DateTime? deadline,
    bool clearDeadline = false,
    int? colorIndex,
    DateTime? updatedAt,
  }) =>
      SavingsGoal(
        id: id,
        title: title ?? this.title,
        emoji: emoji ?? this.emoji,
        targetAmount: targetAmount ?? this.targetAmount,
        currentAmount: currentAmount ?? this.currentAmount,
        deadline: clearDeadline ? null : deadline ?? this.deadline,
        colorIndex: colorIndex ?? this.colorIndex,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'emoji': emoji,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'deadline': deadline?.toIso8601String(),
        'colorIndex': colorIndex,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        emoji: json['emoji'] as String? ?? '🎯',
        targetAmount: (json['targetAmount'] as num).toDouble(),
        currentAmount: (json['currentAmount'] as num? ?? 0).toDouble(),
        deadline: json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String)
            : null,
        colorIndex: json['colorIndex'] as int? ?? 0,
        updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
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
        title,
        emoji,
        targetAmount,
        currentAmount,
        deadline,
        colorIndex,
        updatedAt,
      ];
}
