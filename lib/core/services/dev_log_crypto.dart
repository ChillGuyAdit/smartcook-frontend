import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Seals a developer-log batch so only the SmartCook server can read it.
///
/// X25519 key agreement with a fresh ephemeral key per batch, HKDF-SHA256,
/// then AES-256-GCM. The app holds only the server's PUBLIC key, which can
/// lock but never unlock, so unpacking the APK reveals nothing that decrypts
/// traffic. The matching private key lives in the server's `.env`.
///
/// Wire format and checks mirror
/// `smartcook-backend/src/modules/devlog/crypto.js` - change both together.
/// Confidentiality and integrity only: anyone can encrypt to a public key.
class DevLogCrypto {
  DevLogCrypto._();

  /// Server public key (raw X25519, base64url) and its id. Public by design.
  /// Override at build time with --dart-define=DEVLOG_PUBLIC_KEY=... when the
  /// server key is rotated.
  static const String serverPublicKey = String.fromEnvironment(
    'DEVLOG_PUBLIC_KEY',
    defaultValue: '803R9Mq7rTmUD2TGbTLOItyckXrMciOZMByT3j43LxU',
  );
  static const String keyId = String.fromEnvironment(
    'DEVLOG_KEY_ID',
    defaultValue: '4e3f0250',
  );

  static const int _version = 1;
  static const String _infoPrefix = 'smartcook-devlog-v1|';

  static final X25519 _x25519 = X25519();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static final AesGcm _aes = AesGcm.with256bits();

  static String _b64u(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _unb64u(String s) =>
      Uint8List.fromList(base64Url.decode(base64Url.normalize(s)));

  /// Encrypts `{t, events}` and returns the envelope to POST. `serverKey`,
  /// `kid` and `now` exist so tests can pin them.
  static Future<Map<String, dynamic>> seal(
    List<Map<String, dynamic>> events, {
    String? serverKey,
    String? kid,
    DateTime? now,
  }) async {
    final keyB64 = serverKey ?? serverPublicKey;
    final id = kid ?? keyId;

    final eph = await _x25519.newKeyPair();
    final ephPub = (await eph.extractPublicKey()).bytes;
    final shared = await _x25519.sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(_unb64u(keyB64), type: KeyPairType.x25519),
    );
    // Same derivation as the server: salt = ephemeral public key.
    final aesKey = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: ephPub,
      info: utf8.encode('$_infoPrefix$id'),
    );

    final k = _b64u(ephPub);
    final nonce = _randomBytes(12);
    final plaintext = utf8.encode(jsonEncode({
      't': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'events': events,
    }));
    final box = await _aes.encrypt(
      plaintext,
      secretKey: aesKey,
      nonce: nonce,
      aad: utf8.encode('$_infoPrefix$id|$k'),
    );

    return {
      'v': _version,
      'kid': id,
      'k': k,
      'n': _b64u(nonce),
      'c': _b64u([...box.cipherText, ...box.mac.bytes]),
    };
  }

  static Uint8List _randomBytes(int n) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
  }
}
