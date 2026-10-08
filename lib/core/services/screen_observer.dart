import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dev_log.dart';

/// Records which screen the user is on, so a bug report can say "on
/// MasakanPage, 20 seconds after opening Kulkas" without asking anyone.
///
/// Most routes here are unnamed [MaterialPageRoute]s, so the name comes from
/// the widget type the route builds. Strictly diagnostic: any failure is
/// swallowed and navigation is never affected. No screen contents, form text
/// or arguments are read - only the page's class name.
class ScreenObserver extends NavigatorObserver {
  ScreenObserver({void Function(String screen)? onScreen})
      : _onScreen = onScreen ?? _toDevLog;

  final void Function(String screen) _onScreen;
  String? _last;

  static void _toDevLog(String screen) =>
      DevLog.log('screen_view', action: screen);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _record(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) _record(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null) _record(previousRoute);
  }

  void _record(Route<dynamic> route) {
    try {
      final name = nameOf(route);
      if (name == null || name == _last) return;
      _last = name;
      _onScreen(name);
    } catch (_) {
      // Diagnostics must never break navigation.
    }
  }

  @visibleForTesting
  String? nameOf(Route<dynamic> route) {
    final named = route.settings.name;
    if (named != null && named.isNotEmpty) return named;
    final ctx = navigator?.context;
    if (route is MaterialPageRoute && ctx != null) {
      // Builds the page widget object only (not mounted) to read its type.
      return route.builder(ctx).runtimeType.toString();
    }
    // Dialogs, bottom sheets and popups are not screens.
    return null;
  }
}
