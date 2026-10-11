import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/auth/google_set_password.dart';
import 'package:smartcook/core/l10n/strings.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/view/onboarding/form.dart';
import 'package:smartcook/view/splashscreen.dart';

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

  group('where the splash sends a signed-in person', () {
    test(
        'a Google account without a password goes back to that step, before anything else',
        () {
      expect(
          splashRouteFor(
              {'needs_password': true, 'onboarding_completed': false}),
          SplashRoute.setPassword);
      expect(
          splashRouteFor(
              {'needs_password': true, 'onboarding_completed': true}),
          SplashRoute.setPassword);
    });
    test('otherwise onboarding decides', () {
      expect(
          splashRouteFor(
              {'needs_password': false, 'onboarding_completed': false}),
          SplashRoute.onboarding);
      expect(splashRouteFor({'onboarding_completed': true}), SplashRoute.home);
      expect(splashRouteFor(null), SplashRoute.onboarding);
    });
  });

  group('password step for a Google account', () {
    testWidgets(
        'asks for the name (prefilled from Google) and the password; the name cannot be empty',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
          const GoogleSetPasswordPage(email: 'g@example.com', name: 'Gita')));
      await tester.pump();
      final s = currentStrings;
      final fields = find.byType(TextFormField);
      expect(fields, findsNWidgets(4),
          reason: 'e-mail, name, password, confirm');
      expect(find.widgetWithText(TextFormField, 'Gita'), findsOneWidget);

      await tester.enterText(fields.at(1), '   ');
      await tester.pump();
      expect(find.text(s.fieldRequired), findsOneWidget);
      await tester.enterText(fields.at(1), 'Gita Baru');
      await tester.pump();
      expect(find.text(s.fieldRequired), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('onboarding does not ask for the name again', () {
    testWidgets('first time: no name field', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(const form()));
      await tester.pump();
      expect(find.text('Masukkan Namamu...'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('editing from the profile: the name can still be changed',
        (tester) async {
      _phone(tester);
      await tester.pumpWidget(_app(
          const form(editFromProfile: true, initialData: {'name': 'Ani'})));
      await tester.pump();
      expect(find.widgetWithText(TextFormField, 'Ani'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
