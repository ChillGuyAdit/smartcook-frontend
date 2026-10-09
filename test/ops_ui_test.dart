import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/services/dev_log.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/ops/devices_page.dart';
import 'package:smartcook/ops/more_pages.dart';
import 'package:smartcook/ops/ops_access.dart';
import 'package:smartcook/ops/ops_api.dart';
import 'package:smartcook/ops/ops_shell.dart';
import 'package:smartcook/ops/ops_widgets.dart';
import 'package:smartcook/ops/restrict_sheet.dart';
import 'package:smartcook/ops/security_page.dart';
import 'package:smartcook/ops/server_page.dart';

import 'support/fake_ops_api.dart';

const _allPerms = {
  'monitor',
  'devices',
  'live',
  'people',
  'restrict',
  'logs',
  'trail',
  'members',
  'notice'
};
const _owner = OpsMe(role: 'owner', perms: _allPerms);

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

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, [int times = 4]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

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
    OpsAccess.reset();
    await LanguageController.instance.set(const Locale('id'));
  });

  // ------------------------------------------------------------------ access
  group('who is offered the choice', () {
    testWidgets('a normal account sees nothing at all', (tester) async {
      await _phone(tester);
      final api = FakeOpsApi(meValue: null);
      OpsAccess.api = api;
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Text('home'));
      })));
      await OpsAccess.offer(ctx);
      await tester.pumpAndSettle();
      expect(find.text('Masuk sebagai'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(OpsAccess.current, isNull);
    });

    testWidgets(
        'a member is asked once; "console" opens it, "as usual" does not',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi(meValue: _owner);
      OpsAccess.api = api;
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Text('home'));
      })));
      unawaited(OpsAccess.offer(ctx));
      await tester.pumpAndSettle();
      expect(find.text('Masuk sebagai'), findsOneWidget);
      await tester.tap(find.text('SmartCook biasa'));
      await tester.pumpAndSettle();
      expect(find.byType(OpsShell), findsNothing);

      // asked only once per sign-in
      await OpsAccess.offer(ctx);
      await tester.pumpAndSettle();
      expect(find.text('Masuk sebagai'), findsNothing);
      expect(api.calls.where((c) => c == 'me').length, 1);

      // after signing out it asks again, and "console" opens the shell
      OpsAccess.reset();
      unawaited(OpsAccess.offer(ctx));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konsol'));
      await tester.pumpAndSettle();
      expect(find.byType(OpsShell), findsOneWidget);
    });

    testWidgets('a failing request is treated as "no rights"', (tester) async {
      await _phone(tester);
      OpsAccess.api = _ThrowingApi();
      late BuildContext ctx;
      await tester.pumpWidget(_app(Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Text('home'));
      })));
      await OpsAccess.offer(ctx);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  // -------------------------------------------------------------------- shell
  testWidgets('the bottom bar only offers what the rights allow',
      (tester) async {
    await _phone(tester);
    final api = FakeOpsApi();
    await tester.pumpWidget(_app(
        OpsShell(api: api, me: const OpsMe(role: 'member', perms: {'logs'}))));
    await _settle(tester);
    expect(find.text('Server'), findsNothing);
    expect(find.text('Perangkat'), findsNothing);
    expect(find.text('Keamanan'), findsNothing);
    expect(find.text('Lainnya'), findsWidgets);
    expect(find.text('Log'), findsOneWidget);
    expect(find.text('Pengguna'), findsNothing);
    expect(find.text('Tim'), findsNothing);

    await tester.pumpWidget(_app(OpsShell(api: api, me: _owner)));
    await _settle(tester);
    for (final label in ['Server', 'Perangkat', 'Keamanan', 'Lainnya']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
  });

  // ------------------------------------------------------------------- server
  group('server view', () {
    testWidgets(
        'shows the readings, history fills the charts, a GPU-less machine says so',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(Scaffold(body: ServerPage(api: api))));
      await _settle(tester);
      expect(find.text('Menunggu data pertama...'), findsOneWidget);

      api.lastServer.add({
        'type': 'history',
        'items': [
          for (var i = 0; i < 30; i++)
            {'t': i, 'cpu': 10.0 + i, 'mem': 20.0, 'rx': 100, 'tx': 200}
        ]
      });
      api.lastServer.add(FakeOpsApi.sample());
      await _settle(tester);

      expect(find.text('CPU'), findsOneWidget);
      expect(find.text('43%'), findsWidgets);
      expect(find.text('RAM'), findsOneWidget);
      expect(find.textContaining('Langsung'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('Server ini tidak memiliki GPU.'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Server ini tidak memiliki GPU.'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('smartcook-backend'), 400,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('smartcook-backend'), findsOneWidget);
      expect(find.text('errored'), findsOneWidget,
          reason: 'a failing process is shown, not hidden');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'a lost connection is retried, and leaving the page closes the feed',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(Scaffold(body: ServerPage(api: api))));
      await _settle(tester);
      api.lastServer.add(FakeOpsApi.sample());
      await _settle(tester);
      expect(find.textContaining('Langsung'), findsOneWidget);

      await api.lastServer.close(); // the connection drops
      await _settle(tester);
      expect(find.textContaining('Menyambung ulang'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(api.serverControllers.length, 2, reason: 'it reconnected');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
      expect(api.serverCancelled, greaterThanOrEqualTo(1),
          reason: 'the feed is cancelled when the page goes away');
    });

    testWidgets('"too many viewers" is explained', (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(Scaffold(body: ServerPage(api: api))));
      await _settle(tester);
      api.lastServer.add({'type': 'busy'});
      await _settle(tester);
      expect(find.textContaining('Terlalu banyak pemantau'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    });
  });

  // ------------------------------------------------------------------ devices
  group('devices', () {
    testWidgets(
        'connected / all, search is sent to the server, tiles show who and where',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester
          .pumpWidget(_app(Scaffold(body: DevicesPage(api: api, me: _owner))));
      await _settle(tester);
      expect(api.calls, contains('devicesPage:q=:online=true:page=1'));
      expect(find.text('Xiaomi M2006C3MG'), findsOneWidget);
      expect(find.text('Google Pixel 8'), findsNothing,
          reason: 'offline phones are not in "connected"');
      expect(find.textContaining('ani@example.com'), findsOneWidget);
      expect(find.textContaining('203.0.113.9'), findsOneWidget);
      expect(find.textContaining('CPU 12%'), findsOneWidget,
          reason: 'live reading badge');

      await tester.tap(find.text('Riwayat'));
      await _settle(tester);
      expect(find.text('Google Pixel 8'), findsOneWidget);
      expect(find.text('diblokir'), findsOneWidget);
      expect(find.text('Belum masuk akun'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'xiaomi');
      await tester.pump(const Duration(milliseconds: 500));
      expect(
          api.calls.any((c) => c.startsWith('devicesPage:q=xiaomi')), isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 12));
    });

    testWidgets(
        'detail: facts, history, events, and a live reading that updates',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(DeviceDetailPage(
          api: api, me: _owner, installId: 'install-aaaa-1111')));
      await _settle(tester);
      expect(api.calls, contains('deviceFeed:install-aaaa-1111'));
      expect(find.textContaining('Menunggu perangkat'), findsOneWidget);

      api.lastDevice.add({
        'type': 'reading',
        'reading': {
          'cpu': 7.5,
          'rssMb': 120,
          'memAvailMb': 800,
          'memTotalMb': 3000,
          'battery': 64,
          'charging': false,
          'tempC': 36.5,
          'thermal': 2,
          'storageFreeMb': 20000,
          'at': 1
        }
      });
      await _settle(tester);
      expect(find.textContaining('tiap 2 detik'), findsOneWidget);
      expect(find.text('7.5%'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      expect(find.textContaining('moderate'), findsOneWidget);

      api.lastDevice.add({'type': 'stale', 'ageMs': 200000});
      await _settle(tester);
      expect(find.textContaining('berhenti mengirim'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('RIWAYAT MASUK'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('RIWAYAT MASUK'), findsOneWidget);
      expect(find.text('google'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(api.deviceCancelled, greaterThanOrEqualTo(1));
    });

    testWidgets('a member without the live right never opens the live feed',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(DeviceDetailPage(
          api: api,
          me: const OpsMe(role: 'member', perms: {'devices'}),
          installId: 'install-aaaa-1111')));
      await _settle(tester);
      expect(api.calls.any((c) => c.startsWith('deviceFeed')), isFalse);
      expect(find.text('LANGSUNG'), findsNothing);
      expect(find.text('Blokir IP'), findsNothing, reason: 'no restrict right');
    });

    testWidgets(
        'block IP from a device opens the sheet pre-filled and applies it',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(DeviceDetailPage(
          api: api, me: _owner, installId: 'install-aaaa-1111')));
      await _settle(tester);
      await tester.scrollUntilVisible(find.text('Blokir IP'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Blokir IP'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '203.0.113.9'), findsOneWidget);
      await tester.tap(find.text('7 hari'));
      await tester.pump();
      await tester.tap(find.text('Terapkan'));
      await tester.pumpAndSettle();
      expect(api.restricted.single['ip'], '203.0.113.9');
      expect(
          (api.restricted.single['until'] as DateTime)
              .isAfter(DateTime.now().add(const Duration(days: 6))),
          isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  // ------------------------------------------------------------ restrict sheet
  testWidgets(
      'restrict sheet: needs a target, shows the server refusal, closes on success',
      (tester) async {
    await _phone(tester);
    final api = FakeOpsApi();
    late BuildContext ctx;
    await tester.pumpWidget(_app(Builder(builder: (c) {
      ctx = c;
      return const Scaffold(body: Text('x'));
    })));
    bool? result;
    unawaited(showRestrictSheet(ctx, api).then((v) => result = v));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Terapkan'));
    await tester.pump();
    expect(find.text('Isi alamat IP atau email.'), findsOneWidget);
    expect(api.calls, isNot(contains('restrict')));

    api.restrictError = 'Target ini tidak boleh dibatasi.';
    await tester.enterText(find.byType(TextField).at(1), 'boss@example.com');
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(find.text('Target ini tidak boleh dibatasi.'), findsOneWidget);

    api.restrictError = null;
    await tester.enterText(find.byType(TextField).at(2), 'spam');
    await tester.tap(find.text('Terapkan'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(api.restricted.single, {
      'ip': '',
      'email': 'boss@example.com',
      'reason': 'spam',
      'until': null
    });
  });

  // ----------------------------------------------------------------- security
  testWidgets(
      'security: active rules can be lifted, the activity log is listed',
      (tester) async {
    await _phone(tester);
    final api = FakeOpsApi();
    await tester
        .pumpWidget(_app(Scaffold(body: SecurityPage(api: api, me: _owner))));
    await _settle(tester);
    expect(find.text('203.0.113.0/24'), findsOneWidget);
    expect(find.text('bad@example.com'), findsOneWidget);
    expect(find.text('abuse'), findsOneWidget);
    await tester.tap(find.byTooltip('Cabut').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cabut').last);
    await tester.pumpAndSettle();
    expect(api.calls, contains('lift:r1'));
    expect(find.text('203.0.113.0/24'), findsNothing);
    await tester.scrollUntilVisible(find.textContaining('restriction.add'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('restriction.add'), findsOneWidget);
  });

  // -------------------------------------------------------------- people, logs
  testWidgets('people: search, open one, suspend', (tester) async {
    await _phone(tester);
    final api = FakeOpsApi();
    await tester.pumpWidget(_app(PeoplePage(api: api, me: _owner)));
    await _settle(tester);
    expect(find.text('ani@example.com'), findsOneWidget);
    expect(find.text('ditangguhkan'), findsOneWidget,
        reason: 'a suspended account is marked in the list');
    await tester.tap(find.text('ani@example.com'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('userDetail:u1'));
    expect(find.text('Suspend akun ini'), findsOneWidget);
    await tester.tap(find.text('Suspend akun ini'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'ani@example.com'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('logs: filter by level', (tester) async {
    await _phone(tester);
    final api = FakeOpsApi();
    await tester.pumpWidget(_app(LogsPage(api: api)));
    await _settle(tester);
    expect(api.calls, contains('logs:error'));
    expect(find.textContaining('Null check operator'), findsOneWidget);
    await tester.tap(find.text('Semua'));
    await _settle(tester);
    expect(api.calls, contains('logs:all'));
  });

  testWidgets('overview: the numbers and the failing build', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(OverviewPage(api: FakeOpsApi())));
    await _settle(tester);
    expect(find.text('18'), findsOneWidget);
    expect(find.textContaining('build 16'), findsWidgets);
    expect(find.text('3 perangkat'), findsOneWidget);
  });

  // --------------------------------------------------------------------- team
  group('team', () {
    testWidgets(
        'an owner can hand out every right, including managing the team',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(TeamPage(api: api, me: _owner)));
      await _settle(tester);
      expect(find.text('boss@example.com'), findsOneWidget);
      expect(find.text('adm@example.com'), findsOneWidget);
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();
      expect(find.text('Kelola tim'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'new@example.com');
      await tester.tap(find.text('Log aktivitas'));
      await tester.tap(find.text('Pengguna'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(api.added.single,
          {'email': 'new@example.com', 'perms': contains('trail')});
      expect((api.added.single['perms'] as List).toSet(), {'trail', 'people'});
    });

    testWidgets(
        'a member can only hand out what it holds, never team management',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(TeamPage(
          api: api,
          me: const OpsMe(
              role: 'member', perms: {'members', 'logs', 'devices'}))));
      await _settle(tester);
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();
      expect(find.text('Log'), findsWidgets);
      expect(find.text('Perangkat'), findsWidgets);
      expect(find.text('Kelola tim'), findsNothing,
          reason: 'only an owner grants this');
      expect(find.text('Batasi akses'), findsNothing,
          reason: 'not held by this member');
      expect(find.text('Pantau langsung HP'), findsNothing);
    });

    testWidgets('the server refusal is shown in the dialog', (tester) async {
      await _phone(tester);
      final api = FakeOpsApi()..memberError = 'Email tidak valid.';
      await tester.pumpWidget(_app(TeamPage(api: api, me: _owner)));
      await _settle(tester);
      await tester.tap(find.text('Tambah'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'nope');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.text('Email tidak valid.'), findsOneWidget);
    });
  });

  testWidgets('announcement editor loads and saves', (tester) async {
    await _phone(tester);
    final api = FakeOpsApi();
    await tester.pumpWidget(_app(NoticeEditorPage(api: api)));
    await _settle(tester);
    expect(find.text('Perawatan malam ini'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Fitur baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('setNotice:true:Fitur baru:always:false'));
    expect(find.text('Tersimpan.'), findsOneWidget);
  });

  // ------------------------------------------------------- language + layout
  for (final lang in ['id', 'en']) {
    for (final entry in <String, Widget Function(FakeOpsApi)>{
      'shell': (a) => OpsShell(api: a, me: _owner),
      'devices': (a) => Scaffold(body: DevicesPage(api: a, me: _owner)),
      'device detail': (a) =>
          DeviceDetailPage(api: a, me: _owner, installId: 'install-aaaa-1111'),
      'security': (a) => Scaffold(body: SecurityPage(api: a, me: _owner)),
      'people': (a) => PeoplePage(api: a, me: _owner),
      'logs': (a) => LogsPage(api: a),
      'overview': (a) => OverviewPage(api: a),
      'team': (a) => TeamPage(api: a, me: _owner),
      'notice': (a) => NoticeEditorPage(api: a),
    }.entries) {
      testWidgets(
          '${entry.key} ($lang, narrow phone, large font): renders without overflow',
          (tester) async {
        tester.view.physicalSize = const Size(900, 2000); // 360 dp wide
        tester.view.devicePixelRatio = 2.5;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        await LanguageController.instance.set(Locale(lang));
        final api = FakeOpsApi();
        await tester.pumpWidget(_app(entry.value(api)));
        await _settle(tester, 6);
        for (final c in [...api.serverControllers, ...api.deviceControllers]) {
          c.add(FakeOpsApi.sample());
        }
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: '${entry.key} in $lang');
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 20));
      });
    }
  }

  testWidgets(
      'server page (both languages): narrow phone, large font, full data, no overflow',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 2.5;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    for (final lang in ['id', 'en']) {
      await LanguageController.instance.set(Locale(lang));
      final api = FakeOpsApi();
      await tester.pumpWidget(_app(Scaffold(body: ServerPage(api: api))));
      await _settle(tester);
      api.lastServer.add(FakeOpsApi.sample(cpu: 91.0, memUsed: 900));
      await _settle(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: 'server page in $lang');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 20));
    }
  });

  test('formatting helpers', () {
    expect(fmtBytes(0), '0 B');
    expect(fmtBytes(1536), '1.5 KB');
    expect(fmtBytes(5 * 1024 * 1024 * 1024), '5.0 GB');
    expect(fmtBytes(null), '-');
    expect(fmtRate(2048), '2.0 KB/s');
    expect(fmtDuration(59), '59s');
    expect(fmtDuration(3700), '1h 1m');
    expect(fmtDuration(90000), '1d 1h');
    expect(
        ago(DateTime.now()
            .subtract(const Duration(seconds: 2))
            .toIso8601String()),
        'baru saja');
    expect(
        ago(DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toIso8601String()),
        '5 mnt lalu');
    expect(ago(null), '-');
    expect(numOf('3.5'), 3.5);
    expect(numOf('x'), isNull);
    expect(loadColor(95), const Color(0xFFE53935));
    expect(loadColor(10), const Color(0xFF43A047));
  });

  // ------------------------------------------------------ paging + specs
  group('devices paging and specs', () {
    List<Json> many(int n) => [
          for (var i = 0; i < n; i++)
            {
              'installId': 'install-many-${i.toString().padLeft(4, '0')}',
              'deviceModel': 'Phone $i',
              'manufacturer': 'Brand',
              'online': true,
              'lastSeen': DateTime.now().toIso8601String(),
              'ip': '203.0.113.$i',
              'place': 'Jakarta, Indonesia',
              'live': null,
            }
        ];

    testWidgets('more than 10 devices are paged, 10 per page', (tester) async {
      await _phone(tester);
      final api = FakeOpsApi()..deviceRows = many(23);
      await tester
          .pumpWidget(_app(Scaffold(body: DevicesPage(api: api, me: _owner))));
      await _settle(tester);
      expect(find.text('Brand Phone 0'), findsOneWidget);
      expect(find.text('Brand Phone 10'), findsNothing);
      await tester.scrollUntilVisible(find.byIcon(Icons.chevron_right), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('Halaman 1 dari 3'), findsOneWidget);
      await tester.ensureVisible(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right), warnIfMissed: true);
      await _settle(tester);
      expect(api.calls, contains('devicesPage:q=:online=true:page=2'));
      await tester.scrollUntilVisible(
          find.textContaining('Halaman 2 dari 3'), 300,
          scrollable: find.byType(Scrollable).last);
      expect(find.textContaining('Halaman 2 dari 3'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
      await _settle(tester);
      expect(find.text('Brand Phone 10'), findsOneWidget);
      expect(find.text('Brand Phone 0'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets('10 devices or fewer: no pager', (tester) async {
      await _phone(tester);
      final api = FakeOpsApi()..deviceRows = many(10);
      await tester
          .pumpWidget(_app(Scaffold(body: DevicesPage(api: api, me: _owner))));
      await _settle(tester);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
      await _settle(tester);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets(
        'an offline phone in the history shows when it was last online and its last data',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester
          .pumpWidget(_app(Scaffold(body: DevicesPage(api: api, me: _owner))));
      await _settle(tester);
      await tester.tap(find.text('Riwayat'));
      await _settle(tester);
      expect(find.textContaining('Terakhir online'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 11));
    });

    testWidgets(
        'detail: graphs for cpu, ram, network, storage, cores and the spec sheet',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      api.deviceRows[0]['hw'] = {
        'soc': 'Qualcomm SM8650',
        'cores': 2,
        'coreMaxMhz': [2000, 3000],
        'coreMinMhz': [300, 500],
        'ramMb': 12288,
        'storageMb': 262144,
        'screen': '1080x2400',
        'densityDpi': 420,
        'refreshHz': 120,
        'gpu': 'Adreno (TM) 750',
        'sensors': ['Accelerometer', 'Gyroscope'],
        'features': ['NFC', 'BLE'],
      };
      await tester.pumpWidget(_app(DeviceDetailPage(
          api: api, me: _owner, installId: 'install-aaaa-1111')));
      await _settle(tester);
      api.lastDevice.add({
        'type': 'reading',
        'reading': {
          'cpu': 20,
          'memAvailMb': 8000,
          'memTotalMb': 12000,
          'rxBps': 2048,
          'txBps': 512,
          'battery': 50,
          'voltageMv': 4000,
          'storageFreeMb': 100000,
          'storageTotalMb': 262144,
          'freq': [1800, 0],
          'at': 1
        }
      });
      await _settle(tester);
      expect(find.text('Jaringan masuk'), findsOneWidget);
      expect(find.text('2.0 KB/s'), findsOneWidget);
      expect(find.text('Core 0'), findsOneWidget);
      expect(find.text('1800 MHz'), findsOneWidget);
      expect(find.text('tidur'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('SPESIFIKASI PERANGKAT'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Qualcomm SM8650'), findsOneWidget);
      expect(find.textContaining('Adreno'), findsOneWidget);
      expect(find.textContaining('120 Hz'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });

  testWidgets('announcement: choosing once + a duration is sent to the server',
      (tester) async {
    await _phone(tester);
    final api = FakeOpsApi();
    await tester.pumpWidget(_app(NoticeEditorPage(api: api)));
    await _settle(tester);
    await tester.tap(find.text('Sekali saja'));
    await _settle(tester);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await _settle(tester);
    await tester.tap(find.text('1 jam').last);
    await _settle(tester);
    await tester.tap(find.text('Simpan'));
    await _settle(tester);
    expect(api.calls.any((c) => c.endsWith(':once:true')), isTrue,
        reason: api.calls.toString());
  });

  group('restrictions list', () {
    testWidgets('shows time left, filters, pages by 10 and lifts',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      api.rules = [
        for (var i = 0; i < 13; i++)
          {
            'id': 'r$i',
            'kind': i % 2 == 0 ? 'ip' : 'email',
            'value': i % 2 == 0 ? '203.0.113.$i' : 'u$i@example.com',
            'reason': 'abuse',
            'by': 'boss@example.com',
            'createdAt': DateTime.now().toIso8601String(),
            'until': i == 0
                ? DateTime.now()
                    .add(const Duration(hours: 2, minutes: 5))
                    .toIso8601String()
                : null,
          }
      ];
      await tester
          .pumpWidget(_app(Scaffold(body: SecurityPage(api: api, me: _owner))));
      await _settle(tester);
      expect(find.textContaining('Sisa 2 jam'), findsOneWidget);
      expect(find.text('Permanen (sampai dicabut)'), findsWidgets);
      await tester.scrollUntilVisible(
          find.textContaining('Halaman 1 dari 2'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await _settle(tester);
      expect(api.calls, contains('restrictionsPage:all:2'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });

    testWidgets('filtering by IP asks the server for IP rules only',
        (tester) async {
      await _phone(tester);
      final api = FakeOpsApi();
      await tester
          .pumpWidget(_app(Scaffold(body: SecurityPage(api: api, me: _owner))));
      await _settle(tester);
      await tester.tap(find.text('IP'));
      await _settle(tester);
      expect(api.calls, contains('restrictionsPage:ip:1'));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 31));
    });
  });
}

class _ThrowingApi extends FakeOpsApi {
  @override
  Future<OpsMe?> me() async => throw Exception('offline');
}
