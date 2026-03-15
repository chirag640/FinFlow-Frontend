import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// Responsive spacing tokens — all values derive from R.s() so they scale
/// with screen width. Call R.init(context) before accessing any of these.
class AppSpacing {
  AppSpacing._();

  // ── EdgeInsets presets ──────────────────────────────────────────────────
  static EdgeInsets get screenPadding =>
      EdgeInsets.symmetric(horizontal: R.md, vertical: R.sm);

  static EdgeInsets get cardPadding => EdgeInsets.all(R.md);

  static EdgeInsets get listTilePadding =>
      EdgeInsets.symmetric(horizontal: R.md, vertical: R.sm);

  static EdgeInsets get sectionPadding => EdgeInsets.only(bottom: R.lg);

  static EdgeInsets get buttonPadding =>
      EdgeInsets.symmetric(horizontal: R.lg, vertical: R.sm);

  // ── Vertical gap widgets (use in Column children) ───────────────────────
  static SizedBox get gapXS => SizedBox(height: R.xs);
  static SizedBox get gapSM => SizedBox(height: R.sm);
  static SizedBox get gapMD => SizedBox(height: R.md);
  static SizedBox get gapLG => SizedBox(height: R.lg);
  static SizedBox get gapXL => SizedBox(height: R.xl);
  static SizedBox get gapXXL => SizedBox(height: R.xxl);

  // ── Horizontal gap widgets (use in Row children) ────────────────────────
  static SizedBox get hGapXS => SizedBox(width: R.xs);
  static SizedBox get hGapSM => SizedBox(width: R.sm);
  static SizedBox get hGapMD => SizedBox(width: R.md);
  static SizedBox get hGapLG => SizedBox(width: R.lg);
  static SizedBox get hGapXL => SizedBox(width: R.xl);

  // ── Raw values (when you need the double, not a widget) ─────────────────
  static double get xs => R.xs;
  static double get sm => R.sm;
  static double get md => R.md;
  static double get lg => R.lg;
  static double get xl => R.xl;
  static double get xxl => R.xxl;
}
