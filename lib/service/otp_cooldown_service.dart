import 'package:shared_preferences/shared_preferences.dart';

class OtpCooldownService {
  static const _cooldownPrefix = 'otp_cooldown_';
  static const _expiryPrefix = 'otp_expiry_';

  /// Simpan cooldown (dalam detik) untuk key tertentu.
  /// Contoh key: 'forgot:test@gmail.com', 'login:test@gmail.com'
  static Future<void> setCooldown(String key, int seconds) async {
    if (seconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final nextSendAt =
        DateTime.now().millisecondsSinceEpoch + seconds * 1000;
    await prefs.setInt('$_cooldownPrefix$key', nextSendAt);
  }

  /// Ambil sisa cooldown dalam detik. Jika sudah lewat, mengembalikan 0.
  static Future<int> getRemainingCooldown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final nextSendAt = prefs.getInt('$_cooldownPrefix$key');
    if (nextSendAt == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = nextSendAt - now;
    if (diff <= 0) {
      await prefs.remove('$_cooldownPrefix$key');
      return 0;
    }
    return (diff / 1000).ceil();
  }

  /// Simpan expiry OTP (dalam detik dari sekarang) untuk key tertentu.
  static Future<void> setExpiry(String key, int seconds) async {
    if (seconds <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final expiresAt =
        DateTime.now().millisecondsSinceEpoch + seconds * 1000;
    await prefs.setInt('$_expiryPrefix$key', expiresAt);
  }

  /// Ambil sisa masa berlaku OTP (detik). Jika sudah lewat, mengembalikan 0.
  static Future<int> getRemainingExpiry(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final expiresAt = prefs.getInt('$_expiryPrefix$key');
    if (expiresAt == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = expiresAt - now;
    if (diff <= 0) {
      await prefs.remove('$_expiryPrefix$key');
      return 0;
    }
    return (diff / 1000).ceil();
  }

  /// Helper format detik menjadi string MM:SS
  static String formatSeconds(int seconds) {
    if (seconds <= 0) return '00:00';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

