import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ai_insights/presentation/pages/ai_insights_page.dart';
import '../../features/analytics/presentation/pages/analytics_page.dart';
import '../../features/auth/presentation/pages/auth_landing_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/pin_entry_page.dart';
import '../../features/auth/presentation/pages/pin_setup_page.dart';
import '../../features/auth/presentation/pages/profile_setup_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/verify_email_page.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/providers/cloud_auth_provider.dart';
import '../../features/budgets/presentation/pages/add_budget_page.dart';
import '../../features/budgets/presentation/pages/budgets_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/expenses/domain/entities/expense.dart';
import '../../features/expenses/presentation/pages/add_expense_page.dart';
import '../../features/expenses/presentation/pages/edit_expense_page.dart';
import '../../features/expenses/presentation/pages/expense_detail_page.dart';
import '../../features/expenses/presentation/pages/expenses_page.dart';
import '../../features/expenses/presentation/pages/recurring_manager_page.dart';
import '../../features/export/presentation/pages/export_page.dart';
import '../../features/goals/presentation/pages/goals_page.dart';
import '../../features/groups/presentation/pages/add_group_expense_page.dart';
import '../../features/groups/presentation/pages/create_group_page.dart';
import '../../features/groups/presentation/pages/group_detail_page.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/onboarding/presentation/pages/onboarding_walkthrough_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/sync/presentation/pages/sync_conflict_resolution_page.dart';
import '../../shared/widgets/adaptive_scaffold.dart';
import '../providers/settings_provider.dart';

// Route path constants
abstract class AppRoutes {
  static const String authLanding = '/auth';
  static const String profileSetup = '/auth/profile-setup';
  static const String pinSetup = '/auth/pin-setup';
  static const String pinEntry = '/pin';
  static const String login = '/cloud/login';
  static const String register = '/cloud/register';
  static const String verifyEmail = '/auth/verify-email';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String expenses = '/expenses';
  static const String addExpense = '/expenses/add';
  static const String groups = '/groups';
  static const String groupDetail = '/groups/:id';
  static const String createGroup = '/groups/create';
  static const String addGroupExpense = '/groups/:id/add-expense';
  static const String budgets = '/budgets';
  static const String addBudget = '/budgets/add';
  static const String analytics = '/analytics';
  static const String settings = '/settings';
  static const String changePin = '/settings/change-pin';
  static const String export = '/export';
  static const String editExpense = '/expenses/edit';
  static const String recurringManager = '/expenses/recurring';
  static const String expenseDetail = '/expenses/detail';
  static const String goals = '/goals';
  static const String aiInsights = '/ai-insights';
  static const String syncConflicts = '/sync/conflicts';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthState>(ref.read(authStateProvider));
  ref.listen<AuthState>(authStateProvider, (_, next) {
    authNotifier.value = next;
  });
  ref.onDispose(authNotifier.dispose);

  final cloudNotifier =
      ValueNotifier<CloudAuthState>(ref.read(cloudAuthProvider));
  ref.listen<CloudAuthState>(cloudAuthProvider, (_, next) {
    cloudNotifier.value = next;
  });
  ref.onDispose(cloudNotifier.dispose);

