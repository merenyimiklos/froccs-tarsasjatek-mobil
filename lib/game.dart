import 'dart:math' as math;
import 'dart:math' show Random;

/// A rules-oriented prototype. No copyrighted artwork or card copy is bundled.
const cardNames = <String, String>{
  'muscat': 'Sárgamuskotály', 'barat': 'Szürkebarát',
  'veltelini': 'Zöld Veltelini', 'soda': 'Szóda',
  'bread': 'Zsíros kenyér', 'spill': 'Kilöttyintés',
  'tip': 'Borravaló', 'break': 'Pohártörés', 'shield': 'Ezt neked!',
};
const wineCards = ['muscat', 'barat', 'veltelini'];
const attackCards = ['bread', 'spill', 'tip', 'break'];
const heroNames = [
  'Mélyivó Fred', 'Löttyintős', 'Küv Évi', 'Pohárnok',
  'Recycle Béla', 'Sarki Jézus', 'Sommelier Pityu', 'Vízköpő Karesz',
  'Böske, a Rettentő', 'Hollósi elvtárs', 'Buzgómócsing', 'Icuka',
];

class Seat {
  final String id;
  final String name;
  final bool bot;
  Seat(this.id, this.name, {this.bot = false});
}

/// Host-owned state. Only viewFor() is sent to a player; other hands stay secret.
class Game {
  final Random random = Random.secure();
  late List<Map<String, dynamic>> players;
  final List<String> deck = [];
  final List<String> discard = [];
  final List<int> cupDeck = [];
  final List<int> cupDiscard = [];
  final List<int> market = [];
  int turn = 0;
  int actions = 2;
  int playSlots = 0;
  int finalTurns = -1;
  bool over = false;
  String message = 'Kezdődhet a játék!';
  Map<String, dynamic>? pending;
  List<String>? drawChoice;

  Game(List<Seat> seats) {
    if (seats.length < 2 || seats.length > 6) {
      throw ArgumentError('2–6 játékos szükséges.');
    }
    // Published totals: 10/16/22 wine, 35 soda, 4 defense, 19 attacks.
    // The four attack sub-type counts are provisional until verified.
    _add(deck, 'veltelini', 10);
    _add(deck, 'barat', 16);
    _add(deck, 'muscat', 22);
    _add(deck, 'soda', 35);
    _add(deck, 'shield', 4);
    _add(deck, 'bread', 5);
    _add(deck, 'spill', 5);
    _add(deck, 'tip', 5);
    _add(deck, 'break', 4);
    deck.shuffle(random);

    // Glass size distribution must be checked against a physical copy.
    cupDeck.addAll([
      ...List.filled(10, 2), ...List.filled(10, 3),
      ...List.filled(6, 5),
    ]);
    for (var i = 0; i < seats.length; i++) {
      cupDeck.remove(2);
      cupDeck.remove(3);
    }
    cupDeck.shuffle(random);
    while (market.length < 3 && cupDeck.isNotEmpty) {
      market.add(cupDeck.removeLast());
    }
    // First-game recommended heroes; the advanced four remain opt-in later.
    final starterHeroes = heroNames.take(8).toList()..shuffle(random);
    players = [
      for (var i = 0; i < seats.length; i++)
        {
          'id': seats[i].id, 'name': seats[i].name,
          'bot': seats[i].bot, 'money': 0, 'hero': starterHeroes[i],
          'hand': <String>[], 'cups': <Map<String, dynamic>>[
            {'size': 2, 'cards': <String>[]},
            {'size': 3, 'cards': <String>[]},
          ],
        },
    ];
    for (final p in players) {
      for (var i = 0; i < 5; i++) {
        (p['hand'] as List<String>).add(deck.removeLast());
      }
    }
  }

  static void _add(List<String> list, String value, int count) {
    list.addAll(List.filled(count, value));
  }

  Map<String, dynamic> get current => players[turn];
  String get currentId => current['id'] as String;
  String get currentName => current['name'] as String;
  bool get isBotTurn => !over && (current['bot'] as bool);
  bool get waitingForResponse => pending != null || drawChoice != null;

