abstract class AppConstants {
  static const String appName = 'FinFlow';
  static const String appTagline = 'Your Financial Operating System';
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // Hive box names
  static const String expensesBox = 'ff_expenses';
  static const String groupsBox = 'ff_groups';
  static const String budgetsBox = 'ff_budgets';
  static const String userBox = 'ff_user';
  static const String settingsBox = 'ff_settings';
  static const String goalsBox = 'ff_goals';
  // UPI IDs stored locally per member (memberId → upiId VPA)
  static const String upiIdsBox = 'ff_upi_ids';
  // Tracks expense IDs deleted while offline for server reconciliation on next sync
  static const String pendingDeletionsBox = 'ff_pending_deletions';
  // Tracks expense IDs changed locally and awaiting sync push
  static const String expensePendingUpsertsBox = 'ff_expense_pending_upserts';
  // Tracks budget IDs changed locally and awaiting sync push
  static const String budgetPendingUpsertsBox = 'ff_budget_pending_upserts';
  // Tracks budget IDs deleted locally and awaiting sync push
  static const String budgetPendingDeletionsBox = 'ff_budget_pending_deletions';
  // Tracks goal IDs deleted while offline for server reconciliation on next sync
  static const String goalPendingDeletionsBox = 'ff_goal_pending_deletions';
  // Tracks goal IDs changed locally and awaiting sync push
  static const String goalPendingUpsertsBox = 'ff_goal_pending_upserts';

  // Secure storage keys
  static const String pinKey = 'ff_pin';
  static const String biometricEnabledKey = 'ff_biometric';
  static const String userNameKey = 'ff_user_name';
  static const String monthlyIncomeKey = 'ff_monthly_income';
  static const String cloudUserKey = 'ff_cloud_user';

  // Auth state flags (stored in Hive settings box)
  static const String hasAccountKey = 'ff_has_account';
  static const String isEmailVerifiedKey = 'ff_email_verified';
  static const String hasProfileKey = 'ff_has_profile';
  static const String hasPinKey = 'ff_has_pin';

  // Legacy (kept for migration)
  static const String hasOnboardedKey = 'ff_has_onboarded';
}
