import '../utils/responsive.dart';
import 'package:flutter/material.dart';

/// Responsive border-radius tokens — all radii go through R.s() so they scale
/// with screen width. Call R.init(context) before accessing any of these.
class AppRadius {
  AppRadius._();

  // ── Standard radius tokens ────────────────────────────────────────────────
  static BorderRadius get xxs => BorderRadius.circular(R.s(2));
  static BorderRadius get tiny => BorderRadius.circular(R.s(3));
  static BorderRadius get xs => BorderRadius.circular(R.s(4));
  static BorderRadius get micro => BorderRadius.circular(R.s(6));
  static BorderRadius get sm => BorderRadius.circular(R.s(8));
  static BorderRadius get smPlus => BorderRadius.circular(R.s(10));
  static BorderRadius get md => BorderRadius.circular(R.s(12));
  static BorderRadius get mdPlus => BorderRadius.circular(R.s(14));
  static BorderRadius get lg => BorderRadius.circular(R.s(16));
  static BorderRadius get card => BorderRadius.circular(R.s(20));
  static BorderRadius get xl => BorderRadius.circular(R.s(24));
  static BorderRadius get full => BorderRadius.circular(R.s(999));

  // ── Raw double values ────────────────────────────────────────────────────
  static double get xxsValue => R.s(2);
  static double get tinyValue => R.s(3);
  static double get xsValue => R.s(4);
  static double get microValue => R.s(6);
  static double get smValue => R.s(8);
  static double get smPlusValue => R.s(10);
  static double get mdValue => R.s(12);
  static double get mdPlusValue => R.s(14);
  static double get lgValue => R.s(16);
  static double get cardValue => R.s(20);
  static double get xlValue => R.s(24);

  // ── Convenience for partial radius (e.g., only top corners) ──────────────
  static BorderRadius get xlTop => BorderRadius.only(
        topLeft: Radius.circular(R.s(24)),
        topRight: Radius.circular(R.s(24)),
      );
}
