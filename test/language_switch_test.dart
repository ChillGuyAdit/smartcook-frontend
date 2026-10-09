import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/l10n/strings.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/theme/language_controller.dart';

/// Mirrors the MaterialApp setup in main.dart: the app is rebuilt from a
/// Listenable whenever the language changes.
class _Harness extends StatelessWidget {
  const _Harness({required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
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
}

/// A screen that uses everything that depends on Material/Widgets
/// localisation: Scaffold, AppBar, TextField (selection toolbar strings),
/// a dialog with radio rows, a SnackBar, and the app's own string table.
class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final s = stringsFor(Localizations.localeOf(context));
    return Scaffold(
      appBar: AppBar(title: Text(s.profile)),
      body: Column(
        children: [
          Text(s.logout, key: const Key('logout')),
          const TextField(key: Key('field')),
          TextButton(
            key: const Key('open'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (ctx) => SimpleDialog(
                title: Text(s.language),
                children: [
                  for (final l in LanguageController.supportedLocales)
                    RadioListTile<Locale>(
                      value: l,
                      groupValue: LanguageController.instance.locale,
                      title: Text(l.languageCode),
                      onChanged: (v) {
                        if (v == null) return;
                        // Same order as profile_page.dart: close, then switch.
                        Navigator.pop(ctx);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          LanguageController.instance.set(v);
                        });
                      },
                    ),
                ],
              ),
            ),
            child: Text(s.language),
          ),
          TextButton(
            key: const Key('snack'),
            onPressed: () => ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(s.saveFailed))),
            child: const Text('snack'),
          ),
        ],
      ),
    );
  }
}

void main() {
  setUp(() async {
    DevLog.disabled = true;
    SharedPreferences.setMockInitialValues({});
    await LanguageController.instance.set(const Locale('id'));
  });

  Future<void> pick(WidgetTester tester, String code) async {
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(code));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'switching id -> en -> id through the dialog never blanks the screen',
      (tester) async {
    await tester.pumpWidget(const _Harness(home: _Screen()));
    expect(find.text(const StrId().logout), findsOneWidget);

    for (var round = 0; round < 3; round++) {
      await pick(tester, 'en');
      expect(tester.takeException(), isNull, reason: 'round $round to en');
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text(const StrEn().logout), findsOneWidget);
      expect(find.text(const StrId().logout), findsNothing);

      await pick(tester, 'id');
      expect(tester.takeException(), isNull, reason: 'round $round to id');
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text(const StrId().logout), findsOneWidget);
      expect(find.text(const StrEn().logout), findsNothing);
    }
  });

  testWidgets('text fields, SnackBars and selection work in both languages',
      (tester) async {
    await tester.pumpWidget(const _Harness(home: _Screen()));
    for (final code in ['en', 'id']) {
      await pick(tester, code);
      await tester.enterText(find.byKey(const Key('field')), 'halo');
      await tester.tap(find.byKey(const Key('snack')));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: code);
      expect(find.byType(SnackBar), findsOneWidget);
    }
  });

  testWidgets('switching while a dialog is still open does not crash',
      (tester) async {
    await tester.pumpWidget(const _Harness(home: _Screen()));
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    // Worst case the original bug hit: change the language underneath an open dialog.
    await LanguageController.instance.set(const Locale('en'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('the saved language survives a restart', (tester) async {
    await LanguageController.instance.set(const Locale('en'));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('smartcook_locale'), 'en');
    await LanguageController.instance.set(const Locale('id'));
    expect(prefs.getString('smartcook_locale'), 'id');
  });
}
