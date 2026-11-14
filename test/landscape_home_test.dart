import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:froccs_mobile/main.dart';

void main() {
  testWidgets('Landscape menu with hero choices has no layout overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1180, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(const FroccsApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('FOGLALJ ASZTALT!'), findsOneWidget);
    expect(find.text('VÁLASSZ KETTŐ KOCSMAHŐS KÖZÜL'), findsOneWidget);
  });
}
