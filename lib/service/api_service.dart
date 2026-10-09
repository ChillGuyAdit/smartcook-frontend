import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:smartcook/config/api_config.dart';
import 'package:smartcook/core/services/app_session.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/services/restriction.dart';
import 'package:smartcook/core/services/secure_channel.dart';
import 'package:smartcook/service/offline_manager.dart';
import 'package:smartcook/service/token_service.dart';

/// Error codes the app-token layer returns. A 401 carrying one of these means
/// "renew the app session", not "the user has to log in again".
const Set<String> kAppTokenCodes = {
  'TOKEN_MISSING',
  'TOKEN_INVALID',
  'TOKEN_EXPIRED',
  'REFRESH_MISSING',
  'REFRESH_INVALID',
  'REFRESH_EXPIRED',
  'APP_TOKENS_NOT_CONFIGURED',
};

class ApiService {
  /// Every request goes through the sealed channel (see SecureChannel).
  static final http.Client _http = SecureHttpClient.shared;

  static String get _baseUrl => ApiConfig.baseUrl;

  static void Function()? onUnauthorized;

  /// Called when even a fresh handshake cannot produce a session (e.g. the
  /// build is not the official one). The UI can then explain why.
  static void Function()? onSessionUnavailable;

  /// Builds the header set for one request.
  ///
  /// [useAuth] controls the *user* JWT. The app-session access token is
  /// attached whenever one is available; it is required by every endpoint
  /// except the bootstrap and auto-update paths.
  static Future<Map<String, String>> _headers({
    bool useAuth = true,
    bool requireAppSession = true,
    String? appSessionOverride,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requireAppSession) {
      final session = AppSession.instance;
      if (!session.hasSession || session.needsRefresh) {
        try {
          await session.ensureSession();
        } catch (e) {
          debugPrint('[api] app session unavailable: $e');
        }
      }
      final access = appSessionOverride ?? session.accessToken;
      if (access != null && access.isNotEmpty) {
        headers['Authorization'] = 'Bearer $access';
      }
    }

    if (useAuth) {
      final token = await TokenService.getToken();
      if (token != null && token.isNotEmpty) {
        // The user JWT travels as `X-User-Token`; `Authorization` is
        // reserved for the app session so the two never collide.
        headers['X-User-Token'] = token;
      }
    }
    return headers;
  }

  static bool _isAppTokenFailure(http.Response res, dynamic body) {
    if (res.statusCode != 401) return false;
    if (body is! Map) return false;
    final code = body['code'];
    return code is String && kAppTokenCodes.contains(code);
  }

  /// Runs [call], and if the server rejects the app session, renews it once
  /// and retries. A user-JWT rejection is *not* retried here: that means the
  /// account genuinely needs to sign in again.
  /// Every request passes through here, so this is the one place to record
  /// "which endpoint, how long, what status" for the developer log. Only the
  /// route and timing are recorded - never headers, bodies or tokens.
  static Future<ApiResponse> _withSessionRetry(
    String path,
    Future<http.Response> Function(Map<String, String> headers) call, {
    required bool requireAppSession,
  }) async {
    final sw = Stopwatch()..start();
    final result = await _withSessionRetryInner(
      path,
      call,
      requireAppSession: requireAppSession,
    );
    if (path != '/api/telemetry/beat')
      DevLog.log(
        'api_call',
        action: 'api:$path',
        statusCode: result.statusCode,
        durationMs: sw.elapsedMilliseconds,
        level: result.success ? 'info' : 'warn',
      );
    return result;
  }

  static Future<ApiResponse> _withSessionRetryInner(
    String path,
    Future<http.Response> Function(Map<String, String> headers) call, {
    required bool requireAppSession,
  }) async {
    final first = await call(
      await _headers(requireAppSession: requireAppSession),
    );
    final firstBody = _decode(first);

    if (!_isAppTokenFailure(first, firstBody)) {
      return _handleResponse(first, path: path);
    }

    // A dead refresh token means a full handshake, not just a rotation.
    await AppSession.instance.clearLocal();
    try {
      await AppSession.instance.ensureSession();
    } on SessionException catch (e) {
      debugPrint('[api] re-handshake failed: ${e.failure.name}');
      onSessionUnavailable?.call();
      return _handleResponse(first, path: path);
    }

    final retry = await call(
      await _headers(requireAppSession: requireAppSession),
    );
    return _handleResponse(retry, path: path);
  }

