import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'game.dart';

/// Realtime communication. Online requires deploying server/index.js.
/// LAN is direct WebSocket over the local Wi-Fi, without cloud infrastructure.
/// The host device owns the deck and game state; peers receive private views.
class RoomSession extends ChangeNotifier {
  String myId = _id();
  String myName = 'Játékos';
  String mode = '';
  String code = '';
  String address = '';
  String error = '';
  bool host = false;
  bool connecting = false;
  List<Seat> members = [];
  Map<String, dynamic>? state;
  Game? game;
  WebSocket? _socket;
  HttpServer? _lanServer;
  final Map<String, WebSocket> _peers = {};
  static const int port = 43992;

  static String _id() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<void> startBotGame(String name, int bots) async {
    await leave();
    mode = 'bot';
    host = true;
    myName = name.trim().isEmpty ? 'Játékos' : name.trim();
    members = [
      Seat(myId, myName),
      for (var i = 1; i <= bots.clamp(1, 5); i++)
        Seat('bot-$i', 'Bot $i', bot: true),
    ];
    _start();
  }

  Future<void> createLan(String name) async {
    await leave();
    mode = 'lan';
    host = true;
    myName = name.trim().isEmpty ? 'Játékos' : name.trim();
    members = [Seat(myId, myName)];
    try {
      _lanServer = await HttpServer.bind(InternetAddress.anyIPv4, port);
      address = (await _localIp()) + ':$port';
      _lanServer!.listen((request) async {
        try {
          final ws = await WebSocketTransformer.upgrade(request);
          String peerId = '';
          ws.listen((raw) {
            try {
              final msg = Map<String, dynamic>.from(jsonDecode(raw as String));
              if (msg['type'] == 'join') {
                if (game != null || members.length >= 6) {
                  ws.add(jsonEncode({'type': 'error', 'message': 'A szoba megtelt vagy elindult.'}));
                  ws.close();
                  return;
                }
                final id = (msg['id'] ?? '').toString();
                final name = (msg['name'] ?? 'Játékos').toString().trim();
                if (id.isEmpty || members.any((e) => e.id == id)) {
                  ws.close();
                  return;
                }
                peerId = id;
                members.add(Seat(id, name.isEmpty ? 'Játékos' : name));
                _peers[id] = ws;
                _notifyMembers();
              } else if (msg['type'] == 'action' && peerId.isNotEmpty) {
                _hostAction(peerId, Map<String, dynamic>.from(msg['command'] as Map));
              }
            } catch (e) {
              error = 'Hálózati üzenet hibás: $e';
              notifyListeners();
            }
          }, onDone: () {
            if (peerId.isNotEmpty) {
              _peers.remove(peerId);
              if (game == null) members.removeWhere((e) => e.id == peerId);
              _notifyMembers();
            }
          });
        } catch (_) {}
      });
      _notifyMembers();
    } catch (e) {
      error = 'Helyi szoba nem indítható: $e';
      notifyListeners();
    }
  }

