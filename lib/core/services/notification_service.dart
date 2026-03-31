import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../network/api_endpoints.dart';

@pragma('vm:entry-point')
Future<void> finflowFirebaseBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Keep the background isolate safe even when Firebase is not configured.
  }
}

/// Handles all local (on-device) notifications — no FCM required.
/// Channels:  budget_alerts  |  goal_milestones  |  recurring_alerts
class NotificationService {
  NotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _fcmInitialized = false;
  static Dio? _dioForTokenSync;
  static String? _activeFcmToken;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  static StreamSubscription<String>? _tokenRefreshSub;

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

  static const _groupChannel = AndroidNotificationChannel(
    'group_updates',
    'Group Updates',
    description:
        'Invites, newly added expenses, settlements, and daily expense summaries.',
    importance: Importance.high,
  );

  // ── Init ──────────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;

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
    await androidPlugin?.createNotificationChannel(_groupChannel);
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  static Future<void> syncFcmToken(Dio dio) async {
    await init();
    _dioForTokenSync = dio;
    await _ensureFcmReady();

    if (!_fcmInitialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (e) {
      debugPrint('[FinFlow] FCM token sync failed: $e');
    }
  }

  static Future<void> unregisterFcmToken(Dio dio) async {
    final token = _activeFcmToken;
    if (token == null || token.isEmpty) return;

    try {
      await dio.delete(
        ApiEndpoints.notificationDevices,
        data: {'token': token},
      );
    } catch (e) {
      debugPrint('[FinFlow] FCM token unregister failed: $e');
    } finally {
      _activeFcmToken = null;
    }
  }

  static Future<void> _ensureFcmReady() async {
    if (_fcmInitialized) return;

    try {
      await Firebase.initializeApp();
      final messaging = FirebaseMessaging.instance;

      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(finflowFirebaseBackgroundHandler);

      _foregroundMessageSub ??=
          FirebaseMessaging.onMessage.listen(_showForegroundMessage);

      _tokenRefreshSub ??= messaging.onTokenRefresh.listen((token) async {
        if (_dioForTokenSync == null || token.isEmpty) return;
        await _registerToken(token);
      });

      _fcmInitialized = true;
    } catch (e) {
      // Firebase may be intentionally unconfigured in local/dev builds.
      debugPrint('[FinFlow] FCM disabled: $e');
      _fcmInitialized = false;
    }
  }

  static Future<void> _registerToken(String token) async {
    if (_dioForTokenSync == null) return;
    if (_activeFcmToken == token) return;

    try {
      await _dioForTokenSync!.post(
        ApiEndpoints.notificationDevices,
        data: {
          'token': token,
          'platform': _platformName,
        },
      );
      _activeFcmToken = token;
    } catch (e) {
      debugPrint('[FinFlow] FCM register API failed: $e');
    }
  }

  static Future<void> _showForegroundMessage(RemoteMessage message) async {
    final title = message.notification?.title?.trim();
    final body = message.notification?.body?.trim();
    if (title == null || title.isEmpty || body == null || body.isEmpty) {
      return;
    }

    await _show(
      id: message.messageId.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      channel: _groupChannel,
    );
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      _ => 'unknown',
    };
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
