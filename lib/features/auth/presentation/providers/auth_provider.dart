import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

// Keep a module-level ref so AuthNotifier methods can pass it to the repo.
// Populated by the StateNotifierProvider factory below.

// ── Auth State (5-flag state machine) ─────────────────────────────────────────

class AuthState {
  final AppUser? user;

  /// true after POST /auth/register succeeds (tokens stored)
  final bool hasAccount;

  /// true after POST /auth/verify-email succeeds
  final bool isEmailVerified;

  /// true after profile (name + income) saved locally + sent to server
  final bool hasProfile;

  /// true after user sets a 4-digit PIN (or skips)
  final bool hasPin;

  /// true after PIN entry / biometric unlock — zeroed on app lock
  final bool isAuthenticated;

  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.hasAccount = false,
    this.isEmailVerified = false,
    this.hasProfile = false,
    this.hasPin = false,
    this.isAuthenticated = false,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AppUser? user,
    bool? hasAccount,
    bool? isEmailVerified,
    bool? hasProfile,
    bool? hasPin,
    bool? isAuthenticated,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        user: user ?? this.user,
        hasAccount: hasAccount ?? this.hasAccount,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
        hasProfile: hasProfile ?? this.hasProfile,
        hasPin: hasPin ?? this.hasPin,
        isAuthenticated: isAuthenticated ?? this.isAuthenticated,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Auth Notifier ─────────────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  final Ref _ref;
  static const int _pinMaxAttempts = 5;
  static const int _pinBaseLockSeconds = 30;
  static const int _pinMaxLockSeconds = 600;

  int _failedPinAttempts = 0;
  DateTime? _pinLockedUntil;

  AuthNotifier(this._repo, this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final values = await Future.wait<dynamic>([
      _repo.hasAccount,
      _repo.isEmailVerified,
      _repo.hasProfile,
      _repo.hasPin,
      _repo.getUser(),
    ]);
    final account = values[0] as bool;
    final verified = values[1] as bool;
    final profile = values[2] as bool;
    final pin = values[3] as bool;
    final user = values[4] as AppUser?;

    state = AuthState(
      user: user,
      hasAccount: account,
      isEmailVerified: verified,
      hasProfile: profile,
      hasPin: pin,
      // If all 4 flags true AND no PIN set → auto-authenticate
      // If PIN set → needs PIN entry first
      isAuthenticated: account && verified && profile && !pin,
      // If PIN exists → user must enter it
      isLoading: false,
    );
  }

  // ── Called after cloud register succeeds ───────────────────────────────────
  Future<void> markAccountCreated() async {
    await _repo.setHasAccount(true);
    state = state.copyWith(hasAccount: true);
  }

  // ── Called after OTP verification succeeds ────────────────────────────────
  Future<void> markEmailVerified() async {
    await _repo.setEmailVerified(true);
    state = state.copyWith(isEmailVerified: true);
  }

  // ── Called after profile setup (name + income) saved ──────────────────────
  Future<void> completeProfile(AppUser user) async {
    await _repo.saveUser(user);
    await _repo.setHasProfile(true);
    state = state.copyWith(user: user, hasProfile: true);
  }

  // ── Called after PIN chosen (or skipped with empty string) ────────────────
  Future<void> setupPin(String pin) async {
    if (pin.isNotEmpty) {
      // ref passed so savePin can push the hash to the server
      await _repo.savePin(pin, ref: _ref);
    }
    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    state = state.copyWith(hasPin: true, isAuthenticated: true);
  }

