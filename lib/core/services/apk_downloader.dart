import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../config/api_config.dart';

/// Why an update download could not finish. Each maps to a clear message in
/// the dialog.
enum UpdateFailure {
  /// The server says this is not an official SmartCook build.
  notOfficial,

  /// The download link expired or a newer release replaced it.
  tokenExpired,

  /// Too many update attempts from this network.
  rateLimited,

  /// Finished, but the file did not match the published SHA-256.
  corrupted,

  /// Still no usable connection after all retries. The partial file is kept so
  /// the next attempt continues instead of starting over.
  networkError,
}

class ApkDownloadException implements Exception {
  ApkDownloadException(this.failure);
  final UpdateFailure failure;
  @override
  String toString() => 'ApkDownloadException.${failure.name}';
}

/// Raised when the file on the server changed under a partial download.
class _RestartDownload implements Exception {
  const _RestartDownload();
}

/// Downloads the release APK with the same robustness as Kelilink:
///
/// * Writes into `<target>.part` and resumes with an HTTP `Range` request, so a
///   dropped connection continues instead of restarting.
/// * Retries with backoff for about five minutes, which is what makes a weak
///   signal survivable.
/// * Reuses an already-complete file from a previous attempt when its SHA-256
///   still matches - that is what stops the app downloading 24 MB again after
///   the user closed the installer.
/// * Verifies SHA-256 before the file is handed to Android.
class ApkDownloader {
  ApkDownloader({Dio? dio, this.retryDelays = _defaultDelays}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Waits between attempts; roughly five minutes in total before giving up.
  final List<Duration> retryDelays;

  static const _defaultDelays = [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 60),
    Duration(seconds: 90),
  ];

  /// Returns the finished APK at [target].
  Future<File> download({
    required String relativeUrl,
    required String token,
    required String? abi,
    required int build,
    required File target,
    required Map<String, String> headers,
    String? expectedSha256,
    required void Function(double progress) onProgress,
    void Function(bool waiting)? onWaitingForNetwork,
    CancelToken? cancelToken,
  }) async {
    final part = File('${target.path}.part');

    // Already downloaded in an earlier session but never installed (the user
    // closed the installer, or Android declined). Reuse it instead of
    // fetching the whole APK again.
    if (expectedSha256 != null &&
        expectedSha256.length == 64 &&
        await target.exists()) {
      final digest = await sha256.bind(target.openRead()).first;
      if (digest.toString().toLowerCase() == expectedSha256.toLowerCase()) {
        onProgress(1);
        debugPrint('[update] reusing verified download of build $build');
        return target;
      }
      await target.delete();
    }

    var attempt = 0;
    while (true) {
      try {
        await _fetchRemaining(
          relativeUrl: relativeUrl,
          token: token,
          abi: abi,
          part: part,
          headers: headers,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
        onWaitingForNetwork?.call(false);
        break;
      } on _RestartDownload {
        // The file on the server changed under us; start over.
        if (await part.exists()) await part.delete();
        continue;
      } on ApkDownloadException {
        rethrow;
      } catch (e) {
        // A drop mid-body arrives as HttpException / SocketException from the
        // byte stream, not as a DioException - both mean "resume, don't give
        // up".
        if (e is DioException && CancelToken.isCancel(e)) rethrow;
        if (attempt >= retryDelays.length) {
          throw ApkDownloadException(UpdateFailure.networkError);
        }
        onWaitingForNetwork?.call(true);
        debugPrint(
          '[update] download dropped ($e), retry ${attempt + 1}/${retryDelays.length}',
        );
        await Future<void>.delayed(retryDelays[attempt++]);
      }
    }

    if (expectedSha256 != null && expectedSha256.length == 64) {
      final digest = await sha256.bind(part.openRead()).first;
      if (digest.toString().toLowerCase() != expectedSha256.toLowerCase()) {
        await part.delete();
        throw ApkDownloadException(UpdateFailure.corrupted);
      }
    }
    if (await target.exists()) await target.delete();
    return part.rename(target.path);
  }

  Future<void> _fetchRemaining({
    required String relativeUrl,
    required String token,
    required String? abi,
    required File part,
    required Map<String, String> headers,
    required void Function(double progress) onProgress,
    CancelToken? cancelToken,
  }) async {
    final query = <String, String>{
      't': token,
      if (abi != null) 'abi': abi,
    };
    final url = Uri.parse('${ApiConfig.baseUrl}$relativeUrl')
        .replace(queryParameters: query)
        .toString();

    final already = await part.exists() ? await part.length() : 0;

    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        headers: {...headers, if (already > 0) 'Range': 'bytes=$already-'},
        // A slow network must never be cut off by a timeout mid-download; only
        // a dead connection is, and that is resumed.
        receiveTimeout: const Duration(seconds: 45),
        validateStatus: (_) => true,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status >= 400) {
      final body = await response.data!.stream
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      throw _failureFor(status, String.fromCharCodes(body));
    }

    final resumed = status == 206;
    // 200 when we asked for a range means the server ignored it and sent the
    // whole file, so the partial bytes must be discarded, not appended.
    final start = resumed ? already : 0;
    final header = response.headers.value(Headers.contentLengthHeader);
    final length = int.tryParse(header ?? '') ?? -1;
    final total = length < 0 ? -1 : start + length;

    final sink = part.openWrite(mode: resumed ? FileMode.append : FileMode.write);
    var received = start;
    try {
      await for (final chunk in response.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress((received / total).clamp(0.0, 1.0));
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  Object _failureFor(int status, String body) {
    // 416: the requested range is past the end - the local .part is stale or
    // corrupt, so start the whole file again.
    if (status == 416) return const _RestartDownload();
    if (status == 429) return ApkDownloadException(UpdateFailure.rateLimited);
    if (body.contains('TOKEN_EXPIRED') || status == 410 || status == 404) {
      return ApkDownloadException(UpdateFailure.tokenExpired);
    }
    if (status == 403) return ApkDownloadException(UpdateFailure.notOfficial);
    // 5xx and anything unexpected: treat it like a dropped connection so it
    // is retried rather than shown as a hard failure.
    return DioException(
      requestOptions: RequestOptions(),
      type: DioExceptionType.badResponse,
    );
  }

  /// Where the APK is cached between attempts.
  ///
  /// The *cache* directory, not the temporary one: Android may clear temp
  /// files on its own, and a completed-but-not-installed download is exactly
  /// what we want to keep.
  static Future<File> cachedApk(int build) async {
    final dir = await getApplicationCacheDirectory();
    return File('${dir.path}/smartcook-update-$build.apk');
  }

  /// Removes APKs from earlier updates; they can never be installed again.
  static Future<void> deleteStaleDownloads(int installedBuild) async {
    try {
      final dir = await getApplicationCacheDirectory();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final m = RegExp(r'smartcook-update-(\d+)\.apk(\.part)?$')
            .firstMatch(entity.path.split(Platform.pathSeparator).last);
        final build = int.tryParse(m?.group(1) ?? '');
        if (build != null && build <= installedBuild) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Cache housekeeping must never break an update.
    }
  }

  /// Hands the finished APK to the Android installer.
  static Future<OpenResult> openForInstall(File file) {
    return OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
  }
}