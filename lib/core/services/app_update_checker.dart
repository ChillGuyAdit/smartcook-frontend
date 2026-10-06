import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/device_abi.dart';
import '../l10n/strings.dart';
import '../theme/language_controller.dart';
import 'apk_downloader.dart';
import 'app_update_fetcher.dart';

/// Compiled-in release build number, straight from the `+N` in pubspec.yaml.
/// The release build number, read from the native side.
///
/// It must come from Android's `versionCode`, and the build must be produced
/// by `scripts/build_android_release.ps1` (one APK per `--target-platform`,
/// like Kelilink) rather than `--split-per-abi`. With `--split-per-abi` the
/// Flutter Gradle plugin rewrites `versionCode` to
/// `abiVersionCode * 1000 + build`, so build 8 shipped as 2008 on arm64 and
/// 1008 on arm32. Those never matched the `build` published in latest.json,
/// so `installedBuild < minBuild` was never true, mandatory updates never
/// blocked anyone, and the update dialog never appeared.
///
/// The release script asserts that `versionCode == pubspec build` on every
/// build, so the two cannot silently drift apart again.
Future<int> resolveInstalledBuild() async {
  final native = await AppInfoChannel.versionCode();
  if (native != null && native > 0) return native;
  debugPrint('[update] native versionCode unavailable; checks degraded');
  return 0;
}

/// Version name for display, e.g. "1.0.7".
Future<String> resolveInstalledVersion() async {
  final pkg = await PackageInfo.fromPlatform();
  return pkg.version;
}

/// Auto-update dialog state machine for SmartCook Android.
///
/// Mirrors the Kelilink flow: the app pings `/api/app/version` (no auth,
/// gated by signing-cert header), and if a newer build is mandatory the
/// dialog blocks the user until they install. Optional updates show a
/// single dialog per app start.
class AppUpdateChecker {
  AppUpdateChecker._();

  static bool _optionalShown = false;
  static bool _dialogOpen = false;
  static int _networkRetries = 0;

  /// Entry point called from `main.dart` after the first frame.
  static Future<void> check(BuildContext? Function() contextOf) async {
    if (kIsWeb || !Platform.isAndroid || _dialogOpen) return;

    final Map<String, dynamic> info;
    final int installedBuild;
    final String installedVersion;
    try {
      // Build comes from the Android versionCode, which the release script
      // pins to the pubspec build number; see resolveInstalledBuild().
      installedBuild = await resolveInstalledBuild();
      installedVersion = await resolveInstalledVersion();
      if (installedBuild <= 0) {
        throw StateError('installed build number unknown');
      }
      info = await AppUpdateFetcher.fetchVersion(installedBuild);
      debugPrint(
        '[update] installed=$installedBuild (v$installedVersion) '
        'server latestBuild=${info['latestBuild']} '
        'minBuild=${info['minBuild']} mandatory=${info['mandatory']}',
      );
    } catch (e) {
      // 404 until a release is published, 403 on unofficial builds, or
      // offline: never block the app on an update check.
      debugPrint('[app] check skipped: $e');
      if (e is DioException &&
          e.type != DioExceptionType.connectionError &&
          e.type != DioExceptionType.connectionTimeout) {
        _networkRetries = 0;
      } else {
        _networkRetries++;
        if (_networkRetries <= 3) {
          Future<void>.delayed(
            const Duration(seconds: 30),
            () => check(contextOf),
          );
        }
      }
      return;
    }
    _networkRetries = 0;

    final latest = (info['latestBuild'] as num?)?.toInt() ?? 0;
    final minBuild = (info['minBuild'] as num?)?.toInt() ?? 0;
    if (latest <= installedBuild) {
      debugPrint(
        '[update] up to date: installed=$installedBuild latest=$latest',
      );
      return;
    }

    final forced = info['mandatory'] == true ||
        (installedBuild > 0 && installedBuild < minBuild);
    debugPrint(
      '[update] available: installed=$installedBuild latest=$latest '
      'minBuild=$minBuild mandatory=$forced',
    );

    // Clear the latch on a forced update so a check that ran while the app was
    // still starting cannot suppress the dialog on the next resume.
    if (forced) _optionalShown = false;
    if (!forced && _optionalShown) return;
    _optionalShown = true;

    BuildContext? context;
    for (var i = 0; i < 60; i++) {
      context = contextOf();
      if (context != null && context.mounted) break;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
if (context == null || !context.mounted) {
      // Do not stay silent: this used to be the failure mode where the app
      // stayed on an old build and nothing said why.
      debugPrint(
        '[update] no usable context after 60s; dialog suppressed. '
        'installed=$installedBuild latest=$latest forced=$forced',
      );
      _optionalShown = false;
      return;
    }
  _dialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateDialog(
        info: info,
        installedVersion: installedVersion,
        installedBuild: installedBuild,
        forced: forced,
      ),
    );
    _dialogOpen = false;
  }
}

