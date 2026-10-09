import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcook/core/services/app_update_checker.dart';

/// The update pop-up must survive what the splash / sign-in / home code does to
/// the route stack, and obey "Later" / back only when the update is optional.
void main() {
  final key = GlobalKey<NavigatorState>();
  setUp(UpdateOverlay.reset);

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: key,
      home: const Scaffold(body: Text('splash')),
    ));
  }

  Future<void> open(WidgetTester tester, {required bool forced}) async {
    UpdateOverlay.show(
      key.currentState!,
      forced: forced,
      builder: (close) => AlertDialog(
        title: const Text('Update available'),
        actions: [
          if (!forced) TextButton(onPressed: close, child: const Text('Later')),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets(
      'the pop-up stays when the route under it is replaced (the login bug)',
      (tester) async {
    await pumpApp(tester);
    await open(tester, forced: false);
    expect(find.text('Update available'), findsOneWidget);

    // what login / splash do: replace the top route, then clear the stack
    key.currentState!.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('home'))));
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget,
        reason: 'replaced by the new route');

    key.currentState!.pushAndRemoveUntil(
        MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('signin'))),
        (r) => false);
    await tester.pumpAndSettle();
    expect(find.text('signin'), findsOneWidget);
    expect(find.text('Update available'), findsOneWidget,
        reason: 'removed with the stack');

    UpdateOverlay.handleBack();
    await tester.pump();
  });

  testWidgets('optional update: "Later" and the back key close it',
      (tester) async {
    await pumpApp(tester);
    await open(tester, forced: false);
    await tester.tap(find.text('Later'));
    await tester.pump();
    expect(find.text('Update available'), findsNothing);
    expect(UpdateOverlay.isOpen, isFalse);

    await open(tester, forced: false);
    expect(UpdateOverlay.handleBack(), isTrue,
        reason: 'back is consumed by the pop-up');
    await tester.pump();
    expect(find.text('Update available'), findsNothing);
    expect(UpdateOverlay.isOpen, isFalse);
    // with nothing open the back key is left to the app
    expect(UpdateOverlay.handleBack(), isFalse);
  });

  testWidgets('mandatory update: back is swallowed and the pop-up stays',
      (tester) async {
    await pumpApp(tester);
    await open(tester, forced: true);
    expect(UpdateOverlay.handleBack(), isTrue);
    await tester.pump();
    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Later'), findsNothing);
    expect(UpdateOverlay.isOpen, isTrue);
    // taps on the page behind it do nothing
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    expect(find.text('Update available'), findsOneWidget);
  });

  testWidgets(
      'a second request while one is open does not stack another pop-up',
      (tester) async {
    await pumpApp(tester);
    await open(tester, forced: false);
    await open(tester, forced: false);
    expect(find.text('Update available'), findsOneWidget);
    UpdateOverlay.handleBack();
    await tester.pump();
  });
}
