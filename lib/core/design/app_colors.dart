import 'package:flutter/material.dart';

abstract class AppColors {
  // ── Primary — Deep Indigo ──────────────────────────────────────────────────
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF6366F1);
  static const Color primaryExtraLight = Color(0xFFEEF2FF);
  static const Color primaryDark = Color(0xFF3730A3);

  // ── Accent — Cyan ──────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF06B6D4);
  static const Color accentLight = Color(0xFFCFFAFE);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color successDark = Color(0xFF065F46);
  
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);
  
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFF991B1B);
  
  static const Color info = Color(0xFF06B6D4);
  static const Color infoLight = Color(0xFFCFFAFE);
  static const Color infoDark = Color(0xFF0E7490);
  
  static const Color income = Color(0xFF10B981);
  static const Color incomeLight = Color(0xFFD1FAE5);
  static const Color expense = Color(0xFFEF4444);

  // ── Gradients ──────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient errorGradient = LinearGradient(
    colors: [error, Color(0xFFF87171)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF22D3EE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Light Mode Neutrals ────────────────────────────────────────────────────
  static const Color background = Color(0xFFF8F9FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFFCBD5E1);

  // ── Light Mode Text ────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary = Color(0xFF94A3B8);
  static const Color textDisabled = Color(0xFFCBD5E1);

  // ── Dark Mode ──────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceVariant = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF334155);

  // ── Category Colors ────────────────────────────────────────────────────────
  static const Color catFood = Color(0xFFF59E0B);
  static const Color catTransport = Color(0xFF3B82F6);
  static const Color catShopping = Color(0xFFEC4899);
  static const Color catEntertainment = Color(0xFF8B5CF6);
  static const Color catBills = Color(0xFFEF4444);
  static const Color catHealth = Color(0xFF10B981);
  static const Color catEducation = Color(0xFF6366F1);
  static const Color catTravel = Color(0xFFF97316);
  static const Color catGroceries = Color(0xFF22C55E);
  static const Color catRent = Color(0xFF64748B);
  static const Color catSubscriptions = Color(0xFFA855F7);
  static const Color catOther = Color(0xFF94A3B8);
}
