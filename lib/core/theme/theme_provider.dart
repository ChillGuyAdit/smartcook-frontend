import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Live app-wide theme mode.
///
/// Defaults to following the OS until the stored preference loads, so a
/// cold start never flashes the wrong theme.
class ThemeProvider extends ChangeNotifier {
  ThemeProvider._();

  static final ThemeProvider instance = ThemeProvider._();

  static const _kThemeMode = 'smartcook_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeMode);
    _mode = _fromStorage(stored);
    notifyListeners();
  }

  Future<void> set(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeMode, _toStorage(mode));
  }

  /// Follows the device again, e.g. after the user installs on a new phone.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kThemeMode);
    _mode = ThemeMode.system;
    notifyListeners();
  }

  static ThemeMode _fromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
