import 'package:smartcook/core/services/dev_log.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart' as gSign;
import 'package:smartcook/core/network/env.dart';

/// Result of a Google sign-in attempt.
///
/// `credential` is the raw Firebase `UserCredential` (may be null on cancel
/// or upstream failure). `firebaseIdToken` is the freshly minted Firebase
/// ID token that the backend will verify via Firebase Admin.
class GoogleSignInResult {
  final UserCredential? credential;
  final String? firebaseIdToken;

  const GoogleSignInResult({this.credential, this.firebaseIdToken});

  bool get hasCredential => credential != null;
}

/// Google sign-in wrapper. The OAuth web client id is read from
/// --dart-define=GOOGLE_WEB_CLIENT_ID so the same APK works locally and
/// in release builds without committing secrets.
///
/// On Android `serverClientId` MUST be set to the OAuth web client id
/// from the Firebase console, otherwise `googleAuth.idToken` will be null
/// and the backend will reject the request (it now verifies the token).
class AuthService {
  static const String _webClientId = EnvConfig.googleWebClientId;

  /// Whether Google sign-in is wired up. When the OAuth web client id env
  /// var is empty (default), the Google button must hide itself entirely.
  static bool get isEnabled => _webClientId.isNotEmpty;

  static final gSign.GoogleSignIn _googleSignIn = gSign.GoogleSignIn(
    clientId: _webClientId,
    serverClientId: _webClientId,
  );

  /// Run the Google sign-in flow and return both the Firebase credential
  /// AND a fresh Firebase ID token (force-refreshed) that the backend can
  /// verify.
  ///
  /// Returns a [GoogleSignInResult] with `credential == null` and
  /// `firebaseIdToken == null` if the user cancelled or anything failed.
  /// Callers should display an error SnackBar on every null result — never
  /// fail silently.
  Future<GoogleSignInResult> signinWithGoogle() async {
    if (!isEnabled) {
      // ignore: avoid_print
      print('Google sign-in disabled: GOOGLE_WEB_CLIENT_ID is empty.');
      return const GoogleSignInResult();
    }
    try {
      final gSign.GoogleSignInAccount? user = await _googleSignIn.signIn();
      if (user == null) {
        // ignore: avoid_print
        print('Google sign-in cancelled by user.');
        return const GoogleSignInResult();
      }

      final gSign.GoogleSignInAuthentication googleAuth =
          await user.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        // ignore: avoid_print
        print('Google sign-in: Firebase user is null after credential sign-in.');
        return GoogleSignInResult(credential: userCredential);
      }

      // Force-refresh so the server gets a token with current claims and
      // not a stale cached one.
      final String? firebaseIdToken = await firebaseUser.getIdToken(true);
      if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
        // ignore: avoid_print
        print('Google sign-in: getIdToken returned null/empty.');
      }

      return GoogleSignInResult(
        credential: userCredential,
        firebaseIdToken: firebaseIdToken,
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('Google sign-in error: $e');
      // The usual failure here (ApiException 10 = signing SHA-1 not registered
      // in Firebase) happens on the phone, before any request reaches the
      // server, so this is the only place it can be seen.
      DevLog.error('action', e, action: 'google_signin', stack: st);
      // ignore: avoid_print
      print(st);
      return const GoogleSignInResult();
    }
  }
}