import 'package:flutter_test/flutter_test.dart';
import 'package:froccs_mobile/game.dart';

void main() {
  test('The official base deck contains 106 cards before dealing', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    final a = game.viewFor('a');
    expect(a['deckCount'], 96);
    expect(a['actions'], 2);
    expect((a['market'] as List).length, 3);
    expect((a['players'] as List).length, 2);
  });

  test('Each player only sees their own hand', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    final a = (game.viewFor('a')['players'] as List);
    final b = (game.viewFor('b')['players'] as List);
    expect((a[0]['hand'] as List).length, 5);
    expect((a[1]['hand'] as List), isEmpty);
    expect((b[0]['hand'] as List), isEmpty);
    expect((b[1]['hand'] as List).length, 5);
  });

  test('Out of turn players cannot take actions', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    final result = game.apply('b', {'type': 'draw'});
    expect(result, isNotNull);
    expect(game.turn, 0);
    expect(game.actions, 2);
  });

  test('Two-player draw offers three cards and discards one', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    expect(game.apply('a', {'type': 'draw'}), isNull);
    expect(game.drawChoice?.length, 3);
    expect(game.apply('a', {'type': 'keepDraw', 'drop': 1}), isNull);
    expect(game.drawChoice, isNull);
    expect((game.viewFor('a')['players'] as List).first['handCount'], 7);
    expect(game.actions, 1);
  });

  test('Turn passes after spending both actions', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    expect(game.apply('a', {'type': 'pass'}), isNull);
    expect(game.turn, 1);
    expect(game.actions, 2);
  });

  test('A player starts with one 2 dl and one 3 dl cup', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    for (final player in game.viewFor('a')['players'] as List) {
      expect((player['cups'] as List).map((c) => c['size']).toList(), [2, 3]);
    }
  });
  test('Invalid card placement does not consume an action', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    game.players[0]['hand'] = <String>['soda'];
    final error = game.apply('a', {
      'type': 'play', 'cardIndex': 0, 'cup': 99,
    });
    expect(error, isNotNull);
    expect(game.actions, 2);
    expect(game.playSlots, 0);
    expect(game.players[0]['hand'], ['soda']);
  });

  test('Bots defend when attacked by a human player', () {
    final game = Game([
      Seat('a', 'Anna'), Seat('bot-1', 'Bot', bot: true)
    ]);
    game.players[0]['hand'] = <String>['bread'];
    final victim = game.players[1]['cups'] as List;
    (victim[0]['cards'] as List).add('muscat');
    final error = game.apply('a', {
      'type': 'play', 'cardIndex': 0, 'target': 'bot-1', 'cup': 0,
    });
    expect(error, isNull);
    expect(game.pending, isNotNull);
    game.runBots();
    expect(game.pending, isNull);
  });

}
