import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Android Keystore / iOS Keychain backed storage for the app session tokens.
///
/// The previous implementation kept the JWT in `SharedPreferences`, which is
/// plain XML on disk and readable from a rooted device or an `adb backup`.
/// These two tokens are what authorise every API call, so they move to the
/// platform keystore.
class SecureStore {
  SecureStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // Distinct keys so a bug in one path cannot clobber the other.
  static const _kAccess = 'smartcook_app_access';
  static const _kRefresh = 'smartcook_app_refresh';
  static const _kAccessExpiry = 'smartcook_app_access_expiry';

  static Future<void> writeSession({
    required String access,
    required String refresh,
    required DateTime accessExpiresAt,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    await _storage.write(
      key: _kAccessExpiry,
      value: accessExpiresAt.toIso8601String(),
    );
  }

  static Future<String?> readAccess() => _storage.read(key: _kAccess);

  static Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  static Future<DateTime?> readAccessExpiry() async {
    final raw = await _storage.read(key: _kAccessExpiry);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kAccessExpiry);
  }

  /// Test seam: lets the app assert keystore availability before boot rather
  /// than failing on the first API call.
  static Future<bool> isAvailable() async {
    try {
      await _storage.write(key: '__probe', value: '1');
      await _storage.delete(key: '__probe');
      return true;
    } catch (_) {
      return false;
    }
  }
}
