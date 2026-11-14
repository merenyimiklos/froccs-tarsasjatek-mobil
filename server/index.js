/**
 * Fröccs multiplayer relay.
 * Deploy behind TLS/WSS. No card deck or private hands are stored here:
 * the room host owns game state and sends a per-player private snapshot.
 * Prototype only: a host can cheat; production needs authoritative server logic.
 */
const { WebSocketServer, WebSocket } = require('ws');
const { randomBytes } = require('node:crypto');

const PORT = Number(process.env.PORT || 8080);
const wss = new WebSocketServer({ port: PORT, maxPayload: 16384 });
const rooms = new Map();
const clients = new WeakMap();
const MAX_PLAYERS = 6;
const MAX_ROOMS = Number(process.env.MAX_ROOMS || 1000);
const heroes = new Set([
  'Mélyivó Fred', 'Löttyintős', 'Küv Évi', 'Pohárnok',
  'Recycle Béla', 'Sarki Jézus', 'Sommelier Pityu', 'Vízköpő Karesz',
  'Böske, a Rettentő', 'Hollósi elvtárs', 'Buzgómócsing', 'Icuka',
]);
function safeHero(value) { return heroes.has(value) ? value : null; }

function send(ws, packet) {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(packet));
}
function cleanName(name) {
  return String(name || 'Játékos').trim().slice(0, 24) || 'Játékos';
}
function roomCode() {
  let value;
  do { value = randomBytes(5).toString('hex').slice(0, 6).toUpperCase(); }
  while (rooms.has(value));
  return value;
}
function roomOf(ws) {
  const context = clients.get(ws);
  return context ? rooms.get(context.code) : null;
}
function broadcastMembers(room) {
  const payload = { type: 'members', code: room.code, members: room.members };
  for (const peer of room.peers.values()) send(peer, payload);
}
function error(ws, message) { send(ws, { type: 'error', message }); }

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', () => { ws.isAlive = true; });

  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(data.toString()); }
    catch { return error(ws, 'Hibás JSON.'); }
    if (!msg || typeof msg !== 'object') return;

    if (msg.type === 'create') {
      if (clients.has(ws)) return error(ws, 'Már tag vagy.');
      if (rooms.size >= MAX_ROOMS) return error(ws, 'A szerver megtelt.');
      const id = String(msg.id || '').slice(0, 64);
      if (!/^[a-zA-Z0-9-]{5,64}$/.test(id)) return error(ws, 'Érvénytelen azonosító.');
      const code = roomCode();
      const room = {
        code, hostId: id, members: [{ id, name: cleanName(msg.name), bot: false,
          hero: safeHero(msg.hero) }],
        peers: new Map([[id, ws]]), started: false, createdAt: Date.now(),
      };
      rooms.set(code, room);
      clients.set(ws, { code, id });
      send(ws, { type: 'created', code });
      broadcastMembers(room);
      return;
    }
    if (msg.type === 'join') {
      if (clients.has(ws)) return error(ws, 'Már tag vagy.');
      const code = String(msg.code || '').toUpperCase().trim();
      const room = rooms.get(code);
      if (!room) return error(ws, 'Nincs ilyen szoba.');
      if (room.started) return error(ws, 'A játék már elkezdődött.');
      if (room.members.length >= MAX_PLAYERS) return error(ws, 'A szoba megtelt.');
      const id = String(msg.id || '').slice(0, 64);
      if (!/^[a-zA-Z0-9-]{5,64}$/.test(id) ||
          room.members.some((member) => member.id === id)) {
        return error(ws, 'Azonosító már foglalt vagy hibás.');
      }
      room.members.push({ id, name: cleanName(msg.name),
        bot: false, hero: safeHero(msg.hero) });
      room.peers.set(id, ws);
      clients.set(ws, { code, id });
      broadcastMembers(room);
      return;
    }

    const connection = clients.get(ws);
    const room = roomOf(ws);
    if (!room || !connection) return error(ws, 'Előbb csatlakozz.');
    const { id } = connection;
    if (msg.type === 'pickHero') {
      if (room.started) return error(ws, 'A játszma már elkezdődött.');
      const hero = safeHero(msg.hero);
      if (hero === null) return error(ws, 'Ismeretlen kocsmahős.');
      const member = room.members.find((m) => m.id === id);
      if (!member || member.bot) return error(ws, 'Nem választhatsz karaktert.');
      member.hero = hero;
      broadcastMembers(room);
    } else if (msg.type === 'addBot') {
      if (id !== room.hostId || room.started) return error(ws, 'Nem engedélyezett.');
      if (room.members.length >= MAX_PLAYERS) return error(ws, 'Megtelt a szoba.');
      const botId = String(msg.id || '').slice(0, 64);
      if (!/^bot-[0-9]+$/.test(botId) ||
          room.members.some((member) => member.id === botId)) {
        return error(ws, 'A bot már létezik.');
      }
      room.members.push({ id: botId, name: cleanName(msg.name), bot: true });
      broadcastMembers(room);
    } else if (msg.type === 'started') {
      if (id !== room.hostId || room.members.length < 2) {
        return error(ws, 'Nem lehet elindítani.');
      }
      room.started = true;
      for (const [peerId, peer] of room.peers) {
        if (peerId !== id) send(peer, { type: 'started' });
      }
    } else if (msg.type === 'action') {
      if (!room.started || id === room.hostId) return error(ws, 'A játék nem fut.');
      if (!msg.command || typeof msg.command !== 'object' || Array.isArray(msg.command)) {
        return error(ws, 'Hibás parancs.');
      }
      send(room.peers.get(room.hostId), {
        type: 'peerAction', from: id, command: msg.command,
      });
    } else if (msg.type === 'snapshot') {
      if (id !== room.hostId || !room.started) return error(ws, 'Csak a gazda küldhet állapotot.');
      const target = String(msg.to || '');
      if (!room.peers.has(target)) return;
      if (!msg.game || typeof msg.game !== 'object') return;
      send(room.peers.get(target), { type: 'snapshot', game: msg.game });
    } else if (msg.type === 'peerError') {
      if (id !== room.hostId) return;
      send(room.peers.get(String(msg.to || '')), {
        type: 'error', message: String(msg.message || 'Hiba').slice(0, 300),
      });
    }
  });

  ws.on('close', () => {
    const connection = clients.get(ws);
    if (!connection) return;
    clients.delete(ws);
    const room = rooms.get(connection.code);
    if (!room) return;
    room.peers.delete(connection.id);
    if (room.hostId === connection.id) {
      for (const peer of room.peers.values()) {
        send(peer, { type: 'closed' });
        peer.close();
      }
      rooms.delete(room.code);
      return;
    }
    if (!room.started) room.members = room.members.filter((member) => member.id !== connection.id);
    broadcastMembers(room);
  });
});

const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
  for (const [code, room] of rooms) {
    if (Date.now() - room.createdAt > 24 * 60 * 60 * 1000) {
      for (const peer of room.peers.values()) peer.close();
      rooms.delete(code);
    }
  }
}, 30000);
heartbeat.unref();
console.log('Fröccs relay listening on port ' + PORT);
