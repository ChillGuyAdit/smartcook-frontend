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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    SharedPreferences.setMockInitialValues({});
    DevLog.disabled = true;
    Restriction.clear();
    Restriction.handler = null;
  });

  test(
      'one notice per kind, however many requests fail; clearing allows the next',
      () {
    final seen = <String>[];
    Restriction.handler = (c, m, r, left) => seen.add('$c|$m|$r');
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
    testWidgets(
        'notice page ($lang): title, server message and reason; back does nothing',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await LanguageController.instance.set(Locale(lang));
      final s = stringsFor(Locale(lang));

      await tester.pumpWidget(_app(const RestrictedPage(
          code: Restriction.accountCode,
          message: 'Akun ini ditangguhkan.',
          reason: 'Melanggar aturan')));
      await tester.pump();
      expect(find.text(s.accountSuspendedTitle), findsOneWidget);
      expect(find.text('Akun ini ditangguhkan.'), findsOneWidget);
      expect(
          find.text(s.restrictionReason('Melanggar aturan')), findsOneWidget);
      expect(find.text(s.logout), findsOneWidget,
          reason: 'a suspended account can only sign out');

      await tester.pumpWidget(_app(const RestrictedPage(
          code: Restriction.ipCode, message: '', reason: '')));
      await tester.pump();
      expect(find.text(s.accessBlockedTitle), findsOneWidget);
      expect(find.text(s.accessBlockedBody), findsOneWidget,
          reason: 'falls back to the built-in text without a server message');
      expect(find.textContaining(s.restrictionReason('').split(':').first),
          findsNothing,
          reason: 'no reason box without a reason');
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

  group('time left, switching account, updating', () {
    testWidgets('a timed restriction counts down second by second',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await LanguageController.instance.set(const Locale('id'));
      await tester.pumpWidget(_app(const RestrictedPage(
          code: Restriction.accountCode,
          message: '',
          reason: '',
          remainingSeconds: 3725)));
      await tester.pump();
      expect(find.text('01:02:05'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('01:02:04'), findsOneWidget);
      expect(find.text(stringsFor(const Locale('id')).restrictionLeftLabel),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no end date: says it lasts until lifted, no countdown',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await LanguageController.instance.set(const Locale('en'));
      await tester.pumpWidget(_app(const RestrictedPage(
          code: Restriction.ipCode, message: '', reason: '')));
      await tester.pump();
      final s = stringsFor(const Locale('en'));
      expect(find.text(s.restrictionNoEnd), findsOneWidget);
      expect(find.byKey(const Key('restriction-countdown')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
        'an account suspension offers sign-out and says other accounts work; an address block says switching does not help; both offer an update check',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      for (final lang in ['id', 'en']) {
        await LanguageController.instance.set(Locale(lang));
        final s = stringsFor(Locale(lang));
        await tester.pumpWidget(_app(const RestrictedPage(
            code: Restriction.accountCode, message: '', reason: '')));
        await tester.pump();
        expect(find.text(s.accountSwitchHint), findsOneWidget);
        expect(find.text(s.ipSwitchHint), findsNothing);
        expect(find.text(s.logout), findsOneWidget);
        expect(find.text(s.checkForUpdate), findsOneWidget);
        await tester.pumpWidget(_app(const RestrictedPage(
            code: Restriction.ipCode, message: '', reason: '')));
        await tester.pump();
        expect(find.text(s.ipSwitchHint), findsOneWidget);
        expect(find.text(s.accountSwitchHint), findsNothing);
        expect(find.text(s.checkForUpdate), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });

    test('the time left reaches the handler, and the day format reads well',
        () {
      Restriction.clear();
      int? got;
      Restriction.handler = (c, m, r, left) => got = left;
      Restriction.report(Restriction.accountCode, 'x', '', 5400);
      expect(got, 5400);
      Restriction.handler = null;
      Restriction.clear();
      final id = stringsFor(const Locale('id'));
      final en = stringsFor(const Locale('en'));
      expect(formatRestrictionLeft(id, 90061), '1 hari 01:01:01');
      expect(formatRestrictionLeft(en, 2 * 86400 + 5), '2 days 00:00:05');
      expect(formatRestrictionLeft(en, -3), '00:00:00');
    });

    testWidgets('narrow phone with huge text: no overflow, in both languages',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      for (final lang in ['id', 'en']) {
        await LanguageController.instance.set(Locale(lang));
        for (final code in [Restriction.accountCode, Restriction.ipCode]) {
          await tester.pumpWidget(MediaQuery(
            data: const MediaQueryData(
                size: Size(360, 640), textScaler: TextScaler.linear(2.0)),
            child: _app(RestrictedPage(
                code: code,
                message: '',
                reason: 'Melanggar aturan yang cukup panjang untuk dua baris',
                remainingSeconds: 200000)),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$lang $code');
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  });
}
