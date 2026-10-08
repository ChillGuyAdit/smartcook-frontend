import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme_colors.dart';
import '../service/api_service.dart';
import '../service/otp_cooldown_service.dart';
import '../service/token_service.dart';

/// Three-step account deletion, mirroring the Kelilink flow:
///
///   1. explain what is being deleted,
///   2. type HAPUS to confirm intent,
///   3. enter the OTP mailed to the account's own address.
///
/// The OTP is what makes this safe: an unlocked or borrowed phone cannot
/// delete someone else's account.
class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _confirmController = TextEditingController();
  final _otpController = TextEditingController();

  static const _cooldownKey = 'delete_account_otp';

  bool _stepTwoDone = false;
  bool _sending = false;
  bool _deleting = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  String? _error;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadEmail();
    _initCooldown();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _confirmController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _loadEmail() async {
    final user = await TokenService.getUser();
    if (!mounted) return;
    setState(() => _email = user?['email']?.toString());
  }

  Future<void> _initCooldown() async {
    final left = await OtpCooldownService.getRemainingCooldown(_cooldownKey);
    if (!mounted || left <= 0) return;
    setState(() => _cooldownSeconds = left);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldownSeconds -= 1);
      if (_cooldownSeconds <= 0) {
        _cooldownTimer?.cancel();
        timer.cancel();
      }
    });
  }

  bool get _resendCooldown => _cooldownSeconds > 0;

  bool get _confirmMatches =>
      _confirmController.text.trim().toUpperCase() == 'HAPUS';

  Future<void> _sendOtp() async {
    if (_sending || _resendCooldown) return;
    setState(() {
      _sending = true;
      _error = null;
    });

    final res = await ApiService.post('/api/user/delete/send-otp');

    if (!mounted) return;
    setState(() => _sending = false);

    if (res.success) {
      final seconds = res.data is Map<String, dynamic>
          ? ((res.data as Map<String, dynamic>)['expires_in_seconds'] as num?)
              ?.toInt()
          : null;
      await OtpCooldownService.setCooldown(_cooldownKey, 60);
      if (seconds != null && seconds > 0) {
        await OtpCooldownService.setExpiry(_cooldownKey, seconds);
      }
      await _initCooldown();
      return;
    }

    if (mounted) setState(() => _error = res.message ?? context.s.sendOtpFailed);
  }

  Future<void> _confirmAndDelete() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      setState(() => _error = 'Masukkan 4 digit kode OTP');
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    final res = await ApiService.delete('/api/user', body: {'otp': otp});

    if (!mounted) return;
    if (res.success) {
      // Tokens are dead server-side; clear locally and let the caller log out.
      await TokenService.clearAll();
      Navigator.of(context).pop(true);
      return;
    }

    if (mounted) setState(() {
      _deleting = false;
      _error = res.message ?? context.s.codeWrongOrExpired;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = stringsFor(Localizations.localeOf(context));
    final palette = context.colors;

    return Scaffold(
      appBar: AppBar(title: Text(s.deleteAccount)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.s.deleteAccountWarning,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (!_stepTwoDone) ...[
            Text(
              s.deleteConfirmBody,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmController,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [UpperCaseFormatter()],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(hintText: s.deleteConfirmHint),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _confirmMatches
                  ? () async {
                      final stepOne = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(s.deleteConfirmTitle),
                          content: Text(s.deleteConfirmBody),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(s.cancel),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                s.otpTitle,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );
                      if (stepOne != true || !mounted) return;
                      setState(() {
                        _stepTwoDone = true;
                        _sending = true;
                      });
                      await _sendOtp();
                    }
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                s.deletePermanently,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ] else ...[
            Text(
              s.otpBody,
              style: TextStyle(
                color: palette.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (_email != null) ...[
              const SizedBox(height: 4),
              Text(
                _email!,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: s.otpFieldHint,
                counterText: '',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _deleting ? null : _confirmAndDelete,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _deleting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      s.deletePermanently,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _sending || _resendCooldown ? null : _sendOtp,
              child: Text(
                _sending
                    ? s.otpSending
                    : _resendCooldown
                        ? '${s.resendOtp} (${_cooldownSeconds}s)'
                        : s.resendOtp,
              ),
            ),
            if (_error != null && _otpController.text.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Uppercases input as it is typed, so `hapus` also satisfies the check.
class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
