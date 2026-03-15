import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';

enum ExpenseCategory {
  food(label: 'Food & Dining', emoji: '🍔', color: AppColors.catFood),
  transport(label: 'Transport', emoji: '🚗', color: AppColors.catTransport),
  shopping(label: 'Shopping', emoji: '🛍️', color: AppColors.catShopping),
  entertainment(
    label: 'Entertainment',
    emoji: '🎬',
    color: AppColors.catEntertainment,
  ),
  bills(label: 'Bills & Utilities', emoji: '💡', color: AppColors.catBills),
  health(label: 'Health', emoji: '💊', color: AppColors.catHealth),
  education(label: 'Education', emoji: '📚', color: AppColors.catEducation),
  travel(label: 'Travel', emoji: '✈️', color: AppColors.catTravel),
  groceries(label: 'Groceries', emoji: '🛒', color: AppColors.catGroceries),
  rent(label: 'Rent & Housing', emoji: '🏠', color: AppColors.catRent),
  subscriptions(
    label: 'Subscriptions',
    emoji: '📱',
    color: AppColors.catSubscriptions,
  ),
  other(label: 'Other', emoji: '💰', color: AppColors.catOther);

  final String label;
  final String emoji;
  final Color color;

  const ExpenseCategory({
    required this.label,
    required this.emoji,
    required this.color,
  });

  /// Stable string key for serialization (same as enum name)
  String get key => name;

  static ExpenseCategory fromString(String value) {
    return ExpenseCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ExpenseCategory.other,
    );
  }
}
