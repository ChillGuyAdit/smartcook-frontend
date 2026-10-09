import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../service/api_service.dart';
import '../../service/offline_manager.dart';
import 'app_update_fetcher.dart';
import 'dev_log.dart';

/// A tiny reading of the phone, sent once a minute while the app is open.
///
/// The server answers with how soon it wants the next one: normally a minute,
/// a couple of seconds while somebody is looking at this phone, and the app
/// goes back to a minute on its own when that stops. Nothing is sent while the
/// app is in the background, and a failure is silent.
class Pulse with WidgetsBindingObserver {
  Pulse._();
  static final Pulse instance = Pulse._();

  static const int slow = 30;
  static const int minSeconds = 2;
  static const int maxSeconds = 300;

  Timer? _timer;
  int _next = slow;
  bool _foreground = true;
  bool _started = false;
  bool _busy = false;
  bool _hwSent = false;

  /// Seconds until the next reading, from the server's answer. Pure, so it can
  /// be tested: a bad value falls back to a minute, a low battery that is not
  /// charging never goes faster than every 3 minutes unless watched.
  static int nextDelay(dynamic answer, {int? battery, bool charging = false}) {
    var n = slow;
    var watch = false;
    if (answer is Map) {
      final v = answer['next'];
      if (v is num) n = v.toInt();
      watch = answer['watch'] == true;
    }
    n = n.clamp(minSeconds, maxSeconds);
    if (!watch && battery != null && battery < 15 && !charging && n < 180)
      n = 180;
    return n;
  }

  void start() {
    if (_started || kIsWeb || !Platform.isAndroid) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule(const Duration(seconds: 15));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _next = slow;
      _schedule(const Duration(seconds: 5));
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _timer?.cancel();
    }
  }

  void _schedule(Duration after) {
    _timer?.cancel();
    if (!_foreground) return;
    _timer = Timer(after, _send);
  }

  Future<void> _send() async {
    if (!_foreground || _busy) return;
    final id = DevLog.installId;
    if (id == null || OfflineManager.isOffline.value) {
      _schedule(Duration(seconds: _next));
      return;
    }
    _busy = true;
    var next = slow;
    try {
      final stats =
          await AppInfoChannel.liveStats() ?? const <String, dynamic>{};
      // Hardware facts travel once per launch, with the first reading that gets through.
      final hw = _hwSent ? null : await AppInfoChannel.hardwareInfo();
      final res = await ApiService.post('/api/telemetry/beat', body: {
        'installId': id,
        ...stats,
        'fg': true,
        if (hw != null) 'hw': hw,
      });
      if (res.success && hw != null) _hwSent = true;
      final battery = (stats['battery'] as num?)?.toInt();
      next = nextDelay(res.success ? res.data : null,
          battery: battery, charging: stats['charging'] == true);
    } catch (_) {
      next = slow;
    } finally {
      _busy = false;
    }
    _next = next;
    _schedule(Duration(seconds: next));
  }
}
