import 'dart:convert';

import 'package:flutter/painting.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/services/secure_channel.dart';
import 'package:smartcook/core/theme/language_controller.dart';

// Failure behaviour of the client side of the encrypted channel, with a fake
// transport (no server). The happy paths against the real server code live in
// secure_channel_interop_test.dart.

void main() {
  final api = Uri.parse('https://api.himatif-encoder.com');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureChannel.originOverride = null;
    SecureChannel.testPublicKey = null;
    SecureChannel.testKeyId = null;
    SecureChannel.resetClock();
  });

  test('exempt paths are not sealed: the fake transport sees the real request', () async {
    final seen = <http.BaseRequest>[];
    final client = SecureHttpClient(MockClient.streaming((req, body) async {
      seen.add(req);
      return http.StreamedResponse(Stream.value(utf8.encode('{"ok":true}')), 200,
          headers: {'content-type': 'application/json'});
    }));

    await client.get(api.replace(path: '/api/app/version'));
    await client.get(api.replace(path: '/api/health'));
    await client.post(api.replace(path: '/api/devlog/ingest'), body: '{}');

    expect(seen.map((r) => r.url.path), ['/api/app/version', '/api/health', '/api/devlog/ingest']);
    expect(seen.map((r) => r.method), ['GET', 'GET', 'POST']);
  });

  test('every request tells the server which language the app is set to', () async {
    final seen = <http.BaseRequest>[];
    final client = SecureHttpClient(MockClient.streaming((req, body) async {
      seen.add(req);
      return http.StreamedResponse(Stream.value(utf8.encode('{}')), 200,
          headers: {'content-type': 'application/json'});
    }));
    await LanguageController.instance.set(const Locale('en'));
    await client.get(api.replace(path: '/api/health'));
    await LanguageController.instance.set(const Locale('id'));
    await client.get(api.replace(path: '/api/health'));
    expect(seen.map((r) => r.headers['X-Smartcook-Locale']), ['en', 'id']);
  });

  test('every other API call goes out as POST /api/secure with nothing readable', () async {
    http.BaseRequest? seen;
    String? sent;
    final client = SecureHttpClient(MockClient((req) async {
      seen = req;
      sent = req.body;
      return http.Response('{"success":false,"code":"SECURE_BAD"}', 400,
          headers: {'content-type': 'application/json'});
    }));

    await client.post(
      api.replace(path: '/api/auth/login'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer topsecret'},
      body: jsonEncode({'email': 'sultan@gmail.com', 'password': 'hunter2'}),
    );

    expect(seen!.method, 'POST');
    expect(seen!.url.path, '/api/secure');
    expect(seen!.url.hasQuery, isFalse);
    for (final needle in ['login', 'sultan', 'gmail', 'hunter2', 'topsecret', 'Bearer', 'email']) {
      expect(sent!.contains(needle), isFalse, reason: 'wire leaks "$needle"');
    }
    expect(jsonDecode(sent!).keys.toSet(), {'v', 'kid', 'k', 'n', 'c'});
  });

  test('a plain answer from the channel or a proxy is handed through untouched', () async {
    final client = SecureHttpClient(MockClient((req) async => http.Response(
          '{"success":false,"code":"UPDATE_REQUIRED","message":"Perbarui aplikasi"}',
          426,
          headers: {'content-type': 'application/json'},
        )));
    final r = await client.get(api.replace(path: '/api/recipes'));
    expect(r.statusCode, 426);
    expect(jsonDecode(r.body)['code'], 'UPDATE_REQUIRED');
  });

  test('an HTML error page from a proxy does not crash the client', () async {
    final client = SecureHttpClient(MockClient((req) async => http.Response(
          '<html><body>502 Bad Gateway</body></html>',
          502,
          headers: {'content-type': 'text/html'},
        )));
    final r = await client.get(api.replace(path: '/api/recipes'));
    expect(r.statusCode, 502);
    expect(r.body, contains('Bad Gateway'));
  });

  test('a server that keeps reporting clock skew is retried exactly once', () async {
    var calls = 0;
    final client = SecureHttpClient(MockClient((req) async {
      calls++;
      return http.Response(
        jsonEncode({
          'success': false,
          'code': 'SECURE_CLOCK_SKEW',
          'serverTime': DateTime.now().millisecondsSinceEpoch,
        }),
        400,
        headers: {'content-type': 'application/json'},
      );
    }));
    final r = await client.get(api.replace(path: '/api/recipes'));
    expect(calls, 2, reason: 'one attempt + one retry, never a loop');
    expect(r.statusCode, 400);
  });

  test('a network failure surfaces as an exception, never as a silent plaintext retry', () async {
    final paths = <String>[];
    final client = SecureHttpClient(MockClient((req) async {
      paths.add(req.url.path);
      throw http.ClientException('connection reset');
    }));
    await expectLater(client.get(api.replace(path: '/api/recipes')), throwsA(isA<http.ClientException>()));
    expect(paths, ['/api/secure'], reason: 'the real path is never sent in the clear');
  });

  test('requests to other hosts are not touched', () async {
    Uri? seen;
    final client = SecureHttpClient(MockClient((req) async {
      seen = req.url;
      return http.Response('ok', 200);
    }));
    await client.get(Uri.parse('https://example.org/api/recipes'));
    expect(seen.toString(), 'https://example.org/api/recipes');
  });

  test('every sealed request is different: fresh key, nonce and ciphertext', () async {
    final bodies = <String>[];
    final client = SecureHttpClient(MockClient((req) async {
      bodies.add(req.body);
      return http.Response('{"code":"SECURE_BAD"}', 400, headers: {'content-type': 'application/json'});
    }));
    for (var i = 0; i < 3; i++) {
      await client.get(api.replace(path: '/api/recipes'));
    }
    final envs = bodies.map((b) => jsonDecode(b) as Map<String, dynamic>).toList();
    expect(envs.map((e) => e['k']).toSet().length, 3);
    expect(envs.map((e) => e['n']).toSet().length, 3);
    expect(envs.map((e) => e['c']).toSet().length, 3);
  });
}
