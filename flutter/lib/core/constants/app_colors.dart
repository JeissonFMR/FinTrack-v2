import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Semantic colors — same in both themes
  static const primary = Color(0xFF18181B);
  static const income = Color(0xFF16A34A);
  static const incomeLight = Color(0xFFDCFCE7);
  static const expense = Color(0xFFDC2626);
  static const expenseLight = Color(0xFFFEE2E2);

  // Light theme structural colors (kept for ThemeData const references)
  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE4E4E7);
  static const textPrimary = Color(0xFF18181B);
  static const textSecondary = Color(0xFF71717A);
  static const textHint = Color(0xFFA1A1AA);
  static const primaryLight = Color(0xFFF4F4F5);
  static const divider = Color(0xFFF4F4F5);
}

class ThemeColors {
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textHint;
  final Color primaryLight;
  final Color divider;

  const ThemeColors._({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textHint,
    required this.primaryLight,
    required this.divider,
  });

  static const light = ThemeColors._(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    surfaceVariant: Color(0xFFF4F4F5),
    border: Color(0xFFE4E4E7),
    textPrimary: Color(0xFF18181B),
    textSecondary: Color(0xFF71717A),
    textHint: Color(0xFFA1A1AA),
    primaryLight: Color(0xFFF4F4F5),
    divider: Color(0xFFF4F4F5),
  );

  static const dark = ThemeColors._(
    background: Color(0xFF09090B),
    surface: Color(0xFF18181B),
    surfaceVariant: Color(0xFF27272A),
    border: Color(0xFF3F3F46),
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textHint: Color(0xFF71717A),
    primaryLight: Color(0xFF27272A),
    divider: Color(0xFF27272A),
  );
}

extension ThemeColorsX on BuildContext {
  ThemeColors get colors =>
      Theme.of(this).brightness == Brightness.dark ? ThemeColors.dark : ThemeColors.light;
}
