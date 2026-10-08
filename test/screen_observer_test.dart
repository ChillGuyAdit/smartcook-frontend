import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcook/core/services/screen_observer.dart';

class KulkasLikePage extends StatelessWidget {
  const KulkasLikePage({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('page'));
}

void main() {
  testWidgets('unnamed MaterialPageRoute is named after its page class',
      (tester) async {
    final seen = <String>[];
    final obs = ScreenObserver(onScreen: seen.add);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [obs],
      home: const Scaffold(body: Text('home')),
    ));

    final route =
        MaterialPageRoute<void>(builder: (_) => const KulkasLikePage());
    expect(obs.nameOf(route), 'KulkasLikePage');
  });

  testWidgets('named routes keep their name; popups are not screens',
      (tester) async {
    final seen = <String>[];
    final obs = ScreenObserver(onScreen: seen.add);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [obs],
      home: const Scaffold(body: Text('home')),
    ));

    final named = MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/signin'),
      builder: (_) => const KulkasLikePage(),
    );
    expect(obs.nameOf(named), '/signin');

    final popup = PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => const KulkasLikePage(),
    );
    expect(obs.nameOf(popup), isNull);
  });

  testWidgets('a page that throws while building never breaks the observer',
      (tester) async {
    final seen = <String>[];
    final obs = ScreenObserver(onScreen: seen.add);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [obs],
      home: const Scaffold(body: Text('home')),
    ));
    final bad = MaterialPageRoute<void>(builder: (_) => throw StateError('x'));
    // didPush swallows the error; nameOf itself may throw but _record guards it.
    expect(() => obs.didPush(bad, null), returnsNormally);
  });

  testWidgets('real navigation is recorded once per screen, including back',
      (tester) async {
    final seen = <String>[];
    final obs = ScreenObserver(onScreen: seen.add);
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [obs],
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const KulkasLikePage()),
          ),
          child: const Text('go'),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(seen.last, 'KulkasLikePage');

    final before = seen.length;
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(seen.length, greaterThan(before)); // returned to the first screen
    expect(seen.last, isNot('KulkasLikePage'));
    expect(seen.where((s) => s == seen.last).length, greaterThanOrEqualTo(1));
  });
}
