import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/l10n/strings.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/page/kulkas.dart';
import 'package:smartcook/page/reusable/fridge_details_fields.dart';
import 'package:smartcook/page/tambahkan_bahan.dart';
import 'package:smartcook/service/api_service.dart';

/// The fridge page with real-looking data: what is shown, what is hidden and
/// whether long English/Indonesian text fits a narrow phone.
Widget _app(Widget home) => AnimatedBuilder(
      animation: LanguageController.instance,
      builder: (context, _) => MaterialApp(
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

String _in(int days) =>
    DateTime.now().add(Duration(days: days)).toUtc().toIso8601String();

ApiResponse _ok(List<Map<String, dynamic>> items) =>
    ApiResponse(success: true, data: items);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

final _sampleItems = [
  {
    '_id': 'a',
    'ingredient_name': 'Beras',
    'quantity': 1000,
    'unit': 'gram',
    'expired_date': _in(30)
  },
  {
    '_id': 'b',
    'ingredient_name': 'Tepung terigu protein tinggi untuk roti dan kue basah',
    'quantity': 2500,
    'unit': 'gram',
    'expired_date': null
  },
  {
    '_id': 'c',
    'ingredient_name': 'Gula',
    'quantity': 0.5,
    'unit': 'kg',
    'expired_date': _in(2)
  },
  {
    '_id': 'd',
    'ingredient_name': 'Susu',
    'quantity': 1.0,
    'unit': 'liter',
    'expired_date': _in(-3)
  },
];

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    PackageInfo.setMockInitialValues(
        appName: 'SmartCook',
        packageName: 'com.example.smartcook',
        version: '1.1.4',
        buildNumber: '20',
        buildSignature: '');
    DevLog.disabled = true;
    SharedPreferences.setMockInitialValues({});
    await LanguageController.instance.set(const Locale('id'));
  });

  final items = _sampleItems;

  for (final lang in ['id', 'en']) {
    testWidgets(
        'fridge ($lang): every item is listed, nothing hidden by a default stock limit, no overflow',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      // a phone with a status bar / camera cut-out, like the real ones
      tester.view.padding = const FakeViewPadding(top: 36 * 2.75);
      tester.view.viewPadding = const FakeViewPadding(top: 36 * 2.75);
      await LanguageController.instance.set(Locale(lang));
      await tester.pumpWidget(_app(KulkasPage(loader: () async => _ok(items))));
      await _settle(tester);

      expect(find.text('Beras'), findsOneWidget);
      expect(find.textContaining('Tepung terigu'), findsOneWidget,
          reason: '2500 g must not be hidden by a default limit');
      expect(find.text('Gula'), findsOneWidget);
      expect(find.text('Susu'), findsOneWidget);
      // decimals and units are shown as they are, "1.0" becomes "1"
      expect(find.textContaining('0.5 kg'), findsOneWidget);
      expect(find.textContaining('1 liter'), findsOneWidget);
      expect(find.textContaining('1.0 liter'), findsNothing);
      // no invented expiry: the item without a date says so
      expect(
          find.text(
              lang == 'id' ? 'Tanpa tanggal kadaluarsa' : 'No expiry date'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'fridge: a failed load says so and offers a retry instead of showing an empty fridge',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    var calls = 0;
    await tester.pumpWidget(_app(KulkasPage(loader: () async {
      calls++;
      return calls == 1
          ? ApiResponse(success: false, message: 'x')
          : _ok(items);
    })));
    await _settle(tester);
    expect(find.textContaining('Kulkas belum bisa dimuat'), findsOneWidget);
    expect(find.textContaining('Bahan tidak ditemukan'), findsNothing);
    await tester.tap(find.text('Coba lagi'));
    await _settle(tester);
    expect(find.text('Beras'), findsOneWidget);
  });

  testWidgets('fridge: items stay on screen when a refresh fails',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    var calls = 0;
    await tester.pumpWidget(_app(KulkasPage(loader: () async {
      calls++;
      return calls == 1
          ? _ok(items)
          : ApiResponse(success: false, message: 'x');
    })));
    await _settle(tester);
    expect(find.text('Beras'), findsOneWidget);
    // the floating button reloads the list when it comes back from "add"
    await tester.tap(find.byType(FloatingActionButton));
    await _settle(tester);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await _settle(tester);
    expect(calls, greaterThanOrEqualTo(2), reason: 'coming back must reload');
    expect(find.text('Beras'), findsOneWidget,
        reason: 'a failed refresh must not wipe the list');
  });

  fridgeDetailsTests();
  addPageTests();
  headerLayoutTests();
  flowTests();
}

