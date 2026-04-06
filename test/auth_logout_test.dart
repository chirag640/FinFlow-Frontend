import 'dart:io';

import 'package:finflow/core/constants/app_constants.dart';
import 'package:finflow/core/network/auth_interceptor.dart';
import 'package:finflow/core/storage/hive_service.dart';
import 'package:finflow/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finflow/features/auth/domain/entities/app_user.dart';
import 'package:finflow/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

    final dir = await Directory.systemTemp.createTemp('finflow_test_');
    Hive.init(dir.path);
    await Hive.openBox(AppConstants.expensesBox);
    await Hive.openBox(AppConstants.groupsBox);
    await Hive.openBox(AppConstants.budgetsBox);
    await Hive.openBox(AppConstants.userBox);
    await Hive.openBox(AppConstants.settingsBox);
    await Hive.openBox(AppConstants.goalsBox);
    await Hive.openBox(AppConstants.upiIdsBox);
    await Hive.openBox(AppConstants.pendingDeletionsBox);
    await Hive.openBox(AppConstants.expensePendingUpsertsBox);
    await Hive.openBox(AppConstants.budgetPendingUpsertsBox);
    await Hive.openBox(AppConstants.budgetPendingDeletionsBox);
    await Hive.openBox(AppConstants.goalPendingDeletionsBox);
    await Hive.openBox(AppConstants.goalPendingUpsertsBox);
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
    await Hive.close();
    await Hive.deleteFromDisk();
  });

  setUp(() async {
    secureStore.clear();
    await HiveService.expenses.clear();
    await HiveService.groups.clear();
    await HiveService.budgets.clear();
    await HiveService.user.clear();
    await HiveService.settings.clear();
    await HiveService.goals.clear();
    await HiveService.upiIds.clear();
    await HiveService.pendingDeletions.clear();
    await HiveService.expensePendingUpserts.clear();
    await HiveService.budgetPendingUpserts.clear();
    await HiveService.budgetPendingDeletions.clear();
    await HiveService.goalPendingDeletions.clear();
    await HiveService.goalPendingUpserts.clear();
  });

  test('AuthRepository.clearAll wipes local data and secure storage', () async {
    HiveService.expenses.put('e1', 'expense');
    HiveService.budgets.put('b1', 'budget');
    HiveService.groups.put('g1', 'group');
    HiveService.user.put('current_user', 'user');
    HiveService.settings.put('theme_mode', 'dark');
    HiveService.goals.put('goal1', 'goal');
    HiveService.upiIds.put('m1', 'upi');
    HiveService.pendingDeletions.put('d1', '1');
    HiveService.expensePendingUpserts.put('u1', '1');
    HiveService.budgetPendingUpserts.put('u2', '1');
    HiveService.budgetPendingDeletions.put('d2', '1');
    HiveService.goalPendingDeletions.put('d3', '1');
    HiveService.goalPendingUpserts.put('u3', '1');

    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    await storage.write(key: TokenKeys.accessToken, value: 'access');
    await storage.write(key: TokenKeys.refreshToken, value: 'refresh');
    await storage.write(key: AppConstants.pinKey, value: 'pin');

    final repo = AuthRepository();
    await repo.clearAll();

    expect(HiveService.expenses.isEmpty, isTrue);
    expect(HiveService.budgets.isEmpty, isTrue);
    expect(HiveService.groups.isEmpty, isTrue);
    expect(HiveService.user.isEmpty, isTrue);
    expect(HiveService.settings.isEmpty, isTrue);
    expect(HiveService.goals.isEmpty, isTrue);
    expect(HiveService.upiIds.isEmpty, isTrue);
    expect(HiveService.pendingDeletions.isEmpty, isTrue);
    expect(HiveService.expensePendingUpserts.isEmpty, isTrue);
    expect(HiveService.budgetPendingUpserts.isEmpty, isTrue);
    expect(HiveService.budgetPendingDeletions.isEmpty, isTrue);
    expect(HiveService.goalPendingDeletions.isEmpty, isTrue);
    expect(HiveService.goalPendingUpserts.isEmpty, isTrue);

    expect(await storage.read(key: TokenKeys.accessToken), isNull);
    expect(await storage.read(key: TokenKeys.refreshToken), isNull);
    expect(await storage.read(key: AppConstants.pinKey), isNull);
  });

  test('AuthNotifier.logout resets auth state flags', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(authStateProvider.notifier);
    await notifier.markAccountCreated();
    await notifier.markEmailVerified();
    await notifier.completeProfile(AppUser(
      name: 'Test User',
      monthlyIncome: 1000,
      email: 'test@example.com',
      currencyCode: 'INR',
      createdAt: DateTime(2024, 1, 1),
    ));

    await notifier.logout();

    final state = container.read(authStateProvider);
    expect(state.hasAccount, isFalse);
    expect(state.isEmailVerified, isFalse);
    expect(state.hasProfile, isFalse);
    expect(state.hasPin, isFalse);
    expect(state.isAuthenticated, isFalse);
  });
}
