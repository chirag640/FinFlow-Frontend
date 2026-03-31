import 'dart:convert';

import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/savings_goal.dart';

class GoalLocalDatasource {
  dynamic get _pendingDeleteBox => HiveService.goalPendingDeletions;
  dynamic get _pendingUpsertBox => HiveService.goalPendingUpserts;

  List<SavingsGoal> getAll() {
    final box = HiveService.goals;
    return box.values
        .map((v) => SavingsGoal.fromJson(
            Map<String, dynamic>.from(jsonDecode(v as String) as Map)))
        .toList();
  }

  Future<void> save(SavingsGoal goal, {bool trackPendingUpsert = true}) async {
    await HiveService.goals.put(goal.id, jsonEncode(goal.toJson()));
    await clearPendingDeletion(goal.id);
    if (trackPendingUpsert) {
      await addPendingUpsert(goal.id);
    }
  }

  Future<void> delete(String id, {bool trackPending = true}) async {
    await HiveService.goals.delete(id);
    await clearPendingUpsert(id);
    if (trackPending) {
      await addPendingDeletion(id);
    } else {
      await clearPendingDeletion(id);
    }
  }

  Future<void> clear() async {
    await HiveService.goals.clear();
    await _pendingDeleteBox.clear();
    await _pendingUpsertBox.clear();
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
