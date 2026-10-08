import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpDate;
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// End-to-end encrypted API channel to the SmartCook server.
///
/// HTTPS ends at Cloudflare, which can therefore read every request. Here each
/// request (method, url, headers, body) is sealed to the server's PUBLIC key
/// and sent as `POST /api/secure`; the server opens it, runs the normal route
/// and seals the answer. A proxy only sees random bytes.
///
/// Per request: ephemeral X25519 -> HKDF-SHA256 -> AES-256-GCM. Request and
/// response use different keys, the response is bound to the request nonce,
/// and SSE (chat streaming) is sealed frame by frame.
///
/// Confidentiality and integrity only: the public key is in the APK, so this
/// does not prove who the client is. Mirrors
/// `smartcook-backend/src/modules/secure/channel.js` - change both together.
class SecureChannel {
  SecureChannel._();

  /// Server public key (raw X25519, base64url) and its id. Public by design.
  /// Override with --dart-define=API_PUBLIC_KEY=... / API_KEY_ID=... after a
  /// key rotation.
  static const String publicKey = String.fromEnvironment(
    'API_PUBLIC_KEY',
    defaultValue: 'MUMPRKCsBFsob5DrKtzSMU87mDoYXMIOjn87p-HhsmE',
  );
  static const String keyId = String.fromEnvironment(
    'API_KEY_ID',
    defaultValue: '693883c2',
  );

  /// Build-time kill switch for development against a server without the key:
  /// --dart-define=SECURE_API=false
  static const bool enabled = bool.fromEnvironment('SECURE_API', defaultValue: true);

  static const String _label = 'smartcook-api-v1';

  /// Tests point the client at a local server with its own key.
  @visibleForTesting
  static Uri? originOverride;
  @visibleForTesting
  static String? testPublicKey;
  @visibleForTesting
  static String? testKeyId;

  static Uri get _origin => originOverride ?? Uri.parse(ApiConfig.baseUrl);

  /// Only these inner headers are honoured by the server.
  static const Set<String> _forwarded = {
    'authorization',
    'x-user-token',
    'x-smartcook-build',
    'x-smartcook-cert',
    'x-smartcook-locale',
    'accept-language',
    'content-type',
  };

  static final X25519 _x25519 = X25519();
  static final AesGcm _aes = AesGcm.with256bits();
  static Hkdf _hkdf() => Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  // ----------------------------------------------------------------- clock
  // The server rejects requests more than 5 minutes off its own clock (replay
  // protection). A phone with a wrong clock would be locked out, so the offset
  // is learned from the `Date` header and from the server's own skew error.
  static int _skewMs = 0;

  @visibleForTesting
  static int get skewMs => _skewMs;

  @visibleForTesting
  static void resetClock() => _skewMs = 0;

  static int nowMs() => DateTime.now().millisecondsSinceEpoch + _skewMs;

  static void noteServerTime(int serverMs) {
    _skewMs = serverMs - DateTime.now().millisecondsSinceEpoch;
  }

  static void _noteDateHeader(String? date) {
    if (date == null) return;
    try {
      final diff = HttpDate.parse(date).millisecondsSinceEpoch -
          DateTime.now().millisecondsSinceEpoch;
      // Ignore normal jitter; only correct a clock that is really wrong.
      _skewMs = diff.abs() > 30000 ? diff : 0;
    } catch (_) {}
  }

  // ----------------------------------------------------------------- scope
  /// Paths that stay plaintext on purpose: the update check/download (an old
  /// or blocked app must always be able to learn it needs updating), the
  /// liveness probe, and the developer log (it has its own envelope).
  static bool isExempt(String method, String path) {
    if (method == 'OPTIONS') return true;
    if (method == 'GET' && (path.startsWith('/api/app/') || path == '/api/health')) {
      return true;
    }
    if (method == 'POST' && path == '/api/devlog/ingest') return true;
    return false;
  }

  /// Whether a request to [uri] with [method] goes through the sealed channel.
  static bool shouldSeal(String method, Uri uri) {
    if (!enabled) return false;
    final api = _origin;
    if (uri.host != api.host || uri.port != api.port) return false;
    return !isExempt(method.toUpperCase(), uri.path);
  }

  // ---------------------------------------------------------------- base64
  static String _b64u(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');
  static Uint8List _unb64u(String s) =>
      Uint8List.fromList(base64Url.decode(base64Url.normalize(s)));
  static Uint8List _randomBytes(int n) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
  }

