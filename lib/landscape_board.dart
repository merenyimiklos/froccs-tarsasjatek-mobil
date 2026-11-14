import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game.dart';
import 'card_art.dart';

typedef ActionSender = void Function(Map<String, dynamic> action);

/// Designed for a 1200x660 landscape canvas, scaled uniformly for phones.
/// Replace assets/original/card_<id>.png with the authorised card scans.
class LandscapeBoard extends StatefulWidget {
  const LandscapeBoard({
    super.key,
    required this.snapshot,
    required this.myId,
    required this.onAction,
    required this.onLeave,
  });

  final Map<String, dynamic> snapshot;
  final String myId;
  final ActionSender onAction;
  final VoidCallback onLeave;

  @override
  State<LandscapeBoard> createState() => _LandscapeBoardState();
}

class _LandscapeBoardState extends State<LandscapeBoard> {
  int? selectedCard;

  @override
  void didUpdateWidget(covariant LandscapeBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) {
      final current = ownHand;
      if (selectedCard != null && selectedCard! >= current.length) {
        selectedCard = null;
      }
    }
  }

  List<Map> get players => (widget.snapshot['players'] as List).cast<Map>();
  Map get me => players.firstWhere((p) => p['id'] == widget.myId);
  List<String> get ownHand => (me['hand'] as List).cast<String>();
  bool get myTurn => widget.snapshot['turn'] == widget.myId &&
      widget.snapshot['over'] != true;
  bool get canAct => myTurn && widget.snapshot['pending'] == null &&
      widget.snapshot['drawChoice'] == null;

  void send(Map<String, dynamic> action) {
    setState(() => selectedCard = null);
    widget.onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    final other = players.where((p) => p['id'] != widget.myId).toList();
    final pending = widget.snapshot['pending'] as Map?;
    final choosing = widget.snapshot['drawChoice'] as List?;
    return LayoutBuilder(builder: (context, constraints) {
      return FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: SizedBox(
          width: 1200,
          height: 660,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(children: [
              const Positioned.fill(child: WoodBackground()),
              const Positioned.fill(child: IgnorePointer(
                child: ColoredBox(color: Color(0x29081916)))),
              Positioned(top: 8, left: 470, width: 260,
                child: _header()),
              Positioned(top: 8, left: 850, child: IconButton(
                tooltip: 'Kilépés a játékból',
                onPressed: _leaveConfirm,
                icon: const Icon(Icons.exit_to_app,
                  color: Color(0xFFFFD9A4), size: 29))),
              Positioned(top: 18, left: 18, width: 267,
                height: 114,
                child: other.isEmpty ? const SizedBox.shrink()
                    : _opponent(other.first)),
              Positioned(top: 18, right: 18, width: 267,
                height: 114,
                child: other.length < 2 ? const SizedBox.shrink()
                    : _opponent(other[1])),
              if (other.length > 2)
                Positioned(top: 112, left: 338, width: 525,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final p in other.skip(2))
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _tinyOpponent(p)),
                    ])),
              Positioned(top: 150, left: 18, width: 220,
                height: 327, child: _sidePanel()),
              Positioned(top: 151, right: 18, width: 212,
                height: 327, child: _actionsPanel()),
              Positioned(top: 160, left: 252, width: 694,
                height: 309, child: _tableArea()),
              Positioned(bottom: 13, left: 18, width: 255,
                height: 157, child: _heroPanel()),
              Positioned(bottom: 7, left: 285, right: 18,
                height: 169, child: _handArea()),
              if (pending != null || choosing != null ||
                  widget.snapshot['over'] == true)
                Positioned.fill(child: _modalOverlay(pending, choosing)),
            ]),
          ),
        ),
      );
    });
  }

  Widget _header() => Column(children: [
    Text('FRÖCCS', textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 43, fontWeight: FontWeight.w900, letterSpacing: 4,
        shadows: [Shadow(blurRadius: 5, color: Colors.black.withValues(alpha: 0.9),
          offset: const Offset(2, 3))],
        color: const Color(0xFFFFE4A3))),
    const Text('✦  A KOCSMA NYITVA  ✦', style:
      TextStyle(color: Color(0xFFFFD8A2), letterSpacing: 3, fontSize: 12,
        fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(players.length.toString() + ' játékos · ' +
        (widget.snapshot['deckCount'] as int).toString() + ' lap a pakliban',
      style: const TextStyle(color: Color(0xFFCEE9D9), fontSize: 12)),
  ]);

  Widget _opponent(Map p) {
    final active = p['id'] == widget.snapshot['turn'];
    return Material(color: Colors.transparent,
      child: InkWell(
        onTap: () => _showOpponent(p),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          decoration: _frame(active: active),
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            CircleAvatar(radius: 32, backgroundColor: const Color(0xFFB17850),
              child: Icon(p['bot'] == true ? Icons.smart_toy : Icons.person,
                size: 38, color: const Color(0xFFFFE0A5))),
            const SizedBox(width: 9),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(p['name'].toString(), overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold,
                    color: Color(0xFFFFE8BA))),
                Text(p['hero'].toString(), maxLines: 1,
                  overflow: TextOverflow.ellipsis, style: const TextStyle(
                    fontSize: 11, color: Color(0xFFAED7C9))),
                const SizedBox(height: 5),
                Text('🪙 ' + p['money'].toString() + ' Ft  ·  ' +
                    p['handCount'].toString() + ' lap',
                  style: const TextStyle(fontSize: 13, color: Colors.white)),
                Text((p['cups'] as List).map((c) =>
                      c['size'].toString() + ' dl: ' +
                      (c['cards'] as List).length.toString())
                    .join('    '), maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFFFAD48C))),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  Widget _tinyOpponent(Map p) => InkWell(
    onTap: () => _showOpponent(p),
    child: Container(
      width: 165, height: 40,
      decoration: _frame(active: p['id'] == widget.snapshot['turn']),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(p['name'].toString(), overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFFFFD69E),
              fontWeight: FontWeight.bold, fontSize: 12)),
          Text(p['money'].toString() + ' Ft  ·  ' +
            p['handCount'].toString() + ' lap',
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ])),
  );

  BoxDecoration _frame({bool active = false}) => BoxDecoration(
    borderRadius: BorderRadius.circular(17),
    gradient: const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xF21B4F40), Color(0xF70C2827)]),
    border: Border.all(
      color: active ? const Color(0xFFFFE59C) : const Color(0xFFAB7B43),
      width: active ? 2.5 : 1.3),
    boxShadow: const [BoxShadow(
      color: Color(0xAA000000), blurRadius: 15, offset: Offset(3, 6))],
  );

  Widget _sidePanel() => Container(
    decoration: _frame(),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('🍷 KOCSMAHŐSÖK', style: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFFFFDEAB))),
      const Divider(color: Color(0x88CCAB70)),
      const Text('A szomszéd asztalok', style: TextStyle(
        color: Color(0xFFA8DDD3), fontSize: 12)),
      const SizedBox(height: 6),
      Expanded(child: ListView(children: [
        for (final p in players.where((p) => p['id'] != widget.myId))
          Padding(padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(onTap: () => _showOpponent(p),
              child: Row(children: [
                const Icon(Icons.local_bar, size: 20,
                  color: Color(0xFFFFCA7D)),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p['name'].toString(), overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.bold)),
                    Text(p['hero'].toString(), maxLines: 1,
                      overflow: TextOverflow.ellipsis, style: const TextStyle(
                        fontSize: 10, color: Color(0xFFA5D5C5))),
                  ])),
              ]),
            )),
      ])),
      const Divider(color: Color(0x88CCAB70)),
      const Text('KÖVETKEZŐ LÉPÉS', style: TextStyle(
        color: Color(0xFFFFD48E), fontSize: 11,
        fontWeight: FontWeight.w900)),
      const SizedBox(height: 4),
      Text(widget.snapshot['message'].toString(),
        maxLines: 3, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: Colors.white)),
      if (widget.snapshot['finalTurns'] != -1)
        const Text('ZÁRÓRA KÖZELEG!', style: TextStyle(
          color: Color(0xFFFFBA86), fontWeight: FontWeight.w900)),
    ]),
  );

  Widget _actionsPanel() {
    final slots = widget.snapshot['playSlots'] as int;
    final ready = <int>[];
    final cups = me['cups'] as List;
    for (var i = 0; i < cups.length; i++) {
      if (_ready(cups[i] as Map)) ready.add(i);
    }
    return Container(
      decoration: _frame(),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('AKCIÓK', style: TextStyle(
          fontSize: 20, color: Color(0xFFFFE6B5),
          fontWeight: FontWeight.w900, letterSpacing: 1)),
        Text(myTurn
          ? (slots > 0
            ? 'Kijátszás · még $slots lap'
            : 'A te köröd · ${widget.snapshot['actions']} akció')
          : 'Másik játékos köre',
          style: const TextStyle(color: Color(0xFFACD7C9), fontSize: 12)),
        const SizedBox(height: 4),
        _action('ELADÁS', Icons.paid, const Color(0xFF9E3C36),
          canAct && slots == 0 && widget.snapshot['actions'] == 2 &&
              ready.isNotEmpty,
          () => send({'type': 'sell', 'indexes': ready})),
        _action('HÚZÁS · 2 LAP', Icons.style, const Color(0xFF277A66),
          canAct && slots == 0, () => send({'type': 'draw'})),
        _action('POHÁRVÁSÁRLÁS', Icons.local_drink,
          const Color(0xFF277A66), canAct && slots == 0,
          _buySelection),
        _action(slots > 0 ? 'KIJÁTSZÁS LEZÁRÁSA' : 'KIJÁTSZÁS',
          Icons.style, const Color(0xFFAD7925), canAct,
          () {
            if (slots > 0) {
              send({'type': 'endPlay'});
            } else {
              _toast('Válassz egy lapot alul a kezedből!');
            }
          }),
        _action('KÖR ÁTADÁSA', Icons.skip_next,
          const Color(0xFF466C66), canAct,
          () => send({'type': 'pass'})),
        const Spacer(),
        SizedBox(height: 30, child: Row(children: [
          const Icon(Icons.auto_stories, size: 17,
            color: Color(0xFFFFD28E)),
          const SizedBox(width: 5),
          const Expanded(child: Text('Itallap és szabályok',
            style: TextStyle(fontSize: 11, color: Colors.white70))),
          IconButton(tooltip: 'Szabályok', icon: const Icon(Icons.info_outline,
              size: 20, color: Color(0xFFFFD28E)),
            onPressed: _rulesDialog),
        ])),
      ]),
    );
  }

  Widget _action(String label, IconData icon, Color base, bool enabled,
      VoidCallback callback) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: enabled ? base : const Color(0xFF3A514D),
          elevation: enabled ? 3 : 0,
          shadowColor: Colors.black54,
          borderRadius: BorderRadius.circular(13),
          child: InkWell(
            onTap: enabled ? callback : null,
            borderRadius: BorderRadius.circular(13),
            child: Container(height: 34,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(13),
                border: Border.all(color: enabled
                  ? const Color(0xFFE7BC7C) : Colors.white24, width: 1.3)),
              child: Row(children: [
                const SizedBox(width: 10),
                Icon(icon, color: enabled ? const Color(0xFFFFE7BD)
                  : Colors.white38, size: 18),
                const SizedBox(width: 7),
                Expanded(child: FittedBox(fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, maxLines: 1,
                    style: TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: enabled ? Colors.white : Colors.white38)))),
              ])),
          ),
        ),
      );

  Widget _tableArea() => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      color: const Color(0x33000000),
      border: Border.all(color: const Color(0x55EAC391))),
    child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(13, 8, 13, 2),
        child: Row(children: [
          const Text('KOCSMAPULT', style: TextStyle(
            color: Color(0xFFFFDC9F), fontSize: 15,
            letterSpacing: 1, fontWeight: FontWeight.w900)),
          const Spacer(),
          _pill(Icons.layers, widget.snapshot['deckCount'].toString() + ' lap'),
          const SizedBox(width: 7),
          const Text('·  POHÁRPIAC',
            style: TextStyle(color: Colors.white70, fontSize: 11)),
        ])),
      SizedBox(height: 91, child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < (widget.snapshot['market'] as List).length; i++)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                SizedBox(width: 94, height: 59,
                  child: InkWell(
                    onTap: canAct && widget.snapshot['playSlots'] == 0
                        ? () => send({'type': 'buy', 'indexes': [i]}) : null,
                    child: GlassWidget(size: widget.snapshot['market'][i] as int,
                      amount: 0, mini: true))),
                Text(widget.snapshot['market'][i].toString() + ' dl · 10 Ft',
                  style: const TextStyle(color: Color(0xFFFFD69A),
                    fontSize: 12, fontWeight: FontWeight.bold)),
              ])),
          const SizedBox(width: 12),
          Column(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.style, size: 37, color: Color(0xFFE8C286)),
              Text(widget.snapshot['deckCount'].toString() + ' lap',
                style: const TextStyle(color: Colors.white70)),
            ]),
        ])),
      const Divider(color: Color(0x55F4D9A7), height: 6),
      const Align(alignment: Alignment.centerLeft,
        child: Padding(padding: EdgeInsets.only(left: 13, top: 5),
          child: Text('A SAJÁT POHARAID', style: TextStyle(
            color: Color(0xFFFFDC9F), fontSize: 15,
            fontWeight: FontWeight.w900, letterSpacing: 1)))),
      Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < (me['cups'] as List).length; i++)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 105, height: 78,
                    child: InkWell(
                      onTap: canAct && selectedCard != null
                        ? () => _playOnCup(selectedCard!, i) : null,
                      child: GlassWidget(
                        size: (me['cups'][i]['size'] as num).toInt(),
                        amount: (me['cups'][i]['cards'] as List).length,
                        mini: false))),
                  Text(me['cups'][i]['size'].toString() + ' dl · ' +
                        (me['cups'][i]['cards'] as List).length.toString() +
                        '/' + me['cups'][i]['size'].toString(),
                    style: const TextStyle(color: Color(0xFFFFDC9F),
                      fontWeight: FontWeight.bold)),
                  SizedBox(width: 104, child: Text(
                    _cupCaption((me['cups'][i]['cards'] as List)
                      .cast<String>()),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11,
                      color: Color(0xFFFFE8C3)))),
                ])),
        ])),
      if (selectedCard != null && canAct)
        const Padding(padding: EdgeInsets.only(bottom: 2),
          child: Text('Koppints egy saját pohárra, vagy választ célpontot',
            style: TextStyle(color: Color(0xFFB6E5CE), fontSize: 11))),
    ]),
  );

  Widget _pill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(15),
      color: const Color(0xBB123C34),
      border: Border.all(color: const Color(0x99D5B079))),
    child: Row(children: [
      Icon(icon, size: 15, color: const Color(0xFFFFD08A)),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 12)),
    ]),
  );

  Widget _heroPanel() => Container(
    decoration: _frame(active: myTurn),
    padding: const EdgeInsets.all(12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('SAJÁT KARAKTER', style: TextStyle(
        fontSize: 11, color: Color(0xFFFFC77E), fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Row(children: [
        SizedBox(width: 58, height: 58,
          child: ClipOval(child: Image.asset(
            'assets/original/hero_' + _heroSlug(me['hero'].toString()) + '.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => const CircleAvatar(
              backgroundColor: Color(0xFFC08A4F),
              child: Icon(Icons.local_bar, size: 34, color: Color(0xFF153B34)))))),
        const SizedBox(width: 9),
        Expanded(child: Text(me['hero'].toString(), maxLines: 2,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
            color: Color(0xFFFFE0A6)))),
      ]),
      const Spacer(),
      Text(me['name'].toString(), overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: Colors.white70)),
      const SizedBox(height: 5),
      Row(children: [
        const Icon(Icons.monetization_on, color: Color(0xFFF6C760), size: 23),
        const SizedBox(width: 5),
        Text(me['money'].toString() + ' Ft',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const Spacer(),
        Text(ownHand.length.toString() + ' lap',
          style: const TextStyle(color: Color(0xFFFFDCA8), fontSize: 13)),
      ]),
    ]),
  );

  Widget _handArea() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(left: 12, bottom: 3),
        child: Row(children: [
          Text(myTurn ? '✦  A TE KÖRÖD  ✦' : 'A TE LAPJAID',
            style: const TextStyle(fontSize: 13, color: Color(0xFFFFE3A4),
              fontWeight: FontWeight.w900, letterSpacing: 1)),
          const Spacer(),
          Text('Koppints egy lapra a kijátszáshoz',
            style: TextStyle(fontSize: 11,
              color: Colors.white.withValues(alpha: 0.8))),
        ])),
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: ownHand.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(top: selectedCard == index ? 0 : 9),
          child: GestureDetector(
            onTap: canAct ? () => _selectCard(index) : null,
            child: FroccsCard(card: ownHand[index],
              selected: selectedCard == index),
          ),
        ),
      )),
    ],
  );

  void _selectCard(int index) {
    final card = ownHand[index];
    if (card == 'shield') {
      _toast('Az Ezt neked! lapot támadásra válaszul használhatod.');
      return;
    }
    if (attackCards.contains(card)) {
      _chooseAttack(index, card);
    } else {
      setState(() => selectedCard = selectedCard == index ? null : index);
    }
  }

  void _playOnCup(int index, int cup) {
    if (index >= ownHand.length) return;
    send({'type': 'play', 'cardIndex': index, 'cup': cup});
  }

  Future<void> _chooseAttack(int cardIndex, String card) async {
    final opponents = players.where((p) => p['id'] != widget.myId).toList();
    final target = await showDialog<String>(
      context: context, builder: (context) =>
        AlertDialog(title: Text(cardNames[card] ?? card),
          content: const Text('Válaszd ki, kit szeretnél megtámadni!'),
          actions: [
            for (final p in opponents)
              TextButton(onPressed: () => Navigator.pop(context, p['id']),
                child: Text(p['name'].toString())),
          ]));
    if (!mounted || target == null) return;
    var cupIndex = -1;
    if (card != 'tip') {
      final player = opponents.firstWhere((p) => p['id'] == target);
      final chosen = await _chooseCup(player['cups'] as List);
      if (!mounted || chosen == null) return;
      cupIndex = chosen;
    }
    send({'type': 'play', 'cardIndex': cardIndex,
      'target': target, 'cup': cupIndex});
  }

  Future<int?> _chooseCup(List cups) => showDialog<int>(
    context: context, builder: (context) =>
      AlertDialog(title: const Text('Melyik pohár?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < cups.length; i++)
            ListTile(
              title: Text(cups[i]['size'].toString() + ' dl'),
              subtitle: Text((cups[i]['cards'] as List).length.toString() +
                ' kártya a pohárban'),
              onTap: () => Navigator.pop(context, i)),
        ])));

  Future<void> _buySelection() async {
    final market = (widget.snapshot['market'] as List).cast<int>();
    final selected = <int>{};
    final chosen = await showDialog<List<int>>(
      context: context, builder: (context) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: const Text('Pohárvásárlás'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('1 pohár: 10 Ft  ·  2 pohár: 40 Ft'),
            for (var i = 0; i < market.length; i++)
              CheckboxListTile(
                title: Text(market[i].toString() + ' dl'),
                value: selected.contains(i),
                onChanged: (value) => refresh(() {
                  if (value == true && selected.length < 2) selected.add(i);
                  if (value == false) selected.remove(i);
                })),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Mégse')),
            FilledButton(
              onPressed: selected.isNotEmpty
                ? () => Navigator.pop(context, selected.toList()) : null,
              child: const Text('Vásárlás')),
          ],
        )));
    if (chosen != null && chosen.isNotEmpty) {
      send({'type': 'buy', 'indexes': chosen});
    }
  }

  Widget _modalOverlay(Map? pending, List? choice) {
    Widget content;
    if (widget.snapshot['over'] == true) {
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('ZÁRÓRA!', style: TextStyle(fontSize: 32,
          color: Color(0xFFFFDE8D), fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(widget.snapshot['message'].toString()),
        const SizedBox(height: 15),
        FilledButton.icon(onPressed: widget.onLeave,
          icon: const Icon(Icons.home), label: const Text('ÚJ JÁTÉK')),
      ]);
    } else if (choice != null) {
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('VÁLASSZ KETTŐT!', style: TextStyle(fontSize: 26,
          color: Color(0xFFFFDE8D), fontWeight: FontWeight.w900)),
        const Text('Koppints arra az egy lapra, amelyiket eldobod.'),
        const SizedBox(height: 12),
        Wrap(spacing: 12, children: [
          if (myTurn) for (var i = 0; i < choice.length; i++)
            InkWell(onTap: () => send({'type': 'keepDraw', 'drop': i}),
              child: FroccsCard(card: choice[i].toString()))
          else const Text('A másik játékos választ.'),
        ]),
      ]);
    } else if (pending != null) {
      final isTarget = pending['target'] == widget.myId;
      final isActor = pending['actor'] == widget.myId;
      final responding = pending['phase'] == 'response';
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('ALKUDOZÁS!', style: TextStyle(fontSize: 28,
          color: Color(0xFFFFDE8D), fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text('Kártya: ' + (cardNames[pending['card']] ?? 'Szívatás'),
          style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 14),
        if (isTarget && responding) ...[
          _dialogButton('Ezt neked! védekezés', () => send({'type': 'defend'})),
          _dialogButton('10 Ft felajánlása',
            () => send({'type': 'offer', 'amount': 10})),
          _dialogButton('20 Ft felajánlása',
            () => send({'type': 'offer', 'amount': 20})),
          _dialogButton('Vállalom a támadást',
            () => send({'type': 'takeHit'})),
        ] else if (isActor && !responding) ...[
          Text('Ajánlat: ' + pending['offer'].toString() + ' Ft'),
          _dialogButton('Alku elfogadása',
            () => send({'type': 'acceptOffer'})),
          _dialogButton('Alku visszautasítása',
            () => send({'type': 'rejectOffer'})),
        ] else const Text('Az ellenfél válaszára várunk…'),
      ]);
    } else {
      content = const SizedBox.shrink();
    }
    return ColoredBox(color: const Color(0xBB000000),
      child: Center(child: Container(
        constraints: const BoxConstraints(minWidth: 340, maxWidth: 570),
        padding: const EdgeInsets.all(24),
        decoration: _frame(active: true),
        child: content,
      )));
  }

  Widget _dialogButton(String title, VoidCallback onTap) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 4),
      child: FilledButton(onPressed: onTap, child: Text(title)));

  void _showOpponent(Map p) => showDialog<void>(
    context: context, builder: (context) => AlertDialog(
      title: Text(p['name'].toString() + ' · ' + p['hero'].toString()),
      content: SizedBox(width: 400, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Pénz: ' + p['money'].toString() + ' Ft  ·  ' +
            p['handCount'].toString() + ' lap'),
          for (final cup in p['cups'] as List)
            ListTile(
              leading: const Icon(Icons.local_bar),
              title: Text(cup['size'].toString() + ' dl-es pohár'),
              subtitle: Text((cup['cards'] as List)
                .map((e) => cardNames[e] ?? e).join(', ')),
            ),
        ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Bezárás'))],
    ));

  void _rulesDialog() => showDialog<void>(
    context: context, builder: (context) => AlertDialog(
      title: const Text('Fröccs – gyors szabálysegéd'),
      content: const SizedBox(width: 490, child: SingleChildScrollView(
        child: Text(
          'Körönként 2 akciód van: eladás, húzás, pohárvétel vagy kijátszás.\n\n'
          'Az eladás csak az első akciód lehet. A kész pohárban legalább '
          'egy bor és egy szóda kell legyen, teljesen megtöltve.\n\n'
          '1 pohár 10 Ft, 2 pohár együtt 40 Ft. Maximum 3 poharad lehet.\n\n'
          'Kijátszáskor legfeljebb annyi lapot használhatsz, '
          'ahány poharad van. A szívatások előtt alkudozni lehet.\n\n'
          'Két főnél húzz 3 lapot, tarts meg 2-t.\n\n'
          'FIGYELEM: a teljes itallap-árlista, a hősök egyedi képességei '
          'és a részletes alku még prototípus-fejlesztés alatt állnak.'))),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
        child: const Text('Értem'))],
    ));

  String _heroSlug(String name) => switch (name) {
    'Mélyivó Fred' => 'melyivo_fred',
    'Löttyintős' => 'lottyintos',
    'Küv Évi' => 'kuv_evi',
    'Pohárnok' => 'poharnok',
    'Recycle Béla' => 'recycle_bela',
    'Sarki Jézus' => 'sarki_jezus',
    'Sommelier Pityu' => 'sommelier_pityu',
    'Vízköpő Karesz' => 'vizkopo_karesz',
    'Böske, a Rettentő' => 'boske',
    'Hollósi elvtárs' => 'hollosi',
    'Buzgómócsing' => 'buzgomocsing',
    'Icuka' => 'icuka',
    _ => 'default',
  };

  Future<void> _leaveConfirm() async {
    final ok = await showDialog<bool>(context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kilépsz a játékból?'),
        content: const Text('Az aktuális játszma nem kerül mentésre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Maradok')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kilépés')),
        ]));
    if (ok == true && mounted) widget.onLeave();
  }

  void _toast(String value) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(value)));

  bool _ready(Map cup) {
    final cards = (cup['cards'] as List).cast<String>();
    return cards.length == cup['size'] && cards.contains('soda') &&
      cards.any(wineCards.contains);
  }

  String _cupCaption(List<String> cards) {
    final wines = cards.where(wineCards.contains).toSet();
    if (wines.length > 1) {
      return widget.snapshot['allowMixedWine'] == true
        ? 'Rozé / vegyes (házi)'
        : 'Vegyes · Küv Évi';
    }
    return cards.map(_symbol).join(' ');
  }

  String _symbol(String card) => switch (card) {
    'soda' => '💧',
    'muscat' => '🍇',
    'barat' => '🍷',
    'veltelini' => '🌿',
    'bread' => '🍞',
    'spill' => '💦',
    'tip' => '🪙',
    'break' => '🍸',
    'shield' => '🛡️',
    _ => '🃏',
  };
}

