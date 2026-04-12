import 'package:finflow/core/constants/app_constants.dart';
import 'package:finflow/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finflow/features/auth/domain/entities/app_user.dart';
import 'package:finflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthRepository extends AuthRepository {
  bool _hasPin = true;

  @override
  Future<bool> get hasAccount async => true;

  @override
  Future<bool> get isEmailVerified async => true;

  @override
  Future<bool> get hasProfile async => true;

  @override
  Future<bool> get hasPin async => _hasPin;

  @override
  Future<AppUser?> getUser() async => null;

  @override
  Future<PinVerificationResult> verifyPin(String pin, {Ref? ref}) async {
    if (pin == '2468') {
      return const PinVerificationResult(
        outcome: PinVerificationOutcome.valid,
        usedLocalFallback: true,
      );
    }

    return const PinVerificationResult(
      outcome: PinVerificationOutcome.invalid,
      message: 'Incorrect PIN.',
      usedLocalFallback: true,
    );
  }

  @override
  Future<void> savePin(String pin, {Ref? ref}) async {
    _hasPin = true;
  }

  @override
  Future<void> removePin({Ref? ref}) async {
    _hasPin = false;
  }

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> setHasAccount(bool v) async {}

  @override
  Future<void> setEmailVerified(bool v) async {}

  @override
  Future<void> setHasProfile(bool v) async {}

  @override
  Future<void> saveUser(AppUser user) async {}
}

Future<void> _waitForAuthInit(ProviderContainer container) async {
  for (var i = 0; i < 20; i++) {
    if (!container.read(authStateProvider).isLoading) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> secureStore = {};

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key']?.toString();

      switch (call.method) {
        case 'write':
          if (key != null) {
            secureStore[key] = (args['value'] ?? '').toString();
          }
          return null;
        case 'read':
          return key == null ? null : secureStore[key];
        case 'delete':
          if (key != null) {
            secureStore.remove(key);
          }
          return null;
        case 'deleteAll':
          secureStore.clear();
          return null;
        case 'readAll':
          return Map<String, String>.from(secureStore);
        case 'containsKey':
          return key != null && secureStore.containsKey(key);
        default:
          return null;
      }
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  setUp(() {
    secureStore.clear();
  });

  group('AuthRepository.verifyPin offline-first', () {
    test('returns valid local fallback when local PIN matches', () async {
      final repo = AuthRepository();

      await repo.savePin('1234');
      final result = await repo.verifyPin('1234');

      expect(result.outcome, PinVerificationOutcome.valid);
      expect(result.usedLocalFallback, isTrue);
    });

    test('returns invalid local fallback when local PIN mismatches', () async {
      final repo = AuthRepository();

      await repo.savePin('1234');
      final result = await repo.verifyPin('0000');

      expect(result.outcome, PinVerificationOutcome.invalid);
      expect(result.usedLocalFallback, isTrue);
      expect(result.message, 'Incorrect PIN.');
    });

    test('returns notConfigured when no local PIN exists and no ref passed',
        () async {
      final repo = AuthRepository();

      final result = await repo.verifyPin('1234');

      expect(result.outcome, PinVerificationOutcome.notConfigured);
      expect(result.message, 'No PIN configured for this account.');
      expect(result.usedLocalFallback, isFalse);
    });

    test('supports legacy unsalted hash format', () async {
      final repo = AuthRepository();

      await secureChannel.invokeMethod<void>('write', {
        'key': AppConstants.pinKey,
        'value':
            '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',
      });

      final result = await repo.verifyPin('1234');

      expect(result.outcome, PinVerificationOutcome.valid);
      expect(result.usedLocalFallback, isTrue);
    });
  });

  group('AuthNotifier biometric unlock flow', () {
    test('clears local lockout and allows immediate valid PIN', () async {
      final fakeRepo = _FakeAuthRepository();
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
      );
      addTearDown(container.dispose);

      await _waitForAuthInit(container);
      final notifier = container.read(authStateProvider.notifier);

      for (var i = 0; i < 5; i++) {
        final ok = await notifier.verifyPin('0000');
        expect(ok, isFalse);
      }

      expect(
        container.read(authStateProvider).error,
        contains('Too many incorrect PIN attempts'),
      );

      notifier.unlockWithBiometric();

      final okAfterBiometric = await notifier.verifyPin('2468');
      final state = container.read(authStateProvider);

      expect(okAfterBiometric, isTrue);
      expect(state.isAuthenticated, isTrue);
      expect(state.error, isNull);
    });
  });
}