  // ------------------------------------------------------------------ seal
  static Future<SealedRequest> seal({
    required String method,
    required String url,
    Map<String, String> headers = const {},
    String? body,
    String? serverKey,
    String? kid,
    int? nowMsOverride,
  }) async {
    final keyB64 = serverKey ?? testPublicKey ?? publicKey;
    final id = kid ?? testKeyId ?? keyId;

    final eph = await _x25519.newKeyPair();
    final ephPub = (await eph.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(_unb64u(keyB64), type: KeyPairType.x25519),
    );
    final reqKey = await _hkdf().deriveKey(
      secretKey: shared,
      nonce: ephPub,
      info: utf8.encode('$_label|$id'),
    );
    final respKey = await _hkdf().deriveKey(
      secretKey: shared,
      nonce: ephPub,
      info: utf8.encode('$_label|resp|$id'),
    );

    final innerHeaders = <String, String>{};
    headers.forEach((k, v) {
      final lower = k.toLowerCase();
      if (_forwarded.contains(lower)) innerHeaders[lower] = v;
    });

    final k = _b64u(ephPub);
    final nonce = _randomBytes(12);
    final plaintext = utf8.encode(jsonEncode({
      't': nowMsOverride ?? nowMs(),
      'm': method.toUpperCase(),
      'u': url,
      'h': innerHeaders,
      'b': body,
    }));
    final box = await _aes.encrypt(
      plaintext,
      secretKey: reqKey,
      nonce: nonce,
      aad: utf8.encode('$_label|$id|$k'),
    );
    final n = _b64u(nonce);
    return SealedRequest(
      envelope: {
        'v': 1,
        'kid': id,
        'k': k,
        'n': n,
        'c': _b64u([...box.cipherText, ...box.mac.bytes]),
      },
      respKey: respKey,
      reqNonce: n,
    );
  }

  static Future<SecureReply> openResponse(
    Map<String, dynamic> envelope,
    SealedRequest req,
  ) async {
    final sealed = _unb64u(envelope['c'] as String);
    final plain = await _aes.decrypt(
      SecretBox(
        sealed.sublist(0, sealed.length - 16),
        nonce: _unb64u(envelope['n'] as String),
        mac: Mac(sealed.sublist(sealed.length - 16)),
      ),
      secretKey: req.respKey,
      aad: utf8.encode('$_label|resp|${req.reqNonce}'),
    );
    final m = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return SecureReply(
      status: (m['s'] as num).toInt(),
      headers: {
        for (final e in ((m['h'] as Map?) ?? const {}).entries)
          e.key.toString(): e.value.toString(),
      },
      body: (m['b'] as String?) ?? '',
    );
  }

  /// Decrypts an SSE stream frame by frame and re-emits the original chunks
  /// (`data: {...}\n\n`), so existing stream parsers keep working unchanged.
  static Stream<List<int>> openStream(
    Stream<List<int>> outer,
    SealedRequest req,
  ) async* {
    var buffer = '';
    var index = 0;
    await for (final chunk in outer.cast<List<int>>().transform(utf8.decoder)) {
      buffer += chunk;
      final parts = buffer.split('\n\n');
      buffer = parts.removeLast();
      for (final part in parts) {
        for (final line in part.split('\n')) {
          if (!line.startsWith('data: ')) continue;
          final raw = _unb64u(line.substring(6).trim());
          final plain = await _aes.decrypt(
            SecretBox(
              raw.sublist(12, raw.length - 16),
              nonce: raw.sublist(0, 12),
              mac: Mac(raw.sublist(raw.length - 16)),
            ),
            secretKey: req.respKey,
            aad: utf8.encode('$_label|frame|${req.reqNonce}|${index++}'),
          );
          yield plain;
        }
      }
    }
  }

