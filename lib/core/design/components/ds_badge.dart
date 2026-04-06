import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../../utils/responsive.dart';

enum DSBadgeVariant { primary, success, warning, error, neutral, info }

class DSBadge extends StatelessWidget {
  final String label;
  final DSBadgeVariant variant;
  final bool dot;

  const DSBadge({
    super.key,
    required this.label,
    this.variant = DSBadgeVariant.primary,
    this.dot = false,
  });

  Color get _bg => switch (variant) {
        DSBadgeVariant.primary => AppColors.primaryExtraLight,
        DSBadgeVariant.success => AppColors.successLight,
        DSBadgeVariant.warning => AppColors.warningLight,
        DSBadgeVariant.error => AppColors.errorLight,
        DSBadgeVariant.neutral => AppColors.surfaceVariant,
        DSBadgeVariant.info => AppColors.accentLight,
      };

  Color get _fg => switch (variant) {
        DSBadgeVariant.primary => AppColors.primaryDark,
        DSBadgeVariant.success => AppColors.successDark,
        DSBadgeVariant.warning => AppColors.warningDark,
        DSBadgeVariant.error => AppColors.errorDark,
        DSBadgeVariant.neutral => AppColors.textSecondary,
        DSBadgeVariant.info => AppColors.infoDark,
      };

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: R.sm, vertical: R.s(3)),
      decoration: BoxDecoration(color: _bg, borderRadius: AppRadius.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: R.s(6),
              height: R.s(6),
              decoration: BoxDecoration(color: _fg, shape: BoxShape.circle),
            ),
            SizedBox(width: R.s(5)),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: R.t(11),
              fontWeight: FontWeight.w600,
              color: _fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular count badge (e.g. notification count)
class DSCountBadge extends StatelessWidget {
  final int count;
  final Color? color;

  const DSCountBadge({super.key, required this.count, this.color});

  @override
  Widget build(BuildContext context) {
    R.init(context);
    if (count == 0) return const SizedBox.shrink();
    return Container(
      constraints: BoxConstraints(minWidth: R.s(18), minHeight: R.s(18)),
      padding: EdgeInsets.symmetric(horizontal: R.s(5)),
      decoration: BoxDecoration(
        color: color ?? AppColors.error,
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          fontSize: R.t(10),
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
