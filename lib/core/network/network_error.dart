import 'package:dio/dio.dart';

const _requestIdHeader = 'x-request-id';

String? extractRequestId(DioException e) {
  final fromHeader = e.response?.headers.value(_requestIdHeader);
  if (fromHeader != null && fromHeader.isNotEmpty) return fromHeader;

  final body = e.response?.data;
  if (body is Map && body['requestId'] is String) {
    return body['requestId'] as String;
  }

  final fromRequest = e.requestOptions.headers[_requestIdHeader];
  if (fromRequest is String && fromRequest.isNotEmpty) return fromRequest;
  return null;
}

String formatDioError(
  DioException e, {
  String fallback = 'Something went wrong',
  bool includeReference = true,
}) {
  final msg = e.response?.data?['message'];
  final base = msg is List
      ? msg.join(', ')
      : (msg is String ? msg : (e.message ?? fallback));

  if (!includeReference) return base;

  final requestId = extractRequestId(e);
  if (requestId == null || requestId.isEmpty) return base;
  return '$base (Ref: $requestId)';
}
