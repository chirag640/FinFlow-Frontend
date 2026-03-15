import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../../core/providers/settings_provider.dart';
import '../../../../../core/services/notification_service.dart';
import '../../data/datasources/goal_local_datasource.dart';
import '../../domain/entities/savings_goal.dart';

// ── Color palette for goals ───────────────────────────────────────────────────
abstract class GoalColors {
  static const List<Color> palette = [
    Color(0xFF4F46E5), // Indigo
    Color(0xFF10B981), // Emerald
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFF97316), // Orange
    Color(0xFFEC4899), // Pink
  ];

  static Color at(int index) => palette[index % palette.length];
}

// ── State ─────────────────────────────────────────────────────────────────────
class GoalsState {
  final List<SavingsGoal> goals;
  final bool isLoading;

  const GoalsState({this.goals = const [], this.isLoading = false});

  List<SavingsGoal> get active => goals.where((g) => !g.isCompleted).toList();
  List<SavingsGoal> get completed => goals.where((g) => g.isCompleted).toList();
  double get totalTargeted => goals.fold(0.0, (s, g) => s + g.targetAmount);
  double get totalSaved => goals.fold(0.0, (s, g) => s + g.currentAmount);

  GoalsState copyWith({List<SavingsGoal>? goals, bool? isLoading}) =>
      GoalsState(
        goals: goals ?? this.goals,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class GoalsNotifier extends StateNotifier<GoalsState> {
  final GoalLocalDatasource _ds;
  final Ref _ref;
  static const _uuid = Uuid();

  GoalsNotifier(this._ds, this._ref) : super(const GoalsState()) {
    _load();
  }

  void _load() {
    final goals = _ds.getAll();
    goals.sort((a, b) {
      // Active goals first, then by progress desc
      if (a.isCompleted != b.isCompleted) {
        return a.isCompleted ? 1 : -1;
      }
      return b.progressPercent.compareTo(a.progressPercent);
    });
    state = state.copyWith(goals: goals);
  }

  Future<void> addGoal({
    required String title,
    required String emoji,
    required double targetAmount,
    double currentAmount = 0,
    DateTime? deadline,
    int colorIndex = 0,
  }) async {
    final goal = SavingsGoal(
      id: _uuid.v4(),
      title: title,
      emoji: emoji,
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      deadline: deadline,
      colorIndex: colorIndex,
    );
    await _ds.save(goal);
    _load();
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    await _ds.save(goal);
    _load();
  }

  Future<void> addFunds(String id, double amount) async {
    final goal = state.goals.firstWhere((g) => g.id == id);
    final oldPct = goal.progressPercent;
    final updated = goal.copyWith(
      currentAmount: (goal.currentAmount + amount)
          .clamp(0.0, goal.targetAmount * 2), // generous cap
    );
    await _ds.save(updated);
    _load();

    // ── Goal milestone notifications ──────────────────────────────────
    if (_ref.read(settingsProvider).notifGoalAlerts) {
      final newPct = updated.progressPercent;
      if (oldPct < 1.0 && newPct >= 1.0) {
        await NotificationService.showGoalReached(goal.title);
      } else if (oldPct < 0.5 && newPct >= 0.5) {
        await NotificationService.showGoalMilestone(goal.title, 50);
      }
    }
  }

  Future<void> deleteGoal(String id) async {
    await _ds.delete(id);
    _load();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final goalDatasourceProvider = Provider<GoalLocalDatasource>(
  (_) => GoalLocalDatasource(),
);

final goalsProvider = StateNotifierProvider<GoalsNotifier, GoalsState>((ref) {
  return GoalsNotifier(ref.watch(goalDatasourceProvider), ref);
});
