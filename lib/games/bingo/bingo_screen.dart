import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/debug_log.dart';
import '../../core/scope.dart';
import '../../core/sfx.dart';
import '../../core/theme.dart';
import '../../core/wallet.dart';
import '../../ui/guide.dart';
import '../../ui/widgets.dart';
import '../../core/net/lan.dart';
import 'bingo_engine.dart';
import 'bingo_net.dart';

const bingoGuide = GameGuide('Bingo', [
  GuideSection(
    'Ablauf',
    'Kauf eine bis vier Karten. Die Kugeln werden nacheinander gezogen; jede Zahl, die auf deiner Karte steht, wird markiert. '
        'Wer zuerst das Gewinnmuster voll hat, gewinnt den Pot. Haben mehrere es mit derselben Kugel, wird geteilt. '
        'Die Mitspieler kaufen ebenfalls Karten; 85 % aller Kartenpreise gehen in den Pot.',
  ),
  GuideSection(
    '75 Kugeln (USA)',
    'Karte 5 × 5, die Spalten stehen für B (1–15), I (16–30), N (31–45), G (46–60) und O (61–75). Die Mitte ist frei. '
        'Vor dem Spiel wählst du das Muster: Linie (Reihe, Spalte oder Diagonale), Vier Ecken, Großes X oder Volle Karte.',
  ),
  GuideSection(
    '90 Kugeln (UK)',
    'Karte 3 × 9 mit 15 Zahlen, jede Reihe hat fünf. Gespielt wird in drei Stufen: zuerst eine volle Reihe (15 % des Pots), '
        'dann zwei volle Reihen (25 %), dann die volle Karte (60 %).',
  ),
  GuideSection(
    'Im lokalen Netzwerk',
    'Ein Gerät tippt auf „Tisch eröffnen“ und legt Spielart, Preis, Tempo und Computer-Mitspieler fest. Die anderen tippen auf '
        '„Tisch beitreten“; offene Tische im selben WLAN erscheinen von selbst, sonst die angezeigte Adresse von Hand eingeben. '
        'Der Gastgeber zieht die Kugeln und prüft jedes Bingo, jeder zahlt seine Karten aus dem eigenen Münzkonto und bekommt '
        'seine Gewinne dorthin. Im Netzwerk wird immer automatisch markiert.',
  ),
  GuideSection(
    'Selbst markieren',
    'Mit „Automatisch markieren“ aus tippst du die gezogenen Zahlen selbst an und rufst „Bingo!“. Das muss vor der nächsten '
        'Kugel passieren, sonst verfällt dein Anteil.',
  ),
]);

const _botNames = ['Helga', 'Otto', 'Bärbel', 'Klaus', 'Rosi', 'Horst', 'Inge', 'Dieter', 'Gisela', 'Manni', 'Uschi', 'Erwin'];

class BingoScreen extends StatefulWidget {
  const BingoScreen({super.key, this.seed});
  final int? seed;

  @override
  State<BingoScreen> createState() => _BingoScreenState();
}

enum _Mode { setup, hostLobby, browse, guest, play }

class _BingoScreenState extends State<BingoScreen> {
  late final math.Random _rng = widget.seed == null ? math.Random.secure() : math.Random(widget.seed);
  late final Wallet _wallet = AppScope.of(context).wallet;

  BingoVariant _variant = BingoVariant.us75;
  BingoPattern _pattern = BingoPattern.line;
  int _cards = 2;
  int _bots = 5;
  int _price = 50;
  bool _autoDaub = true;
  int _speedMs = 1500;
  String _name = '';

  _Mode _mode = _Mode.setup;
  BingoGame? _game;
  BingoPlayer? _me;
  Timer? _timer;
  bool _paused = false;
  final Set<int> _marked = {};

  /// Selbst markieren: eigene Gewinne, die noch per „Bingo!“ gerufen werden müssen.
  List<BingoWin> _pending = [];
  final List<String> _log = [];
  int _earned = 0;
  String _message = '';

