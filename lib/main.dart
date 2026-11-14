import 'package:flutter/material.dart';
import 'game.dart';
import 'room.dart';

void main() => runApp(const FroccsApp());

class FroccsApp extends StatelessWidget {
  const FroccsApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fröccs – társasjáték',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFD18C), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF14302B),
      useMaterial3: true,
    ),
    home: const FroccsPage(),
  );
}

class FroccsPage extends StatefulWidget {
  const FroccsPage({super.key});
  @override
  State<FroccsPage> createState() => _FroccsPageState();
}

class _FroccsPageState extends State<FroccsPage> {
  final room = RoomSession();
  final name = TextEditingController(text: 'Játékos');
  final server = TextEditingController(
    text: const String.fromEnvironment('FROCCS_SERVER',
      defaultValue: 'wss://example.org'));
  final code = TextEditingController();
  final lanIp = TextEditingController();
  int botCount = 2;

  @override
  void initState() {
    super.initState();
    room.addListener(refresh);
  }

  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    room.removeListener(refresh);
    room.dispose();
    name.dispose(); server.dispose(); code.dispose(); lanIp.dispose();
    super.dispose();
  }

  void task(Future<void> Function() fn) {
    fn().catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(e.toString())));
    });
  }

  void act(Map<String, dynamic> command) => room.action(command);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: const Color(0xFF28534B),
      title: const Text('FRÖCCS', style: TextStyle(
        fontWeight: FontWeight.w900, letterSpacing: 3)),
      actions: [
        if (room.mode.isNotEmpty)
          IconButton(onPressed: () => task(room.leave),
            icon: const Icon(Icons.logout), tooltip: 'Kilépés'),
      ],
    ),
    body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 820),
      child: room.state != null ? gameScreen()
        : room.mode.isNotEmpty ? lobbyScreen() : homeScreen(),
    ))),
  );

  Widget homeScreen() => ListView(padding: const EdgeInsets.all(16), children: [
    const SizedBox(height: 16),
    const Icon(Icons.local_bar, size: 80, color: Color(0xFFFFD18C)),
    const Text('ÜDV A KOCSMÁBAN!', textAlign: TextAlign.center,
      style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    TextField(controller: name, maxLength: 24,
      decoration: const InputDecoration(labelText: 'Játékosneved',
        border: OutlineInputBorder())),
    section('Játék botok ellen', [
      Row(children: [
        const Text('Botok száma'),
        Expanded(child: Slider(min: 1, max: 5, divisions: 4,
          value: botCount.toDouble(),
          onChanged: (value) => setState(() => botCount = value.toInt()))),
        Text(botCount.toString()),
      ]),
      actionButton('Játék indítása', Icons.smart_toy,
        () => task(() => room.startBotGame(name.text, botCount))),
    ]),
    section('Helyi Wi-Fi játék', [
      const Text('Ugyanazon a Wi-Fi hálózaton szerver nélkül játszhattok.'),
      actionButton('Helyi szoba létrehozása', Icons.wifi_tethering,
        () => task(() => room.createLan(name.text))),
      TextField(controller: lanIp,
        decoration: const InputDecoration(labelText: 'Házigazda IP:port',
          hintText: '192.168.1.10:43992', border: OutlineInputBorder())),
      actionButton('Csatlakozás IP alapján', Icons.wifi,
        () => task(() => room.joinLan(name.text, lanIp.text))),
    ]),
    section('Online játék', [
      TextField(controller: server,
        decoration: const InputDecoration(labelText: 'WebSocket szerver',
          hintText: 'wss://szervered.hu', border: OutlineInputBorder())),
      actionButton('Online szoba létrehozása', Icons.public,
        () => task(() => room.createOnline(name.text, server.text))),
      TextField(controller: code,
        decoration: const InputDecoration(labelText: 'Szobakód',
          border: OutlineInputBorder())),
      actionButton('Csatlakozás szobakóddal', Icons.group_add,
        () => task(() => room.joinOnline(name.text, server.text, code.text))),
    ]),
    const Text('Fejlesztői prototípus. Az eredeti grafikai állományokat '
      'az engedélyezett forrásfájlok beillesztése után integráljuk.',
      textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
  ]);

  Widget lobbyScreen() => ListView(padding: const EdgeInsets.all(16), children: [
    const Icon(Icons.groups, size: 70),
    Text(room.mode == 'online' ? 'ONLINE SZOBA' : 'HELYI SZOBA',
      textAlign: TextAlign.center, style: const TextStyle(fontSize: 24)),
    SelectableText(room.mode == 'online' ? 'Szobakód: ' + room.code
      : 'Helyi cím: ' + room.address, textAlign: TextAlign.center),
    if (room.connecting) const LinearProgressIndicator(),
    if (room.error.isNotEmpty)
      Text(room.error, style: const TextStyle(color: Colors.orange)),
    section('Résztvevők: ' + room.members.length.toString() + '/6', [
      for (final member in room.members)
        ListTile(
          leading: Icon(member.bot ? Icons.smart_toy : Icons.person),
          title: Text(member.name),
          subtitle: member.id == room.myId ? const Text('Te') : null),
    ]),
    if (room.host) ...[
      actionButton('Bot hozzáadása', Icons.smart_toy, room.addBot),
      actionButton('Játék indítása', Icons.play_arrow, room.start),
    ] else const Text('A házigazda indítja a játékot.'),
  ]);

  Widget gameScreen() {
    final snapshot = room.state!;
    final players = (snapshot['players'] as List).cast<Map>();
    final mine = players.firstWhere((p) => p['id'] == room.myId,
      orElse: () => players.first);
    final myTurn = snapshot['turn'] == room.myId && snapshot['over'] != true;
    final pending = snapshot['pending'] as Map?;
    final choice = snapshot['drawChoice'] as List?;
    final active = myTurn && pending == null && choice == null;
    final playerTurn = players.firstWhere((p) => p['id'] == snapshot['turn']);
    final hand = (mine['hand'] as List).cast<String>();
    final cups = mine['cups'] as List;

    return ListView(padding: const EdgeInsets.all(12), children: [
      section('Asztal', [
        Text(snapshot['over'] == true ? 'ZÁRÓRA'
          : 'Most következik: ' + playerTurn['name'].toString(),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
        Text('Akciók: ' + snapshot['actions'].toString() +
          ' · Pakli: ' + snapshot['deckCount'].toString()),
        if (snapshot['playSlots'] != 0)
          Text('Még kijátszható kártyák: ' + snapshot['playSlots'].toString()),
        if (snapshot['finalTurns'] != -1)
          const Text('Utolsó körök!', style: TextStyle(color: Colors.orange)),
        Text(snapshot['message'].toString()),
        if (room.error.isNotEmpty)
          Text(room.error, style: const TextStyle(color: Colors.orange)),
      ]),
      section('Játékosok', [
        for (final player in players)
          Card(color: snapshot['turn'] == player['id']
              ? const Color(0xFF37675E) : null,
            child: Padding(padding: const EdgeInsets.all(8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(player['bot'] == true ? Icons.smart_toy : Icons.person, size: 18),
                const SizedBox(width: 6),
                Expanded(child: Text(player['name'].toString() +
                  ' · ' + player['hero'].toString())),
                Text(player['money'].toString() + ' Ft'),
              ]),
              Text(player['handCount'].toString() + ' lap a kézben',
                style: const TextStyle(fontSize: 12)),
              Wrap(spacing: 6, children: [
                for (final cup in (player['cups'] as List))
                  Chip(label: Text(cup['size'].toString() + ' dl · ' +
                    (cup['cards'] as List).length.toString() +
                    '/' + cup['size'].toString() + ' ' +
                    (cup['cards'] as List).map((e) => symbol(e.toString())).join(' '))),
              ]),
            ]))),
      ]),
      if (snapshot['over'] == true)
        actionButton('Új játék', Icons.home, () => task(room.leave))
      else if (pending != null)
        section('Támadás / alku', [
          Text('Támadás: ' + (cardNames[pending['card']] ?? 'Ismeretlen')),
          if (pending['target'] == room.myId && pending['phase'] == 'response') ...[
            actionButton('Ezt neked! védekezés', Icons.shield,
              () => act({'type': 'defend'})),
            actionButton('Támadás elfogadása', Icons.gavel,
              () => act({'type': 'takeHit'})),
            actionButton('10 Ft alku', Icons.handshake,
              () => act({'type': 'offer', 'amount': 10})),
            actionButton('20 Ft alku', Icons.handshake,
              () => act({'type': 'offer', 'amount': 20})),
          ] else if (pending['actor'] == room.myId && pending['phase'] == 'decision') ...[
            Text('Ajánlat: ' + pending['offer'].toString() + ' Ft'),
            actionButton('Elfogadom', Icons.check,
              () => act({'type': 'acceptOffer'})),
            actionButton('Elutasítom', Icons.close,
              () => act({'type': 'rejectOffer'})),
          ] else const Text('A másik játékos dönt.'),
        ])
      else if (choice != null)
        section('Válassz két kártyát!', [
          if (myTurn) for (var i = 0; i < choice.length; i++)
            actionButton((cardNames[choice[i]] ?? choice[i].toString()) + ' eldobása',
              Icons.delete_outline,
              () => act({'type': 'keepDraw', 'drop': i}))
          else const Text('Másik játékos választ.'),
        ])
      else ...[
        section('Pohárpiac', [
          Wrap(spacing: 8, children: [
            for (var i = 0; i < (snapshot['market'] as List).length; i++)
              OutlinedButton(
                onPressed: active && snapshot['playSlots'] == 0
                  ? () => act({'type': 'buy', 'indexes': [i]}) : null,
                child: Text(snapshot['market'][i].toString() + ' dl · 10 Ft')),
          ]),
          actionButton('Két első pohár megvétele (40 Ft)',
            Icons.add_shopping_cart, () => act({'type': 'buy', 'indexes': [0, 1]})),
        ]),
        section('Lapjaid', [
          Text('Pénzed: ' + mine['money'].toString() + ' Ft'),
          Wrap(spacing: 7, runSpacing: 7, children: [
            for (var i = 0; i < hand.length; i++)
              InkWell(
                onTap: active ? () => chooseCard(hand[i], i, mine, players) : null,
                child: Container(width: 105, height: 128,
                  decoration: BoxDecoration(
                    color: attackCards.contains(hand[i])
                      ? const Color(0xFF8F4649)
                      : const Color(0xFF46665D),
                    borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(symbol(hand[i]), style: const TextStyle(fontSize: 30)),
                      Text(cardNames[hand[i]] ?? hand[i],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]))),
          ]),
        ]),
        if (active) section('Akciók', [
          actionButton('Két kártya húzása', Icons.style,
            () => act({'type': 'draw'})),
          if (snapshot['actions'] == 2 && cups.any((c) => ready(c as Map)))
            actionButton('Kész fröccsök eladása', Icons.paid,
              () => act({'type': 'sell', 'indexes': [
                for (var i = 0; i < cups.length; i++)
                  if (ready(cups[i] as Map)) i,
              ]})),
          if (snapshot['playSlots'] != 0)
            actionButton('Kijátszás befejezése', Icons.check,
              () => act({'type': 'endPlay'})),
          actionButton('Kör befejezése', Icons.skip_next,
            () => act({'type': 'pass'})),
        ]),
      ],
    ]);
  }

  bool ready(Map cup) {
    final cards = (cup['cards'] as List).cast<String>();
    return cards.length == cup['size'] && cards.contains('soda') &&
      cards.any(wineCards.contains);
  }

  String symbol(String value) {
    if (value == 'soda') return '💧';
    if (value == 'muscat') return '🟡';
    if (value == 'barat') return '⚪';
    if (value == 'veltelini') return '🟢';
    return '🃏';
  }

  Future<void> chooseCard(String card, int index, Map me, List<Map> players) async {
    if (card == 'shield') return;
    if (attackCards.contains(card)) {
      final opponents = players.where((p) => p['id'] != room.myId).toList();
      final opponent = await showDialog<String>(context: context,
        builder: (ctx) => SimpleDialog(title: const Text('Célpont'),
          children: [
            for (final p in opponents)
              SimpleDialogOption(child: Text(p['name'].toString()),
                onPressed: () => Navigator.pop(ctx, p['id'] as String)),
          ]));
      if (!mounted || opponent == null) return;
      final victim = opponents.firstWhere((p) => p['id'] == opponent);
      int targetCup = -1;
      if (card != 'tip') {
        final choice = await chooseCup(victim['cups'] as List);
        if (!mounted || choice == null) return;
        targetCup = choice;
      }
      act({'type': 'play', 'cardIndex': index,
        'target': opponent, 'cup': targetCup});
    } else {
      final choice = await chooseCup(me['cups'] as List);
      if (!mounted || choice == null) return;
      act({'type': 'play', 'cardIndex': index, 'cup': choice});
    }
  }

  Future<int?> chooseCup(List cups) => showDialog<int>(context: context,
    builder: (ctx) => SimpleDialog(title: const Text('Válassz poharat'),
      children: [
        for (var i = 0; i < cups.length; i++)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, i),
            child: Text((i + 1).toString() + '. pohár · ' +
              cups[i]['size'].toString() + ' dl'),
          ),
      ]));

  Widget section(String title, List<Widget> contents) =>
    Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title, style: const TextStyle(fontSize: 18,
          fontWeight: FontWeight.bold, color: Color(0xFFFFD18C))),
        const SizedBox(height: 8),
        for (final item in contents) Padding(
          padding: const EdgeInsets.symmetric(vertical: 5), child: item),
      ])));

  Widget actionButton(String title, IconData icon, VoidCallback onPressed) =>
    FilledButton.icon(onPressed: onPressed, icon: Icon(icon),
      label: Text(title),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)));
}
