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

  AuthNotifier(this._repo, this._ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    final account = await _repo.hasAccount;
    final verified = await _repo.isEmailVerified;
    final profile = await _repo.hasProfile;
    final pin = await _repo.hasPin;
    final user = await _repo.getUser();

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
    state = state.copyWith(hasPin: true, isAuthenticated: true);
  }

  // ── Called at PIN entry / biometric unlock ─────────────────────────────────
  Future<bool> verifyPin(String pin) async {
    final valid = await _repo.verifyPin(pin);
    if (valid) {
      state = state.copyWith(isAuthenticated: true);
    } else {
      state = state.copyWith(error: 'Incorrect PIN');
    }
    return valid;
  }

  /// Called after a successful biometric prompt on lock screen.
  void unlockWithBiometric() {
    if (!state.hasPin) return;
    state = state.copyWith(isAuthenticated: true, error: null);
  }

  // ── Remove PIN ─────────────────────────────────────────────────────────────
  Future<void> removePin() async {
    await _repo.removePin(ref: _ref);
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

    // If the server sent a PIN hash and we don't yet have one locally,
    // store it so the user can unlock with the same PIN on this new device.
    bool pin = await _repo.hasPin;
    if (!pin && pinHash != null && pinHash.isNotEmpty) {
      await _repo.syncPinFromHash(pinHash);
      pin = true;
    }

    state = state.copyWith(
      user: appUser,
      hasAccount: true,
      isEmailVerified: true,
      hasProfile: true,
      hasPin: pin,
      isAuthenticated: state.isAuthenticated || !pin,
    );
  }

  // ── Full logout ───────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _repo.clearAll();
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
