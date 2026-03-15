import '../utils/responsive.dart';
import 'package:flutter/material.dart';

/// Responsive border-radius tokens — all radii go through R.s() so they scale
/// with screen width. Call R.init(context) before accessing any of these.
class AppRadius {
  AppRadius._();

  static BorderRadius get xs => BorderRadius.circular(R.s(4));
  static BorderRadius get sm => BorderRadius.circular(R.s(8));
  static BorderRadius get md => BorderRadius.circular(R.s(12));
  static BorderRadius get lg => BorderRadius.circular(R.s(16));
  static BorderRadius get xl => BorderRadius.circular(R.s(24));
  static BorderRadius get card => BorderRadius.circular(R.s(20));
  static BorderRadius get full => BorderRadius.circular(R.s(999));

  // ── Raw double values ────────────────────────────────────────────────────
  static double get xsValue => R.s(4);
  static double get smValue => R.s(8);
  static double get mdValue => R.s(12);
  static double get lgValue => R.s(16);
  static double get xlValue => R.s(24);
  static double get cardValue => R.s(20);
}
