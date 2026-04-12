import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_endpoints.dart';

// ── Token keys ───────────────────────────────────────────────────────────────
abstract class TokenKeys {
  static const accessToken = 'cloud_access_token';
  static const refreshToken = 'cloud_refresh_token';
}

abstract class RequestMetaKeys {
  static const retryCount = '_retryCount';
  static const retriedAuth = '_retried';
}

abstract class RequestHeaderKeys {
  static const requestId = 'x-request-id';
  static const deviceName = 'x-device-name';
}

// ── Global Dio provider ──────────────────────────────────────────────────────
// ignore: unused_element — consumed via cloud_auth_provider.dart
final dioProvider = Provider<Dio>((ref) {
  const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  final baseUrl = configuredBaseUrl.isNotEmpty
      ? configuredBaseUrl
      : (kReleaseMode
          ? 'https://finflow-backend-lunz.onrender.com/api/v1'
          : 'http://10.0.2.2:3000/api/v1');

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Logger runs first so every request/response/error is printed before
  // the auth interceptor mutates headers or retries the request.
  dio.interceptors.add(LoggerInterceptor());
  dio.interceptors.add(AuthInterceptor(dio: dio));

  return dio;
});

// ── Auth interceptor  ────────────────────────────────────────────────────────
class AuthInterceptor extends Interceptor {
  final Dio dio;
  // A bare Dio instance used exclusively for the token-refresh call.
  // Using the main `dio` (which has this interceptor attached) would cause a
  // deadlock when the refresh token is expired: the refresh call's own 401
  // would enter this interceptor, queue itself on _pendingQueue, and
  // then wait forever because the queue is only drained by the same call.
  final Dio _refreshDio;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  bool _isRefreshing = false;
  final Random _random = Random();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static String? _clientDeviceName;
  static Future<String>? _clientDeviceNameFuture;
  // Requests that arrived while a refresh was already in-flight.
  // Each completer receives the new access token on refresh success,
  // or an error on failure, so all queued requests are replayed correctly.
  final List<Completer<String>> _pendingQueue = [];

  AuthInterceptor({required this.dio})
      : _refreshDio = Dio(BaseOptions(
          baseUrl: dio.options.baseUrl,
          connectTimeout: dio.options.connectTimeout,
          receiveTimeout: dio.options.receiveTimeout,
          headers: {'Content-Type': 'application/json'},
        ));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await _attachDeviceName(options);
    _attachRequestId(options);
    _attachIdempotencyKey(options);

    final token = await _storage.read(key: TokenKeys.accessToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _attachDeviceName(RequestOptions options) async {
    if (options.headers.containsKey(RequestHeaderKeys.deviceName)) return;
    options.headers[RequestHeaderKeys.deviceName] =
        await _resolveClientDeviceName();
  }

  static Future<String> _resolveClientDeviceName() async {
    if (_clientDeviceName != null) return _clientDeviceName!;

    _clientDeviceNameFuture ??= _computeClientDeviceName();
    _clientDeviceName = await _clientDeviceNameFuture!;
    return _clientDeviceName!;
  }

  static Future<String> _computeClientDeviceName() async {
    if (kIsWeb) return 'Web Browser';

    try {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final info = await _deviceInfo.androidInfo;
          return _joinDeviceNameParts(
            [info.manufacturer, info.model],
            fallback: 'Android Device',
          );
        case TargetPlatform.iOS:
          final info = await _deviceInfo.iosInfo;
          return _firstAvailableValue(
            [info.name, info.model, info.localizedModel],
            fallback: 'iOS Device',
          );
        case TargetPlatform.macOS:
          final info = await _deviceInfo.macOsInfo;
          return _firstAvailableValue(
            [info.computerName, info.model],
            fallback: 'macOS Device',
          );
        case TargetPlatform.windows:
          final info = await _deviceInfo.windowsInfo;
          return _firstAvailableValue(
            [info.computerName],
            fallback: 'Windows Device',
          );
        case TargetPlatform.linux:
          final info = await _deviceInfo.linuxInfo;
          return _firstAvailableValue(
            [info.prettyName, info.name],
            fallback: 'Linux Device',
          );
        default:
          return _fallbackClientDeviceName();
      }
    } catch (_) {
      return _fallbackClientDeviceName();
    }
  }

