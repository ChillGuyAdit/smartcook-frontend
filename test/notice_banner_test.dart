import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/page/reusable/notice_banner.dart';
import 'package:smartcook/service/api_service.dart';

Widget _host(Future<ApiResponse> Function() fetch) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: NoticeBanner(fetch: fetch)),
    );

ApiResponse _ok(dynamic data) => ApiResponse(success: true, data: data);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows the announcement and remembers it was closed; a new one shows again', (tester) async {
    await tester.pumpWidget(_host(() async => _ok({'id': '1', 'text': 'Perawatan malam ini'})));
    await tester.pumpAndSettle();
    expect(find.text('Perawatan malam ini'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Perawatan malam ini'), findsNothing);

    // same announcement on the next visit: stays closed
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(() async => _ok({'id': '1', 'text': 'Perawatan malam ini'})));
    await tester.pumpAndSettle();
    expect(find.text('Perawatan malam ini'), findsNothing);

    // a different announcement: shown
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_host(() async => _ok({'id': '2', 'text': 'Fitur baru'})));
    await tester.pumpAndSettle();
    expect(find.text('Fitur baru'), findsOneWidget);
  });

  testWidgets('nothing to show or any failure leaves no trace on the page', (tester) async {
    for (final f in <Future<ApiResponse> Function()>[
      () async => _ok(null),
      () async => _ok({'id': '9', 'text': '   '}),
      () async => _ok({'text': 'no id'}),
      () async => ApiResponse(success: false, message: 'x'),
      () async => throw Exception('offline'),
    ]) {
      await tester.pumpWidget(_host(f));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.campaign_outlined), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
