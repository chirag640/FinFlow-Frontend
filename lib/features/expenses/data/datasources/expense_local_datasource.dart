import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/expense.dart';
import '../../../../core/storage/hive_service.dart';

class ExpenseLocalDatasource {
  Box get _box => HiveService.expenses;
  Box get _pendingBox => HiveService.pendingDeletions;

  List<Expense> getAll() {
    return _box.values
        .map((raw) {
          try {
            return Expense.fromJson(
              json.decode(raw as String) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<Expense>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> save(Expense expense) async {
    await _box.put(expense.id, json.encode(expense.toJson()));
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  List<Expense> getByMonth(int year, int month) {
    return getAll().where((e) {
      return e.date.year == year && e.date.month == month;
    }).toList();
  }

  double totalSpentByMonth(int year, int month) {
    return getByMonth(
      year,
      month,
    ).where((e) => !e.isIncome).fold(0.0, (sum, e) => sum + e.amount);
  }

  double totalIncomeByMonth(int year, int month) {
    return getByMonth(
      year,
      month,
    ).where((e) => e.isIncome).fold(0.0, (sum, e) => sum + e.amount);
  }

  // ── Pending Deletions (offline-delete queue) ─────────────────────────────
  // IDs are stored as keys with a constant value '1' for O(1) lookup.

  /// Queue a deletion for server reconciliation on next sync.
  Future<void> addPendingDeletion(String id) async {
    await _pendingBox.put(id, '1');
  }

  /// All expense IDs that were deleted while offline and not yet synced.
  List<String> getPendingDeletions() {
    return _pendingBox.keys.cast<String>().toList();
  }

  /// Remove a single ID after the server confirms deletion.
  Future<void> clearPendingDeletion(String id) async {
    await _pendingBox.delete(id);
  }

  /// Remove all queued deletions after a successful sync push.
  Future<void> clearAllPendingDeletions() async {
    await _pendingBox.clear();
  }
}
