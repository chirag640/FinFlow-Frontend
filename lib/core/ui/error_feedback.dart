import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design/app_colors.dart';

void _showSnackBar(
  BuildContext context,
  String message, {
  required Color backgroundColor,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
}

void showErrorSnackBar(BuildContext context, String message) {
  _showSnackBar(
    context,
    message,
    backgroundColor: AppColors.error,
  );
}

void showSuccessSnackBar(BuildContext context, String message) {
  _showSnackBar(
    context,
    message,
    backgroundColor: AppColors.success,
  );
}

void showInfoSnackBar(BuildContext context, String message) {
  _showSnackBar(
    context,
    message,
    backgroundColor: AppColors.textSecondary,
  );
}

void listenForProviderError<T>({
  required WidgetRef ref,
  required BuildContext context,
  required ProviderListenable<T> provider,
  required String? Function(T state) errorSelector,
  VoidCallback? onErrorShown,
}) {
  ref.listen<T>(provider, (prev, next) {
    final message = errorSelector(next);
    final previous = prev == null ? null : errorSelector(prev);
    if (message == null || message == previous) return;
    onErrorShown?.call();
    showErrorSnackBar(context, message);
  });
}

void listenForProviderSuccess<T>({
  required WidgetRef ref,
  required BuildContext context,
  required ProviderListenable<T> provider,
  required String? Function(T state) successSelector,
  VoidCallback? onSuccessShown,
}) {
  ref.listen<T>(provider, (prev, next) {
    final message = successSelector(next);
    final previous = prev == null ? null : successSelector(prev);
    if (message == null || message == previous) return;
    onSuccessShown?.call();
    showSuccessSnackBar(context, message);
  });
}
