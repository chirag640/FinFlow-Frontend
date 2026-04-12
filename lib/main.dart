import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/app_theme.dart';
import 'core/providers/exchange_rate_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/services/privacy_screen_guard.dart';
import 'core/storage/hive_service.dart';
import 'core/utils/currency_formatter.dart';
import 'features/expenses/presentation/providers/expense_provider.dart';
import 'features/export/services/scheduled_export_service.dart';
import 'features/sync/presentation/providers/sync_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Override the default red-screen error widget in release builds
  // so unhandled widget errors show a friendly branded message.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kReleaseMode) {
      return const Material(
        child: Center(
          child: Text(
            'Something went wrong.\nPlease restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    // Keep the default red-screen in debug/profile for easy diagnosis.
    return ErrorWidget(details.exception);
  };

  try {
    await HiveService.init();
  } catch (e) {
    debugPrint('[FinFlow] Initialization error: $e');
  }
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const ProviderScope(child: FinFlowApp()));

  // Keep non-critical startup work out of the first frame path.
  unawaited(
    NotificationService.init().catchError(
      (Object e) => debugPrint('[FinFlow] Notification init error: $e'),
    ),
  );
}

class FinFlowApp extends ConsumerStatefulWidget {
  const FinFlowApp({super.key});

  @override
  ConsumerState<FinFlowApp> createState() => _FinFlowAppState();
}

class _FinFlowAppState extends ConsumerState<FinFlowApp> {
  late final AppLifecycleListener _lifecycleListener;
  bool _obscureForAppSwitcher = false;
  bool? _lastPrivacyModeEnabled;
  DateTime? _lastScheduledExportCheckAt;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        _setPrivacyObscured(false);
        ref.read(syncProvider.notifier).onAppResumed();
        unawaited(_runScheduledExportCheck());
      },
      onInactive: () {
        if (!mounted) return;
        _setPrivacyObscured(true);
        ref.read(syncProvider.notifier).onAppForegroundChanged(false);
      },
      onPause: () {
        if (!mounted) return;
        _setPrivacyObscured(true);
        ref.read(syncProvider.notifier).onAppForegroundChanged(false);
      },
      onHide: () {
        if (!mounted) return;
        _setPrivacyObscured(true);
        ref.read(syncProvider.notifier).onAppForegroundChanged(false);
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_runScheduledExportCheck());
    });
  }

  Future<void> _runScheduledExportCheck() async {
    final now = DateTime.now();
    final lastRun = _lastScheduledExportCheckAt;
    if (lastRun != null &&
        now.difference(lastRun) < const Duration(minutes: 3)) {
      return;
    }
    _lastScheduledExportCheckAt = now;

    try {
      final expenseState = ref.read(expenseProvider);
      final settings = ref.read(settingsProvider);

      await ScheduledExportService.runDueSchedules(
        now: now,
        allExpenses: expenseState.expenses,
        currencyCode: settings.currency,
        organizationName: settings.organizationName,
        organizationFooter: settings.organizationFooter,
        executiveSignatory: settings.executiveSignatory,
      );
    } catch (error) {
      debugPrint('[FinFlow] Scheduled export check failed: $error');
    }
  }

  void _setPrivacyObscured(bool obscured) {
    final privacyEnabled = ref.read(settingsProvider).privacyModeEnabled;
    final next = privacyEnabled && obscured;
    if (_obscureForAppSwitcher == next) return;
    setState(() => _obscureForAppSwitcher = next);
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    ref.watch(exchangeRateProvider);
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final currency = ref.watch(settingsProvider.select((s) => s.currency));
    final privacyModeEnabled =
        ref.watch(settingsProvider.select((s) => s.privacyModeEnabled));
    if (_lastPrivacyModeEnabled != privacyModeEnabled) {
      _lastPrivacyModeEnabled = privacyModeEnabled;
      if (!privacyModeEnabled) {
        _obscureForAppSwitcher = false;
      }
      unawaited(
        PrivacyScreenGuard.setScreenshotProtection(privacyModeEnabled),
      );
    }
    CurrencyFormatter.setCurrency(currency);
    CurrencyFormatter.setPrivacyMode(privacyModeEnabled);
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final useDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            platformBrightness == Brightness.dark);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: useDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor:
            useDark ? const Color(0xFF1E293B) : Colors.white,
        systemNavigationBarIconBrightness:
            useDark ? Brightness.light : Brightness.dark,
      ),
    );

    return MaterialApp.router(
      title: 'FinFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        if (!_obscureForAppSwitcher) {
          return content;
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            content,
            ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.visibility_off_rounded,
                      size: 34,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Privacy mode active',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