  final settingsNotifier =
      ValueNotifier<SettingsState>(ref.read(settingsProvider));
  ref.listen<SettingsState>(settingsProvider, (_, next) {
    settingsNotifier.value = next;
  });
  ref.onDispose(settingsNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.authLanding,
    refreshListenable:
        Listenable.merge([authNotifier, cloudNotifier, settingsNotifier]),
    redirect: (context, state) {
      final auth = authNotifier.value;
      final cloud = cloudNotifier.value;
      final path = state.uri.path;

      // Don't redirect while initial load is running
      if (auth.isLoading) return null;

      // ── 6-state machine ────────────────────────────────────────────────
      // State 1: No account → landing (register or login)
      if (!auth.hasAccount) {
        // Allow landing + cloud auth routes
        if (path == AppRoutes.authLanding ||
            path == AppRoutes.login ||
            path == AppRoutes.register) {
          return null;
        }
        return AppRoutes.authLanding;
      }

      // State 2: Account exists, email not verified → verify-email
      if (auth.hasAccount && !auth.isEmailVerified) {
        final hasPendingVerification =
            (cloud.pendingVerificationUserId ?? '').trim().isNotEmpty;
        final isCloudEntryRoute = path == AppRoutes.authLanding ||
            path == AppRoutes.login ||
            path == AppRoutes.register;

        // If we already have pending verification context, force OTP flow.
        if (hasPendingVerification) {
          if (path == AppRoutes.verifyEmail) return null;
          return AppRoutes.verifyEmail;
        }

        // If app was restarted before OTP completion, pending context can be
        // absent. Let user re-enter cloud login/register to recover context.
        if (isCloudEntryRoute || path == AppRoutes.verifyEmail) return null;
        return AppRoutes.authLanding;
      }

      // State 3: Verified but no profile → profile-setup
      if (auth.hasAccount && auth.isEmailVerified && !auth.hasProfile) {
        if (path == AppRoutes.profileSetup) return null;
        return AppRoutes.profileSetup;
      }

      // State 4: Profile done but no PIN → pin-setup
      if (auth.hasAccount &&
          auth.isEmailVerified &&
          auth.hasProfile &&
          !auth.hasPin) {
        if (path == AppRoutes.pinSetup) return null;
        return AppRoutes.pinSetup;
      }

      // State 5: All flags true but not authenticated → pin-entry
      if (auth.hasAccount &&
          auth.isEmailVerified &&
          auth.hasProfile &&
          auth.hasPin &&
          !auth.isAuthenticated) {
        if (path == AppRoutes.pinEntry) return null;
        return AppRoutes.pinEntry;
      }

      // State 6: Fully authenticated → dashboard (leave *auth flow* screens only)
      if (auth.isAuthenticated) {
        final settings = settingsNotifier.value;

        // Cloud login/register are opt-in overlay screens — the user navigated
        // there deliberately from Settings to connect their cloud account.
        // Never redirect them away automatically.
        final isCloudOptIn = path.startsWith('/cloud/');
        if (isCloudOptIn) return null;

        final shouldShowOnboarding =
            settings.onboardingTipsEnabled && !settings.onboardingCompleted;
        final isReplayOnboardingRoute = path == AppRoutes.onboarding &&
            state.uri.queryParameters['replay'] == '1';

        if (shouldShowOnboarding) {
          if (path == AppRoutes.onboarding) return null;
          return AppRoutes.onboarding;
        }

        if (isReplayOnboardingRoute) return null;
        if (path == AppRoutes.onboarding) return AppRoutes.dashboard;

        final isAuthFlowScreen = path == AppRoutes.authLanding ||
            path == AppRoutes.pinEntry ||
            path == AppRoutes.verifyEmail ||
            path == AppRoutes.profileSetup ||
            path == AppRoutes.pinSetup;
        if (isAuthFlowScreen) return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.authLanding,
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const AuthLandingPage()),
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const ProfileSetupPage()),
      ),
      GoRoute(
        path: AppRoutes.pinSetup,
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const PinSetupPage()),
      ),
      GoRoute(
        path: AppRoutes.changePin,
        pageBuilder: (context, state) => _fadeSlide(
          key: state.pageKey,
          child: const PinSetupPage(isChangingPin: true),
        ),
      ),
      GoRoute(
        path: AppRoutes.pinEntry,
        pageBuilder: (context, state) =>
            _fadeSlide(key: state.pageKey, child: const PinEntryPage()),
      ),
      // Cloud auth routes (full-screen, no shell)
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const RegisterPage()),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const VerifyEmailPage()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _slideUp(
            key: state.pageKey, child: const OnboardingWalkthroughPage()),
      ),
      // Main shell routes
      ShellRoute(
        builder: (context, state, child) => AdaptiveScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            pageBuilder: (context, state) =>
                _fadeSlide(key: state.pageKey, child: const DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.expenses,
            pageBuilder: (context, state) =>
                _fadeSlide(key: state.pageKey, child: const ExpensesPage()),
          ),
          GoRoute(
            path: AppRoutes.analytics,
            pageBuilder: (context, state) =>
                _fadeSlide(key: state.pageKey, child: const AnalyticsPage()),
          ),
          GoRoute(
            path: AppRoutes.groups,
            pageBuilder: (context, state) =>
                _fadeSlide(key: state.pageKey, child: const GroupsPage()),
          ),
          GoRoute(
            path: AppRoutes.budgets,
            pageBuilder: (context, state) =>
                _fadeSlide(key: state.pageKey, child: const BudgetsPage()),
          ),
          GoRoute(
            path: AppRoutes.settings,
            pageBuilder: (context, state) =>
                _fadeSlide(key: state.pageKey, child: const SettingsPage()),
          ),
        ],
      ),
      // Full-screen routes (outside shell)
      GoRoute(
        path: AppRoutes.addExpense,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const AddExpensePage()),
      ),
      GoRoute(
        path: AppRoutes.editExpense,
        pageBuilder: (context, state) {
          final expense = state.extra as Expense?;
          if (expense == null) {
            return _fadeSlide(key: state.pageKey, child: const ExpensesPage());
          }
          return _slideUp(
            key: state.pageKey,
            child: EditExpensePage(expense: expense),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.recurringManager,
        pageBuilder: (context, state) => _slideUp(
          key: state.pageKey,
          child: const RecurringManagerPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.expenseDetail,
        pageBuilder: (context, state) {
          final expense = state.extra as Expense?;
          if (expense == null) {
            return _fadeSlide(key: state.pageKey, child: const ExpensesPage());
          }
          return _slideUp(
            key: state.pageKey,
            child: ExpenseDetailPage(expense: expense),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.goals,
        pageBuilder: (context, state) => _slideUp(
          key: state.pageKey,
          child: const GoalsPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.createGroup,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const CreateGroupPage()),
      ),
      GoRoute(
        path: AppRoutes.groupDetail,
        pageBuilder: (context, state) => _fadeSlide(
          key: state.pageKey,
          child: GroupDetailPage(groupId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.addGroupExpense,
        pageBuilder: (context, state) => _slideUp(
          key: state.pageKey,
          child: AddGroupExpensePage(groupId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.addBudget,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const AddBudgetPage()),
      ),
      // Export (full-screen)
      GoRoute(
        path: AppRoutes.export,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const ExportPage()),
      ),
      GoRoute(
        path: AppRoutes.aiInsights,
        pageBuilder: (context, state) =>
            _slideUp(key: state.pageKey, child: const AiInsightsPage()),
      ),
      GoRoute(
        path: AppRoutes.syncConflicts,
        pageBuilder: (context, state) => _slideUp(
          key: state.pageKey,
          child: const SyncConflictResolutionPage(),
        ),
      ),
    ],
  );
});

CustomTransitionPage<T> _fadeSlide<T>({
  required LocalKey key,
  required Widget child,
}) =>
    CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, _, innerChild) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: innerChild,
        ),
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );

CustomTransitionPage<T> _slideUp<T>({
  required LocalKey key,
  required Widget child,
}) =>
    CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionsBuilder: (context, animation, _, innerChild) =>
          SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: innerChild,
      ),
      transitionDuration: const Duration(milliseconds: 350),
    );