class FroccsCard extends StatelessWidget {
  const FroccsCard({super.key, required this.card, this.selected = false});

  final String card;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = switch (card) {
      'soda' => const Color(0xFF367CB0),
      'muscat' => const Color(0xFFF7BB52),
      'barat' => const Color(0xFF806C83),
      'veltelini' => const Color(0xFF61974E),
      'shield' => const Color(0xFFD15E48),
      _ => const Color(0xFFCD6245),
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 98, height: 135,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected
            ? const Color(0xFFABFF9B) : const Color(0xFFFFE5C4),
          width: selected ? 4 : 2),
        boxShadow: [
          BoxShadow(color: selected ? const Color(0xAA9CFF78)
            : const Color(0x99000000),
            blurRadius: selected ? 14 : 7, offset: const Offset(1, 4)),
        ]),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/original/card_' + card + '.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => Column(
          children: [
            const SizedBox(height: 5),
            Container(height: 80, width: 87,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const RadialGradient(
                  colors: [Color(0xFFFFECD1), Color(0xFFE9D2A8)])),
              child: CustomPaint(
                painter: PlaceholderCardArt(card),
                child: const SizedBox.expand())),
            Expanded(child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(cardNames[card] ?? card, maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.white,
                  fontWeight: FontWeight.w900)))),
          ],
        )),
    );
  }
}

