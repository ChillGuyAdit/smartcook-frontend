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
  /// Build with:
  ///   flutter build apk --release \
  ///     --dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com
  ///
  /// When empty (default), the Google button hides itself entirely — see
  /// `AuthService.isEnabled` in `lib/service/auth_service.dart`.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );
}