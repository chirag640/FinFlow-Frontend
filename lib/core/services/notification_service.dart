import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handles all local (on-device) notifications — no FCM required.
/// Channels:  budget_alerts  |  goal_milestones  |  recurring_alerts
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // ── Android notification channels ─────────────────────────────────────────
  static const _budgetChannel = AndroidNotificationChannel(
    'budget_alerts',
    'Budget Alerts',
    description: 'Alerts when a budget envelope nears or exceeds its limit.',
    importance: Importance.high,
  );

  static const _goalsChannel = AndroidNotificationChannel(
    'goal_milestones',
    'Goal Milestones',
    description: 'Celebrations when savings goal milestones are hit.',
    importance: Importance.defaultImportance,
  );

  static const _recurringChannel = AndroidNotificationChannel(
    'recurring_alerts',
    'Recurring Expenses',
    description: 'Notifications when recurring expenses are auto-logged.',
    importance: Importance.defaultImportance,
  );

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create Android channels
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_budgetChannel);
    await androidPlugin?.createNotificationChannel(_goalsChannel);
    await androidPlugin?.createNotificationChannel(_recurringChannel);
    await androidPlugin?.requestNotificationsPermission();
  }

  // ── Budget alerts ─────────────────────────────────────────────────────────
  static Future<void> showBudgetWarning(
      String categoryLabel, double pct) async {
    await _show(
      id: categoryLabel.hashCode & 0x7FFFFFFF,
      title: '⚠️ Budget Alert — $categoryLabel',
      body:
          '${(pct * 100).toStringAsFixed(0)}% of your $categoryLabel budget is used.',
      channel: _budgetChannel,
    );
  }

  static Future<void> showBudgetOverLimit(String categoryLabel) async {
    await _show(
      id: (categoryLabel.hashCode + 1000) & 0x7FFFFFFF,
      title: '🚨 Over Budget — $categoryLabel',
      body: "You've exceeded your $categoryLabel budget this month.",
      channel: _budgetChannel,
    );
  }

  // ── Recurring expense alerts ─────────────────────────────────────────────
  static Future<void> showRecurringDue(
      String description, double amount) async {
    await _show(
      id: (description.hashCode + 5000) & 0x7FFFFFFF,
      title: '🔁 Recurring Expense Logged',
      body: '$description — ₹${amount.toStringAsFixed(0)} added automatically.',
      channel: _recurringChannel,
    );
  }

  static Future<void> showRecurringBatch(int count) async {
    await _show(
      id: 5999,
      title: '🔁 $count Recurring Expenses Logged',
      body: '$count recurring expenses were added automatically today.',
      channel: _recurringChannel,
    );
  }

  // ── Goal milestones ──────────────────────────────────────────────────────
  static Future<void> showGoalMilestone(String goalTitle, int pct) async {
    await _show(
      id: (goalTitle.hashCode + 2000) & 0x7FFFFFFF,
      title: '🎯 Goal Milestone — $goalTitle',
      body: "You've reached $pct% of your \"$goalTitle\" savings goal!",
      channel: _goalsChannel,
    );
  }

  static Future<void> showGoalReached(String goalTitle) async {
    await _show(
      id: (goalTitle.hashCode + 3000) & 0x7FFFFFFF,
      title: '🏆 Goal Achieved! — $goalTitle',
      body:
          "Congratulations! You've hit your savings target for \"$goalTitle\".",
      channel: _goalsChannel,
    );
  }

  // ── Internal helper ───────────────────────────────────────────────────────
  static Future<void> _show({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
    );
  }
}
