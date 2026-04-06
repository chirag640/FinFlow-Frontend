import 'package:finflow/core/services/biometric_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BiometricService.mapPlatformException', () {
    test('maps no_fragment_activity to misconfigured state', () {
      final result = BiometricService.mapPlatformException(
        PlatformException(code: 'no_fragment_activity'),
      );

      expect(result.status, BiometricAuthStatus.misconfigured);
      expect(result.shouldDisableBiometricCta, isTrue);
      expect(result.userMessage, isNotNull);
    });

    test('maps user_cancel to canceled state without error copy', () {
      final result = BiometricService.mapPlatformException(
        PlatformException(code: 'user_cancel'),
      );

      expect(result.status, BiometricAuthStatus.canceled);
      expect(result.userMessage, isNull);
    });

    test('maps locked_out to temporary lockout state', () {
      final result = BiometricService.mapPlatformException(
        PlatformException(code: 'locked_out'),
      );

      expect(result.status, BiometricAuthStatus.temporarilyLockedOut);
      expect(
        result.userMessage,
        contains('temporarily locked'),
      );
    });
  });
}
