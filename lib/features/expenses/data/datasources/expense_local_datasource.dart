import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/expense.dart';

class ExpenseLocalDatasource {
  Box get _box => HiveService.expenses;
  Box get _pendingDeleteBox => HiveService.pendingDeletions;
  Box get _pendingUpsertBox => HiveService.expensePendingUpserts;

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

  Future<void> save(Expense expense, {bool trackPending = true}) async {
    await _box.put(expense.id, json.encode(expense.toJson()));
    await clearPendingDeletion(expense.id);
    if (trackPending) {
      await addPendingUpsert(expense.id);
    }
  }

  Future<void> delete(String id, {bool trackPending = true}) async {
    await _box.delete(id);
    await clearPendingUpsert(id);
    if (trackPending) {
      await addPendingDeletion(id);
    } else {
      await clearPendingDeletion(id);
    }
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

  /// Queue an upsert for server reconciliation on next sync.
  Future<void> addPendingUpsert(String id) async {
    await _pendingUpsertBox.put(id, '1');
  }

  /// All expense IDs that changed locally and are pending sync.
  List<String> getPendingUpserts() {
    return _pendingUpsertBox.keys.cast<String>().toList();
  }

  /// Remove a single pending upsert ID.
  Future<void> clearPendingUpsert(String id) async {
    await _pendingUpsertBox.delete(id);
  }

  /// Clear all pending upserts after successful sync push.
  Future<void> clearAllPendingUpserts() async {
    await _pendingUpsertBox.clear();
  }

  /// Queue a deletion for server reconciliation on next sync.
  Future<void> addPendingDeletion(String id) async {
    await _pendingDeleteBox.put(id, '1');
  }

  /// All expense IDs that were deleted while offline and not yet synced.
  List<String> getPendingDeletions() {
    return _pendingDeleteBox.keys.cast<String>().toList();
  }

  /// Remove a single ID after the server confirms deletion.
  Future<void> clearPendingDeletion(String id) async {
    await _pendingDeleteBox.delete(id);
  }

  /// Remove all queued deletions after a successful sync push.
  Future<void> clearAllPendingDeletions() async {
    await _pendingDeleteBox.clear();
  }
}
