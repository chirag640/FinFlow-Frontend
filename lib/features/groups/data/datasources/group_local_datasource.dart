import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/group.dart';
import '../../domain/entities/group_expense.dart';
import '../../../../core/storage/hive_service.dart';

class GroupLocalDatasource {
  Box get _groupBox => HiveService.groups;

  static const String _expensesKey = 'group_expenses';
  Box get _expenseBox => HiveService.settings;

  // ── Groups ─────────────────────────────────────────────────────────────────
  List<Group> getAllGroups() {
    return _groupBox.values
        .where((v) => (v as String).contains('"name"'))
        .map((raw) {
          try {
            return Group.fromJson(
              json.decode(raw as String) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<Group>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Group? getGroup(String id) {
    final raw = _groupBox.get(id);
    if (raw == null) return null;
    try {
      return Group.fromJson(json.decode(raw as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveGroup(Group group) async {
    await _groupBox.put(group.id, json.encode(group.toJson()));
  }

  Future<void> deleteGroup(String id) async {
    await _groupBox.delete(id);
  }

  // ── Group Expenses ─────────────────────────────────────────────────────────
  List<GroupExpense> getExpensesForGroup(String groupId) {
    final raw = _expenseBox.get('${_expensesKey}_$groupId');
    if (raw == null) return [];
    try {
      final list = json.decode(raw as String) as List;
      return list
          .map((e) => GroupExpense.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveGroupExpense(GroupExpense expense) async {
    final existing = getExpensesForGroup(expense.groupId);
    final idx = existing.indexWhere((e) => e.id == expense.id);
    if (idx >= 0) {
      existing[idx] = expense;
    } else {
      existing.insert(0, expense);
    }
    await _expenseBox.put(
      '${_expensesKey}_${expense.groupId}',
      json.encode(existing.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> deleteGroupExpense(String groupId, String expenseId) async {
    final existing = getExpensesForGroup(
      groupId,
    ).where((e) => e.id != expenseId).toList();
    await _expenseBox.put(
      '${_expensesKey}_$groupId',
      json.encode(existing.map((e) => e.toJson()).toList()),
    );
  }
}
