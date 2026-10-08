import 'secure_channel.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import 'app_update_fetcher.dart';
import 'secure_storage.dart';

/// Why a session could not be established. The UI maps these to messages.
enum SessionFailure {
  /// The APK certificate does not match the release cert. Either a repackaged
  /// build or a debug build: it must never receive a token.
  notOfficial,

  /// The server is unreachable or slow.
  network,

  /// The server answered, but not in a shape we understand.
  malformed,

  /// Device keystore is unusable.
  secureStorage,
}

/// Owns the app-level (not user-level) access token.
///
/// The static `x-api-key` this replaces shipped inside the APK, so anyone who
/// unpacked it could replay it forever. A token now only exists after a
/// release-signed app proves itself with its APK certificate.
///
/// Lifecycle:
///   handshake (cert) -> access 24 h + refresh 7 d
///   access expires   -> refresh once, old pair retired (single-use)
///   refresh expires  -> handshake again
class AppSession {
  AppSession._();

  static final AppSession instance = AppSession._();

  static const Duration _expiryLeeway = Duration(minutes: 5);

  String? _access;
  String? _refresh;
  DateTime? _accessExpiresAt;

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      // Accept 4xx as a normal outcome instead of throwing. The handshake
      // distinguishes "this APK is not official" (403 FORBIDDEN_CLIENT) from
      // a genuine network fault, and it can only read that code from the
      // body - which Dio discards when it throws on the status code. Without
      // this, a rejected build was reported as a network error and the app
      // silently retried forever, showing nothing to the user.
      validateStatus: (status) => status != null && status < 500,
    ),
  )..interceptors.add(SecureDioInterceptor());

  /// Serialises concurrent callers so a burst of requests at boot produces
  /// one handshake, not ten.
  Future<void>? _inFlight;

  SessionFailure? _lastFailure;
  SessionFailure? get lastFailure => _lastFailure;

  bool get hasSession => (_access ?? '').isNotEmpty;

  String? get accessToken => _access;

  /// True when the access token is missing or within [_expiryLeeway] of
  /// expiring. Callers use this to refresh before a request fails.
  bool get needsRefresh {
    final token = _access;
    final expiry = _accessExpiresAt;
    if (token == null || token.isEmpty || expiry == null) return true;
    return DateTime.now().isAfter(expiry.subtract(_expiryLeeway));
  }

  /// Loads any persisted session. Safe to call repeatedly.
  Future<void> load() async {
    if (_access != null) return;
    _access = await SecureStore.readAccess();
    _refresh = await SecureStore.readRefresh();
    _accessExpiresAt = await SecureStore.readAccessExpiry();
  }

  /// Guarantees a usable access token, refreshing or handshaking as needed.
  ///
  /// Safe to call from anywhere: concurrent callers share one request.
  Future<void> ensureSession() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _ensure();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _ensure() async {
    await load();
    if (!needsRefresh) return;

    final refresh = _refresh;
    if (refresh != null && refresh.isNotEmpty) {
      final rotated = await _tryRefresh(refresh);
      if (rotated) return;
    }

    await _handshake();
  }

  Future<bool> _tryRefresh(String refresh) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/refresh',
        data: {'refresh': refresh},
      );
      final Map<String, dynamic>? raw = res.data;
      final data = raw?['data'];
      if (res.statusCode == 200 && data is Map<String, dynamic>) {
        await _persist(data);
        _lastFailure = null;
        return true;
      }
      // Errors are {success, code, message} at the root; `res.data?['code']`
      // throws NoSuchMethodError when the body is not a map.
      final code = raw?['code']?.toString();
      debugPrint('[session] refresh rejected: ${res.statusCode} code=$code');
      // A dead refresh token means we must handshake. Anything else
      // (rate limit, 5xx) leaves the stored pair alone so we can retry.
      if (res.statusCode == 401) {
        await SecureStore.clear();
        _access = null;
        _refresh = null;
        _accessExpiresAt = null;
      } else if (code == 'REFRESH_RATE_LIMITED' || res.statusCode == 429) {
        _lastFailure = SessionFailure.network;
      }
      return false;
    } on DioException catch (e) {
      debugPrint('[session] refresh network failure: ${e.type}');
      // A network blip must not destroy a valid refresh token.
      _lastFailure = SessionFailure.network;
      return false;
    }
  }

  Future<void> _handshake() async {
    final cert = await AppInfoChannel.signingCertSha256();
    if (cert == null || cert.isEmpty) {
      _lastFailure = SessionFailure.notOfficial;
      debugPrint('[session] cannot read signing cert; refusing to handshake');
      throw const SessionException(SessionFailure.notOfficial);
    }

    final build = await AppInfoChannel.versionCode();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/auth/handshake',
        data: {
          if (build != null && build > 0) 'build': build,
          'abi': defaultTargetPlatform == TargetPlatform.android ? 'arm64' : null,
        },
        options: Options(headers: {'X-Smartcook-Cert': cert}),
      );

      final Map<String, dynamic>? raw = res.data;
      final data = raw?['data'];
      if (res.statusCode == 201 && data is Map<String, dynamic>) {
        await _persist(data);
        _lastFailure = null;
        debugPrint(
          '[session] handshake ok: access for ${data['access_expires_in']}s, '
          'refresh for ${data['refresh_expires_in']}s',
        );
        return;
      }

      // Errors arrive as {success, code, message} at the root, not wrapped.
      final code = raw?['code']?.toString();
      if (code == 'FORBIDDEN_CLIENT' || res.statusCode == 403) {
        _lastFailure = SessionFailure.notOfficial;
        debugPrint(
          '[session] handshake rejected: ${res.statusCode} code=$code '
          '(this APK is not the official signed build)',
        );
        throw const SessionException(SessionFailure.notOfficial);
      }
      if (code == 'HANDSHAKE_RATE_LIMITED' || res.statusCode == 429) {
        _lastFailure = SessionFailure.network;
      } else {
        _lastFailure = SessionFailure.malformed;
      }
      debugPrint('[session] handshake rejected: ${res.statusCode} code=$code');
      throw SessionException(_lastFailure!);
    } on DioException catch (e) {
      // Reached only for transport-level problems now that 4xx is accepted
      // as a normal response. A server-side 5xx still arrives here.
      _lastFailure = SessionFailure.network;
      debugPrint(
        '[session] handshake failed: ${e.type}'
        '${e.response?.statusCode != null ? ' status=${e.response?.statusCode}' : ''}',
      );
      throw const SessionException(SessionFailure.network);
    }
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final access = data['access'];
    final refresh = data['refresh'];
    if (access is! String || refresh is! String) {
      throw const SessionException(SessionFailure.malformed);
    }

    // Prefer the server's absolute expiry; fall back to the relative TTL so
    // a clock skew between phone and server cannot lock us out for hours.
    DateTime expiry;
    final at = data['access_expires_at'];
    if (at is String) {
      expiry = DateTime.tryParse(at) ?? DateTime.now().add(const Duration(hours: 24));
    } else {
      final ttl = data['access_expires_in'];
      final seconds = ttl is num ? ttl.toInt() : 86400;
      expiry = DateTime.now().add(Duration(seconds: seconds));
    }

    await SecureStore.writeSession(
      access: access,
      refresh: refresh,
      accessExpiresAt: expiry,
    );
    _access = access;
    _refresh = refresh;
    _accessExpiresAt = expiry;
  }

  /// Ends the session server-side, then locally. Never throws: logging out
  /// must succeed even when the server is unreachable.
  Future<void> revoke() async {
    final token = _access;
    if (token != null && token.isNotEmpty) {
      try {
        await _dio.delete<void>(
          '/api/auth/revoke',
          data: {'reason': 'client_logout'},
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } catch (e) {
        debugPrint('[session] revoke call failed (ignored): $e');
      }
    }
    await SecureStore.clear();
    _access = null;
    _refresh = null;
    _accessExpiresAt = null;
  }

  /// Wipes local state without telling the server. Used when the app learns
  /// its token is dead and must handshake again.
  Future<void> clearLocal() async {
    await SecureStore.clear();
    _access = null;
    _refresh = null;
    _accessExpiresAt = null;
  }
}

class SessionException implements Exception {
  const SessionException(this.failure);
  final SessionFailure failure;

  @override
  String toString() => 'SessionException(${failure.name})';
}