  // -------------------------------------------------------------- exchange
  /// Sends one request through the sealed channel using [inner] for the actual
  /// HTTPS call. Retries once if the server says our clock is off.
  static Future<SecureOutcome> exchange({
    required http.Client inner,
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    final url = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
    final origin = _origin;
    final target = origin.replace(path: '/api/secure');

    for (var attempt = 0;; attempt++) {
      final sealed = await seal(method: method, url: url, headers: headers, body: body);
      final outerReq = http.Request('POST', target)
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(sealed.envelope);
      final outer = await inner.send(outerReq);
      _noteDateHeader(outer.headers['date']);

      final type = outer.headers['content-type'] ?? '';
      if (outer.statusCode == 200 && type.contains('text/event-stream')) {
        return SecureOutcome(
          status: 200,
          headers: const {'content-type': 'text/event-stream'},
          stream: openStream(outer.stream, sealed),
        );
      }

      final bytes = await outer.stream.toBytes();
      Object? parsed;
      try {
        parsed = jsonDecode(utf8.decode(bytes));
      } catch (_) {}

      if (parsed is Map && parsed['v'] == 1 && parsed['c'] is String) {
        final reply = await openResponse(Map<String, dynamic>.from(parsed), sealed);
        return SecureOutcome(
          status: reply.status,
          headers: reply.headers,
          stream: Stream.value(utf8.encode(reply.body)),
        );
      }

      if (attempt == 0 &&
          parsed is Map &&
          parsed['code'] == 'SECURE_CLOCK_SKEW' &&
          parsed['serverTime'] is num) {
        noteServerTime((parsed['serverTime'] as num).toInt());
        continue;
      }

      // Anything else is a plain answer from the channel or a proxy (for
      // example 426 UPDATE_REQUIRED, or an HTML error page): hand it through.
      return SecureOutcome(
        status: outer.statusCode,
        headers: outer.headers,
        stream: Stream.value(bytes),
      );
    }
  }
}

class SealedRequest {
  SealedRequest({required this.envelope, required this.respKey, required this.reqNonce});
  final Map<String, dynamic> envelope;
  final SecretKey respKey;
  final String reqNonce;
}

class SecureReply {
  SecureReply({required this.status, required this.headers, required this.body});
  final int status;
  final Map<String, String> headers;
  final String body;
}

class SecureOutcome {
  SecureOutcome({required this.status, required this.headers, required this.stream});
  final int status;
  final Map<String, String> headers;
  final Stream<List<int>> stream;
}

/// Drop-in [http.Client] that seals every API request. Requests to other hosts
/// and the exempt paths go straight through.
class SecureHttpClient extends http.BaseClient {
  SecureHttpClient([http.Client? inner]) : _inner = inner ?? http.Client();

  /// One shared instance for the whole app (keeps connections alive).
  static final SecureHttpClient shared = SecureHttpClient();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!SecureChannel.shouldSeal(request.method, request.url)) {
      return _inner.send(request);
    }
    final bytes = await request.finalize().toBytes();
    final out = await SecureChannel.exchange(
      inner: _inner,
      method: request.method,
      uri: request.url,
      headers: request.headers,
      body: bytes.isEmpty ? null : utf8.decode(bytes),
    );
    return http.StreamedResponse(
      out.stream,
      out.status,
      request: request,
      headers: out.headers,
    );
  }

  @override
  void close() => _inner.close();
}

/// Same sealing for the Dio instance that talks to the session endpoints.
class SecureDioInterceptor extends Interceptor {
  SecureDioInterceptor([http.Client? inner]) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final uri = options.uri;
    if (!SecureChannel.shouldSeal(options.method, uri)) {
      return handler.next(options);
    }
    try {
      final data = options.data;
      final body = data == null ? null : (data is String ? data : jsonEncode(data));
      final headers = <String, String>{
        for (final e in options.headers.entries) e.key: '${e.value}',
        if (body != null) 'Content-Type': 'application/json',
      };
      final out = await SecureChannel.exchange(
        inner: _inner,
        method: options.method,
        uri: uri,
        headers: headers,
        body: body,
      );
      final bytes = await out.stream.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      final text = utf8.decode(bytes);
      Object? decoded;
      if (text.isNotEmpty) {
        try {
          decoded = jsonDecode(text);
        } catch (_) {
          decoded = text;
        }
      }
      final response = Response<dynamic>(
        requestOptions: options,
        statusCode: out.status,
        data: decoded,
        headers: Headers.fromMap({
          for (final e in out.headers.entries) e.key: [e.value],
        }),
      );
      // Dio's own validateStatus would have thrown on 5xx; keep that contract.
      if (options.validateStatus(out.status)) return handler.resolve(response);
      return handler.reject(
        DioException.badResponse(
          statusCode: out.status,
          requestOptions: options,
          response: response,
        ),
      );
    } catch (e, st) {
      return handler.reject(
        DioException(requestOptions: options, error: e, stackTrace: st),
      );
    }
  }
}
