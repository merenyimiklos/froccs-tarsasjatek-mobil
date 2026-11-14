import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'landscape_board.dart';
import 'room.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const FroccsApp());
}

class FroccsApp extends StatelessWidget {
  const FroccsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Fröccs – társasjáték',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFFD28D),
        brightness: Brightness.dark,
        surface: const Color(0xFF174638)),
      scaffoldBackgroundColor: const Color(0xFF173C34),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xB0183833),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6E987E))),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFD28D), width: 2)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10),
      ),
    ),
    home: const FroccsScreen(),
  );
}

class FroccsScreen extends StatefulWidget {
  const FroccsScreen({super.key});

  @override
  State<FroccsScreen> createState() => _FroccsScreenState();
}

class _FroccsScreenState extends State<FroccsScreen> {
  final room = RoomSession();
  final playerName = TextEditingController(text: 'Játékos');
  final server = TextEditingController(text:
    const String.fromEnvironment('FROCCS_SERVER',
      defaultValue: 'wss://example.org'));
  final joinCode = TextEditingController();
  final hostAddress = TextEditingController();
  int selectedMode = 0;
  int botCount = 2;
  String lastError = '';

  @override
  void initState() {
    super.initState();
    room.addListener(_refresh);
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
    if (room.error.isNotEmpty && room.error != lastError) {
      lastError = room.error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lastError, maxLines: 2,
              overflow: TextOverflow.ellipsis),
            width: 410,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            showCloseIcon: true,
            backgroundColor: const Color(0xFF7A372B)));
      });
    }
    if (room.error.isEmpty) lastError = '';
  }

  @override
  void dispose() {
    room.removeListener(_refresh);
    room.dispose();
    playerName.dispose();
    server.dispose();
    joinCode.dispose();
    hostAddress.dispose();
    super.dispose();
  }

  void _task(Future<void> Function() action) {
    action().catchError((Object e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (room.state != null) {
      return Scaffold(
        body: SafeArea(
          child: LandscapeBoard(
            snapshot: room.state!,
            myId: room.myId,
            onAction: room.action,
            onLeave: () => _task(room.leave),
          ),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(child: LayoutBuilder(builder: (context, constraints) {
        return FittedBox(fit: BoxFit.contain, alignment: Alignment.center,
          child: SizedBox(width: 1180, height: 650,
            child: Stack(children: [
              const Positioned.fill(child: WoodBackground()),
              Positioned(top: 24, left: 35, right: 35,
                child: Row(children: [
                  const Icon(Icons.local_bar, size: 26,
                    color: Color(0xFFFFD28D)),
                  const SizedBox(width: 10),
                  const Text('FRÖCCS',
                    style: TextStyle(fontSize: 29, letterSpacing: 3,
                      color: Color(0xFFFFE0A1), fontWeight: FontWeight.w900)),
                  const Spacer(),
                  const Text('✦  A KOCSMA NYITVA  ✦',
                    style: TextStyle(fontSize: 13,
                      color: Color(0xFFFFDFB3), letterSpacing: 2)),
                  const Spacer(),
                  if (room.mode.isNotEmpty)
                    _miniButton('Vissza', Icons.close,
                      () => _task(room.leave)),
                ])),
              if (room.mode.isEmpty) _home()
              else _lobby(),
            ]),
          ));
      })),
    );
  }

  Widget _home() => Row(children: [
    SizedBox(width: 490, child: Padding(
      padding: const EdgeInsets.fromLTRB(42, 78, 10, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Image.asset('assets/original/logo.png', height: 75,
          errorBuilder: (context, error, stack) =>
            const Icon(Icons.wine_bar, size: 72,
              color: Color(0xFFFFD8A5))),
        const SizedBox(height: 10),
        const Text('KEVERJ. ALKUDJ.\nNYERJ!', style: TextStyle(
          fontSize: 36, height: 1.06, letterSpacing: 2,
          color: Color(0xFFFFE4AE), fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Colors.black87, blurRadius: 8,
            offset: Offset(3, 4))])),
        const SizedBox(height: 12),
        const Text('Egy kocsmaasztal. Hat barát. Rengeteg furfang.',
          style: TextStyle(color: Colors.white, fontSize: 17)),
        const SizedBox(height: 20),
        const Text('Fedezd fel Hajnóczy Soma játékának\n'
          'digitális változatát!', style: TextStyle(
          color: Color(0xFFD0E8D9), height: 1.6)),
        const SizedBox(height: 12),
        const Text('VÁLASSZ KETTŐ KOCSMAHŐS KÖZÜL',
          style: TextStyle(color: Color(0xFFFFD28D), fontSize: 14,
            fontWeight: FontWeight.w900, letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Row(children: [
          for (final hero in room.heroOptions) ...[
            Expanded(child: _heroOption(hero)),
            const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 7),
        Row(children: [
          Checkbox(value: room.houseRoseMode,
            activeColor: const Color(0xFFB98E51),
            onChanged: (value) => room.setHouseRoseMode(value ?? false)),
          const Expanded(child: Text('Házi szabály: vegyes borok engedélyezése',
            style: TextStyle(fontSize: 12, color: Colors.white70))),
        ]),
        const Spacer(),
        const Text('TESZTVERZIÓ  •  EREDETI GRAFIKÁK HAMAROSAN',
          style: TextStyle(color: Color(0xFFFFC67F), fontSize: 11,
            letterSpacing: 1)),
      ]),
    )),
    Expanded(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 78, 34, 20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: _panelDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('FOGLALJ ASZTALT!', style: TextStyle(
              color: Color(0xFFFFD99B), fontSize: 25,
              fontWeight: FontWeight.w900)),
            const SizedBox(height: 13),
            TextField(controller: playerName, maxLength: 24,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person),
                labelText: 'Játékosnév',
                counterText: '')),
            const SizedBox(height: 13),
            Row(children: [
              Expanded(child: _modeButton('BOTOK ELLEN', Icons.smart_toy, 0)),
              const SizedBox(width: 8),
              Expanded(child: _modeButton('HELYI WI-FI', Icons.wifi, 1)),
              const SizedBox(width: 8),
              Expanded(child: _modeButton('ONLINE', Icons.public, 2)),
            ]),
            const SizedBox(height: 13),
            Expanded(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _modeDetails(),
            )),
          ]),
      ),
    )),
  ]);

  Widget _heroOption(String hero) {
    final selected = room.selectedHero == hero;
    return Material(
      color: selected ? const Color(0xFF9C6D37) : const Color(0xFF1C5046),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(onTap: () => room.chooseHero(hero),
        borderRadius: BorderRadius.circular(11),
        child: Container(height: 47, padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            border: Border.all(color: selected
              ? const Color(0xFFFFE1A0) : const Color(0xFF56806E),
              width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(11)),
          child: Row(children: [
            Icon(selected ? Icons.verified : Icons.person_outline,
              color: const Color(0xFFFFE1A0), size: 19),
            const SizedBox(width: 5),
            Expanded(child: Text(hero, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12,
                fontWeight: FontWeight.bold))),
          ]),
        )),
    );
  }

  Widget _modeButton(String title, IconData icon, int mode) {
    final chosen = selectedMode == mode;
    return InkWell(onTap: () => setState(() => selectedMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(duration: const Duration(milliseconds: 200),
        height: 61, padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: chosen ? const Color(0xFFAC7A38) : const Color(0xFF1C5548),
          border: Border.all(color: chosen
            ? const Color(0xFFFFE7B6) : const Color(0xFF518C76))),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: const Color(0xFFFFE0A7), size: 23),
          Text(title, style: const TextStyle(fontSize: 11,
            fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        ])),
    );
  }

  Widget _modeDetails() {
    if (selectedMode == 0) {
      return Column(key: const ValueKey(0),
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Gyakorolj a kocsma törzsvendégei ellen!',
          style: TextStyle(fontSize: 17)),
        Row(children: [
          const Text('Botok száma'),
          Expanded(child: Slider(
            value: botCount.toDouble(), min: 1, max: 5, divisions: 4,
            label: botCount.toString(),
            onChanged: (value) => setState(() => botCount = value.round()))),
          Text(botCount.toString(), style: const TextStyle(
            fontSize: 19, color: Color(0xFFFFD28D))),
        ]),
        const Spacer(),
        _goldButton('PARTI INDÍTÁSA', Icons.play_arrow,
          () => _task(() => room.startBotGame(playerName.text, botCount))),
      ]);
    }
    if (selectedMode == 1) {
      return Column(key: const ValueKey(1),
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Ugyanarra a Wi-Fi hálózatra csatlakozzatok.',
            style: TextStyle(fontSize: 16)),
          const SizedBox(height: 10),
          _goldButton('HELYI SZOBA LÉTREHOZÁSA',
            Icons.wifi_tethering, () => _task(() =>
              room.createLan(playerName.text))),
          const SizedBox(height: 14),
          TextField(controller: hostAddress,
            decoration: const InputDecoration(
              labelText: 'Házigazda IP-címe',
              hintText: '192.168.1.10:43992')),
          const SizedBox(height: 10),
          _greenButton('CSATLAKOZÁS', Icons.login,
            () => _task(() => room.joinLan(
              playerName.text, hostAddress.text))),
        ]);
    }
    return Column(key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: server,
        decoration: const InputDecoration(
          labelText: 'Online szerver',
          hintText: 'wss://sajat-szerver.hu')),
      const SizedBox(height: 10),
      _goldButton('ONLINE SZOBA LÉTREHOZÁSA', Icons.add_circle,
        () => _task(() =>
          room.createOnline(playerName.text, server.text))),
      const SizedBox(height: 9),
      TextField(controller: joinCode,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Hatjegyű szobakód')),
      const SizedBox(height: 9),
      _greenButton('BELÉPÉS SZOBAKÓDDAL', Icons.login,
        () => _task(() => room.joinOnline(
          playerName.text, server.text, joinCode.text))),
    ]);
  }

  Widget _lobby() => Center(child: Container(
    width: 790, height: 514,
    margin: const EdgeInsets.only(top: 60),
    padding: const EdgeInsets.all(27),
    decoration: _panelDecoration(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
      const Text('ASZTALFOGLALÁS',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900,
          color: Color(0xFFFFDE9A), letterSpacing: 2)),
      const SizedBox(height: 7),
      SelectableText(room.mode == 'online'
        ? 'SZOBÁD KÓDJA: ' + (room.code.isEmpty ? 'KAPCSOLÓDÁS…' : room.code)
        : 'HELYI CÍM: ' + room.address,
        textAlign: TextAlign.center, style: const TextStyle(
          fontSize: 18, color: Color(0xFFBEE3CE))),
      if (room.connecting) const LinearProgressIndicator(),
      const SizedBox(height: 9),
      const Text('A TE KOCSMAHŐSÖD', style: TextStyle(
        fontWeight: FontWeight.w900, color: Color(0xFFFFD9A7))),
      const SizedBox(height: 6),
      Row(children: [
        for (final hero in room.heroOptions) ...[
          Expanded(child: _heroOption(hero)),
          const SizedBox(width: 10),
        ],
      ]),
      if (room.host) Row(children: [
        Checkbox(value: room.houseRoseMode,
          onChanged: (value) => room.setHouseRoseMode(value ?? false)),
        const Text('Házi szabály: vegyes borok'),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Text('JÁTÉKOSOK  ' + room.members.length.toString() + ' / 6',
          style: const TextStyle(color: Color(0xFFFFD49A),
            fontWeight: FontWeight.bold, fontSize: 17)),
        const Spacer(),
        if (room.host) _miniButton('BOT HOZZÁADÁSA',
          Icons.smart_toy, room.addBot),
      ]),
      const SizedBox(height: 9),
      Expanded(child: ListView(
        children: [
          for (final member in room.members)
            Card(color: const Color(0xFF225446),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFC18B50),
                  child: Icon(member.bot ? Icons.smart_toy : Icons.person,
                    color: const Color(0xFF143C33))),
                title: Text(member.name),
                trailing: member.id == room.myId
                  ? const Text('TE', style: TextStyle(
                    color: Color(0xFFFFD794))) : null,
              )),
        ])),
      if (room.host) _goldButton('KEZDŐDHET A JÁTÉK!',
        Icons.play_arrow, room.start)
      else const Padding(padding: EdgeInsets.all(14),
        child: Text('A házigazda indítja a partit…',
          textAlign: TextAlign.center)),
      if (room.error.isNotEmpty)
        Text(room.error, style: const TextStyle(color: Color(0xFFFF9988))),
    ])),
  );

  BoxDecoration _panelDecoration() => BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    gradient: const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xF21A5042), Color(0xFB0C302C)]),
    border: Border.all(color: const Color(0xFFC49A57), width: 2),
    boxShadow: const [
      BoxShadow(color: Color(0xAA000000), blurRadius: 22,
        offset: Offset(4, 8)),
    ],
  );

  Widget _goldButton(String label, IconData icon, VoidCallback onPressed) =>
    _button(label, icon, onPressed, const Color(0xFFB3833C));

  Widget _greenButton(String label, IconData icon, VoidCallback onPressed) =>
    _button(label, icon, onPressed, const Color(0xFF286D5A));

  Widget _button(String label, IconData icon, VoidCallback onPressed, Color color) =>
    Material(color: color, borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onPressed, borderRadius: BorderRadius.circular(13),
        child: Container(height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFFDC9F))),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: const Color(0xFFFFE6B7)),
            const SizedBox(width: 9),
            Text(label, style: const TextStyle(
              fontWeight: FontWeight.w900, letterSpacing: 0.7)),
          ]))));

  Widget _miniButton(String label, IconData icon, VoidCallback onPressed) =>
    OutlinedButton.icon(onPressed: onPressed,
      icon: Icon(icon, color: const Color(0xFFFFD89B)),
      label: Text(label, style: const TextStyle(
        color: Color(0xFFFFD89B))));
}
