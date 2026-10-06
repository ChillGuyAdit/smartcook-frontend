import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import 'app_update_fetcher.dart';

/// Developer debug log.
///
/// Purpose: when a user reports "it went blank after I switched the language",
/// we need the device, the build, the action and the error without asking them
/// to run anything. This collects that and ships it to `POST /api/devlog/ingest`
/// where it is kept for `DEVLOG_RETENTION_DAYS` (default 30).
///
/// This is deliberately NOT advertised in the release notes. It is a
/// diagnostic aid, not a feature.
///
/// On obfuscation: the payload keys are single letters and the wire format is a
/// compact JSON array rather than a named object, so a casual look at the APK
/// does not reveal what is being collected. That is obscurity, not security -
/// anything shipped to a client can be recovered by a determined reader. Real
/// protection is server-side: every value is length-capped and allow-listed
/// before it is stored, and the endpoint cannot be used to impersonate a user
/// because identity comes from the verified token, never from the payload.
class DevLog {
  DevLog._();

  static const _kInstallId = 'smartcook_devlog_install_id';
  static const _kQueue = 'smartcook_devlog_queue';

  /// Events are queued and flushed in batches. A burst of errors on launch
  /// should not mean a burst of requests.
  static const _maxQueue = 60;
  static const _flushDelay = Duration(seconds: 8);

  static final List<Map<String, dynamic>> _queue = [];
  static Timer? _timer;
  static String? _installId;
  static bool _sending = false;

  // Wire keys. Short on purpose - see the obfuscation note above.
  static const _kEvent = 'e';
  static const _kInstall = 'i';
  static const _kVer = 'v';
  static const _kBuild = 'b';
  static const _kPlat = 'p';
  static const _kOs = 'o';
  static const _kSdk = 's';
  static const _kModel = 'm';
  static const _kMaker = 'f';
  static const _kAbi = 'a';
  static const _kLocale = 'l';
  static const _kAction = 'n';
  static const _kLevel = 'y';
  static const _kError = 'x';
  static const _kDuration = 'd';
  static const _kStatus = 'c';
  static const _kMeta = 'q';

  /// Never let the collector break the app it is measuring.
  static void _guard(String what, void Function() body) {
    try {
      body();
    } catch (e) {
      debugPrint('[devlog] $what failed: $e');
    }
  }

