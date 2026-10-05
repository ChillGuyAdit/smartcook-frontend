/// API configuration for the auto-update side (Kelilink pattern).
///
/// The auto-update fetcher uses the same base URL as the rest of the app.
/// Cert gate + HMAC token live in the service layer.
class EnvConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.himatif-encoder.com',
  );

  /// OAuth Web Client ID for Google Sign-In on Android.
  /// This is the *web* client id from the Firebase console (looks like
  /// `xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com`).
  /// On Android it MUST be passed as `serverClientId` to `GoogleSignIn`,
  /// otherwise `idToken` ends up null and the backend rejects the request.
  ///
  /// The value mirrors the Firebase web OAuth client id, which is already
  /// public in `android/app/google-services.json` — anyone with the APK
  /// can read it anyway, so it is safe (and intentional) to bake it into
  /// the source. It is **not** a secret. Builders can still override at
  /// build time with:
  ///   flutter build apk --release \
  ///     --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '700811312802-kcjdtfuac640bkjgch3rhv6iej094ddr.apps.googleusercontent.com',
  );
}