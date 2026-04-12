import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/hive_service.dart';

abstract class _K {
  static const plans = 'group_budget_plans_v1';
  static const alertKeys = 'group_budget_alert_keys_v1';
}

class GroupBudgetPlan {
  final String groupId;
  final double monthlyBudget;
  final int month;
  final int year;
  final DateTime updatedAt;

  const GroupBudgetPlan({
    required this.groupId,
    required this.monthlyBudget,
    required this.month,
    required this.year,
    required this.updatedAt,
  });

  GroupBudgetPlan copyWith({
    String? groupId,
    double? monthlyBudget,
    int? month,
    int? year,
    DateTime? updatedAt,
  }) {
    return GroupBudgetPlan(
      groupId: groupId ?? this.groupId,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      month: month ?? this.month,
      year: year ?? this.year,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool matchesMonth(DateTime date) => month == date.month && year == date.year;

  Map<String, dynamic> toJson() => {
        'groupId': groupId,
        'monthlyBudget': monthlyBudget,
        'month': month,
        'year': year,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory GroupBudgetPlan.fromJson(Map<String, dynamic> json) {
    return GroupBudgetPlan(
      groupId: (json['groupId'] as String?) ?? '',
      monthlyBudget: ((json['monthlyBudget'] as num?) ?? 0).toDouble(),
      month: (json['month'] as int?) ?? DateTime.now().month,
      year: (json['year'] as int?) ?? DateTime.now().year,
      updatedAt: DateTime.tryParse((json['updatedAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

class GroupBudgetState {
  final Map<String, GroupBudgetPlan> plans;
  final String? error;

  const GroupBudgetState({
    this.plans = const {},
    this.error,
  });

  GroupBudgetState copyWith({
    Map<String, GroupBudgetPlan>? plans,
    Object? error = _sentinel,
  }) {
    return GroupBudgetState(
      plans: plans ?? this.plans,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  GroupBudgetPlan? planFor(String groupId, DateTime date) {
    final plan = plans[groupId];
    if (plan == null) return null;
    return plan.matchesMonth(date) ? plan : null;
  }

  static const _sentinel = Object();
}

class GroupBudgetNotifier extends StateNotifier<GroupBudgetState> {
  GroupBudgetNotifier() : super(const GroupBudgetState()) {
    _load();
  }

  void _load() {
    final box = HiveService.settings;
    final raw = box.get(_K.plans) as String?;
    if (raw == null || raw.isEmpty) {
      state = state.copyWith(plans: const {}, error: null);
      return;
    }

    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final parsed = <String, GroupBudgetPlan>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          final plan = GroupBudgetPlan.fromJson(value);
          if (plan.groupId.isNotEmpty) {
            parsed[entry.key] = plan;
          }
        } else if (value is Map) {
          final plan =
              GroupBudgetPlan.fromJson(Map<String, dynamic>.from(value));
          if (plan.groupId.isNotEmpty) {
            parsed[entry.key] = plan;
          }
        }
      }
      state = state.copyWith(plans: parsed, error: null);
    } catch (_) {
      state = state.copyWith(error: 'Could not read group budget plans.');
    }
  }

  Future<void> setMonthlyBudget({
    required String groupId,
    required double monthlyBudget,
    DateTime? monthReference,
  }) async {
    final refDate = monthReference ?? DateTime.now();
    final nextPlan = GroupBudgetPlan(
      groupId: groupId,
      monthlyBudget: monthlyBudget,
      month: refDate.month,
      year: refDate.year,
      updatedAt: DateTime.now(),
    );

    final nextPlans = <String, GroupBudgetPlan>{
      ...state.plans,
      groupId: nextPlan,
    };
    await _persistPlans(nextPlans);
    state = state.copyWith(plans: nextPlans, error: null);
  }

  Future<void> clearPlan(String groupId) async {
    final nextPlans = <String, GroupBudgetPlan>{...state.plans}
      ..remove(groupId);
    await _persistPlans(nextPlans);
    state = state.copyWith(plans: nextPlans, error: null);
  }

  Future<void> evaluateBudgetAlerts({
    required String groupId,
    required String groupName,
    required double monthlySpend,
    DateTime? now,
  }) async {
    final date = now ?? DateTime.now();
    final plan = state.planFor(groupId, date);
    if (plan == null || plan.monthlyBudget <= 0) return;

    final ratio = monthlySpend / plan.monthlyBudget;
    if (ratio >= 1.0) {
      final key = _alertKey(groupId, plan.month, plan.year, 'over');
      if (await _markAlertKeyIfNew(key)) {
        await NotificationService.showGroupBudgetOverLimit(groupName);
      }
      return;
    }
    if (ratio >= 0.8) {
      final key = _alertKey(groupId, plan.month, plan.year, 'warn');
      if (await _markAlertKeyIfNew(key)) {
        await NotificationService.showGroupBudgetWarning(
          groupName,
          ratio,
        );
      }
    }
  }

  Future<void> _persistPlans(Map<String, GroupBudgetPlan> plans) async {
    final encoded = json.encode({
      for (final entry in plans.entries) entry.key: entry.value.toJson(),
    });
    await HiveService.settings.put(_K.plans, encoded);
  }

  String _alertKey(
    String groupId,
    int month,
    int year,
    String level,
  ) =>
      '$groupId-$year-$month-$level';

  Future<bool> _markAlertKeyIfNew(String key) async {
    final box = HiveService.settings;
    final raw = box.get(_K.alertKeys) as String?;
    final keys = <String>{};
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as List<dynamic>;
        keys.addAll(decoded.whereType<String>());
      } catch (_) {
        keys.clear();
      }
    }

    if (keys.contains(key)) return false;

    keys.add(key);
    await box.put(_K.alertKeys, json.encode(keys.toList()));
    return true;
  }
}

final groupBudgetProvider =
    StateNotifierProvider<GroupBudgetNotifier, GroupBudgetState>(
  (_) => GroupBudgetNotifier(),
);
