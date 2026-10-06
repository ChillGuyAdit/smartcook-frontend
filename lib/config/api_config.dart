// Konfigurasi API SmartCook.
//
// baseUrl adalah Cloudflare Tunnel permanen (named tunnel `smartcook-api`)
// yang merutekan api.himatif-encoder.com -> VPS -> Node di port 2122.
// URL ini tidak berubah walau proses cloudflared restart atau VPS reboot,
// karena hostname-nya diikat ke tunnel ID di DNS Cloudflare.
//
// Catatan: tidak ada lagi `apiKey` statis di sini. Nilai itu ikut dibawa di
// dalam APK sehingga siapa pun yang meng-unzip APK bisa memakainya selamanya.
// Sekarang setiap request memakai access token dari `AppSession`, yang hanya
// diperoleh setelah handshake yang membuktikan sertifikat APK resmi.
class ApiConfig {
  static const String baseUrl = 'https://api.himatif-encoder.com';
}