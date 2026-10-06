import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../config/api_config.dart';

// `UpdateFailure` now lives in apk_downloader.dart, which is the only place
// that can actually produce these outcomes. It used to be declared here too,
// and the duplicate made every reference ambiguous.

/// Bridge to `MainActivity.kt` to read the APK signing certificate.
class AppInfoChannel {
  AppInfoChannel._();

  static const _channel = MethodChannel('kelilink/app_info');

  static Future<String?> signingCertSha256() async {
    try {
      return await _channel.invokeMethod<String>('signingCertSha256');
    } catch (_) {
      return null;
    }
  }

  static Future<int?> versionCode() async {
    try {
      return await _channel.invokeMethod<int>('versionCode');
    } catch (_) {
      return null;
    }
  }

  /// Device facts for the developer debug log: OS version, SDK level, model,
  /// manufacturer, ABI and the app version name. Read natively because the
  /// Dart equivalents are incomplete on Android.
  static Future<Map<String, dynamic>?> deviceInfo() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'deviceInfo',
      );
      if (raw == null) return null;
      return raw.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }
}

/// Talks to the auto-update endpoints. The cert header is what gates the
/// download token; without it the server returns the version info but no
/// token, so the dialog can show "official build required".
class AppUpdateFetcher {
  AppUpdateFetcher._();

  static String? _cachedCert;

  static Future<Map<String, String>> clientHeaders(int build) async {
    _cachedCert ??= await AppInfoChannel.signingCertSha256();
    return {
      if (_cachedCert != null) 'X-Smartcook-Cert': _cachedCert!,
      'X-Smartcook-Build': '$build',
    };
  }

  /// Hits the version endpoint. The server returns 404 when no manifest is
  /// published yet; that's a normal state during development.
  static Future<Map<String, dynamic>> fetchVersion(int build) async {
    final headers = await clientHeaders(build);
    final dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      // Without limits a dead connection left the update check hanging.
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
    ));
    final res = await dio.get<Map<String, dynamic>>(
      '/api/app/version',
      queryParameters: {'build': build},
      options: Options(headers: headers),
    );
    final body = res.data;
    if (body is! Map<String, dynamic>) {
      throw const FormatException('Unexpected /version payload');
    }
    // The API wraps every payload as {success, data}. Reading `latestBuild`
    // off the root returned null, so the checker believed the app was already
    // up to date and never showed the dialog even with a mandatory update
    // pending. Unwrap defensively, the same way ApiService does.
    final payload = body['data'];
    if (payload is Map<String, dynamic>) return payload;
    if (body.containsKey('latestBuild')) return body;
    throw const FormatException('/version payload missing data');
  }
}