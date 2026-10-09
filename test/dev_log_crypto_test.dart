import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcook/core/services/dev_log_crypto.dart';

String _b64u(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List _un(String s) =>
    Uint8List.fromList(base64Url.decode(base64Url.normalize(s)));

/// Server side, written independently of DevLogCrypto.seal so the two cannot
/// share a bug: opens an envelope with the matching private key.
Future<Map<String, dynamic>> _open(
  Map<String, dynamic> env,
  SimpleKeyPair serverKey, {
  String? aadOverride,
}) async {
  final x = X25519();
  final shared = await x.sharedSecretKey(
    keyPair: serverKey,
    remotePublicKey:
        SimplePublicKey(_un(env['k'] as String), type: KeyPairType.x25519),
  );
  final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
    secretKey: shared,
    nonce: _un(env['k'] as String),
    info: utf8.encode('smartcook-devlog-v1|${env['kid']}'),
  );
  final sealed = _un(env['c'] as String);
  final box = SecretBox(
    sealed.sublist(0, sealed.length - 16),
    nonce: _un(env['n'] as String),
    mac: Mac(sealed.sublist(sealed.length - 16)),
  );
  final plain = await AesGcm.with256bits().decrypt(
    box,
    secretKey: key,
    aad: utf8
        .encode(aadOverride ?? 'smartcook-devlog-v1|${env['kid']}|${env['k']}'),
  );
  return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
}

void main() {
  final events = [
    {'e': 'app_launch', 'note': 'rahasia sultan@gmail.com'},
    {'e': 'api_call', 'status': 200},
  ];

  late SimpleKeyPair server;
  late String pub;
  setUp(() async {
    server = await X25519().newKeyPair();
    pub = _b64u((await server.extractPublicKey()).bytes);
  });

  test('round trip with the server private key', () async {
    final env =
        await DevLogCrypto.seal(events, serverKey: pub, kid: 'abcd1234');
    final body = await _open(env, server);
    expect(body['events'], events);
    expect((body['t'] as int) > 0, isTrue);
  });

  test('envelope has the agreed shape, unpadded base64url, 32B key, 12B nonce',
      () async {
    final env =
        await DevLogCrypto.seal(events, serverKey: pub, kid: 'abcd1234');
    expect(env.keys.toSet(), {'v', 'kid', 'k', 'n', 'c'});
    expect(env['v'], 1);
    for (final f in ['k', 'n', 'c']) {
      expect(env[f] as String, isNot(contains('=')));
      expect(env[f] as String, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    }
    expect(_un(env['k'] as String).length, 32);
    expect(_un(env['n'] as String).length, 12);
  });

  test('nothing readable on the wire', () async {
    final wire = jsonEncode(
        await DevLogCrypto.seal(events, serverKey: pub, kid: 'abcd1234'));
    for (final needle in ['rahasia', 'gmail', 'app_launch', 'api_call']) {
      expect(wire.contains(needle), isFalse);
    }
  });

  test('fresh ephemeral key and nonce every batch', () async {
    final a = await DevLogCrypto.seal(events, serverKey: pub, kid: 'abcd1234');
    final b = await DevLogCrypto.seal(events, serverKey: pub, kid: 'abcd1234');
    expect(a['k'], isNot(b['k']));
    expect(a['n'], isNot(b['n']));
    expect(a['c'], isNot(b['c']));
  });

  test('a different server key cannot open it', () async {
    final env =
        await DevLogCrypto.seal(events, serverKey: pub, kid: 'abcd1234');
    final stranger = await X25519().newKeyPair();
    expect(_open(env, stranger), throwsA(anything));
  });

  test('tampering is detected: ciphertext bit flip and AAD mismatch', () async {
    final env =
        await DevLogCrypto.seal(events, serverKey: pub, kid: 'abcd1234');
    final raw = _un(env['c'] as String);
    raw[3] ^= 1;
    expect(_open({...env, 'c': _b64u(raw)}, server), throwsA(anything));
    expect(
      _open(env, server, aadOverride: 'smartcook-devlog-v1|other|${env['k']}'),
      throwsA(anything),
    );
  });

  // Cross-language check: the envelope Dart produces must be opened by the real
  // Node server code. Driven by scripts, skipped when the variables are unset.
  test('interop: write an envelope for the Node server to open', () async {
    final pubKey = Platform.environment['DEVLOG_INTEROP_PUB'];
    final kid = Platform.environment['DEVLOG_INTEROP_KID'];
    final out = Platform.environment['DEVLOG_INTEROP_OUT'];
    if (pubKey == null || kid == null || out == null) {
      markTestSkipped('DEVLOG_INTEROP_* not set');
      return;
    }
    final env = await DevLogCrypto.seal(
      [
        {
          'e': 'app_launch',
          'a': 'from_dart',
          'q': {'ünï': 'çödé ✓'}
        },
      ],
      serverKey: pubKey,
      kid: kid,
    );
    await File(out).writeAsString(jsonEncode(env));
  });
}
