import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../domain/entities/app_user.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/auth_interceptor.dart';
import '../../../../core/storage/hive_service.dart';

/// Generates a 32-character hex random salt.
String _generateSalt() => List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();

/// Computes a lowercase hex SHA-256 digest of [input].
String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

class AuthRepository {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Flag readers ──────────────────────────────────────────────────────────
  Future<bool> get hasAccount async =>
      HiveService.settings.get(AppConstants.hasAccountKey) == true;

  Future<bool> get isEmailVerified async =>
      HiveService.settings.get(AppConstants.isEmailVerifiedKey) == true;

  Future<bool> get hasProfile async =>
      HiveService.settings.get(AppConstants.hasProfileKey) == true;

  Future<bool> get hasPin async {
    final pin = await _storage.read(key: AppConstants.pinKey);
    return pin != null && pin.isNotEmpty;
  }

  // ── Flag writers ──────────────────────────────────────────────────────────
  Future<void> setHasAccount(bool v) async =>
      HiveService.settings.put(AppConstants.hasAccountKey, v);

  Future<void> setEmailVerified(bool v) async =>
      HiveService.settings.put(AppConstants.isEmailVerifiedKey, v);

  Future<void> setHasProfile(bool v) async =>
      HiveService.settings.put(AppConstants.hasProfileKey, v);

  // ── User CRUD ─────────────────────────────────────────────────────────────
  Future<AppUser?> getUser() async {
    final raw = HiveService.user.get('current_user');
    if (raw == null) return null;
    try {
      return AppUser.fromJson(
        json.decode(raw as String) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AppUser user) async {
    await HiveService.user.put('current_user', json.encode(user.toJson()));
  }

  // ── PIN ───────────────────────────────────────────────────────────────────
  /// Hash and store the PIN locally with a random salt, then push the
  /// salted hash to the server so the same PIN works on other devices.
  Future<void> savePin(String pin, {Ref? ref}) async {
    final salt = _generateSalt();
    final hash = _sha256(salt + pin);
    final stored = '$salt:$hash'; // format: "32hexSalt:64hexHash"
    await _storage.write(key: AppConstants.pinKey, value: stored);
    // Push to backend so the PIN syncs to other devices.
    if (ref != null) {
      try {
        final dio = ref.read(dioProvider);
        await dio.patch(ApiEndpoints.updatePin, data: {'pinHash': stored});
      } catch (_) {
        // Silently ignore — sync pull will reconcile on next connect.
      }
    }
  }

  /// Verify a PIN entered by the user against the locally-stored hash.
  /// Supports the new salted format ("32hexSalt:64hexHash") as well as
  /// the legacy unsalted format (existing installs) for backward compatibility.
  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: AppConstants.pinKey);
    if (stored == null) return false;
    // Salted format: "32-char hex salt : 64-char sha-256 hex"
    final colon = stored.indexOf(':');
    if (colon == 32) {
      final salt = stored.substring(0, 32);
      final hash = stored.substring(33);
      return _sha256(salt + pin) == hash;
    }
    // Legacy unsalted fallback (pre-salt installs)
    return _sha256(pin) == stored;
  }

  /// Store a PIN hash received from the server (no re-hashing).
  /// Used on fresh install / new device to sync the existing PIN.
  Future<void> syncPinFromHash(String pinHash) async {
    await _storage.write(key: AppConstants.pinKey, value: pinHash);
  }

  /// Delete the PIN locally and clear it from the server.
  /// Offline-safe: server call failure is swallowed; the local hash is always removed.
  Future<void> removePin({Ref? ref}) async {
    await _storage.delete(key: AppConstants.pinKey);
    if (ref != null) {
      try {
        final dio = ref.read(dioProvider);
        await dio.patch(ApiEndpoints.updatePin, data: {'pinHash': null});
      } catch (_) {}
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> clearAll() async {
    await HiveService.user.clear();
    await HiveService.settings.put(AppConstants.hasAccountKey, false);
    await HiveService.settings.put(AppConstants.isEmailVerifiedKey, false);
    await HiveService.settings.put(AppConstants.hasProfileKey, false);
    await HiveService.settings.put(AppConstants.hasOnboardedKey, false);
    await _storage.deleteAll();
  }
}
