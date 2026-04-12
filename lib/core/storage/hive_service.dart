import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

abstract class HiveService {
  static const List<String> _requiredBoxes = [
    AppConstants.expensesBox,
    AppConstants.groupsBox,
    AppConstants.budgetsBox,
    AppConstants.userBox,
    AppConstants.settingsBox,
    AppConstants.goalsBox,
    AppConstants.upiIdsBox,
    AppConstants.pendingDeletionsBox,
    AppConstants.expensePendingUpsertsBox,
    AppConstants.budgetPendingUpsertsBox,
    AppConstants.budgetPendingDeletionsBox,
    AppConstants.goalPendingDeletionsBox,
    AppConstants.goalPendingUpsertsBox,
  ];

  static Future<void> init() async {
    await Hive.initFlutter();
    try {
      await _openRequiredBoxes();
      await migrateStorageSchema();
    } catch (error) {
      debugPrint(
        '[FinFlow] Hive init failed. Attempting local cache repair: $error',
      );
      await _recoverCorruptedCache();
    }
  }

  static Future<void> migrateStorageSchema() async {
    final settingsBox = Hive.box(AppConstants.settingsBox);
    final rawVersion = settingsBox.get(AppConstants.storageSchemaVersionKey);
    final currentVersion = rawVersion is int
        ? rawVersion
        : int.tryParse(rawVersion?.toString() ?? "0") ?? 0;

    if (currentVersion >= AppConstants.storageSchemaVersion) {
      return;
    }

    if (settingsBox.containsKey(AppConstants.hasOnboardedKey)) {
      await settingsBox.delete(AppConstants.hasOnboardedKey);
    }

    await settingsBox.put(
      AppConstants.storageSchemaVersionKey,
      AppConstants.storageSchemaVersion,
    );
    await settingsBox.put(
      AppConstants.storageSchemaUpdatedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  static Future<void> _openRequiredBoxes() async {
    await Future.wait(_requiredBoxes.map(Hive.openBox));
  }

  static Future<void> _recoverCorruptedCache() async {
    for (final boxName in _requiredBoxes) {
      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }
      await Hive.deleteBoxFromDisk(boxName);
    }

    await _openRequiredBoxes();
    await migrateStorageSchema();
    await markCacheRepairNotice();
  }

  static Future<void> markCacheRepairNotice() async {
    final settingsBox = Hive.box(AppConstants.settingsBox);
    await settingsBox.put(AppConstants.cacheRepairNoticeActiveKey, true);
    await settingsBox.put(
      AppConstants.cacheRepairNoticeMessageKey,
      'Local cache was repaired after a storage issue. Review sync conflicts if data looks outdated.',
    );
    await settingsBox.put(
      AppConstants.cacheRepairNoticeUpdatedAtKey,
      DateTime.now().toIso8601String(),
    );
  }

  static Box get expenses => Hive.box(AppConstants.expensesBox);
  static Box get groups => Hive.box(AppConstants.groupsBox);
  static Box get budgets => Hive.box(AppConstants.budgetsBox);
  static Box get user => Hive.box(AppConstants.userBox);
  static Box get settings => Hive.box(AppConstants.settingsBox);
  static Box get goals => Hive.box(AppConstants.goalsBox);
  static Box get upiIds => Hive.box(AppConstants.upiIdsBox);
  static Box get pendingDeletions => Hive.box(AppConstants.pendingDeletionsBox);
  static Box get expensePendingUpserts =>
      Hive.box(AppConstants.expensePendingUpsertsBox);
  static Box get budgetPendingUpserts =>
      Hive.box(AppConstants.budgetPendingUpsertsBox);
  static Box get budgetPendingDeletions =>
      Hive.box(AppConstants.budgetPendingDeletionsBox);
  static Box get goalPendingDeletions =>
      Hive.box(AppConstants.goalPendingDeletionsBox);
  static Box get goalPendingUpserts =>
      Hive.box(AppConstants.goalPendingUpsertsBox);
}
