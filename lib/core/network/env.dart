/// API configuration for the auto-update side (Kelilink pattern).
///
/// The auto-update fetcher uses the same base URL as the rest of the app.
/// Cert gate + HMAC token live in the service layer.
class EnvConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.himatif-encoder.com',
  );
}