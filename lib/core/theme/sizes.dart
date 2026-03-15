import '../utils/responsive.dart';

/// Responsive size tokens for icons, avatars, buttons, inputs, etc.
/// All values go through R.s() so they scale with screen width.
/// Call R.init(context) before accessing any of these.
class AppSize {
  AppSize._();

  // ── Icons ────────────────────────────────────────────────────────────────
  static double get iconXS => R.s(14);
  static double get iconSM => R.s(16);
  static double get iconMD => R.s(20);
  static double get iconLG => R.s(24);
  static double get iconXL => R.s(32);

  // ── Avatars ──────────────────────────────────────────────────────────────
  static double get avatarXS => R.s(24);
  static double get avatarSM => R.s(32);
  static double get avatarMD => R.s(44);
  static double get avatarLG => R.s(64);
  static double get avatarXL => R.s(96);

  // ── Buttons ──────────────────────────────────────────────────────────────
  static double get buttonHeight => R.s(52);
  static double get buttonHeightSM => R.s(40);
  static double get buttonHeightXS => R.s(32);

  // ── Input fields ─────────────────────────────────────────────────────────
  static double get inputHeight => R.s(56);

  // ── Navigation ───────────────────────────────────────────────────────────
  static double get bottomNavHeight => R.s(64) + R.bottomPadding;
  static double get appBarHeight => R.s(56);

  // ── Cards ────────────────────────────────────────────────────────────────
  static double get cardMinHeight => R.s(80);

  // ── Misc ─────────────────────────────────────────────────────────────────
  static double get dividerThickness => R.s(1);
  static double get borderWidth => R.s(1.5);
  static double get focusBorderWidth => R.s(2);
}
