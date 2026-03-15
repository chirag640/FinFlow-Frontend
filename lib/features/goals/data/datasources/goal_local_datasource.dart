import 'dart:convert';
import '../../../../core/storage/hive_service.dart';
import '../../domain/entities/savings_goal.dart';

class GoalLocalDatasource {
  List<SavingsGoal> getAll() {
    final box = HiveService.goals;
    return box.values
        .map((v) => SavingsGoal.fromJson(
            Map<String, dynamic>.from(jsonDecode(v as String) as Map)))
        .toList();
  }

  Future<void> save(SavingsGoal goal) async {
    await HiveService.goals.put(goal.id, jsonEncode(goal.toJson()));
  }

  Future<void> delete(String id) async {
    await HiveService.goals.delete(id);
  }

  Future<void> clear() async {
    await HiveService.goals.clear();
  }
}