  static String _fallbackClientDeviceName() {
    if (kIsWeb) return 'Web Browser';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android Device',
      TargetPlatform.iOS => 'iOS Device',
      TargetPlatform.macOS => 'macOS Device',
      TargetPlatform.windows => 'Windows Device',
      TargetPlatform.linux => 'Linux Device',
      _ => 'Unknown Device',
    };
  }

  static String _joinDeviceNameParts(
    List<String?> values, {
    required String fallback,
  }) {
    final cleaned = values
        .map((v) => v?.trim() ?? '')
        .where((v) => v.isNotEmpty)
        .toList(growable: false);
    if (cleaned.isEmpty) return fallback;
    return cleaned.join(' ');
  }

  static String _firstAvailableValue(
    List<String?> values, {
    required String fallback,
  }) {
    for (final value in values) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return fallback;
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Only intercept 401s that haven't already been through a retry cycle
    // (extra flag prevents an infinite refresh loop if the server keeps
    // returning 401 even after a successful token exchange).
    final alreadyRetried =
        err.requestOptions.extra[RequestMetaKeys.retriedAuth] == true;
    if (err.response?.statusCode == 401 && !alreadyRetried) {
      if (_isRefreshing) {
        // A refresh is already in-flight — queue this request so it is
        // replayed with the new token once the refresh completes.
        final completer = Completer<String>();
        _pendingQueue.add(completer);
        try {
          final newToken = await completer.future;
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          err.requestOptions.extra[RequestMetaKeys.retriedAuth] = true;
          handler.resolve(await dio.fetch(err.requestOptions));
        } catch (_) {
          handler.next(err);
        }
        return;
      }

      _isRefreshing = true;
      try {
        final newToken = await _tryRefresh();
        if (newToken != null) {
          // Unblock all queued requests with the fresh token
          for (final c in _pendingQueue) {
            c.complete(newToken);
          }
          _pendingQueue.clear();
          // Retry the original request
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          err.requestOptions.extra[RequestMetaKeys.retriedAuth] = true;
          handler.resolve(await dio.fetch(err.requestOptions));
          return;
        }
        // Refresh returned null — no stored refresh token
        for (final c in _pendingQueue) {
          c.completeError(Exception('Token refresh failed'));
        }
        _pendingQueue.clear();
        await _storage.delete(key: TokenKeys.accessToken);
        await _storage.delete(key: TokenKeys.refreshToken);
      } catch (_) {
        for (final c in _pendingQueue) {
          c.completeError(Exception('Token refresh failed'));
        }
        _pendingQueue.clear();
        await _storage.delete(key: TokenKeys.accessToken);
        await _storage.delete(key: TokenKeys.refreshToken);
      } finally {
        _isRefreshing = false;
      }
    }

    if (_canRetry(err)) {
      final request = err.requestOptions;
      final currentCount =
          (request.extra[RequestMetaKeys.retryCount] as int?) ?? 0;
      request.extra[RequestMetaKeys.retryCount] = currentCount + 1;

      final delay = _backoffDelay(currentCount + 1);
      await Future.delayed(delay);
      handler.resolve(await dio.fetch(request));
      return;
    }

    handler.next(err);
  }

  void _attachIdempotencyKey(RequestOptions options) {
    if (!_shouldUseIdempotency(options)) return;
    if (options.headers.containsKey('idempotency-key')) return;
    options.headers['idempotency-key'] = _generateIdempotencyKey();
  }

  void _attachRequestId(RequestOptions options) {
    if (options.headers.containsKey(RequestHeaderKeys.requestId)) return;
    options.headers[RequestHeaderKeys.requestId] = _generateRequestId();
  }

  bool _shouldUseIdempotency(RequestOptions options) {
    final method = options.method.toUpperCase();
    if (method != 'POST' && method != 'PATCH' && method != 'DELETE') {
      return false;
    }

    final path = options.path;
    if (path == ApiEndpoints.refresh || path == ApiEndpoints.logout) {
      return false;
    }

    return path.startsWith('/expenses') ||
        path.startsWith('/groups') ||
        path.startsWith('/budgets') ||
        path.startsWith('/sync') ||
        path.startsWith('/users') ||
        path == ApiEndpoints.authSessionsRevoke;
  }

  String _generateIdempotencyKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'ff-$now-$rand';
  }

  String _generateRequestId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');
    return 'ff-req-$now-$rand';
  }

  bool _canRetry(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    if (method != 'POST' && method != 'PATCH' && method != 'DELETE') {
      return false;
    }

    if (!err.requestOptions.headers.containsKey('idempotency-key')) {
      return false;
    }

    final retryCount =
        (err.requestOptions.extra[RequestMetaKeys.retryCount] as int?) ?? 0;
    if (retryCount >= 2) return false;

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    final status = err.response?.statusCode;
    if (status == null || status == 401 || status == 409) return false;

    return status == 429 || status >= 500;
  }

  Duration _backoffDelay(int attempt) {
    final baseMs = switch (attempt) {
      1 => 350,
      2 => 800,
      _ => 1200,
    };
    final jitter = _random.nextInt(220);
    return Duration(milliseconds: baseMs + jitter);
  }

  Future<String?> _tryRefresh() async {
    final refreshToken = await _storage.read(key: TokenKeys.refreshToken);
    if (refreshToken == null) return null;
    final deviceName = await _resolveClientDeviceName();

    // Use _refreshDio (no AuthInterceptor attached) to avoid a deadlock:
    // if the main `dio` were used and the refresh token was expired/invalid,
    // the resulting 401 would re-enter this interceptor and hang forever.
    final res = await _refreshDio.post(
      ApiEndpoints.refresh,
      data: {
        'refreshToken': refreshToken,
      },
      options: Options(
        headers: {
          RequestHeaderKeys.deviceName: deviceName,
          RequestHeaderKeys.requestId: _generateRequestId(),
        },
      ),
    );

    final newAccess = res.data['data']['accessToken'] as String?;
    final newRefresh = res.data['data']['refreshToken'] as String?;
    if (newAccess == null) return null;

    await _storage.write(key: TokenKeys.accessToken, value: newAccess);
    if (newRefresh != null) {
      await _storage.write(key: TokenKeys.refreshToken, value: newRefresh);
    }
    return newAccess;
  }
}

