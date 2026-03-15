import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/budget.dart';

class BudgetLocalDatasource {
  Box get _box => Hive.box(AppConstants.budgetsBox);

  String _key(int month, int year) => 'budgets_${year}_$month';

  List<Budget> getBudgetsForMonth(int month, int year) {
    final raw = _box.get(_key(month, year)) as String?;
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => Budget.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveBudget(Budget budget) async {
    final budgets = getBudgetsForMonth(budget.month, budget.year);
    final idx = budgets.indexWhere((b) => b.id == budget.id);
    if (idx >= 0) {
      budgets[idx] = budget;
    } else {
      budgets.add(budget);
    }
    await _box.put(_key(budget.month, budget.year),
        json.encode(budgets.map((b) => b.toJson()).toList()));
  }

  Future<void> deleteBudget(String id, int month, int year) async {
    final budgets = getBudgetsForMonth(month, year);
    budgets.removeWhere((b) => b.id == id);
    await _box.put(_key(month, year),
        json.encode(budgets.map((b) => b.toJson()).toList()));
  }

  /// Returns every budget stored across all months/years.
  List<Budget> getAll() {
    final all = <Budget>[];
    for (final key in _box.keys) {
      if (key is String && key.startsWith('budgets_')) {
        try {
          final raw = _box.get(key) as String?;
          if (raw == null) continue;
          final list = json.decode(raw) as List<dynamic>;
          all.addAll(
              list.map((e) => Budget.fromJson(e as Map<String, dynamic>)));
        } catch (_) {}
      }
    }
    return all;
  }
}
