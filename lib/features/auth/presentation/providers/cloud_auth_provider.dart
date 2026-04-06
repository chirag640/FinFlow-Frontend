import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/network/network_error.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/storage/hive_service.dart';
import 'auth_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────
class CloudUser {
  final String id;
  final String name;
  final String email;
  final String? username;
  final String? avatarUrl;
  final String currency;
  final bool emailVerified;
  final double monthlyBudget;
  final bool hasPin;

  const CloudUser({
    required this.id,
    required this.name,
    required this.email,
    this.username,
    this.avatarUrl,
    required this.currency,
    required this.emailVerified,
    required this.monthlyBudget,
    this.hasPin = false,
  });

  factory CloudUser.fromJson(Map<String, dynamic> j) {
    return CloudUser(
      id: (j['id'] ?? j['_id'] ?? '') as String,
      name: (j['name'] ?? '') as String,
      email: (j['email'] ?? '') as String,
      username: j['username'] as String?,
      avatarUrl: j['avatarUrl'] as String?,
      currency: (j['currency'] as String?) ?? 'INR',
      emailVerified: (j['emailVerified'] as bool?) ?? false,
      monthlyBudget: ((j['monthlyBudget'] as num?) ?? 0).toDouble(),
      hasPin: (j['hasPin'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'username': username,
        'avatarUrl': avatarUrl,
        'currency': currency,
        'emailVerified': emailVerified,
        'monthlyBudget': monthlyBudget,
        'hasPin': hasPin,
      };
}

class CloudSession {
  final String id;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final DateTime expiresAt;
  final String? ipAddress;
  final String? userAgent;
  final String? deviceName;

  const CloudSession({
    required this.id,
    required this.createdAt,
    required this.lastUsedAt,
    required this.expiresAt,
    this.ipAddress,
    this.userAgent,
    this.deviceName,
  });

  factory CloudSession.fromJson(Map<String, dynamic> j) => CloudSession(
        id: j['id'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        lastUsedAt: DateTime.parse(j['lastUsedAt'] as String),
        expiresAt: DateTime.parse(j['expiresAt'] as String),
        ipAddress: j['ipAddress'] as String?,
        userAgent: j['userAgent'] as String?,
        deviceName: j['deviceName'] as String?,
      );
}

// ── State ─────────────────────────────────────────────────────────────────────
class CloudAuthState {
  final bool isConnected;
  final CloudUser? user;
  final bool isLoading;
  final String? error;
  final String? pendingVerificationUserId;
  final String? pendingVerificationEmail;

  const CloudAuthState({
    this.isConnected = false,
    this.user,
    this.isLoading = false,
    this.error,
    this.pendingVerificationUserId,
    this.pendingVerificationEmail,
  });

  CloudAuthState copyWith({
    bool? isConnected,
    CloudUser? user,
    bool? isLoading,
    String? error,
    String? pendingVerificationUserId,
    String? pendingVerificationEmail,
    bool clearPending = false,
  }) =>
      CloudAuthState(
        isConnected: isConnected ?? this.isConnected,
        user: user ?? this.user,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        pendingVerificationUserId: clearPending
            ? null
            : pendingVerificationUserId ?? this.pendingVerificationUserId,
        pendingVerificationEmail: clearPending
            ? null
            : pendingVerificationEmail ?? this.pendingVerificationEmail,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────
class CloudAuthNotifier extends StateNotifier<CloudAuthState> {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  final Ref _ref;

  CloudAuthNotifier(this._dio, this._storage, this._ref)
      // Start loading so the Settings page never flashes "Connect to Cloud"
      // during the brief window before _restoreSession reads secure storage.
      : super(const CloudAuthState(isLoading: true)) {
    _restoreSession();
  }

  /// On cold start: if we have a stored access token, call GET /auth/me
  /// to hydrate auth flags. This drives the router to the correct screen.
  Future<void> _restoreSession() async {
    final token = await _storage.read(key: TokenKeys.accessToken);
    if (token == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    final cachedUser = await _readCachedUser();
    if (cachedUser != null) {
      state = state.copyWith(
        isConnected: true,
        isLoading: false,
        user: cachedUser,
      );

      // Hydrate local auth/profile immediately from cache so startup is fast
      // even when the backend is cold, then refresh from network in background.
      final authNotifier = _ref.read(authStateProvider.notifier);
      if (cachedUser.name.trim().isNotEmpty) {
        unawaited(
          authNotifier.syncFromCloud(
            name: cachedUser.name,
            email: cachedUser.email,
            currency: cachedUser.currency,
            monthlyBudget: cachedUser.monthlyBudget,
            hasPinOnServer: cachedUser.hasPin,
          ),
        );
      }
    } else {
      // Token exists in storage — optimistically mark connected so the
      // Settings page immediately shows the correct "Connected" state
      // instead of flashing "Connect to Cloud" during the API round-trip.
      state = state.copyWith(isConnected: true, isLoading: true);
    }

    try {
      final res = await _dio.get(
        ApiEndpoints.me,
        options: Options(receiveTimeout: const Duration(seconds: 12)),
      );
      final userData = res.data['data'] as Map<String, dynamic>;
      final user = CloudUser.fromJson(userData);
      await _cacheUser(user);

      final authNotifier = _ref.read(authStateProvider.notifier);
      await authNotifier.markAccountCreated();

      if (!user.emailVerified) {
        state = state.copyWith(
          isLoading: false,
          user: user,
          isConnected: true,
          pendingVerificationUserId: user.id,
          pendingVerificationEmail: user.email,
        );
        return;
      }

      await authNotifier.markEmailVerified();

      // ENSURE USER IS SET BEFORE SYNCING
      state = state.copyWith(isConnected: true, isLoading: false, user: user);

      unawaited(NotificationService.syncFcmToken(_dio));

      if (user.name.trim().isNotEmpty) {
        await authNotifier.syncFromCloud(
          name: user.name,
          email: user.email,
          currency: user.currency,
          monthlyBudget: user.monthlyBudget,
          hasPinOnServer: user.hasPin,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Tokens genuinely invalid (expired or revoked) — clear and notify user
        await _storage.delete(key: TokenKeys.accessToken);
        await _storage.delete(key: TokenKeys.refreshToken);
        await _clearCachedUser();
        state = const CloudAuthState(
          error: 'Session expired — please sign in again',
        );
      } else {
        // Network error / server down — keep optimistic connected state,
        // user can sync when connectivity returns
        state = state.copyWith(isLoading: false);
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<CloudUser?> register({
    required String email,
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _dio.post(
        ApiEndpoints.register,
        data: {
          'email': email,
          'username': username,
          'password': password,
        },
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      // Registration intentionally returns NO tokens — they are only issued
      // by verifyEmail() once the user proves ownership of their address.
      final user =
          CloudUser.fromJson(res.data['data']['user'] as Map<String, dynamic>);

      // Mark account created in local auth state
      await _ref.read(authStateProvider.notifier).markAccountCreated();

      state = CloudAuthState(
        isLoading: false,
        pendingVerificationUserId: user.id,
        pendingVerificationEmail: user.email,
      );
      return user;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionTimeout) {
        // Backend may have created/updated a pending unverified account but
        // timed out while sending OTP mail. Try login to recover pending
        // verification context and route user to OTP screen.
        await login(email: email, password: password);
        if (state.pendingVerificationUserId != null) {
          state = state.copyWith(isLoading: false, error: null);
          return null;
        }
      }
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return null;
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<CloudUser?> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _dio.post(ApiEndpoints.login, data: {
        'email': email,
        'password': password,
      });
      await _saveTokens(res.data['data']);

      // The login response structure is: { data: { user: { ... }, accessToken: "..." } }
      final userData = res.data['data']['user'] as Map<String, dynamic>;
      final user = CloudUser.fromJson(userData);
      await _cacheUser(user);

      // Always sync local auth state from server so the latest name, currency,
      // and monthly budget are shown immediately — even when re-logging in on
      // a device that already has a local PIN session.
      await _ref.read(authStateProvider.notifier).syncFromCloud(
            name: user.name,
            email: user.email,
            currency: user.currency,
            monthlyBudget: user.monthlyBudget,
            hasPinOnServer: user.hasPin,
          );

      state = state.copyWith(isLoading: false, isConnected: true, user: user);
      unawaited(NotificationService.syncFcmToken(_dio));
      return user;
    } on DioException catch (e) {
      final data = e.response?.data;
      final code = data is Map ? data['code'] : null;
      final userId = data is Map ? (data['userId'] as String?) : null;
      if (e.response?.statusCode == 403 &&
          code == 'EMAIL_NOT_VERIFIED' &&
          userId != null) {
        // Mark account exists but email not verified
        await _ref.read(authStateProvider.notifier).markAccountCreated();
        state = CloudAuthState(
          isLoading: false,
          pendingVerificationUserId: userId,
          pendingVerificationEmail: email,
        );
        return null;
      }
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return null;
    }
  }

  // ── Verify Email ──────────────────────────────────────────────────────────
  Future<CloudUser?> verifyEmail(String userId, String code) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _dio.post(ApiEndpoints.verifyEmail, data: {
        'userId': userId,
        'code': code,
      });
      await _saveTokens(res.data['data']);

      // Response structure: { data: { user: { ... }, accessToken: "..." } }
      final userData = res.data['data']['user'] as Map<String, dynamic>;
      final user = CloudUser.fromJson(userData);
      await _cacheUser(user);

      // Mark email verified — router will redirect to profile-setup
      await _ref.read(authStateProvider.notifier).markEmailVerified();

      state = state.copyWith(
        isLoading: false,
        isConnected: true,
        user: user,
        clearPending: true,
      );
      unawaited(NotificationService.syncFcmToken(_dio));
      return user;
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: _extractError(e));
      return null;
    }
  }

  // ── Resend OTP ────────────────────────────────────────────────────────────
  Future<bool> resendOtp(String userId) async {
    try {
      await _dio.post(
        ApiEndpoints.resendOtp,
        data: {'userId': userId},
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    }
  }

  // ── Update Profile (PATCH /users/me) ────────────────────────────────────
  Future<bool> updateProfile({
    required String name,
    required double monthlyBudget,
    String currency = 'INR',
    String? username,
  }) async {
    try {
      await _dio.patch(ApiEndpoints.userProfile, data: {
        'name': name,
        'monthlyBudget': monthlyBudget,
        'currency': currency,
        if (username != null && username.trim().isNotEmpty)
          'username': username.trim().toLowerCase(),
      });
      state = state.copyWith(
        user: state.user == null
            ? null
            : CloudUser(
                id: state.user!.id,
                name: name,
                email: state.user!.email,
                username: username ?? state.user!.username,
                avatarUrl: state.user!.avatarUrl,
                currency: currency,
                emailVerified: state.user!.emailVerified,
                monthlyBudget: monthlyBudget,
                hasPin: state.user!.hasPin,
              ),
      );
      if (state.user != null) {
        await _cacheUser(state.user!);
      }
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    }
  }

  /// Patches only the currency field — used when user changes currency in Settings.
  Future<bool> updateCurrency(String currency) async {
    if (!state.isConnected) return true; // offline — local change is fine
    try {
      await _dio.patch(ApiEndpoints.userProfile, data: {'currency': currency});
      if (state.user != null) {
        state = state.copyWith(
          user: CloudUser(
            id: state.user!.id,
            name: state.user!.name,
            email: state.user!.email,
            username: state.user!.username,
            avatarUrl: state.user!.avatarUrl,
            currency: currency,
            emailVerified: state.user!.emailVerified,
            monthlyBudget: state.user!.monthlyBudget,
            hasPin: state.user!.hasPin,
          ),
        );
        await _cacheUser(state.user!);
      }
      return true;
    } on DioException {
      return false; // silent — local change already applied
    }
  }

  // ── Forgot / Reset Password ─────────────────────────────────────────────
  Future<bool> forgotPassword(String email) async {
    try {
      await _dio.post(ApiEndpoints.forgotPassword, data: {
        'email': email.trim(),
      });
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    }
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dio.post(ApiEndpoints.resetPassword, data: {
        'email': email.trim(),
        'code': code.trim(),
        'newPassword': newPassword,
      });
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await NotificationService.unregisterFcmToken(_dio);
      final token = await _storage.read(key: TokenKeys.refreshToken);
      if (token != null) {
        await _dio.post(ApiEndpoints.logout, data: {'refreshToken': token});
      }
    } catch (_) {}
    await _storage.delete(key: TokenKeys.accessToken);
    await _storage.delete(key: TokenKeys.refreshToken);
    await _clearCachedUser();
    state = const CloudAuthState();
  }

  // ── Delete Account (DELETE /users/me) ────────────────────────────────────
  Future<bool> deleteAccount() async {
    state = state.copyWith(isLoading: true);
    try {
      await NotificationService.unregisterFcmToken(_dio);
      await _dio.delete(ApiEndpoints.userProfile);
    } on DioException catch (e) {
      // If 401/403 the token may already be invalid — proceed with local cleanup
      if (e.response?.statusCode != 401 && e.response?.statusCode != 403) {
        state = state.copyWith(isLoading: false, error: _extractError(e));
        return false;
      }
    }
    await _storage.delete(key: TokenKeys.accessToken);
    await _storage.delete(key: TokenKeys.refreshToken);
    await _clearCachedUser();
    state = const CloudAuthState();
    return true;
  }

  Future<List<CloudSession>> listSessions() async {
    final res = await _dio.get(ApiEndpoints.authSessions);
    final data = (res.data['data'] as List<dynamic>? ?? const []);
    return data
        .map((row) => CloudSession.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<bool> revokeSession(String sessionId) async {
    try {
      await _dio.post(
        ApiEndpoints.authSessionsRevoke,
        data: {'sessionId': sessionId},
      );
      return true;
    } on DioException catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Future<CloudUser?> _readCachedUser() async {
    final raw = HiveService.user.get(AppConstants.cloudUserKey);
    if (raw is! String || raw.isEmpty) return null;
    try {
      return CloudUser.fromJson(
        json.decode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheUser(CloudUser user) async {
    await HiveService.user.put(
      AppConstants.cloudUserKey,
      json.encode(user.toJson()),
    );
  }

  Future<void> _clearCachedUser() async {
    await HiveService.user.delete(AppConstants.cloudUserKey);
  }

  Future<void> _saveTokens(dynamic data) async {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    // Both tokens must be present. If the server returns a malformed response
    // we throw here so the caller's catch block handles it, rather than
    // silently leaving storage in a half-written state (isConnected: true
    // but token reads null on the next app start).
    if (access == null || refresh == null) {
      throw Exception('Invalid auth response: missing tokens');
    }
    await _storage.write(key: TokenKeys.accessToken, value: access);
    await _storage.write(key: TokenKeys.refreshToken, value: refresh);
  }

  String _extractError(DioException e) {
    return formatDioError(e);
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────
final cloudAuthProvider =
    StateNotifierProvider<CloudAuthNotifier, CloudAuthState>((ref) {
  return CloudAuthNotifier(
    ref.watch(dioProvider),
    const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
    ref,
  );
});