  // Netzwerk
  BingoHost? _host;
  BingoGuest? _guest;
  LanBrowser? _browser;
  List<LanTable> _tables = [];
  List<String> _addresses = [];
  final _manualAddress = TextEditingController();
  StreamSubscription<Object?>? _sub;

  AppScope get _app => AppScope.of(context);
  bool get _net => _host != null || _guest != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _wallet;
    if (_name.isEmpty) {
      _name = '${AppScope.of(context).settings.loadGame('bingo')?['name'] ?? ''}';
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _host?.close();
    _guest?.close();
    _browser?.close();
    _manualAddress.dispose();
    super.dispose();
  }

  void _saveName(String v) {
    _name = v;
    AppScope.of(context).settings.saveGame('bingo', {'name': v});
  }

  String get _displayName => _name.trim().isEmpty ? 'Spieler' : _name.trim();

  // ---------------------------------------------------------------- Allein und als Gastgeber

  List<String> _botNamesShuffled() => [..._botNames]..shuffle(_rng);

  void _startSolo() {
    final cost = _cards * _price;
    if (!_wallet.spend(cost)) return;
    final names = _botNamesShuffled();
    final me = BingoPlayer('Du', human: true)..cards.addAll(BingoGame.dealCards(_variant, _cards, _rng));
    final players = [
      me,
      for (var i = 0; i < _bots; i++) BingoPlayer(names[i])..cards.addAll(BingoGame.dealCards(_variant, 1 + _rng.nextInt(3), _rng)),
    ];
    _begin(BingoGame(variant: _variant, players: players, cardPrice: _price, pattern: _pattern, rng: _rng), me);
  }

