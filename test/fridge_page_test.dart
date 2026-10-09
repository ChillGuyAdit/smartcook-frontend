import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/page/kulkas.dart';
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

String _in(int days) => DateTime.now().add(Duration(days: days)).toUtc().toIso8601String();

ApiResponse _ok(List<Map<String, dynamic>> items) => ApiResponse(success: true, data: items);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    PackageInfo.setMockInitialValues(
        appName: 'SmartCook', packageName: 'com.example.smartcook', version: '1.1.4', buildNumber: '20', buildSignature: '');
    DevLog.disabled = true;
    SharedPreferences.setMockInitialValues({});
    await LanguageController.instance.set(const Locale('id'));
  });

  final items = [
    {'_id': 'a', 'ingredient_name': 'Beras', 'quantity': 1000, 'unit': 'gram', 'expired_date': _in(30)},
    {'_id': 'b', 'ingredient_name': 'Tepung terigu protein tinggi untuk roti dan kue basah', 'quantity': 2500, 'unit': 'gram', 'expired_date': null},
    {'_id': 'c', 'ingredient_name': 'Gula', 'quantity': 0.5, 'unit': 'kg', 'expired_date': _in(2)},
    {'_id': 'd', 'ingredient_name': 'Susu', 'quantity': 1.0, 'unit': 'liter', 'expired_date': _in(-3)},
  ];

  for (final lang in ['id', 'en']) {
    testWidgets('fridge ($lang): every item is listed, nothing hidden by a default stock limit, no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await LanguageController.instance.set(Locale(lang));
      await tester.pumpWidget(_app(KulkasPage(loader: () async => _ok(items))));
      await _settle(tester);

      expect(find.text('Beras'), findsOneWidget);
      expect(find.textContaining('Tepung terigu'), findsOneWidget, reason: '2500 g must not be hidden by a default limit');
      expect(find.text('Gula'), findsOneWidget);
      expect(find.text('Susu'), findsOneWidget);
      // decimals and units are shown as they are, "1.0" becomes "1"
      expect(find.textContaining('0.5 kg'), findsOneWidget);
      expect(find.textContaining('1 liter'), findsOneWidget);
      expect(find.textContaining('1.0 liter'), findsNothing);
      // no invented expiry: the item without a date says so
      expect(find.text(lang == 'id' ? 'Tanpa tanggal kadaluarsa' : 'No expiry date'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fridge: a failed load says so and offers a retry instead of showing an empty fridge', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    var calls = 0;
    await tester.pumpWidget(_app(KulkasPage(loader: () async {
      calls++;
      return calls == 1 ? ApiResponse(success: false, message: 'x') : _ok(items);
    })));
    await _settle(tester);
    expect(find.textContaining('Kulkas belum bisa dimuat'), findsOneWidget);
    expect(find.textContaining('Bahan tidak ditemukan'), findsNothing);
    await tester.tap(find.text('Coba lagi'));
    await _settle(tester);
    expect(find.text('Beras'), findsOneWidget);
  });

  testWidgets('fridge: items stay on screen when a refresh fails', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    var calls = 0;
    await tester.pumpWidget(_app(KulkasPage(loader: () async {
      calls++;
      return calls == 1 ? _ok(items) : ApiResponse(success: false, message: 'x');
    })));
    await _settle(tester);
    expect(find.text('Beras'), findsOneWidget);
    // the floating button reloads the list when it comes back from "add"
    await tester.tap(find.byType(FloatingActionButton));
    await _settle(tester);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await _settle(tester);
    expect(calls, greaterThanOrEqualTo(2), reason: 'coming back must reload');
    expect(find.text('Beras'), findsOneWidget, reason: 'a failed refresh must not wipe the list');
  });
}
