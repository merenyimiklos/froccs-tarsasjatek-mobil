import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:froccs_mobile/card_art.dart';
import 'package:froccs_mobile/game.dart';
import 'package:froccs_mobile/landscape_board.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Every playable card, hero, cup and logo has decodable bundled art', () async {
    expect(HeroCardArt.slugs.keys, containsAll(heroNames));
    final names = [
      for (final id in cardNames.keys) 'card_$id',
      for (final id in HeroCardArt.slugs.values) 'hero_$id',
      'cup_2', 'cup_3', 'cup_5', 'logo',
    ];
    for (final name in names) {
      final data = await rootBundle.load('assets/original/$name.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(
        data.offsetInBytes, data.lengthInBytes));
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(300), reason: name);
      expect(frame.image.height, greaterThan(200), reason: name);
      frame.image.dispose();
      codec.dispose();
    }
  });

  testWidgets('Original card keeps its full frame and selected state', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(
      body: Center(child: FroccsCard(card: 'soda', selected: true)),
    )));
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.contain);
    expect(image.semanticLabel, 'Szóda');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Original cup keeps the current amount visible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 94, height: 59,
        child: GlassWidget(size: 3, amount: 2, mini: true)),
    ))));
    await tester.pumpAndSettle();
    expect(find.text('2/3 dl'), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).semanticLabel,
      '3 dl-es pohár, 2 dl ital');
    expect(tester.takeException(), isNull);
  });
}
