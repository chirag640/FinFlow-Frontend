import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';

abstract class HiveService {
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(AppConstants.expensesBox),
      Hive.openBox(AppConstants.groupsBox),
      Hive.openBox(AppConstants.budgetsBox),
      Hive.openBox(AppConstants.userBox),
      Hive.openBox(AppConstants.settingsBox),
      Hive.openBox(AppConstants.goalsBox),
      Hive.openBox(AppConstants.investmentsBox),
      Hive.openBox(AppConstants.upiIdsBox),
      Hive.openBox(AppConstants.pendingDeletionsBox),
      Hive.openBox(AppConstants.goalPendingDeletionsBox),
    ]);
  }

  static Box get expenses => Hive.box(AppConstants.expensesBox);
  static Box get groups => Hive.box(AppConstants.groupsBox);
  static Box get budgets => Hive.box(AppConstants.budgetsBox);
  static Box get user => Hive.box(AppConstants.userBox);
  static Box get settings => Hive.box(AppConstants.settingsBox);
  static Box get goals => Hive.box(AppConstants.goalsBox);
  static Box get investments => Hive.box(AppConstants.investmentsBox);
  static Box get upiIds => Hive.box(AppConstants.upiIdsBox);
  static Box get pendingDeletions => Hive.box(AppConstants.pendingDeletionsBox);
  static Box get goalPendingDeletions =>
      Hive.box(AppConstants.goalPendingDeletionsBox);
}
