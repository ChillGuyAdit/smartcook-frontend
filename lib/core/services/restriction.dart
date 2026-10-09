/// Where the app learns that this address or account may not use the service.
///
/// The network layers (API client, session handshake) call [report]; the app
/// root registers [handler] and shows one full-screen notice. Reported once
/// per kind until [clear] (so a burst of failing requests shows one screen).
class Restriction {
  Restriction._();

  static const String ipCode = 'IP_BLOCKED';
  static const String accountCode = 'ACCOUNT_SUSPENDED';

  static void Function(
      String code, String message, String reason, int? remainingSeconds)? handler;
  static String? _shown;

  static bool isRestriction(String? code) =>
      code == ipCode || code == accountCode;

  /// [remainingSeconds] is how long the restriction still lasts (null: no end).
  static void report(String code, String message, String reason,
      [int? remainingSeconds]) {
    if (!isRestriction(code) || _shown == code) return;
    _shown = code;
    handler?.call(code, message, reason, remainingSeconds);
  }

  static void clear() => _shown = null;
}
