import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/device_abi.dart';
import '../l10n/strings.dart';
import '../theme/language_controller.dart';
import 'apk_downloader.dart';
import 'app_update_fetcher.dart';
import 'dev_log.dart';

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
      // Clean up APKs from older releases that can never be installed again.
      await ApkDownloader.deleteStaleDownloads(installedBuild);
      debugPrint(
        '[update] installed=$installedBuild (v$installedVersion) '
        'server latestBuild=${info['latestBuild']} '
        'minBuild=${info['minBuild']} mandatory=${info['mandatory']}',
      );
    } catch (e) {
      // 404 until a release is published, 403 on unofficial builds, or
      // offline: never block the app on an update check.
      debugPrint('[app] check skipped: $e');
      DevLog.error('update_check', e, action: 'fetch');
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
    DevLog.log('update_check', action: 'compared', meta: {
      'installed': installedBuild,
      'latest': latest,
      'minBuild': minBuild,
      'mandatory': info['mandatory'] == true,
    });
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

    // Not showDialog(): a dialog is a route, and the splash / sign-in / home
    // loading code replaces or clears routes (`pushReplacement`,
    // `pushNamedAndRemoveUntil`). Whatever was on top of the stack - the
    // dialog - went with it, so right after login the pop-up appeared and
    // vanished again. An overlay entry sits above every route and is only
    // removed by the user (Later / back) - never for a mandatory update.
    await UpdateOverlay.show(
      Navigator.of(context, rootNavigator: true),
      forced: forced,
      builder: (close) => _UpdateDialog(
        info: info,
        installedVersion: installedVersion,
        installedBuild: installedBuild,
        forced: forced,
        onClose: close,
      ),
    );
    _dialogOpen = false;
  }
}

/// Tells the framework that something on screen wants the back key.
///
/// Android only forwards the back key to Flutter while the framework says it
/// can handle it, and with a single route on the stack (splash, sign-in) it
/// says it cannot: the app was simply closed. Used by the overlay below and by
/// the listener in `main.dart` that re-asserts it when a route change reports
/// "nothing to pop" while the pop-up is open.
class _BackAnnouncer extends StatefulWidget {
  const _BackAnnouncer({required this.child});
  final Widget child;

  @override
  State<_BackAnnouncer> createState() => _BackAnnouncerState();
}