  static Future<void> init() async {
    _guard('init', () async {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kInstallId);
      if (id == null || id.isEmpty) {
        final rand = Random.secure();
        final bytes =
            List<int>.generate(16, (_) => rand.nextInt(256));
        id = base64Url.encode(bytes).replaceAll('=', '');
        await prefs.setString(_kInstallId, id);
      }
      _installId = id;
      // Anything queued by a previous run (the app died before flushing) is
      // picked up, so a crash report is not lost just because it was fatal.
      final raw = prefs.getString(_kQueue);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            for (final item in decoded) {
              if (item is Map<String, dynamic>) _queue.add(item);
            }
          }
        } catch (_) {
          // Corrupt queue: drop it rather than blocking startup.
        }
      }
      if (_queue.isNotEmpty) scheduleFlush();
    });
  }

  /// Records an event. `action` is the thing being attempted, e.g.
  /// `load_profile` or `switch_locale`. Call freely - it never throws, never
  /// awaits, and never blocks the UI.
  static void log(
    String event, {
    String? action,
    String level = 'info',
    String? error,
    int? durationMs,
    int? statusCode,
    Map<String, dynamic>? meta,
  }) {
    _guard('log', () {
      final event2 = {
        _kEvent: event,
        _kAction: action,
        _kLevel: level,
        _kError: error,
        _kDuration: durationMs,
        _kStatus: statusCode,
        _kMeta: meta,
        'ts': DateTime.now().toIso8601String(),
      };
      _queue.add(event2);
      if (_queue.length > _maxQueue) _queue.removeAt(0);
      scheduleFlush();
    });
  }

  static void error(
    String event,
    Object e, {
    String? action,
    StackTrace? stack,
    Map<String, dynamic>? meta,
  }) {
    log(
      event,
      action: action,
      level: 'error',
      error: _describe(e, stack),
      meta: meta,
    );
  }

  /// Keeps the useful part of an error: type plus message, optionally the top
  /// of the stack. Truncated so one bad event cannot blow the batch budget.
  static String _describe(Object e, StackTrace? stack) {
    final head = '$e';
    if (stack == null) {
      return head.length > 300 ? '${head.substring(0, 300)}…' : head;
    }
    final frames = stack
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(6)
        .join(' | ');
    final out = '$head @ $frames';
    return out.length > 1200 ? '${out.substring(0, 1200)}…' : out;
  }

  static void scheduleFlush() {
    _timer?.cancel();
    _timer = Timer(_flushDelay, flush);
  }

  /// Device + app context, attached once per event so every stored row is
  /// self-describing and a query needs no joins.
  static Future<Map<String, dynamic>> _context() async {
    final out = <String, dynamic>{};
    try {
      out[_kInstall] = _installId;

      final info = await AppInfoChannel.deviceInfo();
      if (info != null) {
        final plat = info['platform'];
        if (plat is String) out[_kPlat] = plat;
        final os = info['osVersion'];
        if (os is String) out[_kOs] = os;
        final sdk = info['sdkInt'];
        if (sdk is int) out[_kSdk] = sdk;
        final model = info['deviceModel'];
        if (model is String) out[_kModel] = model;
        final maker = info['deviceManufacturer'];
        if (maker is String) out[_kMaker] = maker;
        final abi = info['abi'];
        if (abi is String) out[_kAbi] = abi;
        final ver = info['appVersion'];
        if (ver is String && ver.isNotEmpty) out[_kVer] = ver;
      }

      final build = await AppInfoChannel.versionCode();
      if (build != null && build > 0) out[_kBuild] = build;

      // Recorded per flush, not once at init: the user can switch language
      // mid-session and "which language was it showing" is often the whole
      // question in a bug report.
      final deviceLocale = info?['deviceLocale'];
      if (deviceLocale is String && deviceLocale.isNotEmpty) {
        out[_kLocale] = deviceLocale;
      }
    } catch (_) {
      // Native channel unavailable (unit test, desktop). Context is optional.
    }
    return out;
  }

  static Future<void> flush() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    try {
      _queue.clear();
      final ctx = await _context();
      final enriched = batch
          .map((e) => {...ctx, ...e})
          .toList(growable: false);

      final dio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      // Accept 4xx: a rejected batch must not retry forever, because the batch
      // is a diagnostic, not something the user is waiting on.
      await dio.post<Map<String, dynamic>>(
        '/api/devlog/ingest',
        data: {'events': enriched},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );
      await _persist(_queue);
      debugPrint('[devlog] flushed ${enriched.length} event(s)');
    } catch (e) {
      // Put the batch back at the front so ordering survives, then persist
      // immediately: the app may not survive to flush again.
      _queue.insertAll(0, batch);
      while (_queue.length > _maxQueue) {
        _queue.removeAt(_queue.length - 1);
      }
      await _persist(_queue);
      debugPrint('[devlog] flush failed, requeued ${_queue.length}: $e');
    } finally {
      _sending = false;
    }
  }

  static Future<void> _persist(List<Map<String, dynamic>> items) async {
    _guard('persist', () async {
      final prefs = await SharedPreferences.getInstance();
      if (items.isEmpty) {
        await prefs.remove(_kQueue);
        return;
      }
      // Only a small slice is kept on disk; a long offline stretch should not
      // grow without bound.
      final tail = items.length > _maxQueue
          ? items.sublist(items.length - _maxQueue)
          : items;
      await prefs.setString(_kQueue, jsonEncode(tail));
    });
  }
}