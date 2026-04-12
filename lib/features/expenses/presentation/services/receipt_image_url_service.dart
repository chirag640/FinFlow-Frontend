import 'dart:convert';

import 'package:flutter/foundation.dart';

class ReceiptImageUrlService {
  static const _proxyPathPrefix = '/expenses/receipts/file/';

  static String? resolvePreferredUrl({
    String? receiptImageUrl,
    String? receiptStorageKey,
  }) {
    final direct = receiptImageUrl?.trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    return proxyUrlForStorageKey(receiptStorageKey);
  }

  static String? proxyUrlForStorageKey(String? receiptStorageKey) {
    final key = receiptStorageKey?.trim();
    if (key == null || key.isEmpty) return null;

    final encoded = base64UrlEncode(utf8.encode(key)).replaceAll('=', '');
    return '${_apiBaseUrl()}$_proxyPathPrefix$encoded';
  }

  static bool appearsSignedUrl(String? url) {
    if (url == null) return false;
    return url.contains('X-Amz-Signature=') ||
        url.contains('X-Amz-Algorithm=') ||
        url.contains('X-Amz-Expires=');
  }

  static bool isProxyReceiptUrl(String? url) {
    if (url == null) return false;
    return url.contains(_proxyPathPrefix);
  }

  static String _apiBaseUrl() {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl.replaceFirst(RegExp(r'/+$'), '');
    }

    if (kReleaseMode) {
      return 'https://finflow-backend-lunz.onrender.com/api/v1';
    }

    return 'http://10.0.2.2:3000/api/v1';
  }
}