enum _DialogStage { downloading, installing, failed }

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.info,
    required this.installedVersion,
    required this.installedBuild,
    required this.forced,
  });

  final Map<String, dynamic> info;
  final String installedVersion;
  final int installedBuild;
  final bool forced;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  // Only the fields we need are read below. Any extra fields the server
  // adds to `latest.json` (e.g. future title/subtitle overrides) are
  // intentionally ignored — the dialog degrades gracefully without code
  // changes.
  _DialogStage _stage = _DialogStage.downloading;
  double? _progress;
  String? _error;
  CancelToken? _cancel;

  String get _latestVersion =>
      widget.info['latestVersion']?.toString() ?? '?';

  String get _downloadUrl =>
      widget.info['downloadPath']?.toString() ?? '/api/app/download';

  String? get _token => widget.info['token'] as String?;
  String? get _expectedSha => widget.info['latestApkSha256'] as String?;
  String? get _notes => widget.info['notes'] as String?;

  /// Dialog strings follow the app language, like every other screen.
  Str get _s => stringsFor(LanguageController.instance.locale);

  String _versionLine(String installed, String latest) =>
      _s.versionFromTo.replaceFirst('{from}', installed).replaceFirst(
            '{to}',
            latest,
          );

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() {
      _stage = _DialogStage.downloading;
      _progress = null;
      _error = null;
    });
    if (_token == null) {
      setState(() {
        _stage = _DialogStage.failed;
        _error = '${_s.updateNotOfficial} ${_s.updateDownloadOfficial}';
      });
      return;
    }
    _cancel = CancelToken();
    try {
      await ApkDownloader.downloadAndOpen(
        relativeUrl: _downloadUrl,
        token: _token!,
        build: widget.info['latestBuild'] as int? ?? 0,
        expectedSha256: _expectedSha,
        abi: deviceApkAbi(),
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
        cancelToken: _cancel,
      );
      if (!mounted) return;
      setState(() => _stage = _DialogStage.installing);
    } on ApkDownloadException catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _DialogStage.failed;
        _error = _translateFailure(e.failure);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stage = _DialogStage.failed;
        _error = _s.updateGeneric;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _download());
  }

  String _translateFailure(UpdateFailure f) {
    final base = switch (f) {
      UpdateFailure.notOfficial =>
        '${_s.updateNotOfficial} ${_s.updateDownloadOfficial}',
      UpdateFailure.tokenExpired => _s.updateExpired,
      UpdateFailure.hashMismatch => _s.updateHashMismatch,
      UpdateFailure.networkError => _s.updateNetwork,
      UpdateFailure.unknown => _s.updateGeneric,
    };
    return '$base ${_s.updateRetry}.';
  }

  @override
  Widget build(BuildContext context) {
    final percent =
        _progress == null ? null : (_progress! * 100).clamp(0, 100).round();
    return PopScope(
      canPop: !widget.forced && _stage != _DialogStage.downloading,
      child: AlertDialog(
        title: Text(_stage == _DialogStage.installing
            ? _s.updateInstalling
            : widget.forced
                ? _s.updateMandatoryTitle
                : _s.updateOptionalTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_versionLine(widget.installedVersion, _latestVersion)),
            if (_notes != null && _notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_notes!, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 12),
            if (_stage == _DialogStage.downloading) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(percent == null
                  ? _s.updateDownloading
                  : _s.updatePercentDone.replaceFirst('{percent}', '$percent')),
            ],
            if (_stage == _DialogStage.installing) ...[
              const SizedBox(height: 12),
              Text(
                _s.updateUnknownSourceNotice,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
        actions: [
          if (!widget.forced && _stage != _DialogStage.downloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_s.updateLater),
            ),
          if (_stage == _DialogStage.failed)
            ElevatedButton(
              onPressed: _download,
              child: Text(_s.updateRetry),
            ),
          if (_stage == _DialogStage.installing)
            ElevatedButton(
              onPressed: () async {
                await ApkDownloader.downloadAndOpen(
                  relativeUrl: _downloadUrl,
                  token: _token!,
                  build: widget.info['latestBuild'] as int? ?? 0,
                  expectedSha256: _expectedSha,
                  abi: deviceApkAbi(),
                );
              },
              child: Text(_s.updateInstallAgain),
            ),
        ],
      ),
    );
  }
}