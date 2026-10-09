import 'package:flutter/material.dart';

import '../core/theme/app_theme_colors.dart';
import 'ops_api.dart';
import 'ops_shell.dart';
import 'ops_widgets.dart';

/// Asks the server once whether this account has extra rights, and offers the
/// choice. For everybody else the answer is empty and nothing at all is shown.
class OpsAccess {
  OpsAccess._();

  /// Replaceable in tests.
  static OpsApi api = const HttpOpsApi();

  static OpsMe? _me;
  static bool _offered = false;

  static OpsMe? get current => _me;

  static Future<OpsMe?> check() async {
    try {
      _me = await api.me();
    } catch (_) {
      _me = null;
    }
    return _me;
  }

  /// Forget everything (sign-out): the next sign-in asks again.
  static void reset() {
    _me = null;
    _offered = false;
  }

  /// Called when the home screen appears. Shows the pop-up at most once per
  /// sign-in, and only to accounts the server says have rights.
  static Future<void> offer(BuildContext context) async {
    if (_offered) return;
    final me = await check();
    if (me == null || !context.mounted) return;
    _offered = true;
    final choice = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t('Masuk sebagai', 'Continue as')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _Choice(
              icon: Icons.space_dashboard_outlined,
              title: t('Konsol', 'Console'),
              sub: t('Pantau layanan', 'Monitor the service'),
              onTap: () => Navigator.pop(c, true)),
          const SizedBox(height: 10),
          _Choice(
              icon: Icons.restaurant_menu,
              title: t('SmartCook biasa', 'SmartCook as usual'),
              sub: t('Pakai aplikasi seperti biasa', 'Use the app normally'),
              onTap: () => Navigator.pop(c, false)),
        ]),
      ),
    );
    if (choice == true && context.mounted) open(context, me);
  }

  static void open(BuildContext context, OpsMe me) {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => OpsShell(api: api, me: me)));
  }
}

class _Choice extends StatelessWidget {
  const _Choice(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.onTap});
  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              border: Border.all(color: context.colors.border),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(icon, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(sub,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: context.colors.textSecondary)),
                  ]),
            ),
          ]),
        ),
      );
}
