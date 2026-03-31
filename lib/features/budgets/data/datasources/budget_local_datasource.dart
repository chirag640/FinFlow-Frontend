import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/budget.dart';

class BudgetLocalDatasource {
  Box get _box => HiveService.budgets;
  Box get _pendingUpsertBox => HiveService.budgetPendingUpserts;
  Box get _pendingDeleteBox => HiveService.budgetPendingDeletions;

  String _key(int month, int year) => 'budgets_${year}_$month';

  List<Budget> getBudgetsForMonth(int month, int year) {
    final raw = _box.get(_key(month, year)) as String?;
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list.map((e) => Budget.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveBudget(Budget budget, {bool trackPending = true}) async {
    final budgets = getBudgetsForMonth(budget.month, budget.year);
    final idx = budgets.indexWhere((b) => b.id == budget.id);
    if (idx >= 0) {
      budgets[idx] = budget;
    } else {
      budgets.add(budget);
    }
    await _box.put(_key(budget.month, budget.year),
        json.encode(budgets.map((b) => b.toJson()).toList()));

    await clearPendingDeletion(budget.id);
    if (trackPending) {
      await addPendingUpsert(budget.id);
    }
  }

  Future<void> deleteBudget(
    String id,
    int month,
    int year, {
    bool trackPending = true,
  }) async {
    final budgets = getBudgetsForMonth(month, year);
    budgets.removeWhere((b) => b.id == id);
    await _box.put(_key(month, year),
        json.encode(budgets.map((b) => b.toJson()).toList()));

    await clearPendingUpsert(id);
    if (trackPending) {
      await addPendingDeletion(id);
    } else {
      await clearPendingDeletion(id);
    }
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

  Future<void> addPendingUpsert(String id) async {
    await _pendingUpsertBox.put(id, '1');
  }

  List<String> getPendingUpserts() {
    return _pendingUpsertBox.keys.cast<String>().toList();
  }

  Future<void> clearPendingUpsert(String id) async {
    await _pendingUpsertBox.delete(id);
  }

  Future<void> clearAllPendingUpserts() async {
    await _pendingUpsertBox.clear();
  }

  Future<void> addPendingDeletion(String id) async {
    await _pendingDeleteBox.put(id, '1');
  }

  List<String> getPendingDeletions() {
    return _pendingDeleteBox.keys.cast<String>().toList();
  }

  Future<void> clearPendingDeletion(String id) async {
    await _pendingDeleteBox.delete(id);
  }

  Future<void> clearAllPendingDeletions() async {
    await _pendingDeleteBox.clear();
  }
}
