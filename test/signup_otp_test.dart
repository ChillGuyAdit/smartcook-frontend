import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/auth/mailpassoword.dart';
import 'package:smartcook/auth/signUp.dart';
import 'package:smartcook/core/l10n/strings.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/page/reusable/notice_banner.dart';
import 'package:smartcook/service/api_service.dart';

Widget _app(Widget home) => MaterialApp(
      theme: AppTheme.light,
      locale: LanguageController.instance.locale,
      supportedLocales: LanguageController.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sign up form', () {
    testWidgets(
        'the name field accepts a plain name; only the e-mail field is checked as an e-mail',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const signup()));
      await tester.pump(const Duration(milliseconds: 300));
      final s = currentStrings;
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(3));

      await tester.enterText(fields.at(0), 'test');
      await tester.pump();
      expect(find.text(s.emailInvalid), findsNothing,
          reason: 'a name is not an e-mail address');

      await tester.enterText(fields.at(1), 'bukan-email');
      await tester.pump();
      expect(find.text(s.emailInvalid), findsOneWidget);

      await tester.enterText(fields.at(1), 'ani@example.com');
      await tester.pump();
      expect(find.text(s.emailInvalid), findsNothing);
    });
  });

  group('reset-code screen', () {
    testWidgets(
        'a code that was just sent shows its countdown, never "expired"',
        (tester) async {
      _phone(tester);
      final future = DateTime.now().add(const Duration(minutes: 10));
      SharedPreferences.setMockInitialValues({
        'otp_expiry_forgot:ani@example.com': future.millisecondsSinceEpoch,
      });
      await tester
          .pumpWidget(_app(const mailpassword(email: 'ani@example.com')));
      // first frame, before the stored expiry has been read
      expect(find.text(currentStrings.otpExpired), findsNothing);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(currentStrings.otpExpired), findsNothing);
      expect(find.textContaining(RegExp(r'(09|10):')), findsOneWidget,
          reason: 'a visible countdown from about 10 minutes');
      expect(find.text(currentStrings.otpValidNote), findsOneWidget,
          reason: 'tells how long the code is valid');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('once the time is really up it says expired', (tester) async {
      _phone(tester);
      SharedPreferences.setMockInitialValues({});
      await tester
          .pumpWidget(_app(const mailpassword(email: 'ani@example.com')));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(currentStrings.otpExpired), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('announcement display rule', () {
    Widget host(Future<ApiResponse> Function() f) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: NoticeBanner(fetch: f)),
        );
    ApiResponse ok(dynamic d) => ApiResponse(success: true, data: d);

    testWidgets('"once": shown a single time per device, then never again',
        (tester) async {
      Future<ApiResponse> f() async =>
          ok({'id': 'once-1', 'text': 'Sekali saja', 'mode': 'once'});
      await tester.pumpWidget(host(f));
      await tester.pumpAndSettle();
      expect(find.text('Sekali saja'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(f));
      await tester.pumpAndSettle();
      expect(find.text('Sekali saja'), findsNothing,
          reason: 'second app open: already seen');

      // a new announcement is a new one
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(host(() async =>
          ok({'id': 'once-2', 'text': 'Yang baru', 'mode': 'once'})));
      await tester.pumpAndSettle();
      expect(find.text('Yang baru'), findsOneWidget);
    });

    testWidgets(
        '"always": comes back on the next launch even after the X was pressed in an earlier launch',
        (tester) async {
      Future<ApiResponse> f() async =>
          ok({'id': 'always-1', 'text': 'Selalu', 'mode': 'always'});
      await tester.pumpWidget(host(f));
      await tester.pumpAndSettle();
      expect(find.text('Selalu'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      // nothing is stored for "always", so a fresh launch shows it again
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(host(f));
      await tester.pumpAndSettle();
      expect(find.text('Selalu'), findsOneWidget);
    });
  });
}
