import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';

import '../../config/api_config.dart';

/// Why a forced / step failed end-to-end. Each maps to a clear message.
enum UpdateFailure {
  /// The server says this is not an official SmartCook build.
  notOfficial,

  /// The download link expired or a newer release replaced it.
  tokenExpired,

  /// The APK on disk did not match the SHA-256 from the manifest.
  hashMismatch,

  /// Network or HTTP error; the dialog retries the request.
  networkError,

  /// Range-resume parse failed; treated as dropped connection.
  unknown,
}

class UpdateFailureCode implements Exception {
  UpdateFailureCode(this.failure);
  final UpdateFailure failure;
  @override
  String toString() => 'UpdateFailure.${failure.name}';
}

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
    return body;
  }
}