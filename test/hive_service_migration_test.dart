import 'dart:io';

import 'package:finflow/core/constants/app_constants.dart';
import 'package:finflow/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finflow_hive_migration_');
    Hive.init(tempDir.path);
    await Hive.openBox(AppConstants.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('migrates schema marker and removes legacy onboarding key', () async {
    final settings = Hive.box(AppConstants.settingsBox);
    await settings.put(AppConstants.hasOnboardedKey, true);

    await HiveService.migrateStorageSchema();

    expect(
      settings.get(AppConstants.storageSchemaVersionKey),
      AppConstants.storageSchemaVersion,
    );
    expect(settings.get(AppConstants.storageSchemaUpdatedAtKey), isNotNull);
    expect(settings.containsKey(AppConstants.hasOnboardedKey), isFalse);
  });

  test('is idempotent when current schema is already applied', () async {
    final settings = Hive.box(AppConstants.settingsBox);
    await settings.put(
      AppConstants.storageSchemaVersionKey,
      AppConstants.storageSchemaVersion,
    );
    await settings.put(
      AppConstants.storageSchemaUpdatedAtKey,
      '2026-04-11T00:00:00.000Z',
    );

    await HiveService.migrateStorageSchema();

    expect(
      settings.get(AppConstants.storageSchemaVersionKey),
      AppConstants.storageSchemaVersion,
    );
    expect(
      settings.get(AppConstants.storageSchemaUpdatedAtKey),
      '2026-04-11T00:00:00.000Z',
    );
  });
}
