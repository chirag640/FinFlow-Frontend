import 'dart:convert';
import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/savings_goal.dart';

class GoalLocalDatasource {
  dynamic get _pendingBox => HiveService.goalPendingDeletions;

  List<SavingsGoal> getAll() {
    final box = HiveService.goals;
    return box.values
        .map((v) => SavingsGoal.fromJson(
            Map<String, dynamic>.from(jsonDecode(v as String) as Map)))
        .toList();
  }

  Future<void> save(SavingsGoal goal) async {
    await HiveService.goals.put(goal.id, jsonEncode(goal.toJson()));
    await clearPendingDeletion(goal.id);
  }

  Future<void> delete(String id, {bool trackPending = true}) async {
    await HiveService.goals.delete(id);
    if (trackPending) {
      await addPendingDeletion(id);
    }
  }

  Future<void> clear() async {
    await HiveService.goals.clear();
    await _pendingBox.clear();
  }

  Future<void> addPendingDeletion(String id) async {
    await _pendingBox.put(id, '1');
  }

  List<String> getPendingDeletions() {
    return _pendingBox.keys.cast<String>().toList();
  }

  Future<void> clearPendingDeletion(String id) async {
    await _pendingBox.delete(id);
  }

  Future<void> clearAllPendingDeletions() async {
    await _pendingBox.clear();
  }
}