class _BackAnnouncerState extends State<_BackAnnouncer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        const NavigationNotification(canHandlePop: true).dispatch(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Hosts the update pop-up above all routes (see [AppUpdateChecker.check]).
///
/// Back button: `_MyAppState` is registered as a binding observer before the
/// app's own navigator, so [handleBack] sees the key first. A mandatory update
/// swallows it; an optional one closes the pop-up (like "Later").
class UpdateOverlay {
  UpdateOverlay._();

  static OverlayEntry? _entry;
  static VoidCallback? _close;
  static Completer<void>? _done;

  /// Set by the dialog while it is on screen: closing is allowed (optional
  /// update, not in the middle of a download).
  static bool canDismiss = false;

  /// The dialog can claim the back key first (e.g. to leave the full notes).
  static bool Function()? backHandler;

  static bool get isOpen => _entry != null;

  /// Test seam: forget a pop-up whose widget tree no longer exists.
  @visibleForTesting
  static void reset() {
    _entry = null;
    _close = null;
    backHandler = null;
    canDismiss = false;
    if (_done != null && !_done!.isCompleted) _done!.complete();
    _done = null;
  }

  static Future<void> show(
    NavigatorState nav, {
    required bool forced,
    required Widget Function(VoidCallback close) builder,
  }) {
    final overlay = nav.overlay;
    if (overlay == null) return Future<void>.value();
    if (_entry != null) return _done!.future;
    final done = Completer<void>();
    _done = done;
    canDismiss = !forced;

    late final OverlayEntry entry;
    void close() {
      if (_entry != entry) return;
      _entry = null;
      _close = null;
      backHandler = null;
      canDismiss = false;
      entry.remove();
      entry.dispose();
      if (!done.isCompleted) done.complete();
    }

    entry = OverlayEntry(
      builder: (ctx) => _BackAnnouncer(
        child: Stack(
          children: [
            const ModalBarrier(dismissible: false, color: Color(0x99000000)),
            Padding(
              padding: MediaQuery.of(ctx).viewInsets,
              child: SafeArea(
                child: Center(
                  child: Material(
                    type: MaterialType.transparency,
                    child: builder(close),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    _entry = entry;
    _close = close;
    overlay.insert(entry);
    return done.future;
  }

  /// True when the key was consumed by the pop-up.
  static bool handleBack() {
    if (_entry == null) return false;
    if (backHandler?.call() == true) return true;
    if (canDismiss) _close?.call();
    return true;
  }
}

enum _DialogStage { ready, downloading, installing, failed }

/// One entry from the server's `history`, shown in the full release notes.
class _ReleaseNote {
  final String version;
  final int build;

  /// Android PackageInfo versionCode for this release. Defaults to [build]
  /// for the few releases where the manifest `build` and Android `versionCode`
  /// matched, but is set explicitly for old releases (1.0.0 .. 1.0.4) that
  /// were built before the versionCode==pubspec-build rule. The client uses
  /// this field to decide whether a history entry is actually newer than the
  /// installed app - older manifests always look newer than the installed
  /// build number otherwise, and a v1.0.12 device sees "9 versions behind"
  /// even though it is current.
  final int androidVersionCode;
  final String? date;
  final String notes;

  const _ReleaseNote({
    required this.version,
    required this.build,
    required this.androidVersionCode,
    this.date,
    required this.notes,
  });

  factory _ReleaseNote.fromJson(Map<String, dynamic> j) {
    final build = (j['build'] as num?)?.toInt() ?? 0;
    // `androidVersionCode` is the field the client actually compares against;
    // `build` is the manifest's monotonic counter. Fall back to `build` for
    // new manifests that pre-date the field, so the picker is correct
    // whether or not the field is present.
    final androidVersionCode =
        (j['androidVersionCode'] as num?)?.toInt() ?? build;
    return _ReleaseNote(
      version: j['version'] as String? ?? '',
      build: build,
      androidVersionCode: androidVersionCode,
      date: j['date'] as String?,
      notes: j['notes'] as String? ?? '',
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.info,
    required this.installedVersion,
    required this.installedBuild,
    required this.forced,
    required this.onClose,
  });

  final Map<String, dynamic> info;
  final String installedVersion;
  final int installedBuild;
  final bool forced;
  final VoidCallback onClose;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  // Only the fields we need are read below. Any extra fields the server
  // adds to `latest.json` (e.g. future title/subtitle overrides) are
  // intentionally ignored — the dialog degrades gracefully without code
  // changes.
  //
  // Starts at `ready`, NOT `downloading`: the user sees the release notes and
  // chooses. Auto-downloading the moment a dialog appears burns mobile data
  // without consent and leaves no chance to read what changed.
  _DialogStage _stage = _DialogStage.ready;
  double? _progress;
  bool _waitingForNetwork = false;
  String? _error;
  CancelToken? _cancel;

  // Replaced wholesale when a fresh token is fetched after an expired link.
  late Map<String, dynamic> _info = widget.info;

  String get _latestVersion => _info['latestVersion']?.toString() ?? '?';

  String get _downloadUrl =>
      _info['downloadPath']?.toString() ?? '/api/app/download';

  String? get _token => _info['token'] as String?;
  Map<String, String> get _expectedShas {
    final raw = _info['apkSha256'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    // Backward compat with the previous single-hash shape.
    final single = _info['latestApkSha256'];
    if (single is String && single.isNotEmpty) {
      return {deviceApkAbi(): single};
    }
    return const {};
  }

  String? get _expectedSha {
    return _expectedShas[deviceApkAbi()];
  }

  String? get _notes => _info['notes'] as String?;
  int get _latestBuild => (_info['latestBuild'] as num?)?.toInt() ?? 0;

  List<_ReleaseNote> get _releases => [
        for (final r in (_info['history'] as List? ?? const []))
          if (r is Map) _ReleaseNote.fromJson(Map<String, dynamic>.from(r)),
      ];

  /// Dialog strings follow the app language, like every other screen.
  Str get _s => stringsFor(LanguageController.instance.locale);

  /// Build numbers always rise, but a version *name* can go down (a rollback
  /// after a bad release). Saying "1.0.11 → 1.0.9" would look like a mistake,
  /// so it is phrased as an official update instead.
  String _versionLine() {
    if (_compareVersions(_latestVersion, widget.installedVersion) < 0) {
      return _s.updateOfficialRollback.replaceFirst(
        '{to}',
        _latestVersion,
      );
    }
    return _s.versionFromTo
        .replaceFirst('{from}', widget.installedVersion)
        .replaceFirst('{to}', _latestVersion);
  }

  static int _compareVersions(String a, String b) {
    List<int> parts(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final x = parts(a), y = parts(b);
    for (var i = 0; i < 3; i++) {
      final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
      if (d != 0) return d;
    }
    return 0;
  }

  /// How many versions the user gains by updating. "Naik 3 versi sekaligus"
  /// is far more informative than a single line of notes.
  ///
  /// Uses `androidVersionCode`, not the manifest `build`, to count - the
  /// manifest `build` is the server's own monotonic counter, while
  /// `androidVersionCode` is what the installed app actually reports. The
  /// two diverged for releases before v1.0.5 (Android `versionCode` was
  /// assigned independently), so counting on `build` made a v1.0.12
  /// device look like it was 9 versions behind.
  int get _versionsBehind {
    final newer = _releases
        .where((r) => r.androidVersionCode > widget.installedBuild)
        .length;
    return newer > 0 ? newer : 1;
  }

  // The full notes open inside the pop-up itself: a bottom sheet is a route and
  // would be drawn underneath the overlay that hosts this dialog.
  bool _notesOpen = false;
  final ScrollController _notesScroll = ScrollController();

  void _showAllNotes() => setState(() => _notesOpen = true);

  bool _handleBack() {
    if (_notesOpen) {
      setState(() => _notesOpen = false);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _notesScroll.dispose();
    if (UpdateOverlay.backHandler == _handleBack)
      UpdateOverlay.backHandler = null;
    super.dispose();
  }

  Future<void> _download({bool refreshedToken = false}) async {
    setState(() {
      _stage = _DialogStage.downloading;
      _progress = null;
      _error = null;
      _waitingForNetwork = false;
    });
    if (_token == null) {
      setState(() {
        _stage = _DialogStage.failed;
        _error = '${_s.updateNotOfficial} ${_s.updateDownloadOfficial}';
      });
      return;
    }

    final build = _latestBuild;
    _cancel = CancelToken();
    try {
      // Cached file, so an install the user abandoned is not downloaded twice.
      final target = await ApkDownloader.cachedApk(build);
      final file = await ApkDownloader(
        retryDelays: const [
          Duration(seconds: 2),
          Duration(seconds: 5),
          Duration(seconds: 10),
          Duration(seconds: 20),
          Duration(seconds: 30),
          Duration(seconds: 60),
        ],
      ).download(
        relativeUrl: _downloadUrl,
        token: _token!,
        abi: deviceApkAbi(),
        build: build,
        target: target,
        headers: await AppUpdateFetcher.clientHeaders(widget.installedBuild),
        expectedSha256: _expectedSha,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => _progress = p);
        },
        onWaitingForNetwork: (waiting) {
          if (mounted) setState(() => _waitingForNetwork = waiting);
        },
        cancelToken: _cancel,
      );

      if (!mounted) return;
      setState(() => _stage = _DialogStage.installing);

      final result = await ApkDownloader.openForInstall(file);
      // Android always asks the user to confirm; anything other than `done`
      // means the installer was cancelled or refused, and the file stays
      // cached so the next attempt installs without downloading again.
      DevLog.log('update_result', action: 'installer', meta: {
        'result': result.type.name,
        'build': build,
      });
      if (result.type != ResultType.done) {
        debugPrint(
            '[update] installer result: ${result.type} ${result.message}');
      }
    } on ApkDownloadException catch (e) {
      DevLog.log('update_result', action: 'download', level: 'warn', meta: {
        'failure': e.failure.name,
        'build': build,
      });
      if (!mounted) return;
      if (e.failure == UpdateFailure.tokenExpired && !refreshedToken) {
        // The link is older than its TTL, or a newer release replaced it.
        // Get a fresh one silently and continue; any partial bytes are kept.
        try {
          final fresh =
              await AppUpdateFetcher.fetchVersion(widget.installedBuild);
          if (!mounted) return;
          setState(() => _info = fresh);
          return _download(refreshedToken: true);
        } catch (_) {
          // fall through to the failure message below
        }
      }
      _fail(_translateFailure(e.failure));
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      if (!mounted) return;
      debugPrint('[update] failed: $e');
      _fail(_s.updateGeneric);
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _stage = _DialogStage.failed;
      _waitingForNetwork = false;
      _error = message;
    });
  }

  @override
  void initState() {
    super.initState();
    UpdateOverlay.backHandler = _handleBack;
    // Deliberately no download here. The dialog opens at the `ready` stage so
    // the user reads the notes and presses the button. Starting the transfer
    // automatically would spend mobile data without asking.
  }

  String _translateFailure(UpdateFailure f) {
    final base = switch (f) {
      UpdateFailure.notOfficial =>
        '${_s.updateNotOfficial} ${_s.updateDownloadOfficial}',
      UpdateFailure.tokenExpired => _s.updateExpired,
      UpdateFailure.rateLimited => _s.updateRateLimited,
      UpdateFailure.corrupted => _s.updateHashMismatch,
      // Says the partial file is kept, so the user knows "Lanjutkan" will not
      // start from zero.
      UpdateFailure.networkError => _s.updateNetworkResume,
    };
    return '$base ${_s.updateRetry}.';
  }

  @override
  Widget build(BuildContext context) {
    final percent =
        _progress == null ? null : (_progress! * 100).clamp(0, 100).round();
    // Closing is only allowed for an optional update that is not downloading.
    UpdateOverlay.canDismiss =
        !widget.forced && _stage != _DialogStage.downloading;
    if (_notesOpen) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _notesOpen = false),
                ),
              ),
              Expanded(
                child: _ReleaseNotesList(
                  controller: _notesScroll,
                  releases: _releases,
                  installedBuild: widget.installedBuild,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(_stage == _DialogStage.installing
          ? _s.updateInstalling
          : widget.forced
              ? _s.updateMandatoryTitle
              : _s.updateOptionalTitle),
      // Scrollable so the progress bar and buttons stay reachable when the
      // release notes are long on a small screen.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _versionLine(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (_versionsBehind > 1) ...[
              const SizedBox(height: 4),
              Text(
                _s.updateVersionsBehind.replaceFirst(
                  '{count}',
                  '$_versionsBehind',
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ],
            if (_notes != null && _notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_notes!),
            ],
            if (_releases.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _showAllNotes,
                  child: Text(_releases.length > 1
                      ? _s.updateShowAllNotes
                      : _s.updateShowFullNotes),
                ),
              ),
            if (widget.forced) ...[
              const SizedBox(height: 8),
              Text(_s.updateForcedNotice),
            ],
            if (_stage == _DialogStage.downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 6),
              Text(_waitingForNetwork
                  ? _s.updateWaitingForNetwork
                  : percent == null
                      ? _s.updatePreparing
                      : _s.updatePercentDone.replaceFirst(
                          '{percent}',
                          '$percent',
                        )),
            ],
            if (_stage == _DialogStage.installing) ...[
              const SizedBox(height: 16),
              Text(_s.updateConfirmInAndroid),
              const SizedBox(height: 8),
              Text(
                _s.updateUnknownSourceNotice,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // "Nanti" only on optional updates: a mandatory one cannot be
        // dismissed, so offering a way out would be a lie.
        if (!widget.forced && _stage != _DialogStage.downloading)
          TextButton(
            onPressed: widget.onClose,
            child: Text(_s.updateLater),
          ),
        if (_stage == _DialogStage.downloading)
          TextButton(
            onPressed: () {
              _cancel?.cancel();
              setState(() => _stage = _DialogStage.ready);
            },
            child: Text(_s.updateCancelDownload),
          ),
        if (_stage != _DialogStage.downloading)
          FilledButton(
            onPressed: _download,
            child: Text(switch (_stage) {
              // After a network drop the partial file is intact, so the
              // button offers to continue rather than to start over.
              _DialogStage.failed => (_error ?? '').contains(_s.updateResumeCta)
                  ? _s.updateResumeCta
                  : _s.updateRetry,
              _DialogStage.installing => _s.updateInstallAgain,
              _ => _s.updateNow,
            }),
          ),
      ],
    );
  }
}

/// Scrollable history of every release. The installed version is labelled
/// "Versi kamu", versions the update brings are labelled "Baru". Notes only -
/// an older APK can never be downloaded from here.
class _ReleaseNotesList extends StatelessWidget {
  final ScrollController controller;
  final List<_ReleaseNote> releases;
  final int installedBuild;

  const _ReleaseNotesList({
    required this.controller,
    required this.releases,
    required this.installedBuild,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = stringsFor(Localizations.localeOf(context));
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      itemCount: releases.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox(height: 8) : const Divider(height: 24),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Text(
            s.changelogTitle,
            style: Theme.of(context).textTheme.titleLarge,
          );
        }
        final r = releases[i - 1];
        final isNew = r.build > installedBuild;
        final isCurrent = r.build == installedBuild;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isNew ? scheme.primary.withValues(alpha: 0.08) : null,
            borderRadius: BorderRadius.circular(12),
            border: isCurrent ? Border.all(color: scheme.outline) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${s.version} ${r.version}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: 8),
                  if (isNew) _Chip(label: s.newBadge, color: scheme.primary),
                  if (isCurrent)
                    _Chip(label: s.youAreHere, color: scheme.outline),
                  const Spacer(),
                  if (r.date != null)
                    Text(r.date!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              if (r.notes.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(r.notes),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
