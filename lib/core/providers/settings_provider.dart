// lib/core/providers/settings_provider.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../storage/hive_service.dart';
import '../utils/currency_formatter.dart';

// ── Keys ──────────────────────────────────────────────────────────────────────
abstract class _K {
  static const themeMode = 'theme_mode';
  static const currency = 'currency';
  static const carryForwardStrategy = 'carry_forward_strategy';
  static const carryForwardPercent = 'carry_forward_percent';
  static const carryForwardCap = 'carry_forward_cap';
  static const biometricEnabled = 'biometric_enabled';
  static const notifBudgetAlerts = 'notif_budget_alerts';
  static const notifGoalAlerts = 'notif_goal_alerts';
  static const densityMode = 'density_mode';
  static const onboardingTipsEnabled = 'onboarding_tips_enabled';
  static const onboardingCompleted = 'onboarding_completed';
  static const organizationName = 'organization_name';
  static const organizationFooter = 'organization_footer';
  static const executiveSignatory = 'executive_signatory';
  static const privacyModeEnabled = 'privacy_mode_enabled';
}

enum UiDensityMode { compact, comfortable }

enum CarryForwardStrategy {
  full,
  percentage,
  capped,
  none,
}

// ── State ─────────────────────────────────────────────────────────────────────
class SettingsState {
  final ThemeMode themeMode;
  final String currency;
  final CarryForwardStrategy carryForwardStrategy;
  final double carryForwardPercent;
  final double carryForwardCap;
  final bool biometricEnabled;
  final bool notifBudgetAlerts;
  final bool notifGoalAlerts;
  final UiDensityMode densityMode;
  final bool onboardingTipsEnabled;
  final bool onboardingCompleted;
  final String organizationName;
  final String organizationFooter;
  final String executiveSignatory;
  final bool privacyModeEnabled;
  final bool localCacheRepairNoticeActive;
  final String localCacheRepairNoticeMessage;
  final String? localCacheRepairNoticeUpdatedAt;

  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.currency = 'INR',
    this.carryForwardStrategy = CarryForwardStrategy.full,
    this.carryForwardPercent = 50,
    this.carryForwardCap = 1000,
    this.biometricEnabled = false,
    this.notifBudgetAlerts = true,
    this.notifGoalAlerts = true,
    this.densityMode = UiDensityMode.comfortable,
    this.onboardingTipsEnabled = true,
    this.onboardingCompleted = false,
    this.organizationName = '',
    this.organizationFooter = '',
    this.executiveSignatory = '',
    this.privacyModeEnabled = false,
    this.localCacheRepairNoticeActive = false,
    this.localCacheRepairNoticeMessage = '',
    this.localCacheRepairNoticeUpdatedAt,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    String? currency,
    CarryForwardStrategy? carryForwardStrategy,
    double? carryForwardPercent,
    double? carryForwardCap,
    bool? biometricEnabled,
    bool? notifBudgetAlerts,
    bool? notifGoalAlerts,
    UiDensityMode? densityMode,
    bool? onboardingTipsEnabled,
    bool? onboardingCompleted,
    String? organizationName,
    String? organizationFooter,
    String? executiveSignatory,
    bool? privacyModeEnabled,
    bool? localCacheRepairNoticeActive,
    String? localCacheRepairNoticeMessage,
    String? localCacheRepairNoticeUpdatedAt,
  }) =>
      SettingsState(
        themeMode: themeMode ?? this.themeMode,
        currency: currency ?? this.currency,
        carryForwardStrategy:
            carryForwardStrategy ?? this.carryForwardStrategy,
        carryForwardPercent: carryForwardPercent ?? this.carryForwardPercent,
        carryForwardCap: carryForwardCap ?? this.carryForwardCap,
        biometricEnabled: biometricEnabled ?? this.biometricEnabled,
        notifBudgetAlerts: notifBudgetAlerts ?? this.notifBudgetAlerts,
        notifGoalAlerts: notifGoalAlerts ?? this.notifGoalAlerts,
        densityMode: densityMode ?? this.densityMode,
        onboardingTipsEnabled:
            onboardingTipsEnabled ?? this.onboardingTipsEnabled,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        organizationName: organizationName ?? this.organizationName,
        organizationFooter: organizationFooter ?? this.organizationFooter,
        executiveSignatory: executiveSignatory ?? this.executiveSignatory,
        privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
        localCacheRepairNoticeActive:
            localCacheRepairNoticeActive ?? this.localCacheRepairNoticeActive,
        localCacheRepairNoticeMessage:
            localCacheRepairNoticeMessage ?? this.localCacheRepairNoticeMessage,
        localCacheRepairNoticeUpdatedAt: localCacheRepairNoticeUpdatedAt ??
            this.localCacheRepairNoticeUpdatedAt,
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
    final carryForwardStrategyRaw = box.get(
      _K.carryForwardStrategy,
      defaultValue: CarryForwardStrategy.full.name,
    ) as String;
    final carryForwardPercent =
        (box.get(_K.carryForwardPercent, defaultValue: 50) as num)
            .toDouble()
        .clamp(0, 100)
        .toDouble();
    final carryForwardCap =
        (box.get(_K.carryForwardCap, defaultValue: 1000) as num)
            .toDouble()
        .clamp(0, 1000000000)
        .toDouble();
    CurrencyFormatter.setCurrency(currency);
    final biometric = box.get(_K.biometricEnabled, defaultValue: false) as bool;
    final notifBudget =
        box.get(_K.notifBudgetAlerts, defaultValue: true) as bool;
    final notifGoal = box.get(_K.notifGoalAlerts, defaultValue: true) as bool;
    final densityRaw = box.get(_K.densityMode,
        defaultValue: UiDensityMode.comfortable.name) as String;
    final onboardingTips =
        box.get(_K.onboardingTipsEnabled, defaultValue: true) as bool;
    final onboardingCompleted =
        box.get(_K.onboardingCompleted, defaultValue: false) as bool;
    final orgName = box.get(_K.organizationName, defaultValue: '') as String;
    final orgFooter =
        box.get(_K.organizationFooter, defaultValue: '') as String;
    final executiveSignatory =
        box.get(_K.executiveSignatory, defaultValue: '') as String;
    final privacyMode =
        box.get(_K.privacyModeEnabled, defaultValue: false) as bool;
    final cacheRepairNoticeActive =
        box.get(AppConstants.cacheRepairNoticeActiveKey, defaultValue: false)
            as bool;
    final cacheRepairNoticeMessage =
        box.get(AppConstants.cacheRepairNoticeMessageKey, defaultValue: '')
            as String;
    final cacheRepairNoticeUpdatedAt =
        box.get(AppConstants.cacheRepairNoticeUpdatedAtKey) as String?;

    CurrencyFormatter.setPrivacyMode(privacyMode);
    state = SettingsState(
      themeMode: _toMode(modeStr),
      currency: currency,
      carryForwardStrategy: _toCarryForwardStrategy(carryForwardStrategyRaw),
      carryForwardPercent: carryForwardPercent,
      carryForwardCap: carryForwardCap,
      biometricEnabled: biometric,
      notifBudgetAlerts: notifBudget,
      notifGoalAlerts: notifGoal,
      densityMode: _toDensity(densityRaw),
      onboardingTipsEnabled: onboardingTips,
      onboardingCompleted: onboardingCompleted,
      organizationName: orgName,
      organizationFooter: orgFooter,
      executiveSignatory: executiveSignatory,
      privacyModeEnabled: privacyMode,
      localCacheRepairNoticeActive: cacheRepairNoticeActive,
      localCacheRepairNoticeMessage: cacheRepairNoticeMessage,
      localCacheRepairNoticeUpdatedAt: cacheRepairNoticeUpdatedAt,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await HiveService.settings.put(_K.themeMode, _toStr(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setCurrency(String currency) async {
    await HiveService.settings.put(_K.currency, currency);
    state = state.copyWith(currency: currency);
    CurrencyFormatter.setCurrency(currency);
  }

  Future<void> setCarryForwardStrategy(CarryForwardStrategy strategy) async {
    await HiveService.settings.put(_K.carryForwardStrategy, strategy.name);
    state = state.copyWith(carryForwardStrategy: strategy);
  }

  Future<void> setCarryForwardPercent(double percent) async {
    final clamped = percent.clamp(0, 100).toDouble();
    await HiveService.settings.put(_K.carryForwardPercent, clamped);
    state = state.copyWith(carryForwardPercent: clamped);
  }

  Future<void> setCarryForwardCap(double cap) async {
    final clamped = cap.clamp(0, 1000000000).toDouble();
    await HiveService.settings.put(_K.carryForwardCap, clamped);
    state = state.copyWith(carryForwardCap: clamped);
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

  Future<void> markOnboardingCompleted() async {
    await HiveService.settings.put(_K.onboardingCompleted, true);
    state = state.copyWith(onboardingCompleted: true);
  }

  Future<void> resetOnboardingWalkthrough() async {
    await HiveService.settings.put(_K.onboardingCompleted, false);
    state = state.copyWith(onboardingCompleted: false);
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

  Future<void> setPrivacyModeEnabled(bool enabled) async {
    await HiveService.settings.put(_K.privacyModeEnabled, enabled);
    CurrencyFormatter.setPrivacyMode(enabled);
    state = state.copyWith(privacyModeEnabled: enabled);
  }

  Future<void> dismissLocalCacheRepairNotice() async {
    await HiveService.settings.put(
      AppConstants.cacheRepairNoticeActiveKey,
      false,
    );
    state = state.copyWith(localCacheRepairNoticeActive: false);
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

  static CarryForwardStrategy _toCarryForwardStrategy(String value) =>
      CarryForwardStrategy.values.firstWhere(
        (e) => e.name == value,
        orElse: () => CarryForwardStrategy.full,
      );
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
