import 'package:flutter/widgets.dart';

/// Picks the right string table for the active language.
///
/// Hand-rolled rather than gen_l10n: the repo has no ARB files and the
/// chrome copy is small enough that one file with two classes is easier to
/// review than generated bindings.
///
/// Returns a typed [Str] rather than `dynamic`, because `dynamic` previously
/// let `s.name` through the analyzer and then throw
/// `NoSuchMethodError: Class 'Type' has no instance getter 'name'` on device.
Str stringsFor(Locale locale) =>
    locale.languageCode == 'en' ? const StrEn() : const StrId();

/// Common supertype so widgets can hold either language without `dynamic`.
abstract class Str {
  // Tabs
  String get home;
  String get search;
  String get bot;
  String get save;
  String get profile;

  // Profile
  String get name;
  String get saveProfile;
  String get profileUpdated;
  String get saveFailed;
  String get editProfile;
  String get editPreferences;
  String get changePassword;
  String get changeEmail;
  String get logout;

  // Appearance
  String get appearance;
  String get theme;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get language;
  String get languageIndonesian;
  String get languageEnglish;

  // Help
  String get other;
  String get faq;
  String get contactUs;
  String get faqLoadFailed;
  String get version;
  String get releaseNotes;

  // Danger
  String get danger;
  String get deleteAccount;
  String get deleteAccountSubtitle;
  String get deleteConfirmTitle;
  String get deleteConfirmBody;
  String get deleteConfirmHint;
  String get deletePermanently;
  String get cancel;

  // OTP
  String get otpTitle;
  String get otpBody;
  String get otpFieldHint;
  String get resendOtp;
  String get otpSending;

  // Changelog
  String get changelogTitle;
  String get newBadge;
  String get youAreHere;
  String get noReleaseNotes;

  // Auto-update dialog
  String get updateMandatoryTitle;
  String get updateOptionalTitle;
  String get updateInstalling;
  String get updateLater;
  String get updateRetry;
  String get updateInstallAgain;
  String get updateDownloading;
  String get updateNotOfficial;
  String get updateDownloadOfficial;
  String get updateExpired;
  String get updateHashMismatch;
  String get updateNetwork;
  String get updateGeneric;
  String get updateUnknownSourceNotice;

  /// "Versi kamu {from} → {to}". Keep the placeholders exactly like this.
  String get versionFromTo;
  /// "{percent} % selesai"
  String get updatePercentDone;
}

class StrId implements Str {
  const StrId();

  @override
  String get home => 'Home';
  @override
  String get search => 'Search';
  @override
  String get bot => 'Bot';
  @override
  String get save => 'Save';
  @override
  String get profile => 'Profil';
  @override
  String get name => 'Nama';
  @override
  String get saveProfile => 'Simpan Profil';
  @override
  String get profileUpdated => 'Profil diperbarui';
  @override
  String get saveFailed => 'Gagal menyimpan';
  @override
  String get editProfile => 'Profil';
  @override
  String get editPreferences => 'Edit preferensi & data diri';
  @override
  String get changePassword => 'Ubah password';
  @override
  String get changeEmail => 'Ganti email (OTP)';
  @override
  String get logout => 'Keluar';
  @override
  String get appearance => 'Tampilan';
  @override
  String get theme => 'Tema';
  @override
  String get themeSystem => 'Ikuti sistem';
  @override
  String get themeLight => 'Terang';
  @override
  String get themeDark => 'Gelap';
  @override
  String get language => 'Bahasa';
  @override
  String get languageIndonesian => 'Bahasa Indonesia';
  @override
  String get languageEnglish => 'English';
  @override
  String get other => 'Lainnya';
  @override
  String get faq => 'FAQ & Bantuan';
  @override
  String get contactUs => 'Hubungi Kami';
  @override
  String get faqLoadFailed => 'Gagal memuat FAQ';
  @override
  String get version => 'Versi Aplikasi';
  @override
  String get releaseNotes => 'Lihat catatan rilis';
  @override
  String get danger => 'Bahaya';
  @override
  String get deleteAccount => 'Hapus Akun';
  @override
  String get deleteAccountSubtitle => 'Permanen - tidak dapat dibatalkan';
  @override
  String get deleteConfirmTitle => 'Konfirmasi Hapus';
  @override
  String get deleteConfirmBody =>
      'Ketik HAPUS untuk mengonfirmasi penghapusan akun secara permanen.';
  @override
  String get deleteConfirmHint => 'HAPUS';
  @override
  String get deletePermanently => 'Hapus Permanen';
  @override
  String get cancel => 'Batal';
  @override
  String get otpTitle => 'Masukkan Kode OTP';
  @override
  String get otpBody =>
      'Kode 4 digit sudah dikirim ke email akunmu. Masukkan kode untuk melanjutkan.';
  @override
  String get otpFieldHint => '4 digit kode';
  @override
  String get resendOtp => 'Kirim ulang OTP';
  @override
  String get otpSending => 'Mengirim kode...';
  @override
  String get changelogTitle => 'Catatan rilis';
  @override
  String get newBadge => 'Baru';
  @override
  String get youAreHere => 'Versi kamu';
  @override
  String get noReleaseNotes => 'Belum ada catatan rilis.';