  List<Map<String, dynamic>> _cups(Map<String, dynamic> p) =>
      (p['cups'] as List).cast<Map<String, dynamic>>();
  List<String> _hand(Map<String, dynamic> p) => (p['hand'] as List).cast<String>();
  List<String> _filled(Map<String, dynamic> c) => (c['cards'] as List).cast<String>();
  bool _isReady(Map<String, dynamic> c) {
    final cards = _filled(c);
    return cards.length == c['size'] &&
        cards.contains('soda') && cards.any(wineCards.contains);
  }

  // Prices are temporary playtest values; official itallap values need approval/verification.
  int _price(Map<String, dynamic> c) {
    final cards = _filled(c);
    final wine = cards.firstWhere(wineCards.contains, orElse: () => 'muscat');
    final count = cards.where(wineCards.contains).length;
    final rate = wine == 'veltelini' ? 20 : wine == 'barat' ? 15 : 10;
    return 10 + count * rate + (cards.length == 5 ? 10 : 0);
  }

  Map<String, dynamic> viewFor(String id) {
    return {
      'turn': currentId, 'actions': actions, 'playSlots': playSlots,
      'deckCount': deck.length, 'finalTurns': finalTurns,
      'over': over, 'message': message, 'market': List<int>.from(market),
      'pending': pending == null ? null : Map<String, dynamic>.from(pending!),
      'drawChoice': (drawChoice != null && currentId == id)
          ? List<String>.from(drawChoice!) : null,
      'players': [
        for (final p in players)
          {
            'id': p['id'], 'name': p['name'], 'bot': p['bot'],
            'money': p['money'], 'hero': p['hero'],
            'handCount': _hand(p).length,
            'hand': p['id'] == id ? List<String>.from(_hand(p)) : <String>[],
            'cups': [
              for (final c in _cups(p))
                {'size': c['size'], 'cards': List<String>.from(_filled(c))}
            ],
          }
      ],
    };
  }

