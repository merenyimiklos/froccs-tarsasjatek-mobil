import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:froccs_mobile/game.dart';
import 'package:froccs_mobile/landscape_board.dart';

void main() {
  testWidgets('Landscape table has no vertical overflow at design size',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 660);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = Game([
      Seat('a', 'Ember'),
      Seat('b', 'Bot 1', bot: true),
      Seat('c', 'Bot 2', bot: true),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LandscapeBoard(
        snapshot: game.viewFor('a'),
        myId: 'a',
        onAction: (_) {},
        onLeave: () {},
      )),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Landscape table renders within a typical phone ratio',
      (tester) async {
    tester.view.physicalSize = const Size(915, 412);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = Game([
      Seat('a', 'Ember'),
      Seat('b', 'Bot 1', bot: true),
      Seat('c', 'Bot 2', bot: true),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LandscapeBoard(
        snapshot: game.viewFor('a'),
        myId: 'a',
        onAction: (_) {},
        onLeave: () {},
      )),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  testWidgets('Glass purchase dialog fits on a 915x412 phone',
      (tester) async {
    tester.view.physicalSize = const Size(915, 412);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final game = Game([
      Seat('a', 'Ember'), Seat('b', 'Bot 1', bot: true),
      Seat('c', 'Bot 2', bot: true),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LandscapeBoard(
        snapshot: game.viewFor('a'),
        myId: 'a',
        onAction: (_) {},
        onLeave: () {},
      )),
    ));
    await tester.pump();
    await tester.tap(find.text('POHÁRVÁSÁRLÁS'));
    await tester.pumpAndSettle();
    expect(find.text('Pohárvásárlás'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
