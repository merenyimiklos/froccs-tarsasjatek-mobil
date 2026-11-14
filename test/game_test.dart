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

  test('Mélyivó Fred receives the smallest market glass when selling 5dl', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    game.players[0]['hero'] = 'Mélyivó Fred';
    final cups = game.players[0]['cups'] as List;
    cups[0]['cards'] = <String>['muscat', 'soda'];
    cups[1]['cards'] = <String>['muscat', 'soda', 'muscat'];
    final smallest = game.market.reduce((a, b) => a < b ? a : b);
    expect(game.apply('a', {'type': 'sell', 'indexes': [0, 1]}), isNull);
    final remaining = game.players[0]['cups'] as List;
    expect(remaining, hasLength(1));
    expect(remaining.first['size'], smallest);
  });

  test('Selected character is honoured in a new match', () {
    final game = Game([
      Seat('a', 'Anna', hero: 'Küv Évi'),
      Seat('b', 'Béla', hero: 'Pohárnok'),
    ]);
    expect(game.players[0]['hero'], 'Küv Évi');
    expect(game.players[1]['hero'], 'Pohárnok');
  });

  test('No duplicate character is allocated', () {
    final game = Game([
      Seat('a', 'Anna', hero: 'Küv Évi'),
      Seat('b', 'Béla', hero: 'Küv Évi'),
    ]);
    expect(game.players[0]['hero'], 'Küv Évi');
    expect(game.players[1]['hero'], isNot('Küv Évi'));
  });

  test('Official rule rejects mixing wine types, without losing an action', () {
    final game = Game([
      Seat('a', 'Anna', hero: 'Pohárnok'),
      Seat('b', 'Béla'),
    ]);
    game.players[0]['hand'] = <String>['barat'];
    final cups = game.players[0]['cups'] as List;
    cups[1]['cards'] = <String>['muscat'];
    final err = game.apply('a', {
      'type': 'play', 'cardIndex': 0, 'cup': 1,
    });
    expect(err, isNotNull);
    expect(game.actions, 2);
    expect(game.playSlots, 0);
    expect(cups[1]['cards'], ['muscat']);
  });

  test('Mixed wines are legal in the opt-in house-rules mode', () {
    final game = Game([
      Seat('a', 'Anna', hero: 'Pohárnok'),
      Seat('b', 'Béla'),
    ], allowMixedWine: true);
    game.players[0]['hand'] = <String>['barat'];
    final cups = game.players[0]['cups'] as List;
    cups[1]['cards'] = <String>['muscat'];
    expect(game.apply('a', {
      'type': 'play', 'cardIndex': 0, 'cup': 1,
    }), isNull);
    expect(cups[1]['cards'], ['muscat', 'barat']);
    expect(game.actions, 1);
  });

  test('Küv Évi can combine two different wine types in standard mode', () {
    final game = Game([
      Seat('a', 'Anna', hero: 'Küv Évi'),
      Seat('b', 'Béla'),
    ]);
    game.players[0]['hand'] = <String>['barat'];
    final cups = game.players[0]['cups'] as List;
    cups[1]['cards'] = <String>['muscat'];
    expect(game.apply('a', {
      'type': 'play', 'cardIndex': 0, 'cup': 1,
    }), isNull);
    expect(cups[1]['cards'], ['muscat', 'barat']);
  });

  test('Each turn allows at most two draw actions (four cards for 3 players)', () {
    final game = Game([
      Seat('a', 'Anna'),
      Seat('b', 'Béla'),
      Seat('c', 'Cecil'),
    ]);
    final initialCount = (game.players[0]['hand'] as List).length;
    expect(game.apply('a', {'type': 'draw'}), isNull);
    expect(game.actions, 1);
    expect(game.apply('a', {'type': 'draw'}), isNull);
    expect(game.turn, 1);
    expect((game.players[0]['hand'] as List).length, initialCount + 4);
    expect(game.apply('a', {'type': 'draw'}), isNotNull);
  });

  test('Players may have no more than three glasses, and failed buy is free', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    game.players[0]['money'] = 100;
    final result = game.apply('a', {'type': 'buy', 'indexes': [0, 1]});
    expect(result, isNotNull);
    expect(game.actions, 2);
    expect(game.players[0]['money'], 100);
  });

  test('Glass slot count caps one play action at the number of glasses', () {
    final game = Game([Seat('a', 'Anna'), Seat('b', 'Béla')]);
    game.players[0]['hand'] = <String>['muscat', 'soda', 'soda'];
    expect(game.apply('a', {'type': 'play', 'cardIndex': 0, 'cup': 0}), isNull);
    expect(game.playSlots, 1);
    expect(game.apply('a', {'type': 'play', 'cardIndex': 0, 'cup': 0}), isNull);
    expect(game.playSlots, 0);
    expect(game.actions, 1);
    // This is a new action, not a third card within the previous play.
    expect(game.apply('a', {'type': 'draw'}), isNull);
    expect(game.turn, 1);
  });

}