  Map<String, dynamic>? _findPlayer(String id) {
    for (final p in players) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  String? apply(String id, Map<String, dynamic> c) {
    if (over) return 'A játszma véget ért.';
    final type = c['type'];
    if (pending != null) return _attackResponse(id, c);
    if (drawChoice != null) {
      if (id != currentId || type != 'keepDraw') return 'Válassz a húzott lapokból!';
      final choices = drawChoice!;
      final dropped = (c['drop'] as num?)?.toInt() ?? -1;
      if (dropped < 0 || dropped >= choices.length) return 'Érvénytelen lap.';
      for (var i = 0; i < choices.length; i++) {
        if (i == dropped) { discard.add(choices[i]); } else { _hand(current).add(choices[i]); }
      }
      drawChoice = null;
      message = '$currentName kiválasztotta a húzott lapokat.';
      _advanceIfDone();
      return null;
    }
    if (id != currentId) return 'Most nem te következel.';
    if (type == 'endPlay') {
      if (playSlots == 0) return 'Nincs folyamatban kijátszás.';
      playSlots = 0;
      message = '$currentName lezárta a kijátszást.';
      _advanceIfDone();
      return null;
    }
    if (type == 'pass') {
      playSlots = 0;
      actions = 0;
      _advanceIfDone();
      return null;
    }
    if (playSlots > 0 && type != 'play') return 'Előbb fejezd be a lapkijátszást.';
    if (actions == 0 && playSlots == 0) return 'Elfogytak az akciók.';
    switch (type) {
      case 'draw':
        if (playSlots > 0) return 'Előbb zárd le a kijátszást.';
        actions--;
        if (players.length == 2) {
          drawChoice = [];
          for (var i = 0; i < 3; i++) {
            final card = _draw();
            if (card != null) drawChoice!.add(card);
          }
          if (drawChoice!.length <= 2) {
            _hand(current).addAll(drawChoice!);
            drawChoice = null;
          }
        } else {
          for (var i = 0; i < 2; i++) {
            final card = _draw();
            if (card != null) _hand(current).add(card);
          }
        }
        message = '$currentName lapokat húzott.';
        break;
      case 'buy':
        if (playSlots > 0) return 'Előbb zárd le a kijátszást.';
        final indexes = ((c['indexes'] as List?) ?? [])
            .map((e) => (e as num).toInt()).toList();
        if (indexes.length != 1 && indexes.length != 2) return 'Válassz 1 vagy 2 poharat.';
        if (indexes.toSet().length != indexes.length ||
            indexes.any((i) => i < 0 || i >= market.length)) return 'Hibás pohárválasztás.';
        if (_cups(current).length + indexes.length > 3) return 'Maximum 3 poharad lehet.';
        final cost = indexes.length == 1 ? 10 : current['hero'] == 'Pohárnok' ? 20 : 40;
        if ((current['money'] as int) < cost) return 'Nincs elég pénzed.';
        current['money'] = (current['money'] as int) - cost;
        actions--;
        for (final index in (indexes..sort((a, b) => b.compareTo(a)))) {
          _cups(current).add({'size': market.removeAt(index), 'cards': <String>[]});
        }
        _refillMarket();
        message = '$currentName poharat vásárolt.';
        break;
      case 'sell':
        if (actions != 2 || playSlots > 0) return 'Eladni csak a köröd első akciójával lehet.';
        final indexes = ((c['indexes'] as List?) ?? [])
            .map((e) => (e as num).toInt()).toList();
        if (indexes.isEmpty || indexes.toSet().length != indexes.length ||
            indexes.any((i) => i < 0 || i >= _cups(current).length || !_isReady(_cups(current)[i]))) {
          return 'Csak kész fröccsöt adhatsz el.';
        }
        actions--;
        int income = 0;
        int soldVolume = 0;
        int largeGlasses = 0;
        for (final index in (indexes..sort((a, b) => b.compareTo(a)))) {
          final cup = _cups(current).removeAt(index);
          final size = cup['size'] as int;
          soldVolume += size;
          if (size == 3 || size == 5) largeGlasses++;
          income += _price(cup);
          discard.addAll(_filled(cup));
          cupDiscard.add(size);
        }
        // Official hero abilities are independent of the selling action.
        if (current['hero'] == 'Sommelier Pityu' && soldVolume >= 5) {
          income += largeGlasses * 10;
        }
        current['money'] = (current['money'] as int) + income;
        if (current['hero'] == 'Mélyivó Fred' && soldVolume >= 5 &&
            market.isNotEmpty && _cups(current).length < 3) {
          final smallest = market.reduce(math.min);
          market.remove(smallest);
          _cups(current).add({'size': smallest, 'cards': <String>[]});
          _refillMarket();
        }
        message = '$currentName $income Ft értékben adott el.';
        break;
      case 'play':
        final cardIndex = (c['cardIndex'] as num?)?.toInt() ?? -1;
        if (cardIndex < 0 || cardIndex >= _hand(current).length) return 'Nincs ilyen lapod.';
        final card = _hand(current)[cardIndex];
        if (card == 'shield') return 'Ezt a lapot védekezésre tartogasd.';
        if (_cups(current).isEmpty) return 'Kijátszáshoz pohár kell.';
        if (playSlots == 0 && actions < 1) return 'Elfogytak az akciók.';
        if (playSlots < 0) return 'Elfogyott a kijátszási keret.';
        if (wineCards.contains(card) || card == 'soda') {
          final cupIndex = (c['cup'] as num?)?.toInt() ?? -1;
          if (cupIndex < 0 || cupIndex >= _cups(current).length) return 'Válassz poharat.';
          final cup = _cups(current)[cupIndex];
          final cards = _filled(cup);
          if (cards.length >= cup['size']) return 'Tele a pohár.';
          if (wineCards.contains(card) &&
              cards.any((value) => wineCards.contains(value) && value != card) &&
              current['hero'] != 'Küv Évi') return 'Egy pohárba egyfajta bor kerülhet.';
          if (cards.length + 1 == cup['size']) {
            final next = [...cards, card];
            if (!next.contains('soda') || !next.any(wineCards.contains)) {
              return 'Nem készülhet csak borból vagy csak szódából teli pohár.';
            }
          }
          if (playSlots == 0) {
            actions--;
            playSlots = _cups(current).length;
          }
          cards.add(_hand(current).removeAt(cardIndex));
          playSlots--;
          message = '$currentName töltött a poharába.';
        } else if (attackCards.contains(card)) {
          final target = c['target'] as String? ?? '';
          final victim = _findPlayer(target);
          if (victim == null || victim['id'] == id) return 'Válassz másik játékost.';
          final cupIndex = (c['cup'] as num?)?.toInt() ?? -1;
          if (!_validAttack(card, victim, cupIndex)) return 'A célpont nem támadható ezzel a lappal.';
          if (playSlots == 0) {
            actions--;
            playSlots = _cups(current).length;
          }
          _hand(current).removeAt(cardIndex);
          playSlots--;
          pending = {
            'actor': id, 'target': target, 'card': card,
            'cup': cupIndex, 'offer': 0, 'phase': 'response',
          };
          message = '$currentName támadást indított.';
        } else {
          return 'Nem lehet ezt a lapot kijátszani.';
        }
        break;
      default:
        return 'Ismeretlen művelet.';
    }
    _advanceIfDone();
    return null;
  }

  bool _validAttack(String card, Map<String, dynamic> victim, int cupIndex) {
    if (card == 'tip') return (victim['money'] as int) >= 30 || _cups(victim).isNotEmpty;
    if (card == 'break') {
      return (victim['money'] as int) >= 10 &&
          cupIndex >= 0 && cupIndex < _cups(victim).length &&
          _filled(_cups(victim)[cupIndex]).isEmpty;
    }
    if (cupIndex < 0 || cupIndex >= _cups(victim).length) return false;
    final contents = _filled(_cups(victim)[cupIndex]);
    return card == 'bread'
        ? contents.any(wineCards.contains)
        : contents.contains('soda');
  }

  String? _attackResponse(String id, Map<String, dynamic> c) {
    final p = pending!;
    final type = c['type'];
    final victim = _findPlayer(p['target'] as String)!;
    final attacker = _findPlayer(p['actor'] as String)!;
    if (p['phase'] == 'response') {
      if (id != p['target']) return 'A megtámadott játékos válaszol.';
      if (type == 'defend') {
        if (!_hand(victim).remove('shield')) return 'Nincs védekező lap.';
        discard.add('shield');
        discard.add(p['card'] as String);
        pending = null;
        message = 'Sikeres védekezés!';
      } else if (type == 'offer') {
        final amount = (c['amount'] as num?)?.toInt() ?? 0;
        if (amount <= 0 || amount % 10 != 0 || amount > victim['money']) {
          return 'Pozitív, fedezettel rendelkező 10 Ft-os ajánlat kell.';
        }
        p['offer'] = amount;
        p['phase'] = 'decision';
        message = 'Alkuajánlat: $amount Ft.';
      } else if (type == 'takeHit') {
        _resolveAttack();
      } else {
        return 'Védekezés, alku vagy támadás elfogadása választható.';
      }
    } else {
      if (id != p['actor']) return 'A támadó dönt az ajánlatról.';
      if (type == 'acceptOffer') {
        final amount = p['offer'] as int;
        victim['money'] = (victim['money'] as int) - amount;
        attacker['money'] = (attacker['money'] as int) + amount;
        discard.add(p['card'] as String);
        pending = null;
        message = '$amount Ft-os alku elfogadva.';
      } else if (type == 'rejectOffer') {
        p['phase'] = 'response';
        p['offer'] = 0;
        message = 'Alku elutasítva. Védekezz vagy fogadd a támadást!';
      } else {
        return 'Fogadd el vagy utasítsd el az ajánlatot.';
      }
    }
    _advanceIfDone();
    return null;
  }

  void _resolveAttack() {
    final p = pending!;
    final victim = _findPlayer(p['target'] as String)!;
    final card = p['card'] as String;
    final index = p['cup'] as int;
    if (card == 'tip') {
      victim['money'] = max(0, (victim['money'] as int) - 20);
    } else if (card == 'break') {
      final cup = _cups(victim).removeAt(index);
      cupDiscard.add(cup['size'] as int);
    } else {
      final contents = _filled(_cups(victim)[index]);
      final removedIndex = card == 'spill'
          ? contents.indexOf('soda')
          : contents.indexWhere(wineCards.contains);
      if (removedIndex >= 0) discard.add(contents.removeAt(removedIndex));
    }
    discard.add(card);
    pending = null;
    message = 'A támadás végrehajtva.';
  }

  String? _draw() {
    if (deck.isEmpty) {
      if (finalTurns < 0) finalTurns = players.length + 1;
      if (discard.isEmpty) return null;
      deck.addAll(discard);
      discard.clear();
      deck.shuffle(random);
    }
    final result = deck.removeLast();
    if (deck.isEmpty && finalTurns < 0) {
      finalTurns = players.length + 1;
    }
    return result;
  }

  void _refillMarket() {
    while (market.length < 3) {
      if (cupDeck.isEmpty && cupDiscard.isNotEmpty) {
        cupDeck.addAll(cupDiscard);
        cupDiscard.clear();
        cupDeck.shuffle(random);
      }
      if (cupDeck.isEmpty) break;
      market.add(cupDeck.removeLast());
    }
  }

  void _advanceIfDone() {
    if (pending != null || drawChoice != null || playSlots != 0) return;
    if (actions > 0) return;
    _endTurn();
  }

  void _endTurn() {
    if (finalTurns > 0) {
      finalTurns--;
      if (finalTurns == 0) {
        for (final p in players) {
          for (final c in _cups(p)) {
            if (_isReady(c)) {
              p['money'] = (p['money'] as int) + 20;
            } else if (_filled(c).isNotEmpty) {
              p['money'] = (p['money'] as int) + 10;
            }
          }
        }
        over = true;
        final ranking = [...players]..sort((a, b) {
          final money = (b['money'] as int).compareTo(a['money'] as int);
          return money != 0 ? money : _hand(a).length.compareTo(_hand(b).length);
        });
        message = 'Záróra! Nyertes: ' + ranking.first['name'].toString();
        return;
      }
    }
    turn = (turn + 1) % players.length;
    actions = 2;
    playSlots = 0;
    message = '$currentName következik.';
  }

  /// Deterministic, legal-action-seeking basic bot, intentionally non-cheating.
  /// Resolve pending bot defence even during a human attacker's turn.
  /// Otherwise a bot target would wait forever for a nonexistent UI action.
  void runBots() {
    var guard = 0;
    while (!over && guard++ < 120) {
      if (pending != null) {
        final target = _findPlayer(pending!['target'] as String);
        final actor = _findPlayer(pending!['actor'] as String);
        if (target != null && target['bot'] == true &&
            pending!['phase'] == 'response') {
          apply(target['id'] as String, {
            'type': _hand(target).contains('shield') ? 'defend' : 'takeHit'
          });
          continue;
        }
        if (actor != null && actor['bot'] == true &&
            pending!['phase'] == 'decision') {
          apply(actor['id'] as String, {'type': 'acceptOffer'});
          continue;
        }
        break;
      }
      if (!isBotTurn) break;
      final bot = current;
      if (drawChoice != null) {
        apply(currentId, {
          'type': 'keepDraw',
          'drop': random.nextInt(drawChoice!.length)
        });
        continue;
      }
      if (playSlots > 0) {
        final move = _findBotPlay();
        if (move == null) {
          apply(currentId, {'type': 'endPlay'});
        } else {
          apply(currentId, move);
        }
        continue;
      }
      final ready = <int>[];
      for (var i = 0; i < _cups(bot).length; i++) {
        if (_isReady(_cups(bot)[i])) ready.add(i);
      }
      if (actions == 2 && ready.isNotEmpty) {
        apply(currentId, {'type': 'sell', 'indexes': ready});
      } else if (_cups(bot).isNotEmpty && _findBotPlay() != null) {
        apply(currentId, _findBotPlay()!);
      } else if (_cups(bot).length < 2 &&
          (bot['money'] as int) >= 10 && market.isNotEmpty) {
        apply(currentId, {'type': 'buy', 'indexes': [0]});
      } else {
        apply(currentId, {'type': 'draw'});
      }
    }
  }

  Map<String, dynamic>? _findBotPlay() {
    final hand = _hand(current);
    for (var i = 0; i < hand.length; i++) {
      final card = hand[i];
      if (card == 'shield' || attackCards.contains(card)) continue;
      for (var j = 0; j < _cups(current).length; j++) {
        final cup = _cups(current)[j];
        final contents = _filled(cup);
        if (contents.length >= cup['size']) continue;
        if (wineCards.contains(card) &&
            contents.any((e) => wineCards.contains(e) && e != card)) continue;
        final next = [...contents, card];
        if (next.length == cup['size'] &&
            (!next.contains('soda') || !next.any(wineCards.contains))) continue;
        return {'type': 'play', 'cardIndex': i, 'cup': j};
      }
    }
    return null;
  }
}