  static dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return null;
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  static Future<ApiResponse> _handleResponse(
    http.Response res, {
    String? path,
  }) async {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Terjadi kesalahan pada server.',
        statusCode: res.statusCode,
      );
    }

    // A blocked address or a suspended account: one full-screen notice, and the
    // caller just sees a failed request.
    if (res.statusCode == 403 &&
        body is Map &&
        Restriction.isRestriction(body['code']?.toString())) {
      Restriction.report(
        body['code'].toString(),
        body['message']?.toString() ?? '',
        body['reason']?.toString() ?? '',
      );
      return ApiResponse(
        success: false,
        message: body['message']?.toString(),
        statusCode: 403,
        code: body['code'].toString(),
      );
    }

    // 401 split into two very different situations.
    if (res.statusCode == 401) {
      final code =
          body is Map && body['code'] != null ? body['code'].toString() : '';

      if (kAppTokenCodes.contains(code)) {
        // App session died and could not be renewed: nothing the user did.
        return ApiResponse(
          success: false,
          message: body is Map && body['message'] != null
              ? body['message'].toString()
              : 'Sesi aplikasi kedaluwarsa.',
          statusCode: 401,
          code: code,
        );
      }

      // User JWT rejected: the account must sign in again.
      await TokenService.clearAll();
      onUnauthorized?.call();
      final msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Sesi habis, silakan login lagi';
      return ApiResponse(success: false, message: msg, statusCode: 401);
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      // Jika respons sukses, anggap koneksi online
      OfflineManager.setOffline(false);
      // Backend mungkin mengembalikan data langsung atau dalam wrapper
      dynamic responseData = body;
      if (body is Map) {
        // Cek apakah ada wrapper 'data' atau langsung di root
        responseData = body.containsKey('data') ? body['data'] : body;
      }
      return ApiResponse(
        success: true,
        data: responseData,
        message: body is Map && body['message'] != null
            ? body['message'].toString()
            : null,
        statusCode: res.statusCode,
        code: body is Map && body['code'] != null
            ? body['code'].toString()
            : null,
      );
    }

    final message = body is Map && body['message'] != null
        ? body['message'].toString()
        : 'Terjadi kesalahan (${res.statusCode})';
    final errorCode =
        body is Map && body['code'] != null ? body['code'].toString() : null;
    // Debug log: a failing endpoint is the single most useful thing to know
    // about a bug report, and this is the one place every API call passes
    // through.
    DevLog.log(
      'api_error',
      action: path == null ? null : 'api:$path',
      level: res.statusCode >= 500 ? 'error' : 'warn',
      statusCode: res.statusCode,
      error: errorCode ?? message,
    );
    return ApiResponse(
      success: false,
      // Untuk error, kirim seluruh body agar field seperti
      // retry_after_seconds, expires_in_seconds, dll bisa dibaca frontend.
      data: body,
      message: message,
      statusCode: res.statusCode,
      code:
          body is Map && body['code'] != null ? body['code'].toString() : null,
    );
  }

  static Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParameters,
    bool useAuth = true,
    bool requireAppSession = true,
  }) async {
    try {
      final response = await _withSessionRetry(
        path,
        (headers) async {
          var uri = Uri.parse('$_baseUrl$path');
          if (queryParameters != null && queryParameters.isNotEmpty) {
            uri = uri.replace(queryParameters: queryParameters);
          }
          return _http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
        },
        requireAppSession: requireAppSession,
      );
      return response;
    } catch (e) {
      return _failure(e);
    }
  }

  /// Only a connectivity problem means "offline". Any other exception (a bad
  /// JSON body, a bug in a callback) used to flip the whole app to offline
  /// mode and show "check your connection" for something unrelated.
  static ApiResponse _failure(Object e) {
    if (e is TimeoutException || e is http.ClientException) {
      OfflineManager.setOffline(true);
      return ApiResponse(
        success: false,
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
    debugPrint('[api] unexpected error: $e');
    return ApiResponse(
      success: false,
      message: 'Terjadi kesalahan. Coba lagi.',
    );
  }

  static Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = false,
    bool requireAppSession = true,
  }) async {
    try {
      final bodyStr = body != null ? jsonEncode(body) : null;
      return await _withSessionRetry(
        path,
        (headers) async {
          final uri = Uri.parse('$_baseUrl$path');
          if (kDebugMode) {
            debugPrint('POST $uri');
            debugPrint('Headers: $headers');
            debugPrint('Body: $bodyStr');
          }
          final res = await _http
              .post(uri, headers: headers, body: bodyStr)
              .timeout(const Duration(seconds: 30));
          if (kDebugMode) {
            debugPrint('Response status: ${res.statusCode}');
            debugPrint('Response body: ${res.body}');
          }
          return res;
        },
        requireAppSession: requireAppSession,
      );
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = true,
    bool requireAppSession = true,
  }) async {
    try {
      return await _withSessionRetry(
        path,
        (headers) async {
          final uri = Uri.parse('$_baseUrl$path');
          return _http
              .put(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 30));
        },
        requireAppSession: requireAppSession,
      );
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<ApiResponse> delete(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = true,
    bool requireAppSession = true,
  }) async {
    try {
      return await _withSessionRetry(
        path,
        (headers) async {
          final uri = Uri.parse('$_baseUrl$path');
          return _http
              .delete(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 30));
        },
        requireAppSession: requireAppSession,
      );
    } catch (e) {
      return _failure(e);
    }
  }
}

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;
  final String? code;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.code,
  });
}
