import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcook/core/theme/app_theme.dart';
import 'package:smartcook/core/theme/language_controller.dart';
import 'package:smartcook/models/recipe.dart';
import 'package:smartcook/page/category.dart';

Widget _app(Future<List<Recipe>> Function() loader) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('id'),
      supportedLocales: LanguageController.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CategoryPage(
        categoryName: 'Masakan Sehat',
        themeColors: const [Colors.green, Colors.teal],
        headerImagePath: 'image/soup.png',
        loader: loader,
      ),
    );

void main() {
  testWidgets('loading: indikator tampil selama menunggu data', (tester) async {
    final completer = Completer<List<Recipe>>();
    await tester.pumpWidget(_app(() => completer.future));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(const []);
    await tester.pumpAndSettle();
  });

  testWidgets('success: daftar resep dari model tampil', (tester) async {
    await tester.pumpWidget(_app(() async => const [
          Recipe(id: '1', title: 'Sop Ayam Bening', calories: 200, prepTime: 15, cookTime: 25),
          Recipe(id: '2', title: 'Salad Sayur', calories: 120, prepTime: 10),
        ]));
    await tester.pumpAndSettle();
    expect(find.text('Sop Ayam Bening'), findsOneWidget);
    expect(find.text('Salad Sayur'), findsOneWidget);
    expect(find.text('40m'), findsOneWidget);
  });

  testWidgets('error: pesan galat dan tombol coba lagi, lalu berhasil',
      (tester) async {
    var panggilan = 0;
    await tester.pumpWidget(_app(() async {
      panggilan++;
      if (panggilan == 1) throw Exception('server mati');
      return const [Recipe(id: '1', title: 'Nasi Goreng')];
    }));
    await tester.pumpAndSettle();
    expect(find.textContaining('Resep belum bisa dimuat'), findsOneWidget);
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(panggilan, 2);
  });
}