  // ── Called at PIN entry / biometric unlock ─────────────────────────────────
  Future<bool> verifyPin(String pin) async {
    final now = DateTime.now();
    if (_pinLockedUntil != null && now.isBefore(_pinLockedUntil!)) {
      final waitSeconds = _pinLockedUntil!
          .difference(now)
          .inSeconds
          .clamp(1, _pinMaxLockSeconds);
      state = state.copyWith(
        error: 'Too many PIN attempts. Try again in $waitSeconds seconds.',
      );
      return false;
    }

    final result = await _repo.verifyPin(pin, ref: _ref);

    if (result.isValid) {
      _failedPinAttempts = 0;
      _pinLockedUntil = null;
      state = state.copyWith(isAuthenticated: true, error: null);
      return true;
    }

    if (result.outcome == PinVerificationOutcome.unavailable) {
      state = state.copyWith(
        error: result.message ??
            'Unable to verify PIN right now. Please try again.',
      );
      return false;
    }

    if (result.outcome == PinVerificationOutcome.notConfigured) {
      state = state.copyWith(
        error: result.message ?? 'No PIN is configured for this account.',
      );
      return false;
    }

    if (result.outcome == PinVerificationOutcome.locked) {
      final lockedUntil = result.lockedUntil;
      _pinLockedUntil = lockedUntil;
      final lockSeconds = lockedUntil == null
          ? _pinBaseLockSeconds
          : max(1, lockedUntil.difference(now).inSeconds);
      state = state.copyWith(
        error:
            'Too many incorrect PIN attempts. Try again in $lockSeconds seconds.',
      );
      return false;
    }

    if (result.remainingAttempts != null) {
      final attemptsLeft = result.remainingAttempts!.clamp(0, _pinMaxAttempts);
      _failedPinAttempts = _pinMaxAttempts - attemptsLeft;
      if (attemptsLeft <= 0 && result.lockedUntil != null) {
        _pinLockedUntil = result.lockedUntil;
      }

      state = state.copyWith(
        error: attemptsLeft > 0
            ? 'Incorrect PIN. $attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} left before temporary lock.'
            : 'Too many incorrect PIN attempts. Please wait before trying again.',
      );
      return false;
    }

    _failedPinAttempts += 1;
    String message = 'Incorrect PIN';

    if (_failedPinAttempts >= _pinMaxAttempts) {
      final exponent = _failedPinAttempts - _pinMaxAttempts;
      final lockSeconds = min(
        _pinMaxLockSeconds,
        (_pinBaseLockSeconds * pow(2, exponent)).toInt(),
      );
      _pinLockedUntil = now.add(Duration(seconds: lockSeconds));
      message =
          'Too many incorrect PIN attempts. Try again in $lockSeconds seconds.';
    } else {
      final attemptsLeft = _pinMaxAttempts - _failedPinAttempts;
      message =
          'Incorrect PIN. $attemptsLeft attempt${attemptsLeft == 1 ? '' : 's'} left before temporary lock.';
    }

    state = state.copyWith(error: message);
    return false;
  }

  /// Called after a successful biometric prompt on lock screen.
  void unlockWithBiometric() {
    if (!state.hasPin) return;
    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    state = state.copyWith(isAuthenticated: true, error: null);
  }

  // ── Remove PIN ─────────────────────────────────────────────────────────────
  Future<void> removePin() async {
    await _repo.removePin(ref: _ref);
    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    state = state.copyWith(hasPin: false, isAuthenticated: true);
  }

  // ── Lock app (background timeout) ─────────────────────────────────────────
  void lock() {
    if (state.hasPin) {
      state = state.copyWith(isAuthenticated: false);
    }
  }

  // ── Called on cloud login — returning user whose profile+pin may already exist
  Future<void> syncFromCloud({
    required String name,
    required String email,
    String currency = 'INR',
    double? monthlyBudget,
    bool? hasPinOnServer,
    String?
        pinHash, // SHA-256 hash received from server; null = no PIN on server
  }) async {
    await _repo.setHasAccount(true);
    await _repo.setEmailVerified(true);

    final existing = state.user;
    final appUser = AppUser(
      name: name,
      monthlyIncome: monthlyBudget ?? existing?.monthlyIncome ?? 0,
      email: email,
      currencyCode: currency,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await _repo.saveUser(appUser);
    await _repo.setHasProfile(true);

    bool localPin = await _repo.hasPin;
    if (!localPin && pinHash != null && pinHash.isNotEmpty) {
      await _repo.syncPinFromHash(pinHash);
      localPin = true;
    }

    // If server reports no PIN but a stale local PIN exists, clear local hash
    // to avoid false verification mismatches.
    if (hasPinOnServer == false && localPin) {
      await _repo.removePin();
      localPin = false;
    }

    final effectiveHasPin = hasPinOnServer ?? localPin;
    final nextAuthenticated =
        effectiveHasPin ? (localPin ? state.isAuthenticated : false) : true;

    state = state.copyWith(
      user: appUser,
      hasAccount: true,
      isEmailVerified: true,
      hasProfile: true,
      hasPin: effectiveHasPin,
      isAuthenticated: nextAuthenticated,
    );
  }

  // ── Full logout ───────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _repo.clearAll();
    _failedPinAttempts = 0;
    _pinLockedUntil = null;
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(error: null);
}

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo, ref);
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).user;
});
