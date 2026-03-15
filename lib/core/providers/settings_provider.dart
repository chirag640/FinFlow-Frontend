// lib/core/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/hive_service.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────
abstract class _K {
  static const themeMode = 'theme_mode';
  static const currency = 'currency';
  static const biometricEnabled = 'biometric_enabled';
  static const notifBudgetAlerts = 'notif_budget_alerts';
  static const notifGoalAlerts = 'notif_goal_alerts';
  static const densityMode = 'density_mode';
  static const onboardingTipsEnabled = 'onboarding_tips_enabled';
  static const organizationName = 'organization_name';
  static const organizationFooter = 'organization_footer';
  static const executiveSignatory = 'executive_signatory';
}

enum UiDensityMode { compact, comfortable }

// ── State ─────────────────────────────────────────────────────────────────────
class SettingsState {
  final ThemeMode themeMode;
  final String currency;
  final bool biometricEnabled;
  final bool notifBudgetAlerts;
  final bool notifGoalAlerts;
  final UiDensityMode densityMode;
  final bool onboardingTipsEnabled;
  final String organizationName;
  final String organizationFooter;
  final String executiveSignatory;

  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.currency = 'INR',
    this.biometricEnabled = false,
    this.notifBudgetAlerts = true,
    this.notifGoalAlerts = true,
    this.densityMode = UiDensityMode.comfortable,
    this.onboardingTipsEnabled = true,
    this.organizationName = '',
    this.organizationFooter = '',
    this.executiveSignatory = '',
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currency,
    bool? biometricEnabled,
    bool? notifBudgetAlerts,
    bool? notifGoalAlerts,
    UiDensityMode? densityMode,
    bool? onboardingTipsEnabled,
    String? organizationName,
    String? organizationFooter,
    String? executiveSignatory,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        currency: currency ?? this.currency,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        notifBudgetAlerts: notifBudgetAlerts ?? this.notifBudgetAlerts,
        notifGoalAlerts: notifGoalAlerts ?? this.notifGoalAlerts,
        densityMode: densityMode ?? this.densityMode,
        onboardingTipsEnabled:
            onboardingTipsEnabled ?? this.onboardingTipsEnabled,
        organizationName: organizationName ?? this.organizationName,
        organizationFooter: organizationFooter ?? this.organizationFooter,
        executiveSignatory: executiveSignatory ?? this.executiveSignatory,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _load();
  }

  void _load() {
    final box = HiveService.settings;
    final modeStr = box.get(_K.themeMode, defaultValue: 'light') as String;
    final currency = box.get(_K.currency, defaultValue: 'INR') as String;
    final biometric = box.get(_K.biometricEnabled, defaultValue: false) as bool;
    final notifBudget =
        box.get(_K.notifBudgetAlerts, defaultValue: true) as bool;
    final notifGoal = box.get(_K.notifGoalAlerts, defaultValue: true) as bool;
    final densityRaw = box.get(_K.densityMode,
        defaultValue: UiDensityMode.comfortable.name) as String;
    final onboardingTips =
        box.get(_K.onboardingTipsEnabled, defaultValue: true) as bool;
    final orgName = box.get(_K.organizationName, defaultValue: '') as String;
    final orgFooter =
        box.get(_K.organizationFooter, defaultValue: '') as String;
    final executiveSignatory =
        box.get(_K.executiveSignatory, defaultValue: '') as String;
    state = SettingsState(
      themeMode: _toMode(modeStr),
      currency: currency,
      biometricEnabled: biometric,
      notifBudgetAlerts: notifBudget,
      notifGoalAlerts: notifGoal,
      densityMode: _toDensity(densityRaw),
      onboardingTipsEnabled: onboardingTips,
      organizationName: orgName,
      organizationFooter: orgFooter,
      executiveSignatory: executiveSignatory,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await HiveService.settings.put(_K.themeMode, _toStr(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setCurrency(String currency) async {
    await HiveService.settings.put(_K.currency, currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await HiveService.settings.put(_K.biometricEnabled, enabled);
    state = state.copyWith(biometricEnabled: enabled);
  }

  Future<void> setNotifBudgetAlerts(bool enabled) async {
    await HiveService.settings.put(_K.notifBudgetAlerts, enabled);
    state = state.copyWith(notifBudgetAlerts: enabled);
  }

  Future<void> setNotifGoalAlerts(bool enabled) async {
    await HiveService.settings.put(_K.notifGoalAlerts, enabled);
    state = state.copyWith(notifGoalAlerts: enabled);
  }

  Future<void> setDensityMode(UiDensityMode mode) async {
    await HiveService.settings.put(_K.densityMode, mode.name);
    state = state.copyWith(densityMode: mode);
  }

  Future<void> setOnboardingTipsEnabled(bool enabled) async {
    await HiveService.settings.put(_K.onboardingTipsEnabled, enabled);
    state = state.copyWith(onboardingTipsEnabled: enabled);
  }

  Future<void> setOrganizationProfile({
    required String organizationName,
    required String organizationFooter,
    required String executiveSignatory,
  }) async {
    await HiveService.settings.put(_K.organizationName, organizationName);
    await HiveService.settings.put(_K.organizationFooter, organizationFooter);
    await HiveService.settings.put(_K.executiveSignatory, executiveSignatory);
    state = state.copyWith(
      organizationName: organizationName,
      organizationFooter: organizationFooter,
      executiveSignatory: executiveSignatory,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────
  static ThemeMode _toMode(String s) => switch (s) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };

  static String _toStr(ThemeMode m) => switch (m) {
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
        _ => 'light',
      };

  static UiDensityMode _toDensity(String value) =>
      UiDensityMode.values.firstWhere((e) => e.name == value,
          orElse: () => UiDensityMode.comfortable);
}

// ── Provider ──────────────────────────────────────────────────────────────────
final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (_) => SettingsNotifier(),
);

// ── Supported currencies ──────────────────────────────────────────────────────
class SupportedCurrency {
  final String code;
  final String symbol;
  final String name;
  const SupportedCurrency(
      {required this.code, required this.symbol, required this.name});
}

const kSupportedCurrencies = [
  SupportedCurrency(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
  SupportedCurrency(code: 'USD', symbol: '\$', name: 'US Dollar'),
  SupportedCurrency(code: 'EUR', symbol: '€', name: 'Euro'),
  SupportedCurrency(code: 'GBP', symbol: '£', name: 'British Pound'),
  SupportedCurrency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
  SupportedCurrency(code: 'AED', symbol: 'د.إ', name: 'UAE Dirham'),
  SupportedCurrency(code: 'SGD', symbol: 'S\$', name: 'Singapore Dollar'),
  SupportedCurrency(code: 'CAD', symbol: 'C\$', name: 'Canadian Dollar'),
  SupportedCurrency(code: 'AUD', symbol: 'A\$', name: 'Australian Dollar'),
];

/// Returns the symbol for a currency code, defaulting to the code itself.
String currencySymbol(String code) {
  return kSupportedCurrencies
      .firstWhere(
        (c) => c.code == code,
        orElse: () => SupportedCurrency(code: code, symbol: code, name: code),
      )
      .symbol;
}
