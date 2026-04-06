import 'package:flutter/material.dart';

import '../../utils/responsive.dart';
import '../app_colors.dart';
import 'ds_empty_state.dart';

enum DSAsyncStateKind { loading, error, empty }

/// Unified async feedback component for loading, error, and empty states.
///
/// Use [compact] inside forms/dialogs, and full mode for page-level states.
class DSAsyncState extends StatelessWidget {
  final DSAsyncStateKind kind;
  final String title;
  final String? message;
  final bool compact;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? emoji;

  const DSAsyncState.loading({
    super.key,
    this.title = 'Loading...',
    this.message,
    this.compact = false,
  })  : kind = DSAsyncStateKind.loading,
        onRetry = null,
        actionLabel = null,
        onAction = null,
        emoji = null;

  const DSAsyncState.error({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.compact = false,
    this.onRetry,
  })  : kind = DSAsyncStateKind.error,
        actionLabel = null,
        onAction = null,
        emoji = null;

  const DSAsyncState.empty({
    super.key,
    this.title = 'No data available',
    this.message,
    this.compact = false,
    this.actionLabel,
    this.onAction,
    this.emoji,
  })  : kind = DSAsyncStateKind.empty,
        onRetry = null;

  @override
  Widget build(BuildContext context) {
    R.init(context);

    if (compact) {
      return _CompactAsyncState(
        kind: kind,
        title: title,
        message: message,
        onRetry: onRetry,
      );
    }

    switch (kind) {
      case DSAsyncStateKind.loading:
        return Center(
          child: Padding(
            padding: EdgeInsets.all(R.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: R.s(22),
                  height: R.s(22),
                  child: const CircularProgressIndicator(strokeWidth: 2.2),
                ),
                SizedBox(height: R.sm),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: R.t(14),
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  SizedBox(height: R.xs),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: R.t(12),
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      case DSAsyncStateKind.error:
        return DSEmptyState(
          emoji: '⚠️',
          title: title,
          subtitle: message ?? 'Please try again.',
          actionLabel: onRetry != null ? 'Retry' : null,
          onAction: onRetry,
        );
      case DSAsyncStateKind.empty:
        return DSEmptyState(
          emoji: emoji ?? '📭',
          title: title,
          subtitle: message ?? 'Nothing to show yet.',
          actionLabel: actionLabel,
          onAction: onAction,
        );
    }
  }
}

class _CompactAsyncState extends StatelessWidget {
  final DSAsyncStateKind kind;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  const _CompactAsyncState({
    required this.kind,
    required this.title,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;

    final icon = switch (kind) {
      DSAsyncStateKind.loading => null,
      DSAsyncStateKind.error => Icons.error_outline_rounded,
      DSAsyncStateKind.empty => Icons.inbox_outlined,
    };

    final fg = switch (kind) {
      DSAsyncStateKind.loading => colors.primary,
      DSAsyncStateKind.error => colors.error,
      DSAsyncStateKind.empty => colors.onSurfaceVariant,
    };

    final bg = switch (kind) {
      DSAsyncStateKind.loading => colors.primary.withValues(alpha: 0.08),
      DSAsyncStateKind.error => colors.errorContainer,
      DSAsyncStateKind.empty => colors.surfaceContainerHighest,
    };

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: R.md, vertical: R.sm),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(R.s(12)),
        border: Border.all(
          color: kind == DSAsyncStateKind.error
              ? colors.error.withValues(alpha: 0.22)
              : colors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kind == DSAsyncStateKind.loading)
            SizedBox(
              width: R.s(16),
              height: R.s(16),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          else
            Icon(icon, size: R.s(16), color: fg),
          SizedBox(width: R.s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: R.t(12),
                    fontWeight: FontWeight.w700,
                    color:
                        kind == DSAsyncStateKind.empty ? colors.onSurface : fg,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  SizedBox(height: R.xs),
                  Text(
                    message!,
                    style: TextStyle(
                      fontSize: R.t(12),
                      color: kind == DSAsyncStateKind.error
                          ? colors.onErrorContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (kind == DSAsyncStateKind.error && onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: EdgeInsets.symmetric(horizontal: R.xs),
              ),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}
