/// All API endpoint paths (relative to base URL).
abstract class ApiEndpoints {
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendOtp = '/auth/resend-otp';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String authSessions = '/auth/sessions';
  static const String authSessionsRevoke = '/auth/sessions/revoke';

  static const String userProfile = '/users/me';
  static const String updatePin = '/users/pin';
  static const String verifyPin = '/users/pin/verify';
  static const String userSearch = '/users/search';
  static const String notificationDevices = '/notifications/devices';

  static const String expenses = '/expenses';
  static const String expenseSummary = '/expenses/summary';
  static String expense(String id) => '/expenses/$id';

  static const String groups = '/groups';
  static String group(String id) => '/groups/$id';
  static String groupMembers(String id) => '/groups/$id/members';
  static String groupExpenses(String id) => '/groups/$id/expenses';
  static String groupExpense(String groupId, String expId) =>
      '/groups/$groupId/expenses/$expId';
  static String groupSettlements(String id) => '/groups/$id/settlements';
  static String groupSettle(String id) => '/groups/$id/settle';

  static const String budgets = '/budgets';
  static String budget(String id) => '/budgets/$id';

  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';
  static const String syncTelemetry = '/sync/telemetry';
}