// ── Logger interceptor ────────────────────────────────────────────────────────
class LoggerInterceptor extends Interceptor {
  static const _line =
      '─────────────────────────────────────────────────────────────';
  static const _redacted = '[REDACTED]';
  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };
  static const Set<String> _sensitivePayloadKeys = {
    'password',
    'newpassword',
    'oldpassword',
    'confirmpassword',
    'currentpassword',
    'token',
    'accesstoken',
    'refreshtoken',
    'otp',
    'otpcode',
    'code',
    'pin',
    'pinhash',
    'pinverifierhash',
    'pinsalt',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('┌$_line');
      debugPrint('│ 🌐 ${options.method} ${options.baseUrl}${options.path}');
      debugPrint('├$_line');

      if (options.headers.isNotEmpty) {
        debugPrint('│ 📋 Headers:');
        final safeHeaders = _sanitizeHeaders(options.headers);
        safeHeaders.forEach((k, v) => debugPrint('│   $k: $v'));
        debugPrint('├$_line');
      }

      if (options.queryParameters.isNotEmpty) {
        debugPrint('│ 🔍 Query:');
        final safeQuery = _sanitizePayload(options.queryParameters);
        if (safeQuery is Map) {
          safeQuery.forEach((k, v) => debugPrint('│   $k: $v'));
        } else {
          debugPrint('│   $safeQuery');
        }
        debugPrint('├$_line');
      }

      if (options.data != null) {
        debugPrint('│ 📤 Payload:');
        _printJson(_sanitizePayload(options.data));
        debugPrint('├$_line');
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final printBody = response.requestOptions.extra['printResponse'] ?? true;
      final requestId = _responseRequestId(response) ?? 'n/a';
      debugPrint('│ ✅ ${response.statusCode} '
          '${response.requestOptions.method} '
          '${response.requestOptions.path}');
      debugPrint('│ 🧵 requestId: $requestId');
      debugPrint('├$_line');
      if (printBody && response.data != null) {
        debugPrint('│ 📥 Response:');
        _printJson(_sanitizePayload(response.data));
      } else if (!printBody) {
        debugPrint('│ 📥 [logging disabled for this request]');
      }
      debugPrint('└$_line');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final requestId = _errorRequestId(err) ?? 'n/a';
      debugPrint('│ ❌ ERROR ${err.type.name} — '
          '${err.requestOptions.method} ${err.requestOptions.path}');
      debugPrint('│ 🧵 requestId: $requestId');
      debugPrint('├$_line');
      debugPrint('│ 💬 ${err.message}');
      if (err.response != null) {
        debugPrint('│ 📊 Status: ${err.response?.statusCode}');
        debugPrint('├$_line');
        if (err.response?.data != null) {
          debugPrint('│ 📥 Error body:');
          _printJson(_sanitizePayload(err.response!.data));
        }
      }
      debugPrint('└$_line');
    }
    super.onError(err, handler);
  }

  String? _responseRequestId(Response response) {
    final fromHeader = response.headers.value(RequestHeaderKeys.requestId);
    if (fromHeader != null && fromHeader.isNotEmpty) return fromHeader;

    final body = response.data;
    if (body is Map && body['requestId'] is String) {
      return body['requestId'] as String;
    }

    final fromRequest =
        response.requestOptions.headers[RequestHeaderKeys.requestId];
    if (fromRequest is String && fromRequest.isNotEmpty) return fromRequest;
    return null;
  }

  String? _errorRequestId(DioException err) {
    final fromHeader = err.response?.headers.value(RequestHeaderKeys.requestId);
    if (fromHeader != null && fromHeader.isNotEmpty) return fromHeader;

    final body = err.response?.data;
    if (body is Map && body['requestId'] is String) {
      return body['requestId'] as String;
    }

    final fromRequest = err.requestOptions.headers[RequestHeaderKeys.requestId];
    if (fromRequest is String && fromRequest.isNotEmpty) return fromRequest;
    return null;
  }

  void _printJson(dynamic data) {
    try {
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      pretty.split('\n').forEach((l) => debugPrint('│   $l'));
    } catch (_) {
      debugPrint('│   $data');
    }
  }

  Map<String, dynamic> _sanitizeHeaders(Map<String, dynamic> headers) {
    final safeHeaders = <String, dynamic>{};
    headers.forEach((key, value) {
      final normalized = key.toLowerCase();
      safeHeaders[key] =
          _sensitiveHeaders.contains(normalized) ? _redacted : value;
    });
    return safeHeaders;
  }

  dynamic _sanitizePayload(dynamic value) {
    if (value == null) return value;

    if (value is Map) {
      final sanitized = <String, dynamic>{};
      value.forEach((key, fieldValue) {
        final keyText = key.toString();
        final normalized = keyText.toLowerCase();
        if (_sensitivePayloadKeys.contains(normalized)) {
          sanitized[keyText] = _redacted;
        } else {
          sanitized[keyText] = _sanitizePayload(fieldValue);
        }
      });
      return sanitized;
    }

    if (value is List) {
      return value.map(_sanitizePayload).toList(growable: false);
    }

    return value;
  }
}