  Future<String> _localIp() async {
    final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, includeLoopback: false);
    final ips = interfaces.expand((e) => e.addresses).map((e) => e.address).toList();
    if (ips.isEmpty) return '127.0.0.1';
    return ips.firstWhere((e) => e.startsWith('192.168.') || e.startsWith('10.'),
        orElse: () => ips.first);
  }

  Future<void> joinLan(String name, String ip) async {
    await leave();
    mode = 'lan';
    host = false;
    myName = name.trim().isEmpty ? 'Játékos' : name.trim();
    connecting = true;
    notifyListeners();
    try {
      var destination = ip.trim();
      if (!destination.contains(':')) destination += ':$port';
      destination = destination.replaceFirst('ws://', '');
      _socket = await WebSocket.connect('ws://$destination');
      _listenClient();
      _send({'type': 'join', 'id': myId, 'name': myName});
      address = destination;
    } catch (e) {
      error = 'Csatlakozási hiba: $e';
    }
    connecting = false;
    notifyListeners();
  }

  Future<void> createOnline(String name, String server) async {
    await _connectOnline(name, server, null);
  }

  Future<void> joinOnline(String name, String server, String roomCode) async {
    await _connectOnline(name, server, roomCode.trim().toUpperCase());
  }

  Future<void> _connectOnline(String name, String server, String? room) async {
    await leave();
    mode = 'online';
    host = room == null;
    myName = name.trim().isEmpty ? 'Játékos' : name.trim();
    address = server.trim();
    connecting = true;
    notifyListeners();
    try {
      final uri = Uri.parse(address);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw FormatException('A szerver címe ws:// vagy wss:// kezdetű legyen.');
      }
      _socket = await WebSocket.connect(address);
      _listenClient();
      _send({
        'type': room == null ? 'create' : 'join',
        'name': myName, 'id': myId,
        if (room != null) 'code': room,
      });
    } catch (e) {
      error = 'Online kapcsolat sikertelen: $e';
    }
    connecting = false;
    notifyListeners();
  }

  void _listenClient() {
    _socket!.listen((raw) {
      try {
        final msg = Map<String, dynamic>.from(jsonDecode(raw as String));
        switch (msg['type']) {
          case 'created':
            code = (msg['code'] ?? '').toString();
            break;
          case 'members':
            code = (msg['code'] ?? code).toString();
            members = [
              for (final item in (msg['members'] as List))
                Seat((item['id'] as String), (item['name'] as String),
                    bot: item['bot'] == true),
            ];
            break;
          case 'snapshot':
            state = Map<String, dynamic>.from(msg['game'] as Map);
            break;
          case 'peerAction':
            if (host && game != null) {
              _hostAction((msg['from'] ?? '').toString(),
                  Map<String, dynamic>.from(msg['command'] as Map));
            }
            break;
          case 'error':
            error = (msg['message'] ?? 'Ismeretlen hiba').toString();
            break;
          case 'closed':
            error = 'A házigazda megszakította a kapcsolatot.';
            break;
        }
        notifyListeners();
      } catch (e) {
        error = 'Üzenetfeldolgozási hiba: $e';
        notifyListeners();
      }
    }, onDone: () {
      if (mode != '') {
        error = 'A kapcsolat megszakadt.';
        notifyListeners();
      }
    }, onError: (Object e) {
      error = 'Kapcsolati hiba: $e';
      notifyListeners();
    });
  }

  void _notifyMembers() {
    final msg = jsonEncode({
      'type': 'members', 'code': address,
      'members': [
        for (final s in members) {'id': s.id, 'name': s.name, 'bot': s.bot},
      ],
    });
    for (final ws in _peers.values) { ws.add(msg); }
    notifyListeners();
  }

  void addBot() {
    if (!host || game != null || members.length >= 6) return;
    final i = members.where((e) => e.bot).length + 1;
    members.add(Seat('bot-$i', 'Bot $i', bot: true));
    if (mode == 'online') {
      _send({'type': 'addBot', 'id': 'bot-$i', 'name': 'Bot $i'});
    } else {
      _notifyMembers();
    }
    notifyListeners();
  }

  void start() {
    if (!host || game != null || members.length < 2) return;
    _start();
  }

  void _start() {
    game = Game(members);
    game!.runBots();
    if (mode == 'online') _send({'type': 'started'});
    _sync();
  }

  void action(Map<String, dynamic> command) {
    if (host) {
      _hostAction(myId, command);
    } else {
      _send({'type': 'action', 'command': command});
    }
  }

  void _hostAction(String id, Map<String, dynamic> command) {
    if (game == null) return;
    final result = game!.apply(id, command);
    if (result != null) {
      if (id == myId) {
        error = result;
        notifyListeners();
      } else if (mode == 'online') {
        _send({'type': 'peerError', 'to': id, 'message': result});
      } else {
        _peers[id]?.add(jsonEncode({'type': 'error', 'message': result}));
      }
      return;
    }
    game!.runBots();
    _sync();
  }

  void _sync() {
    if (game == null) return;
    state = game!.viewFor(myId);
    for (final seat in members) {
      if (seat.bot || seat.id == myId) continue;
      final packet = {
        'type': 'snapshot', 'to': seat.id,
        'game': game!.viewFor(seat.id),
      };
      if (mode == 'online') {
        _send(packet);
      } else {
        _peers[seat.id]?.add(jsonEncode(packet));
      }
    }
    notifyListeners();
  }

  void _send(Map<String, dynamic> message) {
    try { _socket?.add(jsonEncode(message)); } catch (e) {
      error = 'Küldési hiba: $e';
      notifyListeners();
    }
  }

  Future<void> leave() async {
    final previous = mode;
    mode = '';
    if (previous == 'online' || (previous == 'lan' && !host)) {
      await _socket?.close();
    }
    _socket = null;
    for (final socket in _peers.values) {
      await socket.close();
    }
    _peers.clear();
    await _lanServer?.close(force: true);
    _lanServer = null;
    state = null;
    game = null;
    members = [];
    code = '';
    address = '';
    error = '';
    host = false;
    connecting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // dispose cannot await; close synchronously initiated futures.
    unawaited(leave());
    super.dispose();
  }
}
