import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/api_config.dart';
import 'app_update_fetcher.dart';

/// A successful end-of-pipe result for the install flow.
class UpdateInstallResult {
  UpdateInstallResult({required this.file, required this.openResult});
  final File file;
  final OpenResult openResult;
}

/// Why an update download couldn't make it. Each is converted to a clear
/// message inside the update dialog.
class ApkDownloadException implements Exception {
  ApkDownloadException(this.failure);
  final UpdateFailure failure;
  @override
  String toString() => 'ApkDownloadException.${failure.name}';
}

class ApkDownloader {
  ApkDownloader._();

  static Future<UpdateInstallResult> downloadAndOpen({
    required String relativeUrl,
    required String token,
    required int build,
    required String? expectedSha256,
    required String? abi,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final query = <String, String>{
      't': token,
      if (abi != null) 'abi': abi,
    };

    final tempDir = await getTemporaryDirectory();
    final target = File('${tempDir.path}/smartcook-update-$build.apk');

    final downloadUrl = Uri.parse('${ApiConfig.baseUrl}$relativeUrl')
        .replace(queryParameters: query)
        .toString();

    try {
      await Dio().download(
        downloadUrl,
        target.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (onProgress != null && total > 0) {
            onProgress(received / total);
          }
        },
      );
    } on DioException catch (e) {
      // 410 Gone = expired token; rebuild the link and retry once.
      if (e.response?.statusCode == 410) {
        throw ApkDownloadException(UpdateFailure.tokenExpired);
      }
      if (e.response?.statusCode == 403) {
        throw ApkDownloadException(UpdateFailure.notOfficial);
      }
      if (e.type == DioExceptionType.cancel) {
        rethrow;
      }
      throw ApkDownloadException(_mapNetworkFailure(e));
    }

    if (expectedSha256 != null && expectedSha256.length == 64) {
      final actual = await _sha256(target);
      if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
        try {
          await target.delete();
        } catch (_) {}
        throw ApkDownloadException(UpdateFailure.hashMismatch);
      }
    }

    final open = await OpenFilex.open(
      target.path,
      type: 'application/vnd.android.package-archive',
    );
    return UpdateInstallResult(file: target, openResult: open);
  }

  static Future<String> _sha256(File f) async {
    final bytes = await f.readAsBytes();
    return sha256.convert(bytes).toString();
  }

  static UpdateFailure _mapNetworkFailure(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.connectionError:
        return UpdateFailure.networkError;
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
      case DioExceptionType.transformTimeout:
        return UpdateFailure.unknown;
    }
  }
}