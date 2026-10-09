import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/l10n/strings.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/services/restriction.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/page/restricted_page.dart';

Widget _app(Widget home) => MaterialApp(
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
    );

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    SharedPreferences.setMockInitialValues({});
    DevLog.disabled = true;
    Restriction.clear();
    Restriction.handler = null;
  });

  test('one notice per kind, however many requests fail; clearing allows the next', () {
    final seen = <String>[];
    Restriction.handler = (c, m, r) => seen.add('$c|$m|$r');
    Restriction.report(Restriction.ipCode, 'blocked', 'abuse');
    Restriction.report(Restriction.ipCode, 'blocked', 'abuse');
    Restriction.report(Restriction.ipCode, 'blocked', 'abuse');
    expect(seen, ['IP_BLOCKED|blocked|abuse']);
    Restriction.report(Restriction.accountCode, 'suspended', '');
    expect(seen.length, 2, reason: 'a different kind is shown');
    Restriction.report('SOMETHING_ELSE', 'x', '');
    Restriction.report(null.toString(), 'x', '');
    expect(seen.length, 2, reason: 'only the two known codes count');
    Restriction.clear();
    Restriction.report(Restriction.ipCode, 'blocked', 'abuse');
    expect(seen.length, 3);
    expect(Restriction.isRestriction('IP_BLOCKED'), isTrue);
    expect(Restriction.isRestriction('TOKEN_EXPIRED'), isFalse);
    expect(Restriction.isRestriction(null), isFalse);
  });

  for (final lang in ['id', 'en']) {
    testWidgets('notice page ($lang): title, server message and reason; back does nothing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await LanguageController.instance.set(Locale(lang));
      final s = stringsFor(Locale(lang));

      await tester.pumpWidget(_app(const RestrictedPage(code: Restriction.accountCode, message: 'Akun ini ditangguhkan.', reason: 'Melanggar aturan')));
      await tester.pump();
      expect(find.text(s.accountSuspendedTitle), findsOneWidget);
      expect(find.text('Akun ini ditangguhkan.'), findsOneWidget);
      expect(find.text(s.restrictionReason('Melanggar aturan')), findsOneWidget);
      expect(find.text(s.logout), findsOneWidget, reason: 'a suspended account can only sign out');

      await tester.pumpWidget(_app(const RestrictedPage(code: Restriction.ipCode, message: '', reason: '')));
      await tester.pump();
      expect(find.text(s.accessBlockedTitle), findsOneWidget);
      expect(find.text(s.accessBlockedBody), findsOneWidget, reason: 'falls back to the built-in text without a server message');
      expect(find.textContaining(s.restrictionReason('').split(':').first), findsNothing, reason: 'no reason box without a reason');
      expect(find.text(s.updateRetry), findsOneWidget);

      // the system back key is ignored
      final popped = await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text(s.accessBlockedTitle), findsOneWidget);
      expect(popped, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
