import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:smartcook/core/services/secure_channel.dart';

// Real cross-language test: the Dart client talks over loopback HTTP to the
// actual Node server stack (scripts/secure-interop-server.js in the backend:
// Express + compression + the secure-channel middleware).
//
// Driven by scripts, skipped when the variables are not set:
//   SECURE_INTEROP_URL         e.g. http://127.0.0.1:41234   (compat mode)
//   SECURE_INTEROP_STRICT_URL  e.g. http://127.0.0.1:41235   (API_REQUIRE_ENCRYPTED)
//   SECURE_INTEROP_PUB / SECURE_INTEROP_KID

String? _env(String k) => Platform.environment[k];

void main() {
  final url = _env('SECURE_INTEROP_URL');
  final strictUrl = _env('SECURE_INTEROP_STRICT_URL');
  final pub = _env('SECURE_INTEROP_PUB');
  final kid = _env('SECURE_INTEROP_KID');
  final skip = (url == null || strictUrl == null || pub == null || kid == null)
      ? 'SECURE_INTEROP_* not set'
      : false;

  late SecureHttpClient client;
  late Uri base;

  setUp(() {
    client = SecureHttpClient(http.Client());
    if (skip != false) return;
    base = Uri.parse(url!);
    SecureChannel.originOverride = base;
    SecureChannel.testPublicKey = pub;
    SecureChannel.testKeyId = kid;
    SecureChannel.resetClock();
  });

  tearDown(() {
    client.close();
    SecureChannel.originOverride = null;
    SecureChannel.testPublicKey = null;
    SecureChannel.testKeyId = null;
  });

  test('GET with query and headers reaches the route intact', () async {
    final r = await client.get(
      base.replace(path: '/api/echo', query: 'q=nasi%20goreng&page=2'),
      headers: {
        'Authorization': 'Bearer abc',
        'X-User-Token': 'jwt.value',
        'X-Smartcook-Build': '15',
        'Accept': 'application/json',
      },
    );
    expect(r.statusCode, 200);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    expect(j['query'], {'q': 'nasi goreng', 'page': '2'});
    expect(j['auth'], 'Bearer abc');
    expect(j['userToken'], 'jwt.value');
    expect(j['build'], '15');
  }, skip: skip);

  test('POST JSON body and a non-200 success status come back correctly', () async {
    final r = await client.post(
      base.replace(path: '/api/echo'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer t'},
      body: jsonEncode({'email': 'a@b.co', 'n': [1, 2], 'teks': 'çödé ✓'}),
    );
    expect(r.statusCode, 201);
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    expect(j['body'], {'email': 'a@b.co', 'n': [1, 2], 'teks': 'çödé ✓'});
    expect(j['auth'], 'Bearer t');
  }, skip: skip);

  test('DELETE with a body, 403, 429 + Retry-After and 500 keep their status', () async {
    final del = http.Request('DELETE', base.replace(path: '/api/echo'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'reason': 'x'});
    final dr = await http.Response.fromStream(await client.send(del));
    expect(jsonDecode(dr.body)['body'], {'reason': 'x'});

    final denied = await client.get(base.replace(path: '/api/denied'));
    expect(denied.statusCode, 403);
    expect(jsonDecode(denied.body)['code'], 'FORBIDDEN_X');

    final limited = await client.get(base.replace(path: '/api/limited'));
    expect(limited.statusCode, 429);
    expect(limited.headers['retry-after'], '7');

    final boom = await client.get(base.replace(path: '/api/boom'));
    expect(boom.statusCode, 500);
  }, skip: skip);

  test('empty bodies, unicode and large compressed responses survive', () async {
    final empty = await client.get(base.replace(path: '/api/empty'));
    expect(empty.statusCode, 204);
    expect(empty.body, '');

    final uni = await client.get(base.replace(path: '/api/unicode'));
    expect(jsonDecode(uni.body)['teks'], 'Ayam goreng çödé ✓ 🍛');

    final big = await client.get(base.replace(path: '/api/big'));
    expect((jsonDecode(big.body)['rows'] as List).length, 5000);
  }, skip: skip);

  test('chat streaming: sealed frames are decrypted back into the original SSE', () async {
    final req = http.Request('POST', base.replace(path: '/api/chat/message-stream'))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer s'
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode({'message': 'resep apa?'});
    final resp = await client.send(req);
    expect(resp.statusCode, 200);

    // Same parsing the chat page does.
    var buffer = '';
    final events = <Map<String, dynamic>>[];
    await for (final chunk in resp.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final parts = buffer.split('\n\n');
      buffer = parts.removeLast();
      for (final part in parts) {
        for (final line in part.split('\n')) {
          if (line.startsWith('data: ')) {
            events.add(jsonDecode(line.substring(6)) as Map<String, dynamic>);
          }
        }
      }
    }
    expect(events.first['status'], 'connected');
    expect(events.where((e) => e['text'] != null).map((e) => e['text']).join(), 'Halo dunia!');
    expect(events.last['done'], true);
    expect(events.last['fullReply'], 'Halo dunia! resep apa?');
  }, skip: skip);

  test('a phone clock 15 minutes wrong is corrected and the request retried', () async {
    SecureChannel.noteServerTime(DateTime.now().millisecondsSinceEpoch - 15 * 60 * 1000);
    expect(SecureChannel.skewMs.abs() > 10 * 60 * 1000, isTrue);

    final r = await client.get(
      base.replace(path: '/api/echo'),
      headers: {'Authorization': 'Bearer clock'},
    );
    expect(r.statusCode, 200);
    expect(jsonDecode(r.body)['auth'], 'Bearer clock');
    expect(SecureChannel.skewMs.abs() < 60 * 1000, isTrue, reason: 'offset learned from the server');
  }, skip: skip);

  test('exempt paths (update check, health) still work in the clear', () async {
    final v = await client.get(base.replace(path: '/api/app/version'));
    expect(v.statusCode, 200);
    expect(jsonDecode(v.body)['data']['latestBuild'], 99);
    expect((await client.get(base.replace(path: '/api/health'))).statusCode, 200);
  }, skip: skip);

  test('Dio interceptor: handshake-style POST, 403 does not throw, 500 does', () async {
    final dio = Dio(BaseOptions(
      baseUrl: base.toString(),
      validateStatus: (s) => s != null && s < 500,
    ))
      ..interceptors.add(SecureDioInterceptor(http.Client()));

    final ok = await dio.post<Map<String, dynamic>>(
      '/api/echo',
      data: {'build': 15},
      options: Options(headers: {'X-Smartcook-Cert': 'abc123'}),
    );
    expect(ok.statusCode, 201);
    expect(ok.data!['body'], {'build': 15});
    expect(ok.data!['cert'], 'abc123');

    final denied = await dio.get<Map<String, dynamic>>('/api/denied');
    expect(denied.statusCode, 403);
    expect(denied.data!['code'], 'FORBIDDEN_X');

    final del = await dio.delete<Map<String, dynamic>>(
      '/api/echo',
      data: {'reason': 'client_logout'},
      options: Options(headers: {'Authorization': 'Bearer r'}),
    );
    expect(del.data!['auth'], 'Bearer r');

    await expectLater(
      dio.get<Map<String, dynamic>>('/api/boom'),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 500)),
    );
  }, skip: skip);

  test('strict server: a plain request is refused with UPDATE_REQUIRED, sealed still works',
      () async {
    final strict = Uri.parse(strictUrl ?? 'http://127.0.0.1:1');
    SecureChannel.originOverride = strict;

    final plain = await http.get(strict.replace(path: '/api/echo'),
        headers: {'Authorization': 'Bearer old-app'});
    expect(plain.statusCode, 426);
    expect(jsonDecode(plain.body)['code'], 'UPDATE_REQUIRED');

    // An old app can still see the update dialog.
    expect((await http.get(strict.replace(path: '/api/app/version'))).statusCode, 200);

    final sealed = await client.get(strict.replace(path: '/api/echo'),
        headers: {'Authorization': 'Bearer new-app'});
    expect(sealed.statusCode, 200);
    expect(jsonDecode(sealed.body)['auth'], 'Bearer new-app');
  }, skip: skip);

  test('strict server + Dio: the interceptor really seals (a plain Dio is refused)', () async {
    final strict = Uri.parse(strictUrl ?? 'http://127.0.0.1:1');
    SecureChannel.originOverride = strict;

    final plainDio = Dio(BaseOptions(
      baseUrl: strict.toString(),
      validateStatus: (s) => s != null && s < 500,
    ));
    final refused = await plainDio.post<Map<String, dynamic>>('/api/echo', data: {'build': 15});
    expect(refused.statusCode, 426);

    final sealedDio = Dio(BaseOptions(
      baseUrl: strict.toString(),
      validateStatus: (s) => s != null && s < 500,
    ))
      ..interceptors.add(SecureDioInterceptor(http.Client()));
    final ok = await sealedDio.post<Map<String, dynamic>>(
      '/api/echo',
      data: {'build': 15},
      options: Options(headers: {'X-Smartcook-Cert': 'abc'}),
    );
    expect(ok.statusCode, 201);
    expect(ok.data!['body'], {'build': 15});
  }, skip: skip);

  test('unrelated hosts are never sealed', () {
    SecureChannel.originOverride = null;
    expect(SecureChannel.shouldSeal('GET', Uri.parse('https://example.org/api/echo')), isFalse);
  });
}
