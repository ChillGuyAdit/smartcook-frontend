import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App language.
///
/// Indonesian and English are both hand-written (see `l10n/`), so nothing a
/// user reads about deleting an account or an OTP code is machine-guessed.
/// Other locales can be added later; anything not listed falls back to
/// Indonesian rather than showing an English string to an Indonesian user.
class LanguageController extends ChangeNotifier {
  LanguageController._();

  static final LanguageController instance = LanguageController._();

  static const supportedLocales = [Locale('id'), Locale('en')];

  static const _kLocale = 'smartcook_locale';

  Locale _locale = const Locale('id');
  Locale get locale => _locale;

  /// True when the device language is one we ship a full translation for.
  bool get isIndonesian => _locale.languageCode == 'id';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kLocale);
    if (stored != null && stored.isNotEmpty) {
      _locale = Locale(stored);
      notifyListeners();
      return;
    }
    // First launch: follow the phone, but only into a language we actually
    // have; everything else starts in Indonesian.
    final device = PlatformDispatcher.instance.locale.languageCode;
    _locale = supportedLocales.any((l) => l.languageCode == device)
        ? Locale(device)
        : const Locale('id');
    notifyListeners();
  }

  Future<void> set(Locale locale) async {
    if (_locale.languageCode == locale.languageCode) return;
    // Persist before notifying. notifyListeners() rebuilds MaterialApp, which
    // recreates the whole navigator tree; if it happened first and the write
    // failed, the in-memory language and the stored one would disagree and the
    // app could come back in the wrong language after a restart.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocale, locale.languageCode);
    _locale = locale;
    debugPrint('[lang] switched to ${locale.languageCode}');
    notifyListeners();
  }

  Future<void> toggle() =>
      set(Locale(isIndonesian ? 'en' : 'id'));
}
