import 'dart:io';

import 'package:finflow/core/constants/app_constants.dart';
import 'package:finflow/core/storage/hive_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'finflow_hive_recovery_notice_',
    );
    Hive.init(tempDir.path);
    await Hive.openBox(AppConstants.settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('persists cache repair notice in settings box', () async {
    await HiveService.markCacheRepairNotice();

    final settings = Hive.box(AppConstants.settingsBox);
    expect(settings.get(AppConstants.cacheRepairNoticeActiveKey), isTrue);
    expect(
      (settings.get(AppConstants.cacheRepairNoticeMessageKey) as String)
          .contains('Local cache was repaired'),
      isTrue,
    );
    expect(settings.get(AppConstants.cacheRepairNoticeUpdatedAtKey), isNotNull);
  });
}