void fridgeDetailsTests() {
  testWidgets('unit and expiry fields: choose a unit, pick a date, clear it',
      (tester) async {
    await LanguageController.instance.set(const Locale('en'));
    String unit = 'pcs';
    DateTime? expiry;
    await tester.pumpWidget(_app(Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: FridgeDetailsFields(
            unit: unit,
            expiry: expiry,
            onUnit: (u) => setState(() => unit = u),
            onExpiry: (d) => setState(() => expiry = d),
          ),
        ),
      ),
    )));
    await tester.pump();
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Pick a date'), findsOneWidget);

    await tester.tap(find.text('kg'));
    await tester.pump();
    expect(unit, 'kg');

    await tester.tap(find.text('Pick a date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(expiry, isNotNull);
    expect(find.text('Pick a date'), findsNothing);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(expiry, isNull,
        reason:
            'a cleared date must be reported as null so the server clears it');
    expect(find.text('Pick a date'), findsOneWidget);
  });

  for (final lang in ['id', 'en']) {
    testWidgets(
        'fridge edit sheet ($lang): unit chips and date button fit and show the item values',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await LanguageController.instance.set(Locale(lang));
      await tester.pumpWidget(_app(KulkasPage(
          loader: () async => _ok([
                {
                  '_id': 'a',
                  'ingredient_name': 'Gula',
                  'quantity': 0.5,
                  'unit': 'kg',
                  'expired_date': _in(5)
                },
              ]))));
      await _settle(tester);
      await tester.tap(find.byIcon(Icons.edit_note_rounded));
      await tester.pumpAndSettle();
      final s = stringsFor(Locale(lang));
      expect(find.text(s.unitLabel), findsOneWidget);
      expect(find.text(s.expiryDateLabel), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.text(s.pickDate), findsNothing,
          reason: 'the item already has a date');
      expect(find.text('0.5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

void addPageTests() {
  testWidgets(
      'add ingredient dialog: unit and expiry can be set next to the quantity',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await LanguageController.instance.set(const Locale('en'));
    await tester.pumpWidget(_app(const TambahkanBahanPage()));
    await _settle(tester);
    await tester.tap(find.text('Protein'));
    await tester.pumpAndSettle();
    // every row shows "<count> <unit>"; the default unit is pcs
    final pill = find.text('0 pcs').first;
    await tester.tap(pill);
    await tester.pumpAndSettle();
    expect(find.text('Unit'), findsOneWidget);
    expect(find.text('Expiry date'), findsOneWidget);
    await tester.tap(find.text('gram'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add_circle));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('1 gram'), findsOneWidget,
        reason: 'the row shows the chosen unit');
    expect(tester.takeException(), isNull);
  });
}

void headerLayoutTests() {
  for (final lang in ['id', 'en']) {
    for (final top in [0.0, 24.0, 48.0]) {
      for (final scale in [1.0, 1.3, 1.6]) {
        testWidgets(
            'fridge header ($lang, status bar ${top.toInt()}dp, font x$scale): nothing overlaps before scrolling',
            (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 2.75;
          tester.view.padding = FakeViewPadding(top: top * 2.75);
          tester.view.viewPadding = FakeViewPadding(top: top * 2.75);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(() {
            tester.view.reset();
            tester.platformDispatcher.clearTextScaleFactorTestValue();
          });
          await LanguageController.instance.set(Locale(lang));
          await tester.pumpWidget(
              _app(KulkasPage(loader: () async => _ok(_sampleItems))));
          await _settle(tester);

          final s = stringsFor(Locale(lang));
          final back =
              tester.getRect(find.byIcon(Icons.arrow_back_ios_new_rounded));
          final title = tester.getRect(find.text(s.yourFridge));
          final intro = tester.getRect(find.text(s.fridgeIntro));
          final search = tester.getRect(find.byType(TextField).first);

          expect(title.top, greaterThanOrEqualTo(back.bottom),
              reason: 'title sits on the back button: $title vs $back');
          expect(intro.top, greaterThanOrEqualTo(title.bottom - 1),
              reason: 'intro overlaps the title');
          expect(intro.bottom, lessThanOrEqualTo(search.top),
              reason: 'intro runs into the search bar: $intro vs $search');
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}

void flowTests() {
  testWidgets('pull to refresh reloads the list without a spinner wiping it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await LanguageController.instance.set(const Locale('en'));
    var calls = 0;
    await tester.pumpWidget(_app(KulkasPage(loader: () async {
      calls++;
      return _ok(_sampleItems);
    })));
    await _settle(tester);
    expect(calls, 1);
    await tester.fling(find.byType(CustomScrollView), const Offset(0, 500), 1000);
    await _settle(tester);
    expect(calls, 2, reason: 'a pull must reload');
    expect(find.text('Beras'), findsOneWidget);
  });

  testWidgets('sort by "Expiring soon": earliest date first, items without a date last', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await LanguageController.instance.set(const Locale('en'));
    await tester.pumpWidget(_app(KulkasPage(loader: () async => _ok(_sampleItems))));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expiring soon'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    double y(String t) => tester.getTopLeft(find.textContaining(t).first).dy;
    expect(y('Susu'), lessThan(y('Gula')), reason: 'expired first');
    expect(y('Gula'), lessThan(y('Beras')));
    expect(y('Beras'), lessThan(y('Tepung')), reason: 'no date goes last');
  });
}
