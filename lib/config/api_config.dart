// Konfigurasi API SmartCook.
//
// baseUrl adalah Cloudflare Tunnel permanen (named tunnel `smartcook-api`)
// yang merutekan api.himatif-encoder.com -> VPS -> Node di port 2122.
// URL ini tidak berubah walau proses cloudflared restart atau VPS reboot,
// karena hostname-nya diikat ke tunnel ID di DNS Cloudflare.
class ApiConfig {
  static const String baseUrl = 'https://api.himatif-encoder.com';

  static const String apiKey =
      'sk_smartcook_api_2026_x9y8z7w6v5u4t3s2r1q0p9o8n7m6l5k4j3i2h1g0f9e8d7c6b5a4z3y2x1w0v9u8t7s6r5q';
}
