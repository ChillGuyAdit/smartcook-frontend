import 'package:flutter/widgets.dart';

import '../theme/language_controller.dart';

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
  String get versionNumberLabel;
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

  /// "Yang baru" / "Perbaikan" section headings in the in-app changelog.
  String get releaseNotesSectionNew;
  String get releaseNotesSectionFix;

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

  // Update dialog: ready state, release notes, resume
  String get updateNow;
  String get updateCancelDownload;
  String get updatePreparing;
  String get updateWaitingForNetwork;
  String get updateResumeCta;
  String get updateNetworkResume;
  String get updateRateLimited;
  String get updateShowAllNotes;
  String get updateShowFullNotes;
  String get updateForcedNotice;
  String get updateConfirmInAndroid;
  String get updateVersionsBehind;
  String get updateOfficialRollback;

  // Shown when the server refuses this build (wrong or rebuilt signature).
  String get buildNotOfficialTitle;
  String get buildNotOfficialBody;
  String get buildNotOfficialAction;
  // ---- screens (l10n sweep)
  String signInIn(Object? s);
  String get newPassword;
  String get oldPassword;
  String get confirmPassword;
  String get confirmNewPassword;
  String get savePassword;
  String get otpCodeField;
  String get enterOtp4;
  String get otpExpired;
  String get otpValidNote;
  String get otpResent;
  String get checkYourEmail;
  String get verify;
  String get signInLabel;
  String get signUpLabel;
  String get forgotPassword;
  String get noAccountYet;
  String get haveAccount;
  String get enterYourEmail;
  String get enterYourPassword;
  String get googleSignInFailed;
  String get googleSignInIncomplete;
  String get invalidResponse;
  String get sessionNotFound;
  String get forgotPasswordIntro;
  String get setPassword;
  String get createNewPasswordTitle;
  String get googleEmailNote;
  String get createNewPassword;
  String get resetPassword;
  String get enterPassword;
  String get reenterPassword;
  String get successTitle;
  String get passwordChangedBody;
  String get continueLabel;
  String get newEmailRequired;
  String get emailChanged;
  String get newEmail;
  String get confirmEmail;
  String get passwordChanged;
  String get useOldPassword;
  String get useEmailOtp;
  String get chefOffline;
  String get clearHistoryTitle;
  String get delete;
  String get askAnythingCooking;
  String get typeMessage;
  String get searchFilter;
  String get maxCaloriesLabel;
  String get maxTimeLabel;
  String get apply;
  String get searchRecipes;
  String get recipesNotFound;
  String get globalModeNote;
  String get recentSearches;
  String get searchFavorites;
  String get showingCache;
  String get pageNotFound;
  String get whatToCookToday;
  String get tasteCategories;
  String get catHealthy;
  String get catBalanced;
  String get catWestern;
  String get fridgeQuestion;
  String get findByIngredients;
  String get addIngredients;
  String get ingredientWord;
  String get noIngredientsYet;
  String get seeAllArrow;
  String get seeAll;
  String get chooseMealTime;
  String get savedForYou;
  String get top10Popular;
  String get top5Recs;
  String get matchForYou;
  String get deleteIngredientTitle;
  String get yesDelete;
  String get sortAndFilter;
  String get sortBy;
  String get mostStock;
  String get leastStock;
  String get expiryFilter;
  String get maxStockLabel;
  String get editFridgeIngredient;
  String get ingredientName;
  String get quantity;
  String get saveChanges;
  String get searchFridge;
  String get ingredientsNotFound;
  String get yourFridge;
  String get fridgeIntro;
  String get favSyncLater;
  String get recipeRemoved;
  String get recipeSaved;
  String get ingredientsNeeded;
  String get noIngredientData;
  String get recipeNoValidId;
  String get findMissingIngredients;
  String get howToMake;
  String get noSteps;
  String get watchTutorial;
  String get moreRecs;
  String get suitableFor;
  String get favoritesOffline;
  String get savedTitle;
  String get noSavedRecipes;
  String get searchOrTypeIngredient;
  String get add;
  String get byCategory;
  String get listLabel;
  String get saveToFridge;
  String get enterIngredientFirst;
  String get pickCategoryFirst;
  String get invalidCategory;
  String get ingredientAlreadyListed;
  String get nothingSentToFridge;
  String get done;
  String get deleteAccountWarning;
  String get sendCodeFailed;
  String get emailRequired;
  String get emailNeedsAt;
  String get emailNeedsCom;
  String get savePasswordFailed;
  String get loadingEmail;
  String get passwordRequired;
  String get confirmPasswordRequired;
  String get passwordsDontMatch;
  String get otpVerifyFailed;
  String get otpVerifiedNewPassword;
  String get resendOtpFailed;
  String get weSentCodeTo;
  String get newPasswordRequired;
  String get passwordMin6;
  String get otpInvalid;
  String get resetPasswordFailed;
  String get loginFailed;
  String get emailInvalid;
  String get fieldRequired;
  String get registerFailed;
  String get enterYourName;
  String get sendFailedShort;
  String get filterDismiss;
  String get otpSentToEmail;
  String get sendOtpFailed;
  String get changeEmailFailed;
  String get sendOtp;
  String get changePasswordFailed;
  String get oldPasswordRequired;
  String get codeWrongOrExpired;
  String get tailoredToHealth;
  String get expiredLabel;
  String get todayLabel;
  String get tomorrowLabel;
  String get ingredientUpdated;
  String get updateFailed;
  String get accessBlockedTitle;
  String get accessBlockedBody;
  String get accountSuspendedTitle;
  String get accountSuspendedBody;
  String restrictionReason(String reason);
  String get soonestExpiry;
  String mergedIntoExisting(int n);
  String get unitLabel;
  String get expiryDateLabel;
  String get pickDate;
  String get clearDate;
  String get backOnline;
  String get offlineBanner;
  String get noExpiryDate;
  String get invalidQuantity;
  String get fridgeLoadFailed;
  String get ingredientDeletedSync;
  String get ingredientDeleted;
  String get deleteFailed;
  String get loadRecipeFailed;
  String get recipeSavedShort;
  String get addToFridgeFailed;
  String get safeForDiabetes;
  String get nutFree;
  String get useBlender;
  String get unnamedRecipe;
  String get saveFailedLogin;
  String get allLabel;
  String get catTitleHealthy;
  String get catTitleBalanced;
  String get catTitleWestern;
  String otpExpiresIn(String t);
  String otpExpiresInClock(String t);
  String googleSignInFailedDetail(String e);
  String navigateFailed(String e);
  String saveSessionFailed(String e);
  String somethingWrong(String e);
  String sendFailed(String e);
  String recipeMeta(Object? cal, Object? minutes);
  String kcal(Object? cal);
  String kcalSpaced(Object? cal);
  String minutesSpaced(Object? n);
  String categoryBlurb(String name);
  String greeting(String name);
  String deleteIngredientBody(String name);
  String stockLabel(Object? n);
  String ingredientsAddedToFridge(Object? n);
  String noResultsFor(String q);
  String newIngredientNote(String name, String category);
  String willSaveWhenOnline(Object? n);
  String savedNOfM(Object? ok, Object? n);
  String processedToFridge(Object? n);
  String resendOtpIn(Object? s);
  String sendOtpIn(Object? s);
  String otpValidAbout(String base, Object? minutes);
  String safeForAllergy(Object? x);
  String viewedByUsers(Object? n);
  String daysLeft(Object? n);
  String couldNotOpen(String url);
  String saveFailedWith(Object? e);
  String lessThanDays(int n);
  String quantityOf(Object? name);

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
  String get versionNumberLabel => 'Versi';
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
  String get releaseNotesSectionNew => 'Yang baru';
  @override
  String get releaseNotesSectionFix => 'Perbaikan';

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

  @override
  String get updateNow => 'Update sekarang';
  @override
  String get updateCancelDownload => 'Batal';
  @override
  String get updatePreparing => 'Menyiapkan unduhan…';
  @override
  String get updateWaitingForNetwork =>
      'Menunggu koneksi internet… unduhan akan dilanjutkan otomatis.';
  @override
  String get updateResumeCta => 'Lanjutkan';
  @override
  String get updateNetworkResume =>
      'Koneksi terputus. Unduhan tersimpan, tidak perlu mengulang dari awal.';
  @override
  String get updateRateLimited =>
      'Terlalu banyak percobaan dari jaringan ini. Coba lagi beberapa saat.';
  @override
  String get updateShowAllNotes => 'Lihat semua catatan rilis';
  @override
  String get updateShowFullNotes => 'Lihat catatan lengkap';
  @override
  String get updateForcedNotice =>
      'Versi ini wajib dipasang untuk melanjutkan.';
  @override
  String get updateConfirmInAndroid =>
      'Pilih "Perbarui" di jendela pemasangan, lalu "Buka" untuk menjalankan versi baru.';
  @override
  String get updateVersionsBehind => 'Naik {count} versi sekaligus';
  @override
  String get updateOfficialRollback => 'Pembaruan resmi SmartCook {to}';

  @override
  String get buildNotOfficialTitle => 'Aplikasi ini tidak resmi';
  @override
  String get buildNotOfficialBody =>
      'SmartCook yang kamu buka tidak ditandatangani dengan sertifikat resmi, jadi server tidak mengizinkannya terhubung. Unduh ulang dari sumber resmi.';
  @override
  String get buildNotOfficialAction => 'Unduh versi resmi';
  // ---- screens (l10n sweep)
  @override
  String signInIn(Object? s) => 'Masuk (${s}s)';
  @override
  String get newPassword => 'Password baru';
  @override
  String get oldPassword => 'Password lama';
  @override
  String get confirmPassword => 'Konfirmasi password';
  @override
  String get confirmNewPassword => 'Konfirmasi password baru';
  @override
  String get savePassword => 'Simpan Password';
  @override
  String get otpCodeField => 'Kode OTP (4 digit)';
  @override
  String get enterOtp4 => 'Masukkan 4 digit kode OTP';
  @override
  String get otpExpired => 'Kode OTP sudah expired. Kirim ulang OTP.';
  @override
  String get otpValidNote => 'Kode berlaku 10 menit sejak dikirim ke email';
  @override
  String get otpResent => 'Kode OTP baru telah dikirim';
  @override
  String get checkYourEmail => 'Cek email kamu';
  @override
  String get verify => 'Verifikasi';
  @override
  String get signInLabel => 'Masuk';
  @override
  String get signUpLabel => 'Daftar';
  @override
  String get forgotPassword => 'Lupa Password?';
  @override
  String get noAccountYet => 'Belum punya akun ?';
  @override
  String get haveAccount => 'Sudah punya akun ?';
  @override
  String get enterYourEmail => 'Masukkan Emailmu';
  @override
  String get enterYourPassword => 'Masukkan Password';
  @override
  String get googleSignInFailed => 'Google sign-in gagal. Coba lagi.';
  @override
  String get googleSignInIncomplete => 'Tidak bisa menyelesaikan masuk dengan Google. Coba lagi.';
  @override
  String get invalidResponse => 'Respons tidak valid';
  @override
  String get sessionNotFound => 'Sesi masuk tidak ditemukan';
  @override
  String get forgotPasswordIntro => 'Jangan khawatir! Masukkan alamat email Anda. Dan kami akan\nmemberikan instruksi untuk mengatur ulang password';
  @override
  String get setPassword => 'Atur Password';
  @override
  String get createNewPasswordTitle => 'Buat Password Baru';
  @override
  String get googleEmailNote => 'Email kamu akan menggunakan email dari akun Google.';
  @override
  String get createNewPassword => 'Buat password baru';
  @override
  String get resetPassword => 'Reset Password';
  @override
  String get enterPassword => 'Masukkan password';
  @override
  String get reenterPassword => 'Masukkan ulang password';
  @override
  String get successTitle => 'Berhasil!';
  @override
  String get passwordChangedBody => 'Selamat Anda berhasil mengganti password baru Anda\nKlik lanjutkan untuk masuk';
  @override
  String get continueLabel => 'Lanjutkan';
  @override
  String get newEmailRequired => 'Email baru wajib diisi';
  @override
  String get emailChanged => 'Email berhasil diubah';
  @override
  String get newEmail => 'Email baru';
  @override
  String get confirmEmail => 'Konfirmasi Email';
  @override
  String get passwordChanged => 'Password berhasil diubah';
  @override
  String get useOldPassword => 'Pakai password lama';
  @override
  String get useEmailOtp => 'Pakai OTP email';
  @override
  String get chefOffline => 'SmartChef tidak tersedia saat offline.\nSilakan sambungkan internet untuk melanjutkan.';
  @override
  String get clearHistoryTitle => 'Hapus riwayat?';
  @override
  String get delete => 'Hapus';
  @override
  String get askAnythingCooking => 'Tanya apa saja tentang masak';
  @override
  String get typeMessage => 'Ketik pesan...';
  @override
  String get searchFilter => 'Filter Pencarian';
  @override
  String get maxCaloriesLabel => 'Maks. Kalori (Kal)';
  @override
  String get maxTimeLabel => 'Maks. Waktu (Menit)';
  @override
  String get apply => 'Terapkan';
  @override
  String get searchRecipes => 'Cari resep...';
  @override
  String get recipesNotFound => 'Resep tidak ditemukan 😥\nCoba ubah filter atau pencarianmu.';
  @override
  String get globalModeNote => 'Mode global: menampilkan resep yang sudah ada di database dari semua user (tetap disesuaikan alergi dan preferensimu).';
  @override
  String get recentSearches => 'Pencarian terbaru';
  @override
  String get searchFavorites => 'Cari resep favoritmu';
  @override
  String get showingCache => 'Menampilkan data dari cache (offline)';
  @override
  String get pageNotFound => 'Halaman tidak ditemukan';
  @override
  String get whatToCookToday => 'Masak apa hari ini?';
  @override
  String get tasteCategories => 'Kategori selera memasak';
  @override
  String get catHealthy => 'Masakan Sehat\nRendah Kalori\nTinggi Nutrisi';
  @override
  String get catBalanced => 'Masakan Dengan\nNutrisi Seimbang';
  @override
  String get catWestern => 'Ala-Ala\nMasakan Barat';
  @override
  String get fridgeQuestion => 'Apa saja isi kulkas mu?';
  @override
  String get findByIngredients => 'Temukan berbagai resep makanan berdasarkan bahan yang kamu miliki';
  @override
  String get addIngredients => 'Tambahkan Bahan';
  @override
  String get ingredientWord => 'Bahan';
  @override
  String get noIngredientsYet => 'Belum ada bahan';
  @override
  String get seeAllArrow => 'Lihat Semua >';
  @override
  String get seeAll => 'Lihat Semua';
  @override
  String get chooseMealTime => 'Pilih Waktu Makan';
  @override
  String get savedForYou => 'Disimpan untukmu';
  @override
  String get top10Popular => '10 Resep Terpopuler';
  @override
  String get top5Recs => '5 Rekomendasi Masakan';
  @override
  String get matchForYou => 'Cocok Untukmu';
  @override
  String get deleteIngredientTitle => 'Hapus Bahan?';
  @override
  String get yesDelete => 'Ya, Hapus';
  @override
  String get sortAndFilter => 'Urutkan & Filter';
  @override
  String get sortBy => 'Urutkan Berdasarkan';
  @override
  String get mostStock => 'Terbanyak';
  @override
  String get leastStock => 'Terdikit';
  @override
  String get expiryFilter => 'Filter Kadaluarsa';
  @override
  String get maxStockLabel => 'Maksimal Stok';
  @override
  String get editFridgeIngredient => 'Edit Bahan Kulkas';
  @override
  String get ingredientName => 'Nama Bahan';
  @override
  String get quantity => 'Jumlah';
  @override
  String get saveChanges => 'Simpan Perubahan';
  @override
  String get searchFridge => 'Cari bahan di kulkas...';
  @override
  String get ingredientsNotFound => 'Bahan tidak ditemukan 😥\nCoba ubah filter atau tambahkan bahan.';
  @override
  String get yourFridge => 'Isi Kulkasmu';
  @override
  String get fridgeIntro => 'Cek dan kelola persediaan bahan masakan yang ada di dalam kulkasmu dengan mudah.';
  @override
  String get favSyncLater => 'Perubahan favorit akan disinkron saat online';
  @override
  String get recipeRemoved => 'Resep dihapus dari simpanan';
  @override
  String get recipeSaved => 'Resep berhasil disimpan!';
  @override
  String get ingredientsNeeded => 'Bahan yang dibutuhkan';
  @override
  String get noIngredientData => 'Tidak ada data bahan';
  @override
  String get recipeNoValidId => 'Resep tidak memiliki ID valid';
  @override
  String get findMissingIngredients => 'Cari Bahan yang Kurang';
  @override
  String get howToMake => 'Cara Membuat';
  @override
  String get noSteps => 'Tidak ada langkah';
  @override
  String get watchTutorial => 'Lihat Tutorial di YouTube';
  @override
  String get moreRecs => 'Rekomendasi Lainnya';
  @override
  String get suitableFor => 'Cocok Untuk Diet, Diabetes, rendah gula, tinggi serat';
  @override
  String get favoritesOffline => 'Tidak bisa mengambil favorit dari server (offline)';
  @override
  String get savedTitle => 'Disimpan';
  @override
  String get noSavedRecipes => 'Belum ada resep yang disimpan';
  @override
  String get searchOrTypeIngredient => 'Cari atau ketik nama bahan baru (mis. \"Daun bawang\")';
  @override
  String get add => 'Tambah';
  @override
  String get byCategory => 'Berdasarkan Kategori:';
  @override
  String get listLabel => 'Daftar:';
  @override
  String get saveToFridge => 'Simpan ke Kulkas';
  @override
  String get enterIngredientFirst => 'Isi nama bahan terlebih dahulu';
  @override
  String get pickCategoryFirst => 'Pilih kategori bahan terlebih dahulu';
  @override
  String get invalidCategory => 'Kategori tidak valid';
  @override
  String get ingredientAlreadyListed => 'Bahan sudah ada di daftar kategori ini';
  @override
  String get nothingSentToFridge => 'Tidak ada bahan yang dikirim ke kulkas. Perubahan daftar tersimpan.';
  @override
  String get done => 'Selesai';
  @override
  String get deleteAccountWarning => 'Akun dan seluruh isinya (kulkas, resep favorit, riwayat chat) akan dihapus permanen dan tidak dapat dipulihkan.';
  @override
  String get sendCodeFailed => 'Gagal mengirim kode';
  @override
  String get emailRequired => 'Email wajib diisi';
  @override
  String get emailNeedsAt => 'Email harus ada simbol \'@\'';
  @override
  String get emailNeedsCom => 'Email harus diakhiri dengan \'.com\'';
  @override
  String get savePasswordFailed => 'Gagal menyimpan password';
  @override
  String get loadingEmail => 'Memuat email...';
  @override
  String get passwordRequired => 'Password wajib diisi';
  @override
  String get confirmPasswordRequired => 'Konfirmasi password wajib diisi';
  @override
  String get passwordsDontMatch => 'Konfirmasi password tidak sama';
  @override
  String get otpVerifyFailed => 'Verifikasi OTP gagal';
  @override
  String get otpVerifiedNewPassword => 'OTP terverifikasi. Silakan buat password baru.';
  @override
  String get resendOtpFailed => 'Gagal mengirim ulang OTP';
  @override
  String get weSentCodeTo => 'Kami mengirim 4 digit kode ke\n';
  @override
  String get newPasswordRequired => 'Password baru wajib diisi';
  @override
  String get passwordMin6 => 'Password minimal 6 karakter';
  @override
  String get otpInvalid => 'Kode OTP tidak valid';
  @override
  String get resetPasswordFailed => 'Gagal reset password';
  @override
  String get loginFailed => 'Login gagal';
  @override
  String get emailInvalid => 'Format email tidak valid';
  @override
  String get fieldRequired => 'Wajib diisi';
  @override
  String get registerFailed => 'Registrasi gagal';
  @override
  String get enterYourName => 'Masukkan Namamu';
  @override
  String get sendFailedShort => 'Gagal mengirim';
  @override
  String get filterDismiss => 'Tutup filter';
  @override
  String get otpSentToEmail => 'Kode OTP telah dikirim ke email kamu.';
  @override
  String get sendOtpFailed => 'Gagal mengirim OTP';
  @override
  String get changeEmailFailed => 'Gagal mengganti email';
  @override
  String get sendOtp => 'Kirim OTP';
  @override
  String get changePasswordFailed => 'Gagal mengganti password';
  @override
  String get oldPasswordRequired => 'Password lama wajib diisi';
  @override
  String get codeWrongOrExpired => 'Kode salah atau sudah kedaluwarsa';
  @override
  String get tailoredToHealth => 'Disesuaikan dengan preferensi kesehatanmu';
  @override
  String get expiredLabel => 'Sudah Kadaluarsa';
  @override
  String get todayLabel => 'Hari ini';
  @override
  String get tomorrowLabel => 'Besok';
  @override
  String get ingredientUpdated => 'Bahan berhasil diperbarui!';
  @override
  String get updateFailed => 'Gagal memperbarui';
  @override
  String get accessBlockedTitle => 'Akses diblokir';
  @override
  String get accessBlockedBody => 'Anda telah diblokir dari layanan ini.';
  @override
  String get accountSuspendedTitle => 'Akun ditangguhkan';
  @override
  String get accountSuspendedBody => 'Akun ini ditangguhkan.';
  @override
  String restrictionReason(String reason) => 'Alasan: $reason';
  @override
  String get soonestExpiry => 'Segera kadaluarsa';
  @override
  String mergedIntoExisting(int n) => '$n bahan digabung ke stok yang sudah ada.';
  @override
  String get unitLabel => 'Satuan';
  @override
  String get expiryDateLabel => 'Tanggal kadaluarsa';
  @override
  String get pickDate => 'Pilih tanggal';
  @override
  String get clearDate => 'Hapus tanggal';
  @override
  String get backOnline => 'Koneksi kembali online';
  @override
  String get offlineBanner => 'Anda sedang offline. Beberapa fitur mungkin terbatas.';
  @override
  String get noExpiryDate => 'Tanpa tanggal kadaluarsa';
  @override
  String get invalidQuantity => 'Isi jumlah dengan angka, misalnya 2 atau 0,5.';
  @override
  String get fridgeLoadFailed => 'Kulkas belum bisa dimuat.\nPeriksa koneksi lalu coba lagi.';
  @override
  String get ingredientDeletedSync => 'Bahan dihapus (akan disinkron saat online)';
  @override
  String get ingredientDeleted => 'Bahan berhasil dihapus!';
  @override
  String get deleteFailed => 'Gagal menghapus';
  @override
  String get loadRecipeFailed => 'Gagal memuat resep';
  @override
  String get recipeSavedShort => 'Resep disimpan!';
  @override
  String get addToFridgeFailed => 'Gagal menambahkan bahan ke kulkas';
  @override
  String get safeForDiabetes => 'Aman Untuk Diabetes';
  @override
  String get nutFree => 'Bebas Kacang';
  @override
  String get useBlender => 'Pakai Blender';
  @override
  String get unnamedRecipe => 'Resep Tanpa Nama';
  @override
  String get saveFailedLogin => 'Gagal menyimpan. Pastikan sudah login.';
  @override
  String get allLabel => 'Semua';
  @override
  String get catTitleHealthy => 'Masakan Sehat Rendah Kalori';
  @override
  String get catTitleBalanced => 'Masakan Nutrisi Seimbang';
  @override
  String get catTitleWestern => 'Ala-Ala Masakan Barat';
  @override
  String otpExpiresIn(String t) => 'Kode akan expired dalam $t';
  @override
  String otpExpiresInClock(String t) => '⏰ OTP akan expired dalam $t';
  @override
  String googleSignInFailedDetail(String e) => 'Google sign-in gagal. Coba lagi. ($e)';
  @override
  String navigateFailed(String e) => 'Gagal navigasi: $e';
  @override
  String saveSessionFailed(String e) => 'Gagal menyimpan sesi: $e';
  @override
  String somethingWrong(String e) => 'Terjadi kesalahan: $e';
  @override
  String sendFailed(String e) => 'Gagal mengirim: $e';
  @override
  String recipeMeta(Object? cal, Object? minutes) => '$cal Kal • ${minutes}m';
  @override
  String kcal(Object? cal) => '$cal Kal';
  @override
  String kcalSpaced(Object? cal) => ' $cal Kal';
  @override
  String minutesSpaced(Object? n) => ' $n menit';
  @override
  String categoryBlurb(String name) => 'Kumpulan resep terbaik untuk kategori $name.';
  @override
  String greeting(String name) => 'Hallo, $name! ';
  @override
  String deleteIngredientBody(String name) => 'Yakin ingin menghapus \'$name\' dari kulkasmu?';
  @override
  String stockLabel(Object? n) => 'Stok: $n';
  @override
  String ingredientsAddedToFridge(Object? n) => '$n bahan ditambahkan ke kulkas';
  @override
  String noResultsFor(String q) => 'Tidak ada hasil untuk "$q"';
  @override
  String newIngredientNote(String name, String category) => 'Bahan baru: "$name" akan disimpan sebagai $category.';
  @override
  String willSaveWhenOnline(Object? n) => '$n bahan akan disimpan ke kulkas saat online';
  @override
  String savedNOfM(Object? ok, Object? n) => '$ok dari $n bahan berhasil disimpan.';
  @override
  String processedToFridge(Object? n) => '$n bahan diproses ke kulkas';
  @override
  String resendOtpIn(Object? s) => 'Kirim ulang OTP (${s}s)';
  @override
  String sendOtpIn(Object? s) => 'Kirim OTP (${s}s)';
  @override
  String otpValidAbout(String base, Object? minutes) => '$base Kode berlaku sekitar $minutes menit.';
  @override
  String safeForAllergy(Object? x) => 'Aman untuk alergi: $x';
  @override
  String viewedByUsers(Object? n) => 'Sudah dilihat $n kali oleh pengguna.';
  @override
  String daysLeft(Object? n) => '$n hari lagi';
  @override
  String couldNotOpen(String url) => 'Tidak bisa membuka $url';
  @override
  String saveFailedWith(Object? e) => 'Gagal menyimpan: $e';
  @override
  String lessThanDays(int n) => '< $n Hari';
  @override
  String quantityOf(Object? name) => 'Jumlah $name';

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
  String get versionNumberLabel => 'Version';
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
  String get releaseNotesSectionNew => 'What\'s new';
  @override
  String get releaseNotesSectionFix => 'Fixes';

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

  @override
  String get updateNow => 'Update now';
  @override
  String get updateCancelDownload => 'Cancel';
  @override
  String get updatePreparing => 'Preparing download…';
  @override
  String get updateWaitingForNetwork =>
      'Waiting for a connection… the download will resume automatically.';
  @override
  String get updateResumeCta => 'Resume';
  @override
  String get updateNetworkResume =>
      'The connection dropped. The download is saved, no need to start over.';
  @override
  String get updateRateLimited =>
      'Too many attempts from this network. Try again in a moment.';
  @override
  String get updateShowAllNotes => 'See all release notes';
  @override
  String get updateShowFullNotes => 'See full notes';
  @override
  String get updateForcedNotice =>
      'This version must be installed to continue.';
  @override
  String get updateConfirmInAndroid =>
      'Choose "Update" in the install prompt, then "Open" to run the new version.';
  @override
  String get updateVersionsBehind => 'Jumping {count} versions at once';
  @override
  String get updateOfficialRollback => 'Official SmartCook update {to}';

  @override
  String get buildNotOfficialTitle => 'This app is not official';
  @override
  String get buildNotOfficialBody =>
      'This SmartCook build is not signed with the official certificate, so the server will not let it connect. Download it again from the official source.';
  @override
  String get buildNotOfficialAction => 'Get the official version';
  // ---- screens (l10n sweep)
  @override
  String signInIn(Object? s) => 'Sign in (${s}s)';
  @override
  String get newPassword => 'New password';
  @override
  String get oldPassword => 'Current password';
  @override
  String get confirmPassword => 'Confirm password';
  @override
  String get confirmNewPassword => 'Confirm new password';
  @override
  String get savePassword => 'Save password';
  @override
  String get otpCodeField => 'OTP code (4 digits)';
  @override
  String get enterOtp4 => 'Enter the 4-digit OTP code';
  @override
  String get otpExpired => 'The OTP code has expired. Please resend it.';
  @override
  String get otpValidNote => 'The code is valid for 10 minutes after it is e-mailed';
  @override
  String get otpResent => 'A new OTP code has been sent';
  @override
  String get checkYourEmail => 'Check your email';
  @override
  String get verify => 'Verify';
  @override
  String get signInLabel => 'Sign in';
  @override
  String get signUpLabel => 'Sign up';
  @override
  String get forgotPassword => 'Forgot password?';
  @override
  String get noAccountYet => 'Don\'t have an account?';
  @override
  String get haveAccount => 'Already have an account?';
  @override
  String get enterYourEmail => 'Enter your email';
  @override
  String get enterYourPassword => 'Enter your password';
  @override
  String get googleSignInFailed => 'Google sign-in failed. Please try again.';
  @override
  String get googleSignInIncomplete => 'Couldn\'t complete sign-in with Google. Please try again.';
  @override
  String get invalidResponse => 'Invalid response';
  @override
  String get sessionNotFound => 'Sign-in session not found';
  @override
  String get forgotPasswordIntro => 'Don\'t worry! Enter your email address and we\'ll\nsend you instructions to reset your password';
  @override
  String get setPassword => 'Set password';
  @override
  String get createNewPasswordTitle => 'Create a new password';
  @override
  String get googleEmailNote => 'Your email will be the one from your Google account.';
  @override
  String get createNewPassword => 'Create new password';
  @override
  String get resetPassword => 'Reset password';
  @override
  String get enterPassword => 'Enter your password';
  @override
  String get reenterPassword => 'Re-enter your password';
  @override
  String get successTitle => 'Success!';
  @override
  String get passwordChangedBody => 'You have successfully changed your password.\nTap continue to sign in';
  @override
  String get continueLabel => 'Continue';
  @override
  String get newEmailRequired => 'New email is required';
  @override
  String get emailChanged => 'Email changed successfully';
  @override
  String get newEmail => 'New email';
  @override
  String get confirmEmail => 'Confirm email';
  @override
  String get passwordChanged => 'Password changed successfully';
  @override
  String get useOldPassword => 'Use current password';
  @override
  String get useEmailOtp => 'Use email OTP';
  @override
  String get chefOffline => 'SmartChef isn\'t available offline.\nPlease connect to the internet to continue.';
  @override
  String get clearHistoryTitle => 'Clear history?';
  @override
  String get delete => 'Delete';
  @override
  String get askAnythingCooking => 'Ask anything about cooking';
  @override
  String get typeMessage => 'Type a message...';
  @override
  String get searchFilter => 'Search filter';
  @override
  String get maxCaloriesLabel => 'Max. calories (kcal)';
  @override
  String get maxTimeLabel => 'Max. time (minutes)';
  @override
  String get apply => 'Apply';
  @override
  String get searchRecipes => 'Search recipes...';
  @override
  String get recipesNotFound => 'No recipes found 😥\nTry changing the filter or your search.';
  @override
  String get globalModeNote => 'Global mode: shows recipes from all users in the database (still adjusted to your allergies and preferences).';
  @override
  String get recentSearches => 'Recent searches';
  @override
  String get searchFavorites => 'Search your favourite recipes';
  @override
  String get showingCache => 'Showing cached data (offline)';
  @override
  String get pageNotFound => 'Page not found';
  @override
  String get whatToCookToday => 'What shall we cook today?';
  @override
  String get tasteCategories => 'Cooking taste categories';
  @override
  String get catHealthy => 'Healthy Food\nLow Calorie\nHigh Nutrition';
  @override
  String get catBalanced => 'Meals With\nBalanced Nutrition';
  @override
  String get catWestern => 'Western-Style\nDishes';
  @override
  String get fridgeQuestion => 'What\'s in your fridge?';
  @override
  String get findByIngredients => 'Find recipes based on the ingredients you have';
  @override
  String get addIngredients => 'Add ingredients';
  @override
  String get ingredientWord => 'Ingredient';
  @override
  String get noIngredientsYet => 'No ingredients yet';
  @override
  String get seeAllArrow => 'See all >';
  @override
  String get seeAll => 'See all';
  @override
  String get chooseMealTime => 'Choose meal time';
  @override
  String get savedForYou => 'Saved for you';
  @override
  String get top10Popular => 'Top 10 Popular Recipes';
  @override
  String get top5Recs => '5 Recommended Dishes';
  @override
  String get matchForYou => 'A match for you';
  @override
  String get deleteIngredientTitle => 'Delete ingredient?';
  @override
  String get yesDelete => 'Yes, delete';
  @override
  String get sortAndFilter => 'Sort & filter';
  @override
  String get sortBy => 'Sort by';
  @override
  String get mostStock => 'Most stock';
  @override
  String get leastStock => 'Least stock';
  @override
  String get expiryFilter => 'Expiry filter';
  @override
  String get maxStockLabel => 'Maximum stock';
  @override
  String get editFridgeIngredient => 'Edit fridge ingredient';
  @override
  String get ingredientName => 'Ingredient name';
  @override
  String get quantity => 'Quantity';
  @override
  String get saveChanges => 'Save changes';
  @override
  String get searchFridge => 'Search ingredients in the fridge...';
  @override
  String get ingredientsNotFound => 'No ingredients found 😥\nTry changing the filter or add an ingredient.';
  @override
  String get yourFridge => 'Your fridge';
  @override
  String get fridgeIntro => 'Easily check and manage the cooking ingredients in your fridge.';
  @override
  String get favSyncLater => 'Favourite changes will sync when you\'re online';
  @override
  String get recipeRemoved => 'Recipe removed from saved';
  @override
  String get recipeSaved => 'Recipe saved!';
  @override
  String get ingredientsNeeded => 'Ingredients needed';
  @override
  String get noIngredientData => 'No ingredient data';
  @override
  String get recipeNoValidId => 'This recipe has no valid ID';
  @override
  String get findMissingIngredients => 'Find missing ingredients';
  @override
  String get howToMake => 'How to make it';
  @override
  String get noSteps => 'No steps';
  @override
  String get watchTutorial => 'Watch the tutorial on YouTube';
  @override
  String get moreRecs => 'More recommendations';
  @override
  String get suitableFor => 'Suitable for diet, diabetes, low sugar, high fibre';
  @override
  String get favoritesOffline => 'Can\'t load favourites right now (offline)';
  @override
  String get savedTitle => 'Saved';
  @override
  String get noSavedRecipes => 'No saved recipes yet';
  @override
  String get searchOrTypeIngredient => 'Search or type a new ingredient (e.g. \"Spring onion\")';
  @override
  String get add => 'Add';
  @override
  String get byCategory => 'By category:';
  @override
  String get listLabel => 'List:';
  @override
  String get saveToFridge => 'Save to fridge';
  @override
  String get enterIngredientFirst => 'Enter the ingredient name first';
  @override
  String get pickCategoryFirst => 'Pick an ingredient category first';
  @override
  String get invalidCategory => 'Invalid category';
  @override
  String get ingredientAlreadyListed => 'This ingredient is already in this category';
  @override
  String get nothingSentToFridge => 'Nothing was sent to the fridge. Your list changes were saved.';
  @override
  String get done => 'Done';
  @override
  String get deleteAccountWarning => 'Your account and everything in it (fridge, favourite recipes, chat history) will be permanently deleted and can\'t be recovered.';
  @override
  String get sendCodeFailed => 'Couldn\'t send the code';
  @override
  String get emailRequired => 'Email is required';
  @override
  String get emailNeedsAt => 'Email must contain \'@\'';
  @override
  String get emailNeedsCom => 'Email must end with \'.com\'';
  @override
  String get savePasswordFailed => 'Couldn\'t save the password';
  @override
  String get loadingEmail => 'Loading email...';
  @override
  String get passwordRequired => 'Password is required';
  @override
  String get confirmPasswordRequired => 'Please confirm your password';
  @override
  String get passwordsDontMatch => 'Passwords don\'t match';
  @override
  String get otpVerifyFailed => 'OTP verification failed';
  @override
  String get otpVerifiedNewPassword => 'OTP verified. Please create a new password.';
  @override
  String get resendOtpFailed => 'Couldn\'t resend the OTP';
  @override
  String get weSentCodeTo => 'We sent a 4-digit code to\n';
  @override
  String get newPasswordRequired => 'New password is required';
  @override
  String get passwordMin6 => 'Password must be at least 6 characters';
  @override
  String get otpInvalid => 'Invalid OTP code';
  @override
  String get resetPasswordFailed => 'Couldn\'t reset the password';
  @override
  String get loginFailed => 'Sign-in failed';
  @override
  String get emailInvalid => 'Invalid email format';
  @override
  String get fieldRequired => 'Required';
  @override
  String get registerFailed => 'Registration failed';
  @override
  String get enterYourName => 'Enter your name';
  @override
  String get sendFailedShort => 'Couldn\'t send';
  @override
  String get filterDismiss => 'Dismiss filter';
  @override
  String get otpSentToEmail => 'The OTP code has been sent to your email.';
  @override
  String get sendOtpFailed => 'Couldn\'t send the OTP';
  @override
  String get changeEmailFailed => 'Couldn\'t change the email';
  @override
  String get sendOtp => 'Send OTP';
  @override
  String get changePasswordFailed => 'Couldn\'t change the password';
  @override
  String get oldPasswordRequired => 'Current password is required';
  @override
  String get codeWrongOrExpired => 'The code is wrong or has expired';
  @override
  String get tailoredToHealth => 'Tailored to your health preferences';
  @override
  String get expiredLabel => 'Expired';
  @override
  String get todayLabel => 'Today';
  @override
  String get tomorrowLabel => 'Tomorrow';
  @override
  String get ingredientUpdated => 'Ingredient updated!';
  @override
  String get updateFailed => 'Couldn\'t update';
  @override
  String get accessBlockedTitle => 'Access blocked';
  @override
  String get accessBlockedBody => 'You have been blocked from this service.';
  @override
  String get accountSuspendedTitle => 'Account suspended';
  @override
  String get accountSuspendedBody => 'This account has been suspended.';
  @override
  String restrictionReason(String reason) => 'Reason: $reason';
  @override
  String get soonestExpiry => 'Expiring soon';
  @override
  String mergedIntoExisting(int n) => n == 1 ? '1 item added to existing stock.' : '$n items added to existing stock.';
  @override
  String get unitLabel => 'Unit';
  @override
  String get expiryDateLabel => 'Expiry date';
  @override
  String get pickDate => 'Pick a date';
  @override
  String get clearDate => 'Clear date';
  @override
  String get backOnline => 'Back online';
  @override
  String get offlineBanner => 'You are offline. Some features may be limited.';
  @override
  String get noExpiryDate => 'No expiry date';
  @override
  String get invalidQuantity => 'Enter the quantity as a number, for example 2 or 0.5.';
  @override
  String get fridgeLoadFailed => 'Couldn\'t load your fridge.\nCheck your connection and try again.';
  @override
  String get ingredientDeletedSync => 'Ingredient deleted (will sync when you\'re online)';
  @override
  String get ingredientDeleted => 'Ingredient deleted!';
  @override
  String get deleteFailed => 'Couldn\'t delete';
  @override
  String get loadRecipeFailed => 'Couldn\'t load the recipe';
  @override
  String get recipeSavedShort => 'Recipe saved!';
  @override
  String get addToFridgeFailed => 'Couldn\'t add the ingredients to the fridge';
  @override
  String get safeForDiabetes => 'Safe for diabetes';
  @override
  String get nutFree => 'Nut-free';
  @override
  String get useBlender => 'Uses a blender';
  @override
  String get unnamedRecipe => 'Untitled recipe';
  @override
  String get saveFailedLogin => 'Couldn\'t save. Make sure you\'re signed in.';
  @override
  String get allLabel => 'All';
  @override
  String get catTitleHealthy => 'Healthy, Low-Calorie Food';
  @override
  String get catTitleBalanced => 'Balanced Nutrition Meals';
  @override
  String get catTitleWestern => 'Western-Style Dishes';
  @override
  String otpExpiresIn(String t) => 'The code expires in $t';
  @override
  String otpExpiresInClock(String t) => '⏰ The OTP expires in $t';
  @override
  String googleSignInFailedDetail(String e) => 'Google sign-in failed. Please try again. ($e)';
  @override
  String navigateFailed(String e) => 'Navigation failed: $e';
  @override
  String saveSessionFailed(String e) => 'Couldn\'t save the session: $e';
  @override
  String somethingWrong(String e) => 'Something went wrong: $e';
  @override
  String sendFailed(String e) => 'Couldn\'t send: $e';
  @override
  String recipeMeta(Object? cal, Object? minutes) => '$cal kcal • ${minutes}m';
  @override
  String kcal(Object? cal) => '$cal kcal';
  @override
  String kcalSpaced(Object? cal) => ' $cal kcal';
  @override
  String minutesSpaced(Object? n) => ' $n min';
  @override
  String categoryBlurb(String name) => 'The best recipes for the $name category.';
  @override
  String greeting(String name) => 'Hello, $name! ';
  @override
  String deleteIngredientBody(String name) => 'Are you sure you want to delete \'$name\' from your fridge?';
  @override
  String stockLabel(Object? n) => 'Stock: $n';
  @override
  String ingredientsAddedToFridge(Object? n) => '$n ingredient(s) added to the fridge';
  @override
  String noResultsFor(String q) => 'No results for "$q"';
  @override
  String newIngredientNote(String name, String category) => 'New ingredient: "$name" will be saved as $category.';
  @override
  String willSaveWhenOnline(Object? n) => '$n ingredient(s) will be saved to the fridge when you\'re online';
  @override
  String savedNOfM(Object? ok, Object? n) => '$ok of $n ingredient(s) saved.';
  @override
  String processedToFridge(Object? n) => '$n ingredient(s) sent to the fridge';
  @override
  String resendOtpIn(Object? s) => 'Resend OTP (${s}s)';
  @override
  String sendOtpIn(Object? s) => 'Send OTP (${s}s)';
  @override
  String otpValidAbout(String base, Object? minutes) => '$base The code is valid for about $minutes minutes.';
  @override
  String safeForAllergy(Object? x) => 'Safe for allergy: $x';
  @override
  String viewedByUsers(Object? n) => 'Viewed $n times by users.';
  @override
  String daysLeft(Object? n) => '$n days left';
  @override
  String couldNotOpen(String url) => 'Could not open $url';
  @override
  String saveFailedWith(Object? e) => 'Couldn\'t save: $e';
  @override
  String lessThanDays(int n) => '< $n days';
  @override
  String quantityOf(Object? name) => 'Quantity of $name';

}

/// `context.s.logout` - always the language the app is showing now, and
/// registers the widget to rebuild when the language changes.
extension StrContext on BuildContext {
  Str get s => stringsFor(Localizations.localeOf(this));
}

/// Strings for code that runs after an `await` (snackbars, dialogs opened from
/// async handlers). Touching `context` there is unsafe: the page may already be
/// gone, and looking up an ancestor of a deactivated element throws. This reads
/// the app-wide language directly, so it needs no `BuildContext`. Inside
/// `build`, prefer `context.s`, which also rebuilds the widget when the language
/// changes.
Str get currentStrings => stringsFor(LanguageController.instance.locale);
