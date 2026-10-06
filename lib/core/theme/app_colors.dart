import 'package:flutter/material.dart';

/// SmartCook palette.
///
/// The brand green is the one already shipped (0xFF4CAF50) so the redesign
/// does not change how the app looks in light mode. Dark values are chosen
/// so text stays readable on dark surfaces without a separate accent brand.
abstract class AppColors {
  // Brand
  static const Color primary = Color(0xFF4CAF50);
  static const Color primaryDark = Color(0xFF2E7D32);
  static const Color primaryLight = Color(0xFF81C784);
  static const Color accent = Color(0xFFFFB300);

  // Semantic
  static const Color success = Color(0xFF2E7D32);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFF57C00);
  static const Color info = Color(0xFF0288D1);

  // Light surfaces
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F1);

  // Light text
  static const Color textPrimary = Color(0xFF1F2933);
  static const Color textSecondary = Color(0xFF5B6570);
  static const Color textDisabled = Color(0xFFB6BEC6);

  // Light lines
  static const Color border = Color(0xFFE2E6EA);
  static const Color divider = Color(0xFFEDF0F2);

  // Dark surfaces
  static const Color backgroundDark = Color(0xFF12161A);
  static const Color surfaceDark = Color(0xFF1A2026);
  static const Color surfaceVariantDark = Color(0xFF252D34);

  // Dark text
  static const Color textPrimaryDark = Color(0xFFF2F5F7);
  static const Color textSecondaryDark = Color(0xFFA8B2BB);
  static const Color textDisabledDark = Color(0xFF6B757E);

  // Dark lines
  static const Color borderDark = Color(0xFF2C343B);
  static const Color dividerDark = Color(0xFF232A30);
}