  @override
  String get updateMandatoryTitle => 'Update wajib';
  @override
  String get updateOptionalTitle => 'Versi terbaru tersedia';
  @override
  String get updateInstalling => 'Memasang update';
  @override
  String get updateLater => 'Nanti';
  @override
  String get updateRetry => 'Coba lagi';
  @override
  String get updateInstallAgain => 'Pasang lagi';
  @override
  String get updateDownloading => 'Mengunduh…';
  @override
  String get updateNotOfficial => 'Build ini tidak resmi.';
  @override
  String get updateDownloadOfficial =>
      'Unduh versi terbaru dari sumber resmi.';
  @override
  String get updateExpired => 'Link unduhan sudah kedaluwarsa.';
  @override
  String get updateHashMismatch => 'Berkas APK tidak cocok.';
  @override
  String get updateNetwork => 'Koneksi terputus.';
  @override
  String get updateGeneric => 'Terjadi kesalahan tak terduga.';
  @override
  String get updateUnknownSourceNotice =>
      'Pertama kali, Android meminta izin "Izinkan dari sumber ini". Aktifkan untuk SmartCook, lalu kembali dan tekan "Pasang lagi".';
  @override
  String get versionFromTo => 'Versi kamu {from} → {to}';
  @override
  String get updatePercentDone => '{percent} % selesai';
}

class StrEn implements Str {
  const StrEn();

  @override
  String get home => 'Home';
  @override
  String get search => 'Search';
  @override
  String get bot => 'Bot';
  @override
  String get save => 'Saved';
  @override
  String get profile => 'Profile';
  @override
  String get name => 'Name';
  @override
  String get saveProfile => 'Save profile';
  @override
  String get profileUpdated => 'Profile updated';
  @override
  String get saveFailed => 'Could not save';
  @override
  String get editProfile => 'Profile';
  @override
  String get editPreferences => 'Edit preferences & personal data';
  @override
  String get changePassword => 'Change password';
  @override
  String get changeEmail => 'Change email (OTP)';
  @override
  String get logout => 'Log out';
  @override
  String get appearance => 'Appearance';
  @override
  String get theme => 'Theme';
  @override
  String get themeSystem => 'Follow system';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get language => 'Language';
  @override
  String get languageIndonesian => 'Bahasa Indonesia';
  @override
  String get languageEnglish => 'English';
  @override
  String get other => 'Other';
  @override
  String get faq => 'FAQ & Help';
  @override
  String get contactUs => 'Contact us';
  @override
  String get faqLoadFailed => 'Could not load the FAQ';
  @override
  String get version => 'App version';
  @override
  String get releaseNotes => 'See release notes';
  @override
  String get danger => 'Danger';
  @override
  String get deleteAccount => 'Delete account';
  @override
  String get deleteAccountSubtitle => 'Permanent - cannot be undone';
  @override
  String get deleteConfirmTitle => 'Confirm deletion';
  @override
  String get deleteConfirmBody =>
      'Type HAPUS to confirm deleting your account permanently.';
  @override
  String get deleteConfirmHint => 'HAPUS';
  @override
  String get deletePermanently => 'Delete permanently';
  @override
  String get cancel => 'Cancel';
  @override
  String get otpTitle => 'Enter the OTP code';
  @override
  String get otpBody =>
      'A 4-digit code was sent to your account email. Enter it to continue.';
  @override
  String get otpFieldHint => '4-digit code';
  @override
  String get resendOtp => 'Resend OTP';
  @override
  String get otpSending => 'Sending code...';
  @override
  String get changelogTitle => 'Release notes';
  @override
  String get newBadge => 'New';
  @override
  String get youAreHere => 'Your version';
  @override
  String get noReleaseNotes => 'No release notes yet.';

  @override
  String get updateMandatoryTitle => 'Required update';
  @override
  String get updateOptionalTitle => 'New version available';
  @override
  String get updateInstalling => 'Installing update';
  @override
  String get updateLater => 'Later';
  @override
  String get updateRetry => 'Try again';
  @override
  String get updateInstallAgain => 'Install again';
  @override
  String get updateDownloading => 'Downloading…';
  @override
  String get updateNotOfficial => 'This build is not official.';
  @override
  String get updateDownloadOfficial =>
      'Download the latest version from the official source.';
  @override
  String get updateExpired => 'The download link has expired.';
  @override
  String get updateHashMismatch => 'The APK file does not match.';
  @override
  String get updateNetwork => 'The connection was dropped.';
  @override
  String get updateGeneric => 'Something unexpected went wrong.';
  @override
  String get updateUnknownSourceNotice =>
      'The first time, Android asks permission to "Allow from this source". Enable it for SmartCook, then come back and press "Install again".';
  @override
  String get versionFromTo => 'Your version {from} → {to}';
  @override
  String get updatePercentDone => '{percent}% complete';
}
