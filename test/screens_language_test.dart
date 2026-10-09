import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/auth/forgotpassword.dart';
import 'package:smartcook/auth/mailpassoword.dart';
import 'package:smartcook/auth/resetpassword.dart';
import 'package:smartcook/auth/signIn.dart';
import 'package:smartcook/auth/signUp.dart';
import 'package:smartcook/auth/sukses.dart';
import 'package:smartcook/core/l10n/strings.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/page/bot_page.dart';
import 'package:smartcook/page/category.dart';
import 'package:smartcook/page/change_email_page.dart';
import 'package:smartcook/page/change_password_page.dart';
import 'package:smartcook/page/delete_account_page.dart';
import 'package:smartcook/page/homepage.dart';
import 'package:smartcook/page/kulkas.dart';
import 'package:smartcook/page/profile_page.dart';
import 'package:smartcook/page/save_page.dart';
import 'package:smartcook/page/search_page.dart';
import 'package:smartcook/page/tambahkan_bahan.dart';

/// Renders the REAL screens and switches the language while they are on screen.
/// What this proves: no exception on either language, nothing blank, and the
/// visible copy actually changes (no Indonesian left in English and no English
/// left in Indonesian).
class _App extends StatelessWidget {
  const _App(this.home);
  final Widget home;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: LanguageController.instance,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          locale: LanguageController.instance.locale,
          supportedLocales: LanguageController.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: home,
        ),
      );
}

/// Every piece of visible copy: Text widgets plus input hints/labels.
List<String> visibleCopy(WidgetTester tester) {
  final out = <String>[];
  for (final e in tester.widgetList<Text>(find.byType(Text))) {
    final t = e.data ?? e.textSpan?.toPlainText();
    if (t != null && t.trim().isNotEmpty) out.add(t.trim());
  }
  for (final e in tester.widgetList<TextField>(find.byType(TextField))) {
    for (final t in [e.decoration?.hintText, e.decoration?.labelText]) {
      if (t != null && t.trim().isNotEmpty) out.add(t.trim());
    }
  }
  for (final e in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
    // hint of the inner TextField is already covered above
    if (e.initialValue != null && e.initialValue!.isNotEmpty) out.add(e.initialValue!);
  }
  return out;
}

// Words that only belong to one language. Brand and loan words are left out.
const indonesianOnly = [
  'Masukkan', 'Lupa ', 'Belum punya', 'Sudah punya', 'Kode ', 'Gagal', 'Ubah ',
  'Ganti ', 'Simpan', 'wajib', 'Konfirmasi', 'Selamat', 'Lanjutkan', 'Kirim ',
  'Berhasil', 'Pakai ', 'Daftar', 'Cek email',
];
const englishOnly = [
  'Sign Up', 'Signin', 'SignIn', 'Check your email', 'Verify', 'Create new',
  'Enter your', 'Re-enter', 'Success!', 'Forgot password', 'Sign in', 'Sign up',
];

void main() {
  setUp(() async {
    // Plugins that only exist on a device: answer them so screens that read the
    // app version or the secure store finish loading like they do on a phone.
    TestWidgetsFlutterBinding.ensureInitialized();
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    PackageInfo.setMockInitialValues(
      appName: 'SmartCook',
      packageName: 'com.example.smartcook',
      version: '1.1.1',
      buildNumber: '17',
      buildSignature: '',
    );
    DevLog.disabled = true;
    SharedPreferences.setMockInitialValues({});
    await LanguageController.instance.set(const Locale('id'));
  });

  final screens = <String, Widget Function()>{
    'sign in': () => const signin(),
    'sign up': () => const signup(),
    'forgot password': () => const forgotpassowrd(),
    'verify email code': () => const mailpassword(email: 'a@b.co'),
    'reset password': () => const resetpassword(email: 'a@b.co', otp: '1234'),
    'password changed': () => const sukses(),
    'change email': () => const ChangeEmailPage(),
    'change password': () => const ChangePasswordPage(),
    'delete account': () => const DeleteAccountPage(),
    'home': () => const homepage(),
    'fridge': () => const KulkasPage(),
    'search': () => const SearchPage(),
    'saved recipes': () => const SavePage(),
    'chat bot': () => const BotPage(),
    'add ingredients': () => const TambahkanBahanPage(),
    'profile': () => const ProfilePage(),
    'category (healthy)': () => const CategoryPage(
          categoryName: 'Masakan Sehat Rendah Kalori',
          themeColors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          headerImagePath: 'image/broccoli.png',
        ),
  };

  for (final entry in screens.entries) {
    testWidgets('${entry.key}: copy follows the language, no blank screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_App(entry.value()));
      // Let the first (offline, failing) data load finish, retries included.
      for (var i = 0; i < 70; i++) {
        // Real time for the (blocked, instantly failing) network calls...
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        // ...fake time for retry back-offs and animations.
        await tester.pump(const Duration(milliseconds: 500));
        final loading = find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
        if (i >= 5 && !loading && visibleCopy(tester).isNotEmpty) break;
      }
      expect(tester.takeException(), isNull, reason: '${entry.key} in id');
      final id = visibleCopy(tester);
      expect(id, isNotEmpty, reason: '${entry.key} rendered nothing in id');

      await LanguageController.instance.set(const Locale('en'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '${entry.key} in en');
      final en = visibleCopy(tester);
      expect(en, isNotEmpty, reason: '${entry.key} rendered nothing in en');

      // The copy must actually change...
      expect(en.join('|'), isNot(id.join('|')), reason: '${entry.key}: language switch changed nothing');
      // ...and leave nothing of the other language behind.
      for (final w in indonesianOnly) {
        expect(en.where((t) => t.contains(w)), isEmpty, reason: '${entry.key} (en) still says "$w": ${en.where((t) => t.contains(w))}');
      }
      for (final w in englishOnly) {
        expect(id.where((t) => t.contains(w)), isEmpty, reason: '${entry.key} (id) still says "$w": ${id.where((t) => t.contains(w))}');
      }

      // And back again.
      await LanguageController.instance.set(const Locale('id'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '${entry.key} back to id');
      expect(visibleCopy(tester).join('|'), id.join('|'), reason: '${entry.key}: round trip differs');
    });
  }

  // Regression: in English "Already have an account? Sign in" used to wrap and
  // push "Sign in" to the far left edge of the next line.
  for (final lang in ['id', 'en']) {
    for (final c in [
      ('sign up', () => const signup(), (Str s) => s.haveAccount, (Str s) => s.signInLabel),
      ('sign in', () => const signin(), (Str s) => s.noAccountYet, (Str s) => s.signUpLabel),
    ]) {
      testWidgets('${c.$1} ($lang): the switch-screen link sits on the same line, centred', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        await LanguageController.instance.set(Locale(lang));
        await tester.pumpWidget(_App(c.$2()));
        await tester.pump(const Duration(milliseconds: 500));
        final s = stringsFor(Locale(lang));
        final question = tester.getRect(find.text(c.$3(s)).last);
        final link = tester.getRect(find.text(c.$4(s)).last);
        expect((question.center.dy - link.center.dy).abs(), lessThan(10), reason: 'link wrapped to its own line');
        final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
        final group = question.expandToInclude(link);
        expect((group.center.dx - width / 2).abs(), lessThan(width * 0.12), reason: 'not centred: $group');
      });
    }
  }
}
