import 'package:flutter/material.dart';
import '../utils/responsive.dart';

/// App-wide text styles — all font sizes go through R.t() so they scale with
/// screen width. Call R.init(context) before accessing any of these.
class AppText {
  AppText._();

  static TextStyle get displayLarge => TextStyle(
        fontSize: R.t(32),
        fontWeight: FontWeight.w800,
        height: 1.1,
      );

  static TextStyle get displayMedium => TextStyle(
        fontSize: R.t(26),
        fontWeight: FontWeight.w700,
        height: 1.2,
      );

  static TextStyle get headingLarge => TextStyle(
        fontSize: R.t(22),
        fontWeight: FontWeight.w700,
      );

  static TextStyle get headingMedium => TextStyle(
        fontSize: R.t(18),
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headingSmall => TextStyle(
        fontSize: R.t(16),
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => TextStyle(
        fontSize: R.t(16),
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodyMedium => TextStyle(
        fontSize: R.t(14),
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  static TextStyle get bodySmall => TextStyle(
        fontSize: R.t(12),
        fontWeight: FontWeight.w400,
      );

  static TextStyle get label => TextStyle(
        fontSize: R.t(11),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      );

  static TextStyle get caption => TextStyle(
        fontSize: R.t(10),
        fontWeight: FontWeight.w400,
      );

  // ── Convenience ────────────────────────────────────────────────────────
  /// Number display — large currency amounts, stat cards
  static TextStyle get numericLarge => TextStyle(
        fontSize: R.t(28),
        fontWeight: FontWeight.w800,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get numericMedium => TextStyle(
        fontSize: R.t(18),
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