class GlassWidget extends StatelessWidget {
  const GlassWidget({
    super.key, required this.size, required this.amount, required this.mini,
  });
  final int size;
  final int amount;
  final bool mini;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: GlassPainter(
      fullness: size == 0 ? 0 : amount / size),
    child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(amount == 0 ? '◇' : '🍇',
          style: TextStyle(fontSize: mini ? 25 : 31)),
        Text(size.toString() + ' dl', style: TextStyle(fontSize: mini ? 12 : 16,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFFFE3B0))),
      ])),
  );
}

class GlassPainter extends CustomPainter {
  GlassPainter({required this.fullness});
  final double fullness;

  @override
  void paint(Canvas canvas, Size size) {
    final glass = Path()
      ..moveTo(size.width * 0.13, size.height * 0.08)
      ..lineTo(size.width * 0.87, size.height * 0.08)
      ..lineTo(size.width * 0.78, size.height * 0.92)
      ..quadraticBezierTo(size.width * 0.5, size.height,
        size.width * 0.22, size.height * 0.92)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0x446ECCE4));
    if (fullness > 0) {
      final liquid = Path()
        ..addRect(Rect.fromLTRB(0, size.height * (0.95 - 0.75 * fullness),
          size.width, size.height));
      canvas.save();
      canvas.clipPath(glass);
      canvas.drawPath(liquid, Paint()..shader =
        const LinearGradient(colors: [
          Color(0xBBEDD085), Color(0xCCD1A552),
        ], begin: Alignment.topCenter, end: Alignment.bottomCenter)
          .createShader(Offset.zero & size));
      canvas.restore();
    }
    canvas.drawPath(glass, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFFDBF1E7));
    final rim = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.08),
      width: size.width * 0.74, height: 11);
    canvas.drawOval(rim, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFD5EFE7));
  }

  @override
  bool shouldRepaint(covariant GlassPainter oldDelegate) =>
    fullness != oldDelegate.fullness;
}

class WoodBackground extends StatelessWidget {
  const WoodBackground({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: WoodPainter(), child: const SizedBox.expand());
}

class WoodPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader =
      const LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Color(0xFF744728), Color(0xFF3B2419),
          Color(0xFF80502B), Color(0xFF2E1D16)])
          .createShader(Offset.zero & size));
    final random = math.Random(404);
    for (var n = 0; n < 36; n++) {
      final y = n * size.height / 36;
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
        Paint()..color = const Color(0x44301912)..strokeWidth = 2.2);
    }
    for (var n = 0; n < 320; n++) {
      final y = random.nextDouble() * size.height;
      final start = random.nextDouble() * size.width;
      final length = 20 + random.nextDouble() * 200;
      canvas.drawLine(Offset(start, y),
        Offset(math.min(size.width, start + length), y + 0.8),
        Paint()..color = const Color(0x2879AB89)..strokeWidth = 0.9);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader =
      RadialGradient(radius: 0.85,
        colors: [Colors.transparent, const Color(0xAA000000)])
          .createShader(Offset.zero & size));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
