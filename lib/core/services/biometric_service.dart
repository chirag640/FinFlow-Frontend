// lib/core/services/biometric_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricAuthStatus {
  success,
  canceled,
  notAvailable,
  notEnrolled,
  temporarilyLockedOut,
  permanentlyLockedOut,
  passcodeNotSet,
  misconfigured,
  failed,
}

@immutable
class BiometricAuthResult {
  final BiometricAuthStatus status;
  final String? userMessage;

  const BiometricAuthResult(this.status, {this.userMessage});

  bool get isSuccess => status == BiometricAuthStatus.success;
  bool get isCanceled => status == BiometricAuthStatus.canceled;
  bool get shouldDisableBiometricCta =>
      status == BiometricAuthStatus.notAvailable ||
      status == BiometricAuthStatus.misconfigured;
}

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

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
  static Future<BiometricAuthResult> authenticateWithResult({
    String localizedReason = 'Use biometrics to unlock FinFlow',
  }) async {
    try {
      if (!await isAvailable()) {
        return const BiometricAuthResult(
          BiometricAuthStatus.notAvailable,
          userMessage:
              'Biometric unlock is unavailable on this device. Please use your PIN.',
        );
      }

      await _auth.stopAuthentication();
      final didAuthenticate = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
          sensitiveTransaction: true,
        ),
      );
      if (didAuthenticate) {
        return const BiometricAuthResult(BiometricAuthStatus.success);
      }

      return const BiometricAuthResult(BiometricAuthStatus.canceled);
    } on PlatformException catch (e) {
      return mapPlatformException(e);
    } catch (_) {
      return const BiometricAuthResult(
        BiometricAuthStatus.failed,
        userMessage: 'Biometric unlock failed. Please use your PIN.',
      );
    }
  }

  /// Backward-compatible bool API.
  static Future<bool> authenticate({
    String localizedReason = 'Use biometrics to unlock FinFlow',
  }) async {
    final result =
        await authenticateWithResult(localizedReason: localizedReason);
    return result.isSuccess;
  }

  @visibleForTesting
  static BiometricAuthResult mapPlatformException(PlatformException e) {
    final code = _normalizeErrorCode(e.code);

    if (_isAnyOf(code, const {
      'canceled',
      'cancelled',
      'usercanceled',
      'usercancel',
      'systemcanceled',
      'systemcancel',
      'appcanceled',
      'appcancel',
      'authcanceled',
    })) {
      return const BiometricAuthResult(BiometricAuthStatus.canceled);
    }

    if (_isAnyOf(code, const {
      'notavailable',
      'unsupported',
      'nohardware',
      'nobiometrichardware',
      'hardwareunavailable',
      'biometricerrornohardware',
      'biometricerrorhwunavailable',
    })) {
      return const BiometricAuthResult(
        BiometricAuthStatus.notAvailable,
        userMessage:
            'Biometric unlock is unavailable on this device. Please use your PIN.',
      );
    }

    if (_isAnyOf(code, const {
      'notenrolled',
      'noneenrolled',
      'biometricerrornoneenrolled',
      'nobiometrics',
    })) {
      return const BiometricAuthResult(
        BiometricAuthStatus.notEnrolled,
        userMessage:
            'No biometrics are enrolled on this device. Add one in device settings and try again.',
      );
    }

    if (_isAnyOf(code, const {
      'lockedout',
      'temporarylockout',
      'biometricerrorlockout',
    })) {
      return const BiometricAuthResult(
        BiometricAuthStatus.temporarilyLockedOut,
        userMessage:
            'Biometric unlock is temporarily locked. Use your PIN and try again later.',
      );
    }

    if (_isAnyOf(code, const {
      'permanentlylockedout',
      'permanentlockout',
      'biometricerrorlockoutpermanent',
    })) {
      return const BiometricAuthResult(
        BiometricAuthStatus.permanentlyLockedOut,
        userMessage:
            'Biometric unlock is locked due to too many attempts. Unlock your device with passcode and try again.',
      );
    }

    if (_isAnyOf(code, const {
      'passcodenotset',
      'devicecredentialnotset',
      'securitycredentialnotset',
    })) {
      return const BiometricAuthResult(
        BiometricAuthStatus.passcodeNotSet,
        userMessage:
            'Set a device passcode to enable biometric unlock on this phone.',
      );
    }

    if (_isAnyOf(code, const {
      'nofragmentactivity',
      'fragmentactivitymissing',
      'activityisnotfragmentactivity',
      'otheroperatingsystem',
      'notinteractive',
    })) {
      return const BiometricAuthResult(
        BiometricAuthStatus.misconfigured,
        userMessage:
            'Biometric unlock is not configured correctly on this build. Please update the app.',
      );
    }

    return const BiometricAuthResult(
      BiometricAuthStatus.failed,
      userMessage: 'Biometric unlock failed. Please use your PIN.',
    );
  }

  static String _normalizeErrorCode(String rawCode) {
    return rawCode
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');
  }

  static bool _isAnyOf(String code, Set<String> values) {
    return values.contains(code);
  }
}
