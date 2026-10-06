import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme_colors.dart';

/// Backwards-compatible colour helper.
///
/// Historically every page did `AppColor().utama` / `AppColor().abuabu`, and
/// those values were literal `Color(0xFF...)`. Now that dark mode exists, the
/// same members resolve against the active palette while keeping the
/// light-mode appearance identical to v1.0.4.
@Deprecated(
  'Use AppColors (static tokens) or context.colors (theme-reactive) instead.',
)
class AppColor {
  final BuildContext? context;

  /// Pass a context to get theme-aware values; omit it for the legacy
  /// light-only palette.
  AppColor([this.context]);

  AppThemeColors get _p {
    final ctx = context;
    if (ctx == null) return AppThemeColors.light;
    return Theme.of(ctx).extension<AppThemeColors>() ?? AppThemeColors.light;
  }

  Color get utama => AppColors.primary;

  Color get warnaIcon => AppColors.primaryLight;

  Color get hijauPucat => AppColors.surfaceVariant;

  Color get iconGenCewe => AppColors.error;

  Color get warnaIcon2 => AppColors.accent;

  Color get IconGenCowo => AppColors.info;

  Color get hintTextColor => _p.textDisabled;

  Color get abuabuAgaGelap => _p.textPrimary;

  Color get putih => _p.surface;

  Color get abuabu => _p.surfaceVariant;

  Color get KuningCerah => AppColors.warning;

  Color get fontEquipColor => AppColors.primaryDark;
}

/// Shortcut so pages can write `context.palette`.
extension AppColorContext on BuildContext {
  AppThemeColors get palette =>
      Theme.of(this).extension<AppThemeColors>() ?? AppThemeColors.light;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
