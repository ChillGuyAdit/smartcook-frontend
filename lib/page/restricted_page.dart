import 'package:flutter/material.dart';

import '../auth/signIn.dart';
import '../core/l10n/strings.dart';
import '../core/services/restriction.dart';
import '../service/token_service.dart';
import '../core/theme/app_theme_colors.dart';
import '../view/splashscreen.dart';

/// Full-screen notice for a blocked address or a suspended account. There is
/// nothing else to do on it, so the system back key is ignored.
class RestrictedPage extends StatelessWidget {
  const RestrictedPage({
    super.key,
    required this.code,
    required this.message,
    required this.reason,
  });

  final String code;
  final String message;
  final String reason;

  bool get _account => code == Restriction.accountCode;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
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
                      message.isEmpty
                          ? (_account
                              ? s.accountSuspendedBody
                              : s.accessBlockedBody)
                          : message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15,
                          height: 1.4,
                          color: context.colors.textSecondary),
                    ),
                    if (reason.trim().isNotEmpty) ...[
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
                          s.restrictionReason(reason.trim()),
                          style: TextStyle(
                              fontSize: 14, color: context.colors.textPrimary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final nav = Navigator.of(context);
                          if (_account) {
                            await TokenService.clearAll();
                            Restriction.clear();
                            nav.pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                  builder: (_) => const signin()),
                              (_) => false,
                            );
                          } else {
                            Restriction.clear();
                            nav.pushAndRemoveUntil(
                              MaterialPageRoute<void>(
                                  builder: (_) => const splashscreen()),
                              (_) => false,
                            );
                          }
                        },
                        child: Text(_account ? s.logout : s.updateRetry),
                      ),
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
