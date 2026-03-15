import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/design/app_theme.dart';
import 'core/providers/settings_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_service.dart';
import 'core/storage/hive_service.dart';

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

class FinFlowApp extends ConsumerWidget {
  const FinFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return MaterialApp.router(
      title: 'FinFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