  void _begin(BingoGame g, BingoPlayer me) {
    setState(() {
      _mode = _Mode.play;
      _game = g;
      _me = me;
      _marked.clear();
      _pending = [];
      _log.clear();
      _earned = 0;
      _paused = false;
      _message = 'Pot ${formatCoins(g.pot)} · los geht’s';
    });
    debugLog.info('bingo', '${_variant == BingoVariant.us75 ? '75' : '90'} Kugeln, ${me.cards.length} Karten à $_price, ${g.players.length} Spieler, Pot ${g.pot}${_net ? ' (Netzwerk)' : ''}');
    _host?.publish(g, const [], _log);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _speedMs), (_) => _call());
  }

  Future<void> _openTable() async {
    final host = BingoHost(hostName: _displayName, variant: _variant, pattern: _pattern, cardPrice: _price, bots: _bots, rng: _rng);
    try {
      await host.open();
    } catch (e) {
      debugLog.warn('netz', 'Tisch eröffnen: $e');
      setState(() => _message = 'Tisch konnte nicht eröffnet werden');
      await host.close();
      return;
    }
    _addresses = await localAddresses();
    _sub = host.changed.listen((_) {
      if (mounted) setState(() {});
    });
    setState(() {
      _host = host;
      _autoDaub = true;
      _mode = _Mode.hostLobby;
    });
  }

  void _hostStartRound() {
    final host = _host!;
    final cost = _cards * _price;
    if (!_wallet.spend(cost)) return;
    final (g, me) = host.startRound(_cards, _botNamesShuffled());
    _begin(g, me);
  }

  void _call() {
    final g = _game;
    if (g == null || _paused) return;
    if (g.over) {
      _timer?.cancel();
      return;
    }
    if (_pending.isNotEmpty) {
      _log.add('Nicht „Bingo!“ gerufen – Anteil verfallen');
      _pending = [];
    }
    final wins = g.callNext();
    _app.sfx.play(Sound.tick);
    final ball = g.called.last;
    if (_autoDaub && _me!.cards.any((c) => c.numbers.contains(ball))) _marked.add(ball);
    for (final w in wins) {
      if (w.player == _me && !_autoDaub) {
        _pending.add(w);
        continue;
      }
      _pay(w);
    }
    _host?.publish(g, wins, _log);
    setState(() {
      _message = wins.isEmpty
          ? ''
          : wins.any((w) => w.player == _me)
              ? (_autoDaub ? 'BINGO! ${g.stageName(wins.first.stage)}' : 'Du hast es! Schnell „Bingo!“ rufen')
              : 'Bingo bei ${wins.map((w) => w.player.name).toSet().join(' und ')}: ${g.stageName(wins.first.stage)}';
    });
    if (wins.isNotEmpty) _app.sfx.play(wins.any((w) => w.player == _me) ? Sound.bigWin : Sound.lose);
    if (g.over) {
      _timer?.cancel();
      if (_pending.isEmpty) _finish();
    }
  }

  void _pay(BingoWin w) {
    final g = _game!;
    _log.add('${g.stageName(w.stage)}: ${w.player.name} ${formatCoins(w.amount)}');
    if (w.player == _me) {
      _wallet.credit(w.amount);
      _earned += w.amount;
    }
  }

  void _claim() {
    if (_pending.isEmpty) {
      setState(() => _message = 'Noch kein Bingo');
      return;
    }
    for (final w in _pending) {
      _pay(w);
    }
    _pending = [];
    _app.sfx.play(Sound.bigWin);
    setState(() => _message = 'BINGO!');
    if (_game!.over) _finish();
  }

  void _finish() {
    debugLog.info('bingo', 'Ende nach ${_game!.called.length} Kugeln, du: +$_earned · ${_log.join('; ')}');
    _wallet.refillIfBroke();
    final g = _game!;
    _host?.publish(g, const [], _log);
    setState(() {});
  }

  /// Zurück zur Auswahl; als Gastgeber zurück in den Warteraum.
  void _back() {
    _timer?.cancel();
    setState(() {
      _game = null;
      _message = '';
      _mode = _host != null ? _Mode.hostLobby : _Mode.setup;
    });
  }

  Future<void> _closeNet() async {
    _timer?.cancel();
    await _sub?.cancel();
    _sub = null;
    await _host?.close();
    await _guest?.close();
    await _browser?.close();
    if (!mounted) return;
    setState(() {
      _host = null;
      _guest = null;
      _browser = null;
      _game = null;
      _mode = _Mode.setup;
      _message = '';
    });
  }

  // ---------------------------------------------------------------- Als Mitspieler

  Future<void> _browse() async {
    final b = LanBrowser('bingo');
    await b.start();
    _sub = b.tables.listen((t) {
      if (mounted) setState(() => _tables = t);
    });
    setState(() {
      _browser = b;
      _tables = b.current;
      _mode = _Mode.browse;
    });
  }

  Future<void> _join(String address, int port) async {
    if (!_wallet.canAfford(_cards)) return;
    final guest = BingoGuest(_displayName, _cards);
    guest.onStart = (cost) {
      if (!_wallet.spend(cost)) return false;
      _earned = 0;
      _log.clear();
      return true;
    };
    guest.onPay = (amount, text) {
      _wallet.credit(amount);
      _earned += amount;
      _app.sfx.play(Sound.bigWin);
      if (mounted) setState(() => _message = 'BINGO! $text');
    };
    try {
      await guest.join(address, port);
    } catch (e) {
      debugLog.warn('netz', 'Beitreten: $e');
      if (mounted) setState(() => _message = 'Tisch nicht erreichbar');
      await guest.close();
      return;
    }
    await _sub?.cancel();
    await _browser?.close();
    _browser = null;
    var lastBalls = 0;
    _sub = guest.changed.listen((_) {
      if (!mounted) return;
      final v = guest.view;
      if (v != null && v.called.length != lastBalls) {
        lastBalls = v.called.length;
        _app.sfx.play(Sound.tick);
      }
      if (!guest.lan.connected) _message = 'Der Gastgeber hat den Tisch geschlossen';
      setState(() {});
    });
    setState(() {
      _guest = guest;
      _mode = _Mode.guest;
      _message = '';
    });
  }

  // ---------------------------------------------------------------- Oberfläche

  @override
  Widget build(BuildContext context) {
    return GameFrame(
      title: 'Bingo',
      guide: bingoGuide,
      child: switch (_mode) {
        _Mode.setup => _setup(),
        _Mode.hostLobby => _hostLobby(),
        _Mode.browse => _browseView(),
        _Mode.guest => _guestView(),
        _Mode.play => _table(BingoView.of(_game!, _me!, _log), local: true),
      },
    );
  }

  TextStyle get _style => TextStyle(color: Palette.of(context).onFelt, fontSize: 16);

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(t, style: _style.copyWith(fontWeight: FontWeight.w700)));

  Widget _panel(List<Widget> children) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListenableBuilder(
              listenable: _wallet,
              builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
            ),
          ),
        ),
      );

  Widget _cardChips() => Wrap(spacing: 8, children: [
        for (var n = 1; n <= 4; n++) ChoiceChip(label: Text('$n'), selected: _cards == n, onSelected: (_) => setState(() => _cards = n)),
      ]);

  Widget _nameField() => TextFormField(
        initialValue: _name,
        maxLength: 16,
        decoration: const InputDecoration(labelText: 'Dein Name am Tisch', counterText: ''),
        onChanged: _saveName,
      );

  Widget _setup() {
    return _panel([
      _label('Spielart'),
      SegmentedButton<BingoVariant>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: BingoVariant.us75, label: Text('75 Kugeln (USA)')),
          ButtonSegment(value: BingoVariant.uk90, label: Text('90 Kugeln (UK)')),
        ],
        selected: {_variant},
        onSelectionChanged: (s) => setState(() => _variant = s.first),
      ),
      if (_variant == BingoVariant.us75) ...[
        _label('Gewinnmuster'),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final pt in BingoPattern.values)
            ChoiceChip(label: Text(bingoPatternNames[pt]!), selected: _pattern == pt, onSelected: (_) => setState(() => _pattern = pt)),
        ]),
      ] else
        Padding(padding: const EdgeInsets.only(top: 8), child: Text('Eine Reihe, dann zwei Reihen, dann volle Karte', style: _style)),
      _label('Deine Karten'),
      _cardChips(),
      _label('Preis je Karte'),
      Wrap(spacing: 8, children: [
        for (final pr in const [10, 50, 100, 500])
          ChoiceChip(label: Text(formatCoins(pr)), selected: _price == pr, onSelected: (_) => setState(() => _price = pr)),
      ]),
      _label('Mitspieler (Computer)'),
      Wrap(spacing: 8, runSpacing: 6, children: [
        for (var n = 0; n <= 9; n++) ChoiceChip(label: Text('$n'), selected: _bots == n, onSelected: (_) => setState(() => _bots = n)),
      ]),
      _label('Tempo'),
      SegmentedButton<int>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 2500, label: Text('Gemütlich')),
          ButtonSegment(value: 1500, label: Text('Normal')),
          ButtonSegment(value: 800, label: Text('Schnell')),
        ],
        selected: {_speedMs},
        onSelectionChanged: (s) => setState(() => _speedMs = s.first),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('Automatisch markieren', style: _style),
        subtitle: Text('Aus: selbst antippen und „Bingo!“ rufen (nur allein)', style: _style.copyWith(fontSize: 14)),
        value: _autoDaub,
        onChanged: (v) => setState(() => _autoDaub = v),
      ),
      const SizedBox(height: 10),
      Center(
        child: ActionButton(
          primary: true,
          label: 'Allein spielen: ${formatCoins(_cards * _price)}',
          onPressed: _wallet.canAfford(_cards * _price) && _bots > 0 ? _startSolo : null,
        ),
      ),
      _label('Im lokalen Netzwerk'),
      _nameField(),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          ActionButton(label: 'Tisch eröffnen', onPressed: _openTable),
          ActionButton(label: 'Tisch beitreten', onPressed: _browse),
        ],
      ),
      if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message, textAlign: TextAlign.center, style: _style)),
      const SizedBox(height: 6),
      Text(
        'Alle Geräte müssen im selben WLAN sein. Beim Tisch eröffnen stellst du Spielart, Preis, Tempo und Computer-Mitspieler ein.',
        textAlign: TextAlign.center,
        style: _style.copyWith(fontSize: 14),
      ),
    ]);
  }

  Widget _hostLobby() {
    final host = _host!;
    return _panel([
      Text('Dein Tisch ist offen', textAlign: TextAlign.center, style: _style.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(host.info, textAlign: TextAlign.center, style: _style),
      Text('Von Hand beitreten: ${_addresses.isEmpty ? '–' : _addresses.map((a) => '$a:${host.lan.port}').join(' oder ')}',
          textAlign: TextAlign.center, style: _style.copyWith(fontSize: 14)),
      _label('Am Tisch'),
      Text('• $_displayName (du)', style: _style),
      for (final s in host.seats.values) Text('• ${s.name}: ${s.cards} ${s.cards == 1 ? 'Karte' : 'Karten'}${s.ready ? '' : ' (wartet)'}', style: _style),
      if (_bots > 0) Text('• $_bots Computer-Mitspieler', style: _style),
      _label('Deine Karten'),
      _cardChips(),
      const SizedBox(height: 14),
      Center(
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          ActionButton(
            primary: true,
            label: 'Runde starten: ${formatCoins(_cards * _price)}',
            onPressed: _wallet.canAfford(_cards * _price) && (host.seats.values.any((s) => s.ready) || _bots > 0) ? _hostStartRound : null,
          ),
          ActionButton(label: 'Tisch schließen', onPressed: _closeNet),
        ]),
      ),
    ]);
  }

  Widget _browseView() {
    return _panel([
      Text('Offene Tische', textAlign: TextAlign.center, style: _style.copyWith(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      if (_tables.isEmpty)
        Text('Suche im WLAN …', textAlign: TextAlign.center, style: _style)
      else
        for (final t in _tables)
          Card(
            child: ListTile(
              title: Text(t.name),
              subtitle: Text('${t.info}\n${t.address}'),
              isThreeLine: true,
              trailing: const Icon(Icons.login),
              onTap: () => _join(t.address, t.port),
            ),
          ),
      _label('Deine Karten'),
      _cardChips(),
      _label('Von Hand verbinden'),
      TextField(
        controller: _manualAddress,
        decoration: const InputDecoration(labelText: 'Adresse:Port, z. B. 192.168.1.20:41234'),
        keyboardType: TextInputType.url,
      ),
      const SizedBox(height: 10),
      Center(
        child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          ActionButton(
            label: 'Verbinden',
            onPressed: () {
              final parts = _manualAddress.text.trim().split(':');
              final port = parts.length == 2 ? int.tryParse(parts[1]) : null;
              if (port != null) _join(parts[0], port);
            },
          ),
          ActionButton(label: 'Zurück', onPressed: _closeNet),
        ]),
      ),
      if (_message.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_message, textAlign: TextAlign.center, style: _style)),
    ]);
  }

  Widget _guestView() {
    final guest = _guest!;
    final v = guest.view;
    if (!guest.lan.connected) {
      return _panel([
        Text(_message.isEmpty ? 'Verbindung beendet' : _message, textAlign: TextAlign.center, style: _style.copyWith(fontSize: 18)),
        const SizedBox(height: 12),
        Center(child: ActionButton(primary: true, label: 'Zurück', onPressed: _closeNet)),
      ]);
    }
    if (v == null || (v.over && guest.ready)) {
      return _panel([
        Text(guest.info.isEmpty ? 'Verbunden' : guest.info, textAlign: TextAlign.center, style: _style.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
        _label('Am Tisch'),
        for (final p in guest.lobby) Text('• $p', style: _style),
        const SizedBox(height: 12),
        Text('Warte, bis der Gastgeber die Runde startet …', textAlign: TextAlign.center, style: _style),
        const SizedBox(height: 12),
        Center(child: ActionButton(label: 'Tisch verlassen', onPressed: _closeNet)),
      ]);
    }
    return _table(v, local: false);
  }

  String _letter(BingoVariant variant, int n) => variant == BingoVariant.us75 ? 'BINGO'[(n - 1) ~/ 15] : '';

  Widget _ball(BingoVariant variant, int n, double size, {bool latest = false}) {
    const colors = [Color(0xFF1E88E5), Color(0xFFE53935), Color(0xFFFDD835), Color(0xFF43A047), Color(0xFF8E24AA)];
    final c = variant == BingoVariant.us75 ? colors[(n - 1) ~/ 15] : colors[(n - 1) * 5 ~/ 91];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(center: const Alignment(-0.3, -0.4), colors: [Color.lerp(c, Colors.white, 0.5)!, c]),
        border: Border.all(color: latest ? Colors.white : const Color(0x55000000), width: latest ? 3 : 1),
      ),
      child: Container(
        width: size * 0.62,
        height: size * 0.62,
        alignment: Alignment.center,
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_letter(variant, n).isNotEmpty)
                  Text(_letter(variant, n), style: const TextStyle(fontWeight: FontWeight.w800, height: 1, color: Color(0xFF241410))),
                Text('$n', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, height: 1.05, color: Color(0xFF241410))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _table(BingoView v, {required bool local}) {
    final p = Palette.of(context);
    final d = v.drawn;
    final last = v.called.reversed.take(6).toList();
    final autoDaub = _autoDaub || !local;
    final stageLine = v.over
        ? 'Spiel vorbei · du: +${formatCoins(_earned)}'
        : '${v.stageName(v.stage)} · ${formatCoins(v.prizeFor(v.stage))} · Kugel ${v.called.length}';
    final shownStage = math.max(0, math.min(v.stage, v.stages) - 1);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight * 1.2;
        final cardW = math.min(wide ? box.maxWidth * 0.3 : box.maxWidth - 24, 360.0);
        final cards = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final c in v.myCards)
              SizedBox(
                // 90er-Karten sind breit: auf dem Handy untereinander, 75er passen zu zweit nebeneinander
                width: v.myCards.length > 1 && !wide && v.variant == BingoVariant.us75 ? (box.maxWidth - 34) / 2 : cardW,
                child: _CardView(
                  card: c,
                  variant: v.variant,
                  isMarked: (n) => autoDaub ? d.contains(n) : _marked.contains(n),
                  winning: c.winningCells(v.variant, d, pattern: v.pattern, stage: shownStage),
                  missing: v.over ? null : c.missing(v.variant, d, pattern: v.pattern, stage: v.stage),
                  onTap: autoDaub
                      ? null
                      : (n) => setState(() {
                            if (d.contains(n)) _marked.add(n);
                          }),
                ),
              ),
          ],
        );
        final header = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (last.isNotEmpty) _ball(v.variant, last.first, 76, latest: true) else const SizedBox(width: 76, height: 76),
                const SizedBox(width: 10),
                for (final n in last.skip(1)) Padding(padding: const EdgeInsets.only(right: 4), child: _ball(v.variant, n, 36)),
              ],
            ),
            const SizedBox(height: 6),
            Text(stageLine, style: const TextStyle(color: Color(0xFFFFC95C), fontWeight: FontWeight.w700, fontSize: 16)),
            Text('Pot ${formatCoins(v.pot)} · ${v.playerCount} Spieler · ${v.cardCount} Karten', style: TextStyle(color: p.onFelt, fontSize: 14)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 10,
              runSpacing: 2,
              alignment: WrapAlignment.center,
              children: [
                for (final (name, missing) in v.others)
                  Text('$name${v.over ? '' : ' noch $missing'}', style: TextStyle(color: p.onFelt.withValues(alpha: 0.8), fontSize: 13)),
              ],
            ),
          ],
        );
        final List<Widget> buttons;
        if (!local) {
          buttons = [
            if (v.over) ActionButton(primary: true, label: 'Nächste Runde mitspielen: ${formatCoins(_cards * v.cardPrice)}', onPressed: () => setState(() {
                  _guest!.cards = _cards;
                  _guest!.sendReady();
                })),
            ActionButton(label: 'Tisch verlassen', onPressed: _closeNet),
          ];
        } else if (v.over && _pending.isEmpty) {
          buttons = _host != null
              ? [
                  ActionButton(primary: true, label: 'Zum Warteraum', onPressed: _back),
                  ActionButton(label: 'Tisch schließen', onPressed: _closeNet),
                ]
              : [
                  ActionButton(primary: true, label: 'Noch eine Runde: ${formatCoins(_cards * _price)}', onPressed: _wallet.canAfford(_cards * _price) ? _startSolo : null),
                  ActionButton(label: 'Einstellungen', onPressed: _back),
                ];
        } else {
          buttons = [
            if (!autoDaub) ActionButton(primary: true, label: 'Bingo!', onPressed: _claim),
            if (v.over)
              ActionButton(
                label: 'Aufgeben',
                onPressed: () => setState(() {
                  _pending = [];
                  _finish();
                }),
              ),
            if (!v.over) ActionButton(label: _paused ? 'Weiter' : 'Pause', onPressed: () => setState(() => _paused = !_paused)),
            if (_host == null) ActionButton(label: 'Aussteigen', onPressed: _back),
          ];
        }
        final controls = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ResultBanner(text: _message, highlight: _message.startsWith('BINGO') || _message.startsWith('Du hast')),
            if (v.over) ...[
              for (final l in v.log) Text(l, style: TextStyle(color: p.onFelt, fontSize: 14)),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: buttons),
          ],
        );
        if (wide) {
          return Row(
            children: [
              Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: cards))),
              SizedBox(
                width: math.min(360, box.maxWidth * 0.4),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [header, const SizedBox(height: 10), controls]),
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Padding(padding: const EdgeInsets.only(top: 10), child: header),
            Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: cards))),
            Padding(padding: const EdgeInsets.fromLTRB(10, 0, 10, 12), child: controls),
          ],
        );
      },
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.variant, required this.isMarked, required this.winning, this.missing, this.onTap});
  final BingoCard card;
  final BingoVariant variant;
  final bool Function(int) isMarked;
  final Set<(int, int)> winning;
  final int? missing;
  final void Function(int)? onTap;

  @override
  Widget build(BuildContext context) {
    final us = variant == BingoVariant.us75;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: winning.isNotEmpty ? const Color(0xFFFFB300) : const Color(0xFF6B3E1E), width: winning.isNotEmpty ? 3 : 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (us)
            Row(children: [
              for (final l in 'BINGO'.split(''))
                Expanded(child: Center(child: Text(l, style: const TextStyle(fontFamily: displayFont, fontSize: 18, color: Color(0xFFC62828))))),
            ]),
          for (var r = 0; r < card.height; r++)
            Row(
              children: [
                for (var c = 0; c < card.width; c++)
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: us ? 1 : 0.85,
                      child: _cell(r, c),
                    ),
                  ),
              ],
            ),
          if (missing != null)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(missing == 0 ? 'BINGO!' : 'noch $missing', style: const TextStyle(color: Color(0xFF6D4C41), fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _cell(int r, int c) {
    final n = card.rows[r][c];
    final free = n == 0 && variant == BingoVariant.us75;
    final empty = n == 0 && !free;
    final marked = free || (n > 0 && isMarked(n));
    final win = winning.contains((r, c));
    return GestureDetector(
      onTap: onTap == null || n == 0 ? null : () => onTap!(n),
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: empty ? const Color(0xFFE8DCC4) : Colors.white,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0x22000000)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (!empty)
              FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: free
                      ? const Icon(Icons.star, color: Color(0xFFC62828))
                      : Text('$n', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF241410))),
                ),
              ),
            if (marked)
              FractionallySizedBox(
                widthFactor: 0.82,
                heightFactor: 0.82,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: win ? const Color(0xAAFFB300) : const Color(0x88E53935),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
