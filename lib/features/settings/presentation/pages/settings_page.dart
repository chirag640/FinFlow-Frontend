// Figma: Screen/Settings
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/components/ds_dialog.dart';
import '../../../../core/providers/exchange_rate_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/ui/error_feedback.dart';
import '../../../../core/utils/responsive.dart';
import '../../../ai_insights/presentation/providers/ai_insights_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/providers/cloud_auth_provider.dart';
import '../../../budgets/presentation/providers/budget_provider.dart';
import '../../../expenses/presentation/providers/expense_provider.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../groups/presentation/providers/upi_id_provider.dart';
import '../../../sync/presentation/providers/sync_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _routeSyncTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _routeSyncTriggered) return;
      _routeSyncTriggered = true;
      ref.read(syncProvider.notifier).onRouteVisible('settings');
    });
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;

    final cloud = ref.watch(cloudAuthProvider);
    final syncState = ref.watch(syncProvider);
    final conflictSummary = ref.watch(syncConflictSummaryProvider);
    final settings = ref.watch(settingsProvider);
    final exchangeRates = ref.watch(exchangeRateProvider);

    final exchangeSubtitle = exchangeRates.updatedAt == null
      ? 'Using cached rates'
      : settings.currency == exchangeRates.baseCurrency
        ? 'Base currency (${exchangeRates.baseCurrency})'
        : '1 ${exchangeRates.baseCurrency} = ${exchangeRates.rateFor(settings.currency).toStringAsFixed(4)} ${settings.currency}';

    listenForProviderError(
      ref: ref,
      context: context,
      provider: cloudAuthProvider,
      errorSelector: (s) => s.error,
    );
    listenForProviderSuccess(
      ref: ref,
      context: context,
      provider: syncProvider,
      successSelector: (s) =>
          (s.isSyncing || s.lastSyncTime == null || s.error != null)
              ? null
              : 'Data synced with cloud',
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text('Settings',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: colors.onSurface)),
        // actions: [
        //   IconButton(
        //     tooltip: 'Search settings',
        //     icon: const Icon(Icons.search_rounded),
        //     onPressed: () =>
        //         _showSettingsSearch(context, ref, cloud, syncState),
        //   ),
        // ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(R.md),
          children: [
            _SettingsHeroCard(
              cloud: cloud,
              onEdit: cloud.isConnected
                  ? () => _showEditProfileDialog(context, ref, cloud)
                  : null,
            ).animate().fadeIn(),
            const Gap(14),
            _QuickActionsRow(
              cloudConnected: cloud.isConnected,
              syncing: syncState.isSyncing,
              onCloud: cloud.isConnected
                  ? () => _showSessionManagerDialog(context, ref)
                  : () => context.push(AppRoutes.login),
              onSync: syncState.isSyncing
                  ? null
                  : () => ref.read(syncProvider.notifier).sync(),
              onExport: () => context.push(AppRoutes.export),
            ).animate().fadeIn(delay: 100.ms),
            const Gap(14),
            _CompactSection(
              title: 'Cloud & Account',
              initiallyExpanded: true,
              child: _SettingsCard(children: [
                if (cloud.isLoading) ...[
                  _SettingsTile(
                    icon: Icons.cloud_sync_rounded,
                    iconColor: colors.onSurfaceVariant,
                    title: 'Verifying connection...',
                    subtitle: 'Checking your cloud session',
                    trailing: SizedBox.square(
                      dimension: R.s(18),
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                ] else if (!cloud.isConnected) ...[
                  _SettingsTile(
                    icon: cloud.error != null
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_upload_outlined,
                    iconColor: cloud.error != null
                        ? AppColors.error
                        : AppColors.primary,
                    title: cloud.error != null
                        ? 'Session Expired'
                        : 'Connect to Cloud',
                    subtitle: cloud.error ?? 'Back up & sync across devices',
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: R.s(16), color: colors.onSurfaceVariant),
                    onTap: () => context.push(AppRoutes.login),
                  ),
                  Divider(height: 1, indent: R.s(56)),
                  _SettingsTile(
                    icon: Icons.person_add_outlined,
                    iconColor: AppColors.accent,
                    title: 'Create Account',
                    subtitle: 'New user? Register for free',
                    trailing: Icon(Icons.arrow_forward_ios_rounded,
                        size: R.s(16), color: colors.onSurfaceVariant),
                    onTap: () => context.push(AppRoutes.register),
                  ),
                ] else ...[
                  _SettingsTile(
                    icon: Icons.cloud_done_outlined,
                    iconColor: AppColors.success,
                    title: cloud.user?.email ?? 'Connected',
                    subtitle: syncState.lastSyncTime != null
                        ? 'Last synced ${_formatTime(syncState.lastSyncTime!)}'
                        : 'Connected',
                    trailing: syncState.isSyncing
                        ? SizedBox.square(
                            dimension: R.s(18),
                            child: const CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : null,
                  ),
                  Divider(height: 1, indent: R.s(56)),
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: AppColors.primary,
                    title: 'Edit Profile',
                    subtitle: cloud.user?.name ?? '',
                    onTap: () => _showEditProfileDialog(context, ref, cloud),
                  ),
                  Divider(height: 1, indent: R.s(56)),
                  _SettingsTile(
                    icon: Icons.devices_outlined,
                    iconColor: AppColors.primary,
                    title: 'Manage Sessions',
                    subtitle: 'Review and revoke active devices',
                    onTap: () => _showSessionManagerDialog(context, ref),
                  ),
                  Divider(height: 1, indent: R.s(56)),
                  _SettingsTile(
                    icon: Icons.merge_type_rounded,
                    iconColor: AppColors.warning,
                    title: 'Resolve Sync Conflicts',
                    subtitle: conflictSummary.hasConflicts
                        ? '${conflictSummary.total} pending local changes'
                        : 'No pending local conflicts',
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: R.s(16),
                      color: colors.onSurfaceVariant,
                    ),
                    onTap: () => context.push(AppRoutes.syncConflicts),
                  ),
                  Divider(height: 1, indent: R.s(56)),
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.error,
                    title: 'Sign out',
                    subtitle: 'Clears local data on this device',
                    onTap: () => _confirmDisconnect(context, ref),
                  ),
                  Divider(height: 1, indent: R.s(56)),
                  _SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    iconColor: AppColors.error,
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your cloud account',
                    onTap: () => _confirmDeleteAccount(context, ref),
                  ),
                ],
              ]),
            ).animate().fadeIn(delay: 150.ms),
            const Gap(10),
            _CompactSection(
              title: 'Security',
              child: _SettingsCard(children: [
                Builder(builder: (context) {
                  final hasPin = ref.watch(authStateProvider).hasPin;
                  return Column(
                    children: [
                      _SettingsTile(
                        icon: Icons.pin_outlined,
                        iconColor: AppColors.primary,
                        title: hasPin ? 'Change PIN' : 'Set up PIN',
                        subtitle: hasPin
                            ? 'Update your 4-digit app PIN'
                            : 'Add a PIN to protect your data',
                        onTap: () => context.push(
                          hasPin ? AppRoutes.changePin : AppRoutes.pinSetup,
                        ),
                      ),
                      if (hasPin) ...[
                        Divider(height: 1, indent: R.s(56)),
                        _SettingsTile(
                          icon: Icons.lock_open_outlined,
                          iconColor: AppColors.error,
                          title: 'Remove PIN',
                          subtitle: 'Disable PIN protection for this app',
                          onTap: () => _confirmRemovePin(context, ref),
                        ),
                      ],
                    ],
                  );
                }),
                Divider(height: 1, indent: R.s(56)),
                _BiometricTile(settings: settings, ref: ref),
              ]),
            ).animate().fadeIn(delay: 180.ms),
            const Gap(10),
            _CompactSection(
              title: 'Preferences',
              child: _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.palette_outlined,
                  iconColor: AppColors.accentLight.withValues(alpha: 1),
                  title: 'Appearance',
                  subtitle: _themeLabel(settings.themeMode),
                  onTap: () =>
                      _showThemePicker(context, ref, settings.themeMode),
                ),
                Divider(height: 1, indent: R.s(56)),
                _SettingsTile(
                  icon: Icons.currency_exchange_rounded,
                  iconColor: AppColors.success,
                  title: 'Currency',
                  subtitle:
                      '${settings.currency} — ${currencySymbol(settings.currency)}',
                  onTap: () =>
                      _showCurrencyPicker(context, ref, settings.currency),
                ),
                Divider(height: 1, indent: R.s(56)),
                _SettingsTile(
                  icon: Icons.swap_horiz_rounded,
                  iconColor: AppColors.primary,
                  title: 'Exchange Rates',
                  subtitle: exchangeRates.error ?? exchangeSubtitle,
                  trailing: exchangeRates.isLoading
                      ? SizedBox.square(
                          dimension: R.s(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: R.s(16),
                          color: colors.onSurfaceVariant,
                        ),
                  onTap: () => _showExchangeRateSheet(context),
                ),
                Divider(height: 1, indent: R.s(56)),
                _SettingsTile(
                  icon: Icons.visibility_off_outlined,
                  iconColor: AppColors.warning,
                  title: 'Privacy Mode',
                  subtitle: 'Hide amounts across dashboards and lists',
                  trailing: Switch.adaptive(
                    value: settings.privacyModeEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setPrivacyModeEnabled(value),
                  ),
                ),
                Divider(height: 1, indent: R.s(56)),
                _SettingsTile(
                  icon: Icons.lightbulb_outline_rounded,
                  iconColor: AppColors.warning,
                  title: 'Onboarding Tips',
                  subtitle: settings.onboardingTipsEnabled
                      ? 'Walkthrough auto-open is enabled'
                      : 'Walkthrough auto-open is disabled',
                  trailing: Switch.adaptive(
                    value: settings.onboardingTipsEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (value) => ref
                        .read(settingsProvider.notifier)
                        .setOnboardingTipsEnabled(value),
                  ),
                ),
                Divider(height: 1, indent: R.s(56)),
                _SettingsTile(
                  icon: Icons.explore_outlined,
                  iconColor: AppColors.accent,
                  title: 'Replay Feature Walkthrough',
                  subtitle: settings.onboardingCompleted
                      ? 'Run the guided tour again'
                      : 'Start the guided tour',
                  trailing: Icon(Icons.arrow_forward_ios_rounded,
                      size: R.s(16), color: colors.onSurfaceVariant),
                  onTap: () => context.push('${AppRoutes.onboarding}?replay=1'),
                ),
                Divider(height: 1, indent: R.s(56)),
                // _SettingsTile(
                //   icon: Icons.view_compact_alt_outlined,
                //   iconColor: AppColors.primary,
                //   title: 'Density Mode',
                //   subtitle: _densityLabel(settings.densityMode),
                //   onTap: () =>
                //       _showDensityPicker(context, ref, settings.densityMode),
                // ),
              ]),
            ).animate().fadeIn(delay: 210.ms),
            // const Gap(10),
            // _CompactSection(
            //   title: 'Notifications',
            //   child: _SettingsCard(children: [
            //     _SettingsTile(
            //       icon: Icons.notifications_active_rounded,
            //       iconColor: AppColors.warning,
            //       title: 'Budget Alerts',
            //       subtitle: 'Notify when a budget envelope hits 80% or over',
            //       trailing: Switch.adaptive(
            //         value: settings.notifBudgetAlerts,
            //         activeThumbColor: AppColors.primary,
            //         onChanged: (v) => ref
            //             .read(settingsProvider.notifier)
            //             .setNotifBudgetAlerts(v),
            //       ),
            //     ),
            //     Divider(height: 1, indent: R.s(56)),
            //     _SettingsTile(
            //       icon: Icons.savings_rounded,
            //       iconColor: AppColors.success,
            //       title: 'Goal Milestones',
            //       subtitle: 'Notify at 50% and 100% of each savings goal',
            //       trailing: Switch.adaptive(
            //         value: settings.notifGoalAlerts,
            //         activeThumbColor: AppColors.primary,
            //         onChanged: (v) => ref
            //             .read(settingsProvider.notifier)
            //             .setNotifGoalAlerts(v),
            //       ),
            //     ),
            //   ]),
            // ).animate().fadeIn(delay: 240.ms),
            const Gap(10),
            _CompactSection(
              title: 'Data & About',
              child: _SettingsCard(children: [
                _SettingsTile(
                  icon: Icons.download_outlined,
                  iconColor: AppColors.accent,
                  title: 'Export Data',
                  subtitle: 'Export with filters, grouping, and templates',
                  onTap: () => context.push(AppRoutes.export),
                ),
                Divider(height: 1, indent: R.s(56)),
                // _SettingsTile(
                //   icon: Icons.corporate_fare_outlined,
                //   iconColor: AppColors.primary,
                //   title: 'Organization Branding',
                //   subtitle: settings.organizationName.isEmpty
                //       ? 'Configure logo text, footer, and signatory'
                //       : settings.organizationName,
                //   onTap: () =>
                //       _showOrganizationBrandingDialog(context, ref, settings),
                // ),
                // Divider(height: 1, indent: R.s(56)),
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: colors.onSurfaceVariant,
                  title: 'Version',
                  subtitle: '1.0.0',
                ),
                Divider(height: 1, indent: R.s(56)),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  iconColor: colors.onSurfaceVariant,
                  title: 'Privacy Policy',
                  trailing: Icon(Icons.open_in_new_rounded,
                      size: R.s(14), color: colors.onSurfaceVariant),
                ),
              ]),
            ).animate().fadeIn(delay: 270.ms),
            const Gap(16),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ── Theme helpers ────────────────────────────────────────────────────────
  String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System default',
        _ => 'Light',
      };

  String _densityLabel(UiDensityMode mode) => switch (mode) {
        UiDensityMode.compact => 'Compact',
        UiDensityMode.comfortable => 'Comfortable',
      };

  Future<void> _showThemePicker(
      BuildContext context, WidgetRef ref, ThemeMode current) async {
    final colors = Theme.of(context).colorScheme;
    final options = [
      (ThemeMode.light, Icons.light_mode_outlined, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
      (ThemeMode.system, Icons.brightness_auto_outlined, 'System default'),
    ];
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: R.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(R.s(20), R.s(12), R.s(20), R.sm),
                child: Text('Appearance',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: R.t(16))),
              ),
              ...options.map((o) {
                final (mode, icon, label) = o;
                return ListTile(
                  leading: Icon(icon,
                      color: current == mode
                          ? AppColors.primary
                          : colors.onSurfaceVariant),
                  title: Text(label),
                  trailing: current == mode
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    ref.read(settingsProvider.notifier).setThemeMode(mode);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDensityPicker(
      BuildContext context, WidgetRef ref, UiDensityMode current) async {
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.view_compact_alt_outlined,
                  color: current == UiDensityMode.compact
                      ? AppColors.primary
                      : colors.onSurfaceVariant),
              title: const Text('Compact'),
              subtitle: const Text('More information on screen'),
              trailing: current == UiDensityMode.compact
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setDensityMode(UiDensityMode.compact);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.space_dashboard_outlined,
                  color: current == UiDensityMode.comfortable
                      ? AppColors.primary
                      : colors.onSurfaceVariant),
              title: const Text('Comfortable'),
              subtitle: const Text('Larger spacing and touch targets'),
              trailing: current == UiDensityMode.comfortable
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () {
                ref
                    .read(settingsProvider.notifier)
                    .setDensityMode(UiDensityMode.comfortable);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Future<void> _showSettingsSearch(
    BuildContext context,
    WidgetRef ref,
    CloudAuthState cloud,
    SyncState syncState,
  ) async {
    var query = '';
    final hasPin = ref.read(authStateProvider).hasPin;
    final settings = ref.read(settingsProvider);

    final items = <_SettingsSearchItem>[
      _SettingsSearchItem(
        title: 'Appearance',
        subtitle: _themeLabel(settings.themeMode),
        onTap: () => _showThemePicker(context, ref, settings.themeMode),
      ),
      _SettingsSearchItem(
        title: 'Currency',
        subtitle: settings.currency,
        onTap: () => _showCurrencyPicker(context, ref, settings.currency),
      ),
      _SettingsSearchItem(
        title: 'Density Mode',
        subtitle: _densityLabel(settings.densityMode),
        onTap: () => _showDensityPicker(context, ref, settings.densityMode),
      ),
      _SettingsSearchItem(
        title: 'Export Data',
        subtitle: 'Open export center',
        onTap: () => context.push(AppRoutes.export),
      ),
      _SettingsSearchItem(
        title: 'Organization Branding',
        subtitle: settings.organizationName.isEmpty
            ? 'Configure PDF report branding'
            : settings.organizationName,
        onTap: () => _showOrganizationBrandingDialog(context, ref, settings),
      ),
      if (cloud.isConnected)
        _SettingsSearchItem(
          title: 'Edit Profile',
          subtitle: cloud.user?.name ?? '',
          onTap: () => _showEditProfileDialog(context, ref, cloud),
        ),
      if (cloud.isConnected)
        _SettingsSearchItem(
          title: 'Manage Sessions',
          subtitle: 'Review active cloud devices',
          onTap: () => _showSessionManagerDialog(context, ref),
        ),
      if (!cloud.isConnected)
        _SettingsSearchItem(
          title: 'Connect to Cloud',
          subtitle: 'Login to sync data',
          onTap: () => context.push(AppRoutes.login),
        ),
      _SettingsSearchItem(
        title: hasPin ? 'Change PIN' : 'Set up PIN',
        subtitle: 'Security',
        onTap: () =>
            context.push(hasPin ? AppRoutes.changePin : AppRoutes.pinSetup),
      ),
      _SettingsSearchItem(
        title: 'Sync Now',
        subtitle:
            syncState.isSyncing ? 'Sync in progress' : 'Trigger immediate sync',
        onTap: syncState.isSyncing
            ? null
            : () => ref.read(syncProvider.notifier).sync(),
      ),
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filtered = items.where((item) {
            final hay = '${item.title} ${item.subtitle}'.toLowerCase();
            return hay.contains(query.toLowerCase());
          }).toList();

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: R.md,
                right: R.md,
                top: R.md,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + R.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Search settings',
                    ),
                    onChanged: (v) => setModalState(() => query = v),
                  ),
                  const Gap(10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = filtered[i];
                        return ListTile(
                          dense: true,
                          title: Text(item.title),
                          subtitle: item.subtitle.isEmpty
                              ? null
                              : Text(item.subtitle),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: item.onTap == null
                              ? null
                              : () {
                                  Navigator.pop(ctx);
                                  item.onTap!.call();
                                },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showOrganizationBrandingDialog(
    BuildContext context,
    WidgetRef ref,
    SettingsState settings,
  ) async {
    final orgCtrl = TextEditingController(text: settings.organizationName);
    final footerCtrl = TextEditingController(text: settings.organizationFooter);
    final signCtrl = TextEditingController(text: settings.executiveSignatory);
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (ctx) => DSDialog(
        title: const Text('Organization Branding',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: orgCtrl,
                decoration: InputDecoration(
                  labelText: 'Organization Name',
                  hintText: 'e.g. FinFlow Labs Pvt Ltd',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Gap(12),
              TextField(
                controller: footerCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Footer Note',
                  hintText: 'Confidential • Internal use only',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Gap(12),
              TextField(
                controller: signCtrl,
                decoration: InputDecoration(
                  labelText: 'Executive Signatory',
                  hintText: 'CFO / Finance Head',
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.mdAll,
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              await ref.read(settingsProvider.notifier).setOrganizationProfile(
                    organizationName: orgCtrl.text.trim(),
                    organizationFooter: footerCtrl.text.trim(),
                    executiveSignatory: signCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    orgCtrl.dispose();
    footerCtrl.dispose();
    signCtrl.dispose();
  }

  // ── Currency helpers ─────────────────────────────────────────────────────
  Future<void> _showCurrencyPicker(
      BuildContext context, WidgetRef ref, String current) async {
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, sc) => Padding(
          padding: EdgeInsets.only(top: R.sm),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(R.s(20), R.s(12), R.s(20), R.sm),
                child: Text('Select Currency',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: R.t(16))),
              ),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  itemCount: kSupportedCurrencies.length,
                  itemBuilder: (_, i) {
                    final c = kSupportedCurrencies[i];
                    final isCurrent = c.code == current;
                    return ListTile(
                      leading: Text(c.symbol,
                          style: TextStyle(
                              fontSize: R.t(20), fontWeight: FontWeight.w600)),
                      title: Text(c.name),
                      subtitle: Text(c.code,
                          style: TextStyle(color: colors.onSurfaceVariant)),
                      trailing: isCurrent
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.primary)
                          : null,
                      onTap: () {
                        ref.read(settingsProvider.notifier).setCurrency(c.code);
                        ref.read(exchangeRateProvider.notifier).refreshIfStale();
                        // Fire-and-forget: patch server so currency survives
                        // re-login on other devices. Silent on failure — next
                        // sync pull will overwrite with server value anyway.
                        ref
                            .read(cloudAuthProvider.notifier)
                            .updateCurrency(c.code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showExchangeRateSheet(BuildContext context) async {
    final colors = Theme.of(context).colorScheme;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Consumer(
          builder: (context, ref, __) {
            final state = ref.watch(exchangeRateProvider);
            final settings = ref.watch(settingsProvider);
            final selectedRate = state.rateFor(settings.currency);
            final sample = state.convert(
              1000,
              fromCurrency: state.baseCurrency,
              toCurrency: settings.currency,
            );

            return Padding(
              padding: EdgeInsets.fromLTRB(R.md, R.md, R.md, R.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Live Exchange Rates',
                          style: TextStyle(
                            fontSize: R.t(16),
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh rates',
                        onPressed: state.isLoading
                            ? null
                            : () => ref
                                .read(exchangeRateProvider.notifier)
                                .refreshRates(),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  Text(
                    state.updatedAt == null
                        ? 'Using fallback/cached rates.'
                        : 'Updated ${_formatTime(state.updatedAt!)}',
                    style: TextStyle(
                      fontSize: R.t(12),
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: R.s(12)),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(R.md),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(R.s(14)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Base: ${state.baseCurrency}',
                          style: TextStyle(
                            fontSize: R.t(12),
                            fontWeight: FontWeight.w700,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        SizedBox(height: R.xs),
                        Text(
                          '1 ${state.baseCurrency} = ${selectedRate.toStringAsFixed(4)} ${settings.currency}',
                          style: TextStyle(
                            fontSize: R.t(14),
                            fontWeight: FontWeight.w700,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        SizedBox(height: R.xs),
                        Text(
                          '1000 ${state.baseCurrency} ≈ ${currencySymbol(settings.currency)}${sample.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: R.t(11),
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: R.s(12)),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: R.s(280)),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: kSupportedCurrencies.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final currency = kSupportedCurrencies[i];
                        final rate = state.rateFor(currency.code);
                        return ListTile(
                          dense: true,
                          title: Text('${currency.code} • ${currency.name}'),
                          subtitle: Text(
                            currency.code == state.baseCurrency
                                ? 'Base currency'
                                : '1 ${state.baseCurrency} = ${rate.toStringAsFixed(4)} ${currency.code}',
                          ),
                          trailing: Text(
                            currency.symbol,
                            style: TextStyle(
                              fontSize: R.t(16),
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (state.error != null) ...[
                    SizedBox(height: R.sm),
                    Text(
                      state.error!,
                      style: TextStyle(
                        fontSize: R.t(11),
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showEditProfileDialog(
      BuildContext context, WidgetRef ref, CloudAuthState cloud) async {
    // Use the latest user from cloud state to avoid nulls
    final user = cloud.user;
    final nameCtrl = TextEditingController(text: user?.name ?? '');
    final usernameCtrl = TextEditingController(text: user?.username ?? '');

    // Explicitly handle 0 or null for the income field
    final budget = user?.monthlyBudget ?? 0.0;
    final incomeCtrl = TextEditingController(
        text: budget > 0 ? budget.toStringAsFixed(0) : '');

    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => DSDialog(
          title: const Text('Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: usernameCtrl,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.length < 3) return 'Username must be 3+ chars';
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(value)) {
                      return 'Only lowercase letters, numbers, underscores';
                    }
                    return null;
                  },
                ),
                const Gap(12),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const Gap(12),
                TextFormField(
                  controller: incomeCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Monthly Income',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Income is required';
                    if (double.tryParse(v) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => saving = true);
                      final name = nameCtrl.text.trim();
                      final username = usernameCtrl.text.trim().toLowerCase();
                      final income = double.parse(incomeCtrl.text);
                      final currency = ref.read(settingsProvider).currency;
                      final ok = await ref
                          .read(cloudAuthProvider.notifier)
                          .updateProfile(
                            name: name,
                            username: username,
                            monthlyBudget: income,
                            currency: currency,
                          );
                      if (ok) {
                        // Keep local auth state in sync
                        await ref
                            .read(authStateProvider.notifier)
                            .syncFromCloud(
                              name: name,
                              email: cloud.user?.email ?? '',
                              currency: currency,
                              monthlyBudget: income,
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } else {
                        setState(() => saving = false);
                      }
                    },
              child: saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save',
                      style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    nameCtrl.dispose();
    usernameCtrl.dispose();
    incomeCtrl.dispose();
  }

  Future<void> _showSessionManagerDialog(
      BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _SessionManagerDialog(),
    );
  }

  void _resetLocalState(WidgetRef ref) {
    ref.invalidate(expenseProvider);
    ref.invalidate(budgetProvider);
    ref.invalidate(groupProvider);
    ref.invalidate(groupExpenseProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(upiIdProvider);
    ref.invalidate(aiInsightsProvider);
    ref.invalidate(syncProvider);
    ref.invalidate(settingsProvider);
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await DSConfirmDialog.show(
      context: context,
      title: 'Delete cloud account?',
      message:
          'This permanently deletes your FinFlow cloud account and all synced data. Your local device data will remain.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!context.mounted) return;

    if (confirmed == true) {
      final currentPassword = await _promptCurrentPasswordForDelete(context);
      if (currentPassword == null) return;

      final ok = await ref.read(cloudAuthProvider.notifier).deleteAccount(
            currentPassword: currentPassword,
          );
      if (ok) {
        await ref.read(authStateProvider.notifier).logout();
        _resetLocalState(ref);
        if (context.mounted) {
          context.go(AppRoutes.authLanding);
        }
      }
    }
  }

  Future<String?> _promptCurrentPasswordForDelete(BuildContext context) async {
    final controller = TextEditingController();
    bool obscureText = true;
    String? validationError;
    String? value;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => DSDialog(
          title: const Text('Confirm your password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'For security, enter your account password before deletion.',
              ),
              const Gap(12),
              TextField(
                controller: controller,
                obscureText: obscureText,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  final password = controller.text;
                  if (password.trim().length < 8) {
                    setDialogState(
                      () => validationError =
                          'Enter your current password (min 8 chars)',
                    );
                    return;
                  }
                  value = password;
                  Navigator.pop(dialogCtx);
                },
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setDialogState(() => obscureText = !obscureText),
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              if (validationError != null) ...[
                const Gap(8),
                Text(
                  validationError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final password = controller.text;
                if (password.trim().length < 8) {
                  setDialogState(
                    () => validationError =
                        'Enter your current password (min 8 chars)',
                  );
                  return;
                }
                value = password;
                Navigator.pop(dialogCtx);
              },
              child: const Text(
                'Continue',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return value;
  }

  Future<void> _confirmRemovePin(BuildContext context, WidgetRef ref) async {
    // First verify current PIN via a dedicated dialog
    String enteredPin = '';
    String? pinError;
    bool confirmed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => DSDialog(
          title: const Text('Confirm current PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter your PIN to remove PIN protection.'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary : AppColors.border,
                      border: Border.all(
                        color:
                            filled ? AppColors.primary : AppColors.borderDark,
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              if (pinError != null) ...[
                const SizedBox(height: 8),
                Text(pinError!,
                    style:
                        const TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 16),
              // Simple digit grid inside dialog
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                runSpacing: 8,
                children: [
                  ...List.generate(9, (i) {
                    final digit = '${i + 1}';
                    return SizedBox(
                      width: 56,
                      height: 48,
                      child: TextButton(
                        onPressed: () {
                          if (enteredPin.length < 4) {
                            setDialogState(() {
                              enteredPin += digit;
                              pinError = null;
                            });
                          }
                        },
                        child: Text(digit,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600)),
                      ),
                    );
                  }),
                  SizedBox(
                    width: 56,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        if (enteredPin.isNotEmpty) {
                          setDialogState(() => enteredPin =
                              enteredPin.substring(0, enteredPin.length - 1));
                        }
                      },
                      child: const Icon(Icons.backspace_outlined, size: 20),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    height: 48,
                    child: TextButton(
                      onPressed: () {
                        if (enteredPin.length < 4) {
                          setDialogState(() {
                            enteredPin += '0';
                            pinError = null;
                          });
                        }
                      },
                      child: const Text('0',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: enteredPin.length == 4
                  ? () async {
                      final valid = await ref
                          .read(authStateProvider.notifier)
                          .verifyPin(enteredPin);
                      if (valid) {
                        confirmed = true;
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      } else {
                        final authError = ref.read(authStateProvider).error;
                        setDialogState(() {
                          pinError = authError ?? 'Incorrect PIN. Try again.';
                          enteredPin = '';
                        });
                      }
                    }
                  : null,
              child: const Text('Confirm',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );

    if (!confirmed || !context.mounted) return;
    await ref.read(authStateProvider.notifier).removePin();
    if (!context.mounted) return;
    showSuccessSnackBar(context, 'PIN removed successfully');
  }

  Future<void> _confirmDisconnect(BuildContext context, WidgetRef ref) async {
    final confirmed = await DSConfirmDialog.show(
      context: context,
      title: 'Sign out of cloud?',
      message: 'This will sign you out and clear local data on this device.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );
    if (confirmed == true) {
      await ref.read(cloudAuthProvider.notifier).logout();
      await ref.read(authStateProvider.notifier).logout();
      _resetLocalState(ref);
      if (context.mounted) {
        context.go(AppRoutes.authLanding);
      }
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _SessionManagerDialog extends ConsumerStatefulWidget {
  const _SessionManagerDialog();

  @override
  ConsumerState<_SessionManagerDialog> createState() =>
      _SessionManagerDialogState();
}

class _SessionManagerDialogState extends ConsumerState<_SessionManagerDialog> {
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _revokingSessionId;
  List<CloudSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _loadSessions(initial: true);
  }

  Future<void> _loadSessions({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      _error = null;
      if (initial) {
        _loading = true;
      } else {
        _refreshing = true;
      }
    });

    try {
      final sessions =
          await ref.read(cloudAuthProvider.notifier).listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load sessions. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _revoke(String sessionId) async {
    final confirmed = await DSConfirmDialog.show(
      context: context,
      title: 'Revoke this session?',
      message:
          'This device will be signed out from cloud sync until it logs in again.',
      cancelLabel: 'Cancel',
      confirmLabel: 'Revoke',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revokingSessionId = sessionId);
    final ok =
        await ref.read(cloudAuthProvider.notifier).revokeSession(sessionId);
    if (!mounted) return;
    setState(() => _revokingSessionId = null);

    if (ok) {
      await _loadSessions();
      if (!mounted) return;
      showSuccessSnackBar(context, 'Session revoked');
      return;
    }

    final err = ref.read(cloudAuthProvider).error;
    setState(() => _error = err ?? 'Failed to revoke session');
  }

  String _relative(DateTime value) {
    final diff = DateTime.now().difference(value);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _displayDeviceName(CloudSession session) {
    final raw = session.deviceName?.trim();
    final genericLabels = <String>{
      'flutter android app',
      'flutter ios app',
      'flutter windows app',
      'flutter macos app',
      'flutter linux app',
      'flutter app on android',
      'flutter app on ios',
      'flutter app on windows',
      'flutter app on macos',
      'flutter app on linux',
      'flutter app',
      'unknown device',
    };

    final normalizedRaw = raw?.toLowerCase();
    if (raw != null &&
        raw.isNotEmpty &&
        normalizedRaw != null &&
        !genericLabels.contains(normalizedRaw) &&
        !raw.toLowerCase().contains('unknown browser') &&
        !raw.toLowerCase().contains('unknown os')) {
      return raw;
    }

    final ua = session.userAgent?.toLowerCase() ?? '';
    if (ua.isEmpty) return 'Unknown device';

    if (ua.contains('dart/') || ua.contains('flutter')) {
      if (ua.contains('android')) return 'Android Device';
      if (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ios')) {
        return 'iOS Device';
      }
      if (ua.contains('windows')) return 'Windows Device';
      if (ua.contains('mac os') || ua.contains('macintosh')) {
        return 'macOS Device';
      }
      if (ua.contains('linux')) return 'Linux Device';
      return 'Unknown Device';
    }

    final os = ua.contains('android')
        ? 'Android'
        : ua.contains('iphone') || ua.contains('ipad') || ua.contains('ios')
            ? 'iOS'
            : ua.contains('windows')
                ? 'Windows'
                : ua.contains('mac os') || ua.contains('macintosh')
                    ? 'macOS'
                    : ua.contains('linux')
                        ? 'Linux'
                        : 'Unknown OS';

    final browser = ua.contains('edg/')
        ? 'Edge'
        : ua.contains('opr/') || ua.contains('opera')
            ? 'Opera'
            : ua.contains('samsungbrowser/')
                ? 'Samsung Internet'
                : ua.contains('chrome/') || ua.contains('crios/')
                    ? 'Chrome'
                    : ua.contains('firefox/') || ua.contains('fxios/')
                        ? 'Firefox'
                        : ua.contains('safari/') && !ua.contains('chrome/')
                            ? 'Safari'
                            : 'Unknown Browser';

    return '$browser on $os';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DSDialog(
      title: const Text('Active Sessions'),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const SizedBox(
                height: 140,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_sessions.length} active device${_sessions.length == 1 ? '' : 's'}',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _refreshing ? null : () => _loadSessions(),
                        icon: _refreshing
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  if (_sessions.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'No active sessions found.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                  if (_sessions.isNotEmpty)
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s = _sessions[i];
                          final revoking = _revokingSessionId == s.id;
                          final subtitle = [
                            'Signed in ${_relative(s.createdAt)}',
                            'Last used ${_relative(s.lastUsedAt)}',
                            'Expires ${_relative(s.expiresAt)}',
                          ].join(' • ');

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(_displayDeviceName(s)),
                            subtitle: Text(
                              subtitle,
                              style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                            trailing: TextButton(
                              onPressed: revoking ? null : () => _revoke(s.id),
                              child: revoking
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.error,
                                      ),
                                    )
                                  : const Text(
                                      'Revoke',
                                      style: TextStyle(color: AppColors.error),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SettingsSearchItem {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _SettingsSearchItem({
    required this.title,
    this.subtitle = '',
    this.onTap,
  });
}

class _SettingsHeroCard extends StatelessWidget {
  final CloudAuthState cloud;
  final VoidCallback? onEdit;

  const _SettingsHeroCard({required this.cloud, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = cloud.user?.name.trim().isNotEmpty == true
        ? cloud.user!.name
        : (cloud.user?.email ?? 'Local User');
    final username = cloud.user?.username ?? 'not set';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(R.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: R.s(46),
            height: R.s(46),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(R.s(14)),
            ),
            child: Icon(Icons.person_rounded,
                color: AppColors.primary, size: R.s(24)),
          ),
          const Gap(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: R.t(15),
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                Text(
                  '@$username',
                  style: TextStyle(
                    fontSize: R.t(12),
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final bool cloudConnected;
  final bool syncing;
  final VoidCallback onCloud;
  final VoidCallback? onSync;
  final VoidCallback onExport;

  const _QuickActionsRow({
    required this.cloudConnected,
    required this.syncing,
    required this.onCloud,
    required this.onSync,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: cloudConnected
                ? Icons.cloud_done_outlined
                : Icons.cloud_upload_outlined,
            label: cloudConnected ? 'Cloud' : 'Connect',
            onTap: onCloud,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _QuickActionButton(
            icon: syncing ? Icons.sync : Icons.sync_rounded,
            label: syncing ? 'Syncing' : 'Sync Now',
            onTap: onSync,
          ),
        ),
        const Gap(8),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.lock_outline_rounded,
            label: 'Security',
            onTap: () => context.push(AppRoutes.changePin),
          ),
        ),
        const Gap(8),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.download_outlined,
            label: 'Export',
            onTap: onExport,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(R.md),
      child: Ink(
        padding: EdgeInsets.symmetric(vertical: R.s(10)),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(R.md),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon,
                color:
                    onTap == null ? colors.onSurfaceVariant : AppColors.primary,
                size: R.s(18)),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                fontSize: R.t(11),
                fontWeight: FontWeight.w600,
                color:
                    onTap == null ? colors.onSurfaceVariant : colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactSection extends StatelessWidget {
  final String title;
  final Widget child;
  final bool initiallyExpanded;

  const _CompactSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.xs),
          childrenPadding: EdgeInsets.fromLTRB(R.xs, 0, R.xs, R.xs),
          title: Text(
            title,
            style: TextStyle(
              fontSize: R.t(13),
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          children: [child],
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(R.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: R.s(36),
        height: R.s(36),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(R.s(10)),
        ),
        child: Icon(icon, color: iconColor, size: R.s(20)),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: R.t(14),
              color: colors.onSurface)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style:
                  TextStyle(fontSize: R.t(12), color: colors.onSurfaceVariant))
          : null,
      trailing: trailing,
      contentPadding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.xs),
    );
  }
}

// ── Biometric Tile ────────────────────────────────────────────────────────────
class _BiometricTile extends StatefulWidget {
  final SettingsState settings;
  final WidgetRef ref;

  const _BiometricTile({required this.settings, required this.ref});

  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  bool _available = false;
  bool _checkingAvailability = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final available = await BiometricService.isAvailable();
    if (!mounted) return;

    setState(() {
      _available = available;
      _checkingAvailability = false;
    });

    if (!available && widget.settings.biometricEnabled) {
      await widget.ref
          .read(settingsProvider.notifier)
          .setBiometricEnabled(false);
    }
  }

  Future<void> _handleToggle(bool enabled) async {
    if (_updating) return;
    setState(() => _updating = true);

    try {
      if (enabled) {
        final available = await BiometricService.isAvailable();
        if (!available) {
          if (!mounted) return;
          setState(() => _available = false);
          await widget.ref
              .read(settingsProvider.notifier)
              .setBiometricEnabled(false);
          if (!mounted) return;
          showInfoSnackBar(
            context,
            'No biometrics are enrolled on this device. Set up biometrics in device settings first.',
          );
          return;
        }

        final result = await BiometricService.authenticateWithResult(
          localizedReason: 'Confirm biometrics to enable unlock in FinFlow',
        );
        if (!mounted) return;

        if (result.isSuccess) {
          await widget.ref
              .read(settingsProvider.notifier)
              .setBiometricEnabled(true);
          if (!mounted) return;
          showSuccessSnackBar(context, 'Biometric unlock enabled.');
          return;
        }

        if (result.shouldDisableBiometricCta) {
          setState(() => _available = false);
          await widget.ref
              .read(settingsProvider.notifier)
              .setBiometricEnabled(false);
        }

        if (!result.isCanceled && result.userMessage != null) {
          if (!mounted) return;
          showErrorSnackBar(context, result.userMessage!);
        }
        return;
      }

      await widget.ref
          .read(settingsProvider.notifier)
          .setBiometricEnabled(false);
      if (!mounted) return;
      showInfoSnackBar(context, 'Biometric unlock disabled.');
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    if (_checkingAvailability) {
      return _SettingsTile(
        icon: Icons.fingerprint_rounded,
        iconColor: colors.onSurfaceVariant,
        title: 'Biometric Unlock',
        subtitle: 'Checking device support...',
        trailing: SizedBox.square(
          dimension: R.s(18),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (!_available) {
      return _SettingsTile(
        icon: Icons.fingerprint_rounded,
        iconColor: colors.onSurfaceVariant,
        title: 'Biometric Unlock',
        subtitle: 'No enrolled biometrics found on this device',
      );
    }

    return ListTile(
      leading: Container(
        width: R.s(36),
        height: R.s(36),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(R.s(10)),
        ),
        child: Icon(Icons.fingerprint_rounded,
            color: AppColors.primary, size: R.s(20)),
      ),
      title: Text('Biometric Unlock',
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: R.t(14),
              color: colors.onSurface)),
      subtitle: Text(
        widget.settings.biometricEnabled
            ? 'Fingerprint / Face ID enabled'
            : 'Use fingerprint or Face ID to unlock',
        style: TextStyle(fontSize: R.t(12), color: colors.onSurfaceVariant),
      ),
      trailing: _updating
          ? SizedBox.square(
              dimension: R.s(18),
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Switch.adaptive(
              value: widget.settings.biometricEnabled,
              onChanged: _handleToggle,
              activeThumbColor: AppColors.primary,
            ),
      contentPadding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.xs),
    );
  }
}
