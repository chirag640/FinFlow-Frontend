import 'package:flutter/foundation.dart';
import 'package:flutter_windowmanager/flutter_windowmanager.dart';

class PrivacyScreenGuard {
  static bool _secureFlagEnabled = false;

  static Future<void> setScreenshotProtection(bool enabled) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (_secureFlagEnabled == enabled) {
      return;
    }

    try {
      if (enabled) {
        await FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } else {
        await FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      }
      _secureFlagEnabled = enabled;
    } catch (e) {
      debugPrint('[FinFlow Privacy] Unable to toggle secure screen flag: $e');
    }
  }
}
