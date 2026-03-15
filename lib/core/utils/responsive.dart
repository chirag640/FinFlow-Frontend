import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// R — initialise-once responsive helper
//   Call R.init(context) as the very first line of every build() method.
//   Base design width: 390 px (iPhone 14 Pro).
// ─────────────────────────────────────────────────────────────────────────────
class R {
  R._();

  static late MediaQueryData _mq;
  static late double _width;
  static late double _height;
  static late double _scale;
  static late double _textScale;

  /// Must be called once at the top of the root widget's build().
  static void init(BuildContext context) {
    _mq = MediaQuery.of(context);
    _width = _mq.size.width;
    _height = _mq.size.height;
    _scale = _width / 390;
    _textScale = (_width / 390).clamp(0.85, 1.4);
  }

  // ── Raw dimensions ──────────────────────────────────────────────────────
  static double get screenW => _width;
  static double get screenH => _height;

  /// Percentage of screen width: w(50) = 50 % of width
  static double w(double percent) => _width * percent / 100;

  /// Percentage of screen height
  static double h(double percent) => _height * percent / 100;

  /// Scale a design-spec pixel value (designed at 390 px)
  static double s(double size) => size * _scale;

  /// Scale a font size (flatter curve — no ballooning on tablets)
  static double t(double size) => size * _textScale;

  // ── Named spacing tokens ────────────────────────────────────────────────
  static double get xs => s(4);
  static double get sm => s(8);
  static double get md => s(16);
  static double get lg => s(24);
  static double get xl => s(32);
  static double get xxl => s(48);

  // ── Breakpoints ─────────────────────────────────────────────────────────
  static bool get isPhone => _width < 600;
  static bool get isMobile => _width < 600;
  static bool get isTablet => _width >= 600 && _width < 900;
  static bool get isDesktop => _width >= 900;

  // ── Safe area ───────────────────────────────────────────────────────────
  static double get topPadding => _mq.padding.top;
  static double get bottomPadding => _mq.padding.bottom;
  static double get safeHeight =>
      _height - _mq.padding.top - _mq.padding.bottom;

  // ── Adaptive grid columns ───────────────────────────────────────────────
  static int get gridColumns {
    if (isDesktop) return 4;
    if (isTablet) return 3;
    return 2;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Responsive — legacy context-based helper (kept for backward compat)
// ─────────────────────────────────────────────────────────────────────────────
enum ScreenSize { mobile, tablet, desktop }

abstract class Responsive {
  static const double mobileBreakpoint = 480.0;
  static const double desktopBreakpoint = 1200.0;

  static ScreenSize of(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < mobileBreakpoint) return ScreenSize.mobile;
    if (w < desktopBreakpoint) return ScreenSize.tablet;
    return ScreenSize.desktop;
  }

  static bool isMobile(BuildContext context) =>
      of(context) == ScreenSize.mobile;
  static bool isTablet(BuildContext context) =>
      of(context) == ScreenSize.tablet;
  static bool isDesktop(BuildContext context) =>
      of(context) == ScreenSize.desktop;

  static T value<T>(
    BuildContext context, {
    required T mobile,
    required T tablet,
    required T desktop,
  }) =>
      switch (of(context)) {
        ScreenSize.mobile => mobile,
        ScreenSize.tablet => tablet,
        ScreenSize.desktop => desktop,
      };

  static double fluid(
    BuildContext context, {
    double min = 8,
    double max = 32,
    double minWidth = 320,
    double maxWidth = 1440,
  }) {
    final w = MediaQuery.of(context).size.width.clamp(minWidth, maxWidth);
    return min + (max - min) * ((w - minWidth) / (maxWidth - minWidth));
  }

  static int gridColumns(BuildContext context) =>
      value(context, mobile: 1, tablet: 2, desktop: 3);

  static double pagePaddingH(BuildContext context) =>
      fluid(context, min: 16, max: 40, minWidth: 320, maxWidth: 1200);
}
