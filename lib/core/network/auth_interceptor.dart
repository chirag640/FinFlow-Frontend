import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
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
}

// ── Global Dio provider ──────────────────────────────────────────────────────
// ignore: unused_element — consumed via cloud_auth_provider.dart
final dioProvider = Provider<Dio>((ref) {
  const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://10.0.2.2:3000/api/v1');

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
    _attachRequestId(options);
    _attachIdempotencyKey(options);

    final token = await _storage.read(key: TokenKeys.accessToken);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
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
        path.startsWith('/investments') ||
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

    // Use _refreshDio (no AuthInterceptor attached) to avoid a deadlock:
    // if the main `dio` were used and the refresh token was expired/invalid,
    // the resulting 401 would re-enter this interceptor and hang forever.
    final res = await _refreshDio.post(ApiEndpoints.refresh, data: {
      'refreshToken': refreshToken,
    });

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

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      print('┌$_line');
      print('│ 🌐 ${options.method} ${options.baseUrl}${options.path}');
      print('├$_line');

      if (options.headers.isNotEmpty) {
        print('│ 📋 Headers:');
        options.headers.forEach((k, v) => print('│   $k: $v'));
        print('├$_line');
      }

      if (options.queryParameters.isNotEmpty) {
        print('│ 🔍 Query:');
        options.queryParameters.forEach((k, v) => print('│   $k: $v'));
        print('├$_line');
      }

      if (options.data != null) {
        print('│ 📤 Payload:');
        _printJson(options.data);
        print('├$_line');
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final printBody = response.requestOptions.extra['printResponse'] ?? true;
      final requestId = _responseRequestId(response) ?? 'n/a';
      print('│ ✅ ${response.statusCode} '
          '${response.requestOptions.method} '
          '${response.requestOptions.path}');
      print('│ 🧵 requestId: $requestId');
      print('├$_line');
      if (printBody && response.data != null) {
        print('│ 📥 Response:');
        _printJson(response.data);
      } else if (!printBody) {
        print('│ 📥 [logging disabled for this request]');
      }
      print('└$_line');
    }
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final requestId = _errorRequestId(err) ?? 'n/a';
      print('│ ❌ ERROR ${err.type.name} — '
          '${err.requestOptions.method} ${err.requestOptions.path}');
      print('│ 🧵 requestId: $requestId');
      print('├$_line');
      print('│ 💬 ${err.message}');
      if (err.response != null) {
        print('│ 📊 Status: ${err.response?.statusCode}');
        print('├$_line');
        if (err.response?.data != null) {
          print('│ 📥 Error body:');
          _printJson(err.response!.data);
        }
      }
      print('└$_line');
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
      pretty.split('\n').forEach((l) => print('│   $l'));
    } catch (_) {
      print('│   $data');
    }
  }
}
