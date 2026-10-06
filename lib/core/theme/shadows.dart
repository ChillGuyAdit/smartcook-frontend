import 'package:flutter/material.dart';

import 'app_theme_colors.dart';

/// Shared shadow helpers.
///
/// The previous code used `Colors.black.withOpacity(0.05)` inline in dozens
/// of places, which reads badly on a dark background. These scale with the
/// theme instead, so a card keeps the same perceived elevation in both modes.
extension AppShadows on BuildContext {
  AppThemeColors get _palette =>
      Theme.of(this).extension<AppThemeColors>()!;

  List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: _palette.shadow,
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  List<BoxShadow> get softShadow => [
        BoxShadow(
          color: _palette.shadow,
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];

  List<BoxShadow> get floatShadow => [
        BoxShadow(
          color: _palette.shadow,
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];
}
