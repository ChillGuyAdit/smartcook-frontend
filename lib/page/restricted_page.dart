import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import '../auth/signIn.dart';
import '../core/l10n/strings.dart';
import '../core/services/app_update_checker.dart';
import '../core/services/restriction.dart';
import '../service/token_service.dart';
import '../core/theme/app_theme_colors.dart';
import '../view/splashscreen.dart';

/// "1 hari 02:03:04" / "1 day 02:03:04" / "00:04:09".
String formatRestrictionLeft(Str s, int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final d = total ~/ 86400;
  final h = (total % 86400) ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final sec = total % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  final clock = '${two(h)}:${two(m)}:${two(sec)}';
  return d > 0 ? '${s.restrictionDays(d)} $clock' : clock;
}

/// Full-screen notice for a blocked address or a suspended account.
///
/// It says why, for how long (a live countdown when the restriction ends by
/// itself), and what can still be done: a suspended account can sign out and
/// use another account; a blocked address cannot be dodged by switching
/// account, so that page says so. Updating the app always stays possible. The
/// system back key is ignored: there is nothing behind this screen.
class RestrictedPage extends StatefulWidget {
  const RestrictedPage({
    super.key,
    required this.code,
    required this.message,
    required this.reason,
    this.remainingSeconds,
  });

  final String code;
  final String message;
  final String reason;

  /// Seconds until the restriction ends by itself; null when it has no end.
  final int? remainingSeconds;

  @override
  State<RestrictedPage> createState() => _RestrictedPageState();
}

class _RestrictedPageState extends State<RestrictedPage> {
  Timer? _timer;
  int? _left;
  bool _leaving = false;

  bool get _account => widget.code == Restriction.accountCode;

  @override
  void initState() {
    super.initState();
    _left = widget.remainingSeconds;
    if (_left != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _left = (_left ?? 1) - 1);
        if ((_left ?? 1) <= 0) _retry();
      });
    }
    // An update (mandatory or not) must stay reachable from here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppUpdateChecker.recheck(() => mounted ? context : null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// The time is up (or the person asked): start over, the server decides.
  void _retry() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    Restriction.clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const splashscreen()),
      (_) => false,
    );
  }

  Future<void> _signOut() async {
    final nav = Navigator.of(context);
    await TokenService.clearAll();
    Restriction.clear();
    nav.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const signin()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final left = _left;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.block_rounded,
                          size: 44, color: Colors.redAccent),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _account ? s.accountSuspendedTitle : s.accessBlockedTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.message.isEmpty
                          ? (_account
                              ? s.accountSuspendedBody
                              : s.accessBlockedBody)
                          : widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: context.colors.textSecondary),
                    ),
                    if (widget.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: context.colors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.colors.border),
                        ),
                        child: Text(
                          s.restrictionReason(widget.reason.trim()),
                          style: TextStyle(
                              fontSize: 14, color: context.colors.textPrimary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Column(children: [
                        Text(
                          left == null
                              ? s.restrictionNoEnd
                              : s.restrictionLeftLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: context.colors.textSecondary),
                        ),
                        if (left != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            formatRestrictionLeft(s, left),
                            key: const Key('restriction-countdown'),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _account ? s.accountSwitchHint : s.ipSwitchHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: context.colors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _account ? _signOut : _retry,
                        child: Text(_account ? s.logout : s.updateRetry),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      icon:
                          const Icon(Icons.system_update_alt_rounded, size: 18),
                      label: Text(s.checkForUpdate),
                      onPressed: () => AppUpdateChecker.recheck(() => context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
