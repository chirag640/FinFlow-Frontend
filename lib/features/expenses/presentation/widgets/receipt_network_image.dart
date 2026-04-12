import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../services/receipt_image_url_service.dart';

class ReceiptNetworkImage extends StatefulWidget {
  final String? receiptImageUrl;
  final String? receiptStorageKey;
  final double width;
  final double height;
  final BoxFit fit;

  const ReceiptNetworkImage({
    super.key,
    required this.receiptImageUrl,
    required this.receiptStorageKey,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  State<ReceiptNetworkImage> createState() => _ReceiptNetworkImageState();
}

class _ReceiptNetworkImageState extends State<ReceiptNetworkImage> {
  String? _activeUrl;
  bool _didProxyRetry = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = ReceiptImageUrlService.resolvePreferredUrl(
      receiptImageUrl: widget.receiptImageUrl,
      receiptStorageKey: widget.receiptStorageKey,
    );
  }

  @override
  void didUpdateWidget(covariant ReceiptNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptImageUrl != widget.receiptImageUrl ||
        oldWidget.receiptStorageKey != widget.receiptStorageKey) {
      _activeUrl = ReceiptImageUrlService.resolvePreferredUrl(
        receiptImageUrl: widget.receiptImageUrl,
        receiptStorageKey: widget.receiptStorageKey,
      );
      _didProxyRetry = false;
    }
  }

  void _retryWithProxyUrl() {
    if (_didProxyRetry) return;
    final current = _activeUrl;
    final proxyUrl =
        ReceiptImageUrlService.proxyUrlForStorageKey(widget.receiptStorageKey);
    if (proxyUrl == null || proxyUrl == current) return;

    _didProxyRetry = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _activeUrl = proxyUrl;
      });
    });
  }

  Widget _errorFallback() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.textTertiary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _activeUrl;
    if (url == null || url.isEmpty) {
      return _errorFallback();
    }

    return Image.network(
      url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) {
        final shouldRetryWithProxy = !_didProxyRetry &&
            widget.receiptStorageKey != null &&
            widget.receiptStorageKey!.trim().isNotEmpty &&
            (!ReceiptImageUrlService.isProxyReceiptUrl(url) ||
                ReceiptImageUrlService.appearsSignedUrl(url));

        if (shouldRetryWithProxy) {
          _retryWithProxyUrl();
          return Container(
            width: widget.width,
            height: widget.height,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        }

        return _errorFallback();
      },
    );
  }
}
