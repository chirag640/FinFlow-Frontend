import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';

class ReceiptUploadResult {
  final String receiptStorageKey;
  final String receiptImageUrl;
  final String? receiptImageMimeType;

  const ReceiptUploadResult({
    required this.receiptStorageKey,
    required this.receiptImageUrl,
    this.receiptImageMimeType,
  });
}

class ReceiptUploadService {
  static Future<ReceiptUploadResult> uploadReceipt({
    required Dio dio,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) async {
    final intentResponse = await dio.post(
      ApiEndpoints.expenseReceiptUploadIntent,
      data: {'mimeType': mimeType},
    );

    final intentData = _extractEnvelopeData(intentResponse.data);
    final receiptStorageKey = intentData['receiptStorageKey'] as String?;
    final expiresAt = intentData['expiresAt'] as String?;
    final signature = intentData['signature'] as String?;

    if (receiptStorageKey == null || expiresAt == null || signature == null) {
      throw StateError('Receipt upload intent response is missing fields');
    }

    final formData = FormData.fromMap({
      'receiptStorageKey': receiptStorageKey,
      'expiresAt': expiresAt,
      'signature': signature,
      'mimeType': mimeType,
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
    });

    final uploadResponse = await dio.post(
      ApiEndpoints.expenseReceiptUpload,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    final uploadData = _extractEnvelopeData(uploadResponse.data);
    final receiptImageUrl = uploadData['receiptImageUrl'] as String?;
    final uploadedStorageKey = uploadData['receiptStorageKey'] as String?;

    if (receiptImageUrl == null || uploadedStorageKey == null) {
      throw StateError('Receipt upload response is missing fields');
    }

    return ReceiptUploadResult(
      receiptStorageKey: uploadedStorageKey,
      receiptImageUrl: receiptImageUrl,
      receiptImageMimeType: uploadData['receiptImageMimeType'] as String?,
    );
  }

  static Map<String, dynamic> _extractEnvelopeData(dynamic payload) {
    if (payload is! Map) {
      throw StateError('Unexpected API response shape');
    }

    final root = payload.cast<String, dynamic>();
    final data = root['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return data.cast<String, dynamic>();
    }

    return root;
  }
}
