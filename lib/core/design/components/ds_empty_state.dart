import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../utils/responsive.dart';
import '../app_colors.dart';

class DSEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DSEmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: R.s(40), vertical: R.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: R.t(64))).animate().scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 500.ms,
                  curve: Curves.elasticOut,
                ),
            SizedBox(height: R.s(20)),
            Text(
              title,
              style: TextStyle(
                fontSize: R.t(18),
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            )
                .animate(delay: 100.ms)
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.2, end: 0, duration: 400.ms),
            SizedBox(height: R.sm),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: R.t(14),
                fontWeight: FontWeight.w400,
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate(delay: 150.ms).fadeIn(duration: 400.ms),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: R.lg),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(Icons.add, size: R.s(18)),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: R.lg,
                    vertical: R.sm + R.xs,
                  ),
                  shape: const StadiumBorder(),
                ),
              )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}

class DSErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const DSErrorState({
    super.key,
    this.message = 'Something went wrong',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(R.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('😕', style: TextStyle(fontSize: R.t(56))),
            SizedBox(height: R.md),
            Text(
              message,
              style: TextStyle(
                fontSize: R.t(16),
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              SizedBox(height: R.s(20)),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh, size: R.s(16)),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
