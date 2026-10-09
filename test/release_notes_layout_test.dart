import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/services/app_update_checker.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';

ReleaseNote _n(String v, int b, String date) => ReleaseNote(
      version: v,
      build: b,
      androidVersionCode: b,
      date: date,
      notes:
          'Judul di bagian atas kulkas tidak lagi saling menimpa di layar kecil atau huruf besar.',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final lang in ['id', 'en']) {
    for (final scale in [1.0, 1.6, 2.0]) {
      testWidgets(
          'release notes ($lang, text x$scale, narrow): the badge and the date never run off the edge',
          (tester) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        await LanguageController.instance.set(Locale(lang));
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.dark,
          locale: Locale(lang),
          supportedLocales: LanguageController.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (c, w) => MediaQuery(
              data: MediaQuery.of(c)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: w!),
          home: Scaffold(
            body: ReleaseNotesList(
              controller: ScrollController(),
              installedBuild: 24,
              releases: [
                _n('1.3.1', 25, '2026-10-09'),
                _n('1.3.0', 24, '2026-10-10'),
                _n('1.2.0', 23, '2026-10-09'),
              ],
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      });
    }
  }
}
