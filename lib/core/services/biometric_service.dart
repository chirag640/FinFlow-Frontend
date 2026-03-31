// lib/core/services/biometric_service.dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final _auth = LocalAuthentication();

  /// Returns true if the device supports biometrics (fingerprint / face ID).
  static Future<bool> isAvailable() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return false;

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns available biometric types for UI hints.
  static Future<List<BiometricType>> availableTypes() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  /// Attempts biometric authentication.
  /// Returns true on success, false if cancelled or user falls back.
  static Future<bool> authenticate() async {
    try {
      await _auth.stopAuthentication();
      return await _auth.authenticate(
        localizedReason: 'Use biometrics to unlock FinFlow',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
