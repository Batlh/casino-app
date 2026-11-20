import 'dart:math';

import '../debug_log.dart';
import 'lan.dart';
import 'lan_table.dart';

/// Zweierspiele im lokalen Netz (Brettspiele): Jedes Gerät führt seine eigene Partie, ausgetauscht werden
/// nur die Züge. Die Spiele kennen keinen Zufall, darum bleiben beide Partien gleich.
///
/// Ablauf: Der Gastgeber wartet auf einen Gegner, wählt seine Seite und startet. Beide bekommen
/// {'t': 'start', 'names', 'seat'}. Jeder Zug geht als {'t': 'move', 'n', 'm'} an die andere Seite;
/// fehlt ein Zug oder passt einer nicht, schickt der Gastgeber die ganze Zugliste ('moves').
class NetDuelLink {
  NetDuelLink.host(this.host, {Random? rng})
      : guest = null,
        _rng = rng ?? Random();
  NetDuelLink.guest(this.guest)
      : host = null,
        _rng = Random();

  final NetTableHost? host;
  final NetTableGuest? guest;
  final Random _rng;

  /// Neues Spiel: Namen je Platz, dein Platz und Einstellungen des Spiels (z. B. Variante).
  void Function(List<String> names, int seat, Map<String, Object?> options)? onStart;

  /// Zug der anderen Seite; false, wenn er nicht passt.
  bool Function(Object? move)? onMove;

  /// Schnellnachricht der anderen Seite (Nummer aus quickMessages).
  void Function(Object? index)? onChat;

  /// Gegner ist gegangen oder Gastgeber hat geschlossen.
  void Function()? onGone;

  final List<Object?> moves = [];
  List<String> names = const [];
  Map<String, Object?> options = const {};
  int seat = -1;
  NetSeat? _opponent;
  bool get playing => seat >= 0;
  NetSeat? get opponent => _opponent ?? (host?.seats.values.firstOrNull);

  void attach() {
    final h = host;
    if (h != null) {
      h.onMove = (s, m) {
        if (s != _opponent) return;
        _receive(m);
      };
      h.onLeave = (s) {
        if (s == _opponent) {
          _opponent = null;
          onGone?.call();
        }
      };
    }
    final g = guest;
    if (g != null) g.onMessage = _receive;
  }

  void _send(LanMessage m) {
    final h = host;
    if (h != null) {
      final o = _opponent;
      if (o != null) h.send(o, m);
      return;
    }
    guest?.send(m);
  }

  /// Gastgeber: Spiel starten. side 0 = du beginnst, 1 = Gegner beginnt, sonst zufällig.
  bool start(String hostName, int side, {Map<String, Object?> options = const {}}) {
    final o = opponent;
    if (host == null || o == null) return false;
    _opponent = o;
    final mine = side == 0 || side == 1 ? side : _rng.nextInt(2);
    names = mine == 0 ? [hostName, o.name] : [o.name, hostName];
    seat = mine;
    this.options = options;
    moves.clear();
    debugLog.info('netz', 'Zweierspiel: ${names[0]} gegen ${names[1]}');
    _send({'t': 'start', 'names': names, 'seat': 1 - mine, 'opt': options});
    onStart?.call(names, seat, options);
    return true;
  }

  /// Schnellnachricht an die andere Seite.
  void sendChat(int index) => _send({'t': 'chat', 'm': index});

  /// Eigenen Zug verschicken (nachdem er hier ausgeführt wurde).
  void sendMove(Object? m) {
    if (!playing) return;
    moves.add(m);
    _send({'t': 'move', 'n': moves.length, 'm': m});
  }

  void _resync() {
    if (host != null) {
      _send({'t': 'moves', 'names': names, 'seat': 1 - seat, 'opt': options, 'list': moves});
    } else {
      _send({'t': 'sync'});
    }
  }

  void _receive(LanMessage m) {
    switch (m['t']) {
      case 'start' || 'moves':
        names = [for (final n in m['names'] as List) '$n'];
        seat = (m['seat'] as num).toInt();
        options = ((m['opt'] as Map?) ?? const {}).cast<String, Object?>();
        moves.clear();
        onStart?.call(names, seat, options);
        if (m['t'] == 'start') return;
        for (final mv in m['list'] as List) {
          moves.add(mv);
          if (onMove?.call(mv) != true) {
            debugLog.warn('netz', 'Zugliste passt nicht');
            break;
          }
        }
      case 'chat':
        onChat?.call(m['m']);
      case 'sync':
        if (host != null) _resync();
      case 'move':
        if (!playing) return;
        final n = (m['n'] as num).toInt();
        if (n <= moves.length) return;
        if (n != moves.length + 1) {
          _resync();
          return;
        }
        final mv = m['m'];
        if (onMove?.call(mv) == true) {
          moves.add(mv);
        } else {
          debugLog.warn('netz', 'Zug passt nicht: $mv');
          _resync();
        }
    }
  }

  Future<void> close() async {
    await host?.close();
    await guest?.close();
  }
}
