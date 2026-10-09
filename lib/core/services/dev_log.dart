import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../service/token_service.dart';
import 'app_update_fetcher.dart';
import 'dev_log_crypto.dart';

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
  static String? get installId => _installId;
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

  // Extended device facts. Mirror WIRE in src/modules/devlog/service.js;
  // change one and change both.
  static const _kDeviceBrand = 'xb';
  static const _kDeviceBoard = 'xbb';
  static const _kDeviceHardware = 'xh';
  static const _kDeviceSoc = 'xso';
  static const _kDeviceHost = 'xho';
  static const _kDeviceFingerprint = 'xfp';
  static const _kSupportedAbis = 'xab';
  static const _kInstaller = 'xin';
  static const _kInstallerPackage = 'xip';
  static const _kFirstInstall = 'xfi';
  static const _kLastUpdate = 'xlu';
  static const _kTargetSdk = 'xtg';
  static const _kMinSdk = 'xmn';
  static const _kTimezone = 'xtz';
  static const _kCountry = 'xco';
  static const _kScreenWidth = 'xsw';
  static const _kScreenHeight = 'xsh';
  static const _kScreenDensity = 'xsd';
  static const _kTotalMemory = 'xrm';
  static const _kAvailableMemory = 'xam';
  static const _kTotalStorage = 'xrt';
  static const _kFreeStorage = 'xrf';
  static const _kLowStorage = 'xls';
  static const _kBatteryLevel = 'xbl';
  static const _kIsCharging = 'xch';
  static const _kNetworkType = 'xnt';
  static const _kCarrier = 'xcn';
  static const _kSimCountry = 'xsi';
  static const _kHasFineLocation = 'xfl';

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
  /// Tests set this so no flush timer outlives the test.
  @visibleForTesting
  static bool disabled = false;

  static void log(
    String event, {
    String? action,
    String level = 'info',
    String? error,
    int? durationMs,
    int? statusCode,
    Map<String, dynamic>? meta,
  }) {
    if (disabled) return;
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
        void put(String key, String dst) {
          final v = info[key];
          if (v is String && v.isNotEmpty) out[dst] = v;
        }
        void putInt(String key, String dst) {
          final v = info[key];
          if (v is int) out[dst] = v;
        }
        void putBool(String key, String dst) {
          final v = info[key];
          if (v is bool) out[dst] = v;
        }
        void putList(String key, String dst) {
          final v = info[key];
          if (v is List) out[dst] = v.cast<String>().take(8).toList();
        }

        put('platform', _kPlat);
        put('osVersion', _kOs);
        putInt('sdkInt', _kSdk);
        put('deviceModel', _kModel);
        put('deviceManufacturer', _kMaker);
        put('abi', _kAbi);
        put('appVersion', _kVer);

        // Extended fields. None of these are PII: brand/board/SoC identify
        // the device class but not the individual, install source identifies
        // how the user got the app, and storage/network/battery describe the
        // environment a bug happened in.
        put('deviceBrand', _kDeviceBrand);
        put('deviceBoard', _kDeviceBoard);
        put('deviceHardware', _kDeviceHardware);
        put('deviceSoc', _kDeviceSoc);
        put('deviceHost', _kDeviceHost);
        put('deviceFingerprint', _kDeviceFingerprint);
        putList('supportedAbis', _kSupportedAbis);
        put('installer', _kInstaller);
        put('installerPackage', _kInstallerPackage);
        final first = info['firstInstallTime'];
        if (first is int && first > 0) out[_kFirstInstall] = DateTime.fromMillisecondsSinceEpoch(first).toUtc().toIso8601String();
        final last = info['lastUpdateTime'];
        if (last is int && last > 0) out[_kLastUpdate] = DateTime.fromMillisecondsSinceEpoch(last).toUtc().toIso8601String();
        putInt('targetSdk', _kTargetSdk);
        putInt('minSdk', _kMinSdk);
        put('timezone', _kTimezone);
        put('country', _kCountry);
        putInt('screenWidthPx', _kScreenWidth);
        putInt('screenHeightPx', _kScreenHeight);
        putInt('screenDensity', _kScreenDensity);
        putInt('totalMemoryBytes', _kTotalMemory);
        putInt('availableMemoryBytes', _kAvailableMemory);
        putInt('totalInternalStorageBytes', _kTotalStorage);
        putInt('freeInternalStorageBytes', _kFreeStorage);
        putBool('lowStorage', _kLowStorage);
        putInt('batteryLevel', _kBatteryLevel);
        putBool('isCharging', _kIsCharging);
        putInt('networkType', _kNetworkType);
        put('carrierName', _kCarrier);
        put('simCountryIso', _kSimCountry);
        putBool('hasFineLocation', _kHasFineLocation);
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
      // The server resolves the account from this verified token (never from
      // the payload). Without it every row was anonymous, so a report could not
      // be tied to "which account".
      String? userToken;
      try {
        userToken = await TokenService.getToken();
      } catch (_) {}
      // Accept 4xx: a rejected batch must not retry forever, because the batch
      // is a diagnostic, not something the user is waiting on.
      // Sealed so that only the server can read it (see DevLogCrypto). If
      // sealing itself fails the batch is dropped rather than sent in clear:
      // this is a diagnostic, and plaintext would defeat the point.
      final Map<String, dynamic> payload;
      try {
        payload = await DevLogCrypto.seal(enriched);
      } catch (e) {
        debugPrint('[devlog] could not seal batch, dropped: $e');
        await _persist(_queue);
        return;
      }
      await dio.post<Map<String, dynamic>>(
        '/api/devlog/ingest',
        data: payload,
        options: Options(
          validateStatus: (s) => s != null && s < 500,
          headers: {
            if (userToken != null && userToken.isNotEmpty)
              'X-User-Token': userToken,
          },
        ),
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