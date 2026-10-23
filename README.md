# SmartCook Frontend

Aplikasi mobile berbasis Flutter untuk menemukan dan mengelola resep masakan dengan fitur AI chatbot, manajemen kulkas, dan rekomendasi resep yang disesuaikan dengan preferensi pengguna.

## 📱 Tentang Aplikasi

SmartCook adalah aplikasi resep masakan yang membantu pengguna menemukan resep berdasarkan bahan yang tersedia di kulkas mereka, preferensi kesehatan (alergi), dan waktu makan. Aplikasi ini dilengkapi dengan AI chatbot untuk interaksi yang lebih interaktif dalam mencari resep, serta fitur offline-first untuk pengalaman yang lebih baik bahkan tanpa koneksi internet.

## ✨ Fitur Utama

### 🏠 Homepage
Dashboard utama yang menampilkan:
- **Rekomendasi Resep Berdasarkan Waktu Makan**: Breakfast, Lunch, dan Dinner dengan animasi transisi yang smooth
- **Kategori Masakan**: Filter resep berdasarkan kategori (Masakan Sehat, Nutrisi Seimbang, Masakan Barat)
- **Preview Kulkas**: Tampilan cepat bahan makanan yang tersedia
- **Resep Populer**: 10 resep terpopuler berdasarkan jumlah views
- **Resep Disimpan**: Resep favorit yang disesuaikan dengan alergi pengguna
- **Rekomendasi Personal**: 5 resep yang direkomendasikan khusus untuk pengguna

### 🔍 Search
- Pencarian resep dengan dukungan offline caching
- Riwayat pencarian terbaru
- Pencarian cepat dari cache lokal saat offline

### 🤖 Bot Chat
- AI chatbot untuk interaksi resep yang lebih interaktif
- Streaming response untuk pengalaman real-time
- Recipe embeds untuk menampilkan resep langsung dalam chat
- Riwayat chat yang tersimpan
- Dukungan markdown untuk formatting pesan

### 💾 Save/Favorites
- Halaman untuk melihat semua resep yang disimpan
- Sinkronisasi otomatis saat online kembali
- Dukungan offline untuk melihat resep yang sudah di-cache

### 👤 Profile
- Manajemen profil pengguna
- Pengaturan alergi makanan
- Ubah email dan password
- Informasi akun

### 🧊 Kulkas (Fridge)
- Manajemen bahan makanan yang tersedia
- Tambah/hapus bahan dengan kuantitas
- Rekomendasi resep berdasarkan bahan di kulkas
- Sinkronisasi dengan backend

### 📂 Categories
- Filter resep berdasarkan kategori:
  - Masakan Sehat Rendah Kalori Tinggi Nutrisi
  - Masakan Dengan Nutrisi Seimbang
  - Ala-Ala Masakan Barat

### 📴 Offline Support
- Caching data resep untuk penggunaan offline
- Sinkronisasi otomatis saat koneksi kembali online
- Antrian operasi offline yang akan di-sync saat online
- Banner notifikasi status koneksi

### 🔐 Authentication
- Login/Register dengan Email-Password
- Google Sign-In integration
- Forgot Password dan Reset Password
- Onboarding flow untuk pengguna baru

## 🔄 Alur Aplikasi

```
Splash Screen
    ↓
[Check Auth Status]
    ↓
    ├─→ Not Authenticated → Sign In / Sign Up
    │                           ↓
    │                    [Google Sign-In / Email-Password]
    │                           ↓
    │                    [Check Onboarding Status]
    │                           ↓
    │                    ├─→ Not Completed → Onboarding Flow
    │                    │                        ↓
    │                    │                   [Form Pengisian Data]
    │                    │                        ↓
    │                    │                    Homepage
    │                    └─→ Completed → Homepage
    │                                        ↓
    │                            [Bottom Navigation]
    │                                ├─→ Home (Index 0)
    │                                │     ├─→ Category Page
    │                                │     ├─→ Kulkas Page
    │                                │     ├─→ Tambahkan Bahan Page
    │                                │     └─→ Masakan Detail Page
    │                                ├─→ Search (Index 1)
    │                                │     └─→ Masakan Detail Page
    │                                ├─→ Bot Chat (Index 2)
    │                                │     └─→ Masakan Detail Page (dari embeds)
    │                                ├─→ Save/Favorites (Index 3)
    │                                │     └─→ Masakan Detail Page
    │                                └─→ Profile (Index 4)
    │                                      ├─→ Change Email Page
    │                                      └─→ Change Password Page
    │
    └─→ Authenticated → [Check Onboarding]
                            ↓
                    ├─→ Not Completed → Onboarding Flow
                    └─→ Completed → Homepage
```

## 📁 Struktur Proyek

```
smartcook-frontend/
├── lib/
│   ├── main.dart                 # Entry point aplikasi dengan Firebase initialization
│   ├── firebase_options.dart      # Konfigurasi Firebase
│   │
│   ├── auth/                     # Authentication flows
│   │   ├── signIn.dart           # Halaman login
│   │   ├── signUp.dart          # Halaman registrasi
│   │   ├── forgotpassword.dart   # Lupa password
│   │   ├── resetpassword.dart    # Reset password
│   │   ├── google_set_password.dart  # Set password setelah Google Sign-In
│   │   └── sukses.dart          # Halaman sukses setelah registrasi
│   │
│   ├── page/                     # Halaman utama aplikasi
│   │   ├── homepage.dart         # Dashboard utama
│   │   ├── search_page.dart      # Halaman pencarian
│   │   ├── bot_page.dart         # Halaman AI chatbot
│   │   ├── save_page.dart        # Halaman resep tersimpan
│   │   ├── profile_page.dart     # Halaman profil
│   │   ├── kulkas.dart           # Halaman manajemen kulkas
│   │   ├── tambahkan_bahan.dart  # Halaman tambah bahan
│   │   ├── masakan.dart          # Halaman detail resep
│   │   ├── category.dart         # Halaman kategori resep
│   │   ├── change_email_page.dart    # Ubah email
│   │   ├── change_password_page.dart  # Ubah password
│   │   └── reusable/
│   │       └── bottom_navbar.dart    # Bottom navigation bar
│   │
│   ├── service/                  # Services untuk business logic
│   │   ├── api_service.dart     # Service untuk API calls
│   │   ├── auth_service.dart     # Service untuk autentikasi
│   │   ├── token_service.dart    # Service untuk manajemen token
│   │   ├── offline_manager.dart  # Manager untuk status offline/online
│   │   └── offline_cache_service.dart  # Service untuk caching offline
│   │
│   ├── view/                     # Views dan screens
│   │   ├── splashscreen.dart     # Splash screen
│   │   └── onboarding/          # Onboarding flow
│   │       ├── mainBoarding.dart
│   │       ├── onboarding1.dart
│   │       ├── onboarding2.dart
│   │       ├── onboarding3.dart
│   │       └── form.dart         # Form pengisian data onboarding
│   │
│   ├── config/                   # Konfigurasi
│   │   └── api_config.dart      # Konfigurasi API endpoint dan key
│   │
│   └── helper/                   # Helper utilities
│       └── color.dart           # Color constants
│
├── image/                        # Assets gambar
├── pubspec.yaml                  # Dependencies dan konfigurasi Flutter
└── README.md                     # Dokumentasi proyek
```

## 🛠 Teknologi yang Digunakan

### Framework & Language
- **Flutter**: SDK ^3.5.0
- **Dart**: Bahasa pemrograman utama

### Authentication & Backend
- **Firebase Core**: ^3.11.0
- **Firebase Auth**: ^5.5.0
- **Google Sign-In**: ^6.2.2

### State Management & Storage
- **StatefulWidget**: State management utama
- **ValueNotifier**: Untuk status offline/online global
- **Shared Preferences**: ^2.2.2 - Penyimpanan key-value untuk sesi, tema, bahasa, riwayat pencarian, dan antrean operasi offline
- **SQLite (sqflite)**: ^2.4.4 - Database lokal untuk cache resep dan isi kulkas agar tetap bisa dibuka tanpa internet

### Networking & API
- **HTTP**: ^1.2.0 - HTTP client untuk API calls
- Custom API Service dengan error handling dan offline detection

### UI Components
- **Smooth Page Indicator**: ^2.0.1 - Untuk onboarding indicators
- **Flutter Markdown**: ^0.7.4+1 - Untuk rendering markdown di chat bot
- **URL Launcher**: Untuk membuka link eksternal

### Architecture Patterns
- **Offline-First Architecture**: Aplikasi dirancang untuk bekerja offline dengan sync otomatis
- **Service Layer Pattern**: Pemisahan business logic ke service layer
- **Repository Pattern**: Untuk data management dengan caching

## 👥 Core Team

Tim **SmartCook** yang membangun proyek ini:

<table>
<tr>
<td align="center">
<img src="https://github.com/faturrahman82.png" width="100px" alt="Maul"/>
<br />
<strong>Maul</strong>
<br />
<sub>💻 <strong>Frontend Flutter Developer</strong></sub>
<br />
<sub>
📱 Flutter Implementation<br/>
🎯 Feature Development<br/>
🔧 Component Building<br/>
📊 State Management<br/>
🧪 Testing & Debugging<br/>
</sub>
<br />
<a href="https://github.com/faturrahman82">GitHub</a>
</td>
<td align="center">
<img src="https://github.com/geraldy-pf.png" width="100px" alt="Geraldy Putra Fazrian"/>
<br />
<strong>Geraldy Putra Fazrian</strong>
<br />
<sub>💻 <strong>Frontend Flutter Developer</strong></sub>
<br />
<sub>
📱 Flutter Implementation<br/>
🎯 Feature Development<br/>
🔧 Component Building<br/>
📊 State Management<br/>
🧪 Testing & Debugging<br/>
</sub>
<br />
<a href="https://github.com/geraldy-pf">GitHub</a>
</td>
<td align="center">
<img src="https://github.com/ChillGuyAdit.png" width="100px" alt="ChillGuyAdit"/>
<br />
<strong>ChillGuyAdit</strong>
<br />
<sub>🎨 <strong>UI/UX Designer</strong></sub>
<br />
<sub>
🎨 Visual Design<br/>
🖼️ Asset Creation<br/>
🎯 Design System<br/>
✨ User Experience<br/>
📐 Layout Design<br/>
</sub>
<br />
<a href="https://github.com/ChillGuyAdit">GitHub</a>
</td>
<td align="center">
<img src="https://github.com/Sadamdi.png" width="100px" alt="Sulthan Adam Rahmadi"/>
<br />
<strong>Sulthan Adam Rahmadi</strong>
<br />
<sub>🚀 <strong>Backend Developer</strong></sub>
<br />
<sub>
⚙️ Backend Server<br/>
🔧 Logic Implementation<br/>
🗄️ Database Design<br/>
🔐 API Development<br/>
🏗️ System Architecture<br/>
</sub>
<br />
<a href="https://github.com/Sadamdi">GitHub</a>
</td>
</tr>
</table>

## 🚀 Instalasi & Setup

### Prerequisites

- Flutter SDK (^3.5.0 atau lebih tinggi)
- Dart SDK
- Android Studio / VS Code dengan Flutter extension
- Firebase project setup
- Backend API yang sudah berjalan

### Langkah Instalasi

1. **Clone repository**
   ```bash
   git clone <repository-url>
   cd smartcook-frontend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Setup Firebase**
   - Buat Firebase project di [Firebase Console](https://console.firebase.google.com/)
   - Download `google-services.json` untuk Android dan `GoogleService-Info.plist` untuk iOS
   - Letakkan file-file tersebut di direktori yang sesuai:
     - `android/app/google-services.json`
     - `ios/Runner/GoogleService-Info.plist`
   - Install FlutterFire CLI (jika belum):
     ```bash
     dart pub global activate flutterfire_cli
     ```
   - Generate `firebase_options.dart` menggunakan FlutterFire CLI:
     ```bash
     flutterfire configure
     ```
   - **PENTING**: File `firebase_options.dart` sudah di-ignore oleh git karena berisi informasi sensitif

4. **Konfigurasi API**
   - Copy file contoh konfigurasi:
     ```bash
     cp lib/config/api_config.example.dart lib/config/api_config.dart
     ```
   - Edit file `lib/config/api_config.dart` dan isi dengan:
     - `baseUrl`: URL backend API Anda
     - `apiKey`: API key yang sesuai
   - **PENTING**: File `api_config.dart` sudah di-ignore oleh git karena berisi API key yang sensitif. Jangan commit file ini ke repository!

5. **Run aplikasi**
   ```bash
   flutter run
   ```

### Build untuk Production

**Android:**
```bash
flutter build apk --release
# atau
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

## 📋 Requirements

- Flutter SDK ^3.5.0
- Dart SDK
- Android SDK (untuk Android development)
- Xcode (untuk iOS development, macOS only)
- Firebase project dengan Authentication enabled
- Backend API server yang berjalan

## 🔧 Konfigurasi

### API Configuration
File `lib/config/api_config.dart` berisi konfigurasi untuk:
- Base URL backend API
- API Key untuk autentikasi

**⚠️ PENTING**: File `api_config.dart` sudah di-ignore oleh git karena berisi informasi sensitif. Gunakan `api_config.example.dart` sebagai template.

### Firebase Configuration
Pastikan Firebase sudah dikonfigurasi dengan:
- Authentication enabled (Email/Password dan Google Sign-In)
- Firebase project ID yang sesuai

**⚠️ PENTING**: File `firebase_options.dart` sudah di-ignore oleh git. Generate file ini menggunakan `flutterfire configure` setelah setup Firebase project.

### File-file yang Tidak Boleh Di-commit

File-file berikut sudah di-ignore oleh `.gitignore` dan **TIDAK BOLEH** di-commit ke repository:

- `lib/config/api_config.dart` - Berisi API keys yang sensitif
- `lib/firebase_options.dart` - Berisi konfigurasi Firebase yang sensitif
- `android/app/google-services.json` - Konfigurasi Firebase untuk Android
- `ios/Runner/GoogleService-Info.plist` - Konfigurasi Firebase untuk iOS
- `*.env` - File environment variables
- `*.keystore`, `*.jks` - Android signing keys
- File build dan cache lainnya

Pastikan untuk tidak meng-commit file-file sensitif ini ke repository publik!

## 🏗 Architecture Highlights

### Offline-First Design
- Data resep dan isi kulkas di-cache secara lokal di SQLite (sqflite), sedangkan pengaturan, sesi, dan antrean operasi disimpan di SharedPreferences
- Operasi yang dilakukan saat offline akan diantri dan di-sync saat online kembali
- Banner notifikasi otomatis menampilkan status koneksi

### Caching Strategy
- Resep yang pernah dilihat di-cache untuk akses cepat
- List resep (favorites, recommendations, popular) di-cache
- Pencarian terbaru disimpan untuk akses cepat
- Global ingredients list di-cache untuk performa lebih baik

### Error Handling
- Graceful error handling untuk semua API calls
- Fallback ke cache saat offline atau error
- User-friendly error messages
- Auto-retry mechanism untuk operasi yang gagal

### Security
- Token-based authentication
- Secure token storage menggunakan TokenService
- Auto-logout saat token expired atau unauthorized
- API key protection

## 📝 Catatan Pengembangan

- Aplikasi menggunakan offline-first architecture untuk pengalaman pengguna yang lebih baik
- Semua operasi yang memerlukan koneksi internet memiliki fallback ke cache
- Token authentication di-handle secara otomatis dengan auto-refresh
- Error handling yang komprehensif untuk berbagai skenario

## 📄 License

MIT License

Copyright (c) 2026 SmartCook Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## 🙏 Acknowledgments

Terima kasih kepada semua kontributor yang telah membantu dalam pengembangan aplikasi SmartCook ini.

---

**SmartCook** - Temukan resep masakan terbaik untukmu! 🍳
