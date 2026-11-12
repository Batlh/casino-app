import 'dart:math';

import '../riichi_hand.dart';
import '../tiles.dart';
import 'mj_hand.dart';
import 'mj_scoring.dart';
import 'mj_shape.dart';

enum MjVariant { sichuanBattle, sichuanRiver, hongKong, taiwan, mcr, singapore, korean, zungJung, western, filipino, vietnam }

/// Sichuan: Wer gewinnt, steigt aus (Blutkampf) oder spielt weiter (Blutfluss).
enum BloodMode { none, battle, river }

/// Zahlungsweise bei Ron und Tsumo.
class PayContext {
  PayContext({required this.players, required this.winner, required this.loser, required this.dealer, required this.active});
  final int players;
  final int winner;
  final int? loser;
  final int dealer;

  /// Wer noch mitspielt und zahlen muss (Sichuan-Blutkampf).
  final List<bool> active;
}

class MjRules {
  const MjRules({
    required this.variant,
    required this.title,
    required this.blurb,
    required this.unitName,
    required this.kinds,
    required this.scorer,
    required this.pay,
    this.players = 4,
    this.handSize = 13,
    this.flowers = 0,
    this.animals = false,
    this.jokers = 0,
    this.chi = true,
    this.exchange = false,
    this.voidSuit = false,
    this.blood = BloodMode.none,
    this.sevenPairs = true,
    this.orphans = true,
    this.knitted = false,
    this.pairsPung = false,
    this.minScore = 0,
    this.startPoints = 2000,
    this.multiRon = false,
    this.hands = 4,
    this.dealerStays = true,
    this.honorsAreFlowers = false,
    this.vietnamSet = false,
    this.instant = const {},
    this.instantUnit = 0,
  });

  final MjVariant variant;
  final String title;
  final String blurb;

  /// Fan, Tai oder Punkte.
  final String unitName;

  /// Steinsorten in der Mauer (je vier).
  final List<int> kinds;
  final MjScore Function(Shape s, WinInfo w) scorer;
  final List<int> Function(MjScore s, PayContext c) pay;
  final int players;
  final int handSize;

  /// 0, 4 (nur Blumen) oder 8 (Blumen und Jahreszeiten).
  final int flowers;
  final bool animals;
  final int jokers;
  final bool chi;

  /// Sichuan: drei Steine tauschen und eine Farbe als leer wählen.
  final bool exchange;
  final bool voidSuit;
  final BloodMode blood;
  final bool sevenPairs;
  final bool orphans;
  final bool knitted;
  final bool pairsPung;
  final int minScore;
  final int startPoints;

  /// Mehrere dürfen auf denselben Abwurf gewinnen.
  final bool multiRon;

  /// Geberwechsel bis zum Spielende (eine Runde).
  final int hands;
  final bool dealerStays;

  /// Winde und Drachen werden wie Blumen beiseitegelegt (Philippinen).
  final bool honorsAreFlowers;

  /// Vietnam: 24 Joker in acht Arten, Kaiser und Kaiserin; Joker dürfen für Punkte beiseitegelegt werden.
  final bool vietnamSet;

  /// Sofortzahlungen in Einheiten: kanOpen, kanClosed, kanAdded, noFlowers, flowers13.
  final Map<String, int> instant;
  final int instantUnit;

  int get sets => handSize == 16 ? 5 : 4;

  List<int> buildWall() => [
        for (final k in kinds) ...[k, k, k, k],
        if (flowers >= 4) ...[for (var i = 0; i < 4; i++) firstFlower + i],
        if (flowers >= 8) ...[for (var i = 0; i < 4; i++) firstSeason + i],
        if (animals) ...[for (var i = 0; i < 4; i++) firstAnimal + i],
        for (var i = 0; i < jokers; i++) jokerTile,
        if (vietnamSet) ...[
          for (var k = 0; k < 8; k++) ...List.filled(3, firstVietJoker + k),
          ...List.filled(4, emperorTile),
          ...List.filled(4, empressTile),
        ],
      ];

  /// Beste Wertung einer fertigen Hand, oder null wenn sie nicht fertig ist.
  MjScore? evaluate(List<int> closed, List<Meld> melds, WinInfo w) {
    final shapes = shapesOf(
      closed,
      melds,
      w,
      sets: sets,
      sevenPairs: sevenPairs,
      orphans: orphans,
      knitted: knitted,
      pairsPung: pairsPung,
    );
    if (shapes.isEmpty) return null;
    return bestScore(shapes, w, scorer);
  }
}

// ---------------------------------------------------------------- Zahlungen

/// Allgemein: Ron zahlt der Werfende [ronFactor]-fach, die anderen [ronOthers]-fach;
/// Tsumo zahlen alle [tsumoFactor]-fach. Mit [dealerDouble] zahlt und bekommt der Geber doppelt.
List<int> Function(MjScore, PayContext) simplePay(
  int Function(MjScore) unit, {
  int ronFactor = 1,
  int ronOthers = 0,
  int tsumoFactor = 1,
  bool dealerDouble = false,
}) =>
    (s, c) {
      final out = List.filled(c.players, 0);
      final u = unit(s);
      for (var p = 0; p < c.players; p++) {
        if (p == c.winner || !c.active[p]) continue;
        var k = c.loser == null ? tsumoFactor : (p == c.loser ? ronFactor : ronOthers);
        if (dealerDouble && (p == c.dealer || c.winner == c.dealer)) k *= 2;
        out[p] -= u * k;
        out[c.winner] += u * k;
      }
      return out;
    };

List<int> _mcrPay(MjScore s, PayContext c) {
  final out = List.filled(c.players, 0);
  for (var p = 0; p < c.players; p++) {
    if (p == c.winner) continue;
    final v = c.loser == null || p == c.loser ? s.points + 8 : 8;
    out[p] -= v;
    out[c.winner] += v;
  }
  return out;
}

/// Korea: Ron zahlt der Werfende die Handpunkte doppelt, Bonuspunkte zahlen beide.
/// Bei einer Grenzhand zahlen beide die Grenze, der Werfende doppelt.
List<int> _koreanPay(MjScore s, PayContext c) {
  final out = List.filled(c.players, 0);
  final hand = s.core * 10;
  final bonus = s.extra * 10;
  for (var p = 0; p < c.players; p++) {
    if (p == c.winner) continue;
    final v = c.loser == null
        ? hand + bonus
        : p == c.loser
            ? 2 * hand + bonus
            : (s.limit ? hand : 0) + bonus;
    out[p] -= v;
    out[c.winner] += v;
  }
  return out;
}

const _hkTable = [1, 2, 4, 8, 16, 24, 32, 48, 64, 96, 128, 192, 256, 256];

int sichuanUnit(MjScore s, int cap) => 100 * (1 << min(s.points, cap));

// ---------------------------------------------------------------- Steinsätze

final _allKinds = [for (var t = 0; t < tileKinds; t++) t];
final _suitKinds = [for (var t = 0; t < 27; t++) t];
final _koreanKinds = [
  for (var t = 0; t < 18; t++) t,
  18,
  26,
  27,
  28,
  29,
  31,
  32,
  33,
];

MjRules sichuanRules(BloodMode mode) => MjRules(
      variant: mode == BloodMode.river ? MjVariant.sichuanRiver : MjVariant.sichuanBattle,
      title: mode == BloodMode.river ? 'Sichuan Blutfluss' : 'Sichuan Blutkampf',
      blurb: mode == BloodMode.river
          ? 'Wie Mahjong Inferno: nach dem Sieg geht es weiter'
          : 'Drei Steine tauschen, eine Farbe streichen, wer gewinnt steigt aus',
      unitName: 'Fan',
      kinds: _suitKinds,
      scorer: scoreSichuan,
      pay: simplePay((s) => sichuanUnit(s, 6)),
      chi: false,
      exchange: true,
      voidSuit: true,
      blood: mode,
      orphans: false,
      startPoints: 10000,
      multiRon: true,
    );

final mjRules = <MjVariant, MjRules>{
  MjVariant.sichuanBattle: sichuanRules(BloodMode.battle),
  MjVariant.sichuanRiver: sichuanRules(BloodMode.river),
  MjVariant.hongKong: MjRules(
    variant: MjVariant.hongKong,
    title: 'Hongkong',
    blurb: 'Kantonesisch mit Blumen und Fan, die Hühnerhand zählt nicht',
    unitName: 'Fan',
    kinds: _allKinds,
    flowers: 8,
    scorer: scoreHongKong,
    pay: simplePay((s) => 10 * _hkTable[min(s.points, 13)], ronFactor: 2, tsumoFactor: 1),
    minScore: 1,
    startPoints: 3000,
  ),
  MjVariant.taiwan: MjRules(
    variant: MjVariant.taiwan,
    title: 'Taiwan (16 Steine)',
    blurb: '16 Steine auf der Hand, fünf Gruppen und ein Paar, Tai-Wertung',
    unitName: 'Tai',
    kinds: _allKinds,
    handSize: 16,
    flowers: 8,
    sevenPairs: false,
    orphans: false,
    pairsPung: true,
    scorer: scoreTaiwan,
    pay: simplePay((s) => 100 + 50 * s.points),
    startPoints: 5000,
  ),
  MjVariant.mcr: MjRules(
    variant: MjVariant.mcr,
    title: 'Chinesisch offiziell (MCR)',
    blurb: 'Turnierregel mit 81 Mustern, gewonnen wird ab 8 Punkten',
    unitName: 'Punkte',
    kinds: _allKinds,
    flowers: 8,
    knitted: true,
    scorer: scoreMcr,
    pay: _mcrPay,
    minScore: 8,
    startPoints: 0,
    dealerStays: false,
  ),
  MjVariant.singapore: MjRules(
    variant: MjVariant.singapore,
    title: 'Singapur',
    blurb: 'Mit vier Tiersteinen, Tai-Wertung bis 5',
    unitName: 'Tai',
    kinds: _allKinds,
    flowers: 8,
    animals: true,
    scorer: scoreSingapore,
    pay: simplePay((s) => 10 * (1 << min(s.points, 5)), ronFactor: 2, ronOthers: 1, tsumoFactor: 2),
    minScore: 1,
    startPoints: 2000,
  ),
  MjVariant.korean: MjRules(
    variant: MjVariant.korean,
    title: 'Korea (zu dritt)',
    blurb: 'Drei Spieler, ohne Nordwind und Bambus 2 bis 8, kein Chi, ab 3 Handpunkten',
    unitName: 'Punkte',
    kinds: _koreanKinds,
    players: 3,
    flowers: 4,
    chi: false,
    scorer: scoreKorean,
    pay: _koreanPay,
    minScore: 3,
    startPoints: 1000,
    hands: 3,
    dealerStays: false,
  ),
  MjVariant.zungJung: MjRules(
    variant: MjVariant.zungJung,
    title: 'Zung Jung',
    blurb: 'Moderne Punktwertung mit klaren Mustern, ohne Blumen',
    unitName: 'Punkte',
    kinds: _allKinds,
    scorer: scoreZungJung,
    pay: simplePay((s) => s.points, ronFactor: 3, tsumoFactor: 1),
    startPoints: 1000,
  ),
  MjVariant.western: MjRules(
    variant: MjVariant.western,
    title: 'Westlich klassisch',
    blurb: 'Die alte Regel aus Europa: Punkte für Gruppen, dann Verdopplungen',
    unitName: 'Punkte',
    kinds: _allKinds,
    flowers: 8,
    sevenPairs: false,
    scorer: scoreWestern,
    pay: simplePay((s) => s.points, ronFactor: 1, ronOthers: 1, tsumoFactor: 1, dealerDouble: true),
    startPoints: 5000,
  ),
  MjVariant.filipino: MjRules(
    variant: MjVariant.filipino,
    title: 'Philippinen',
    blurb: '16 Steine nur aus Farben, Winde und Drachen sind Blumen, Bunot zahlt doppelt',
    unitName: 'Viertel',
    kinds: _allKinds,
    handSize: 16,
    flowers: 8,
    honorsAreFlowers: true,
    sevenPairs: false,
    orphans: false,
    pairsPung: true,
    scorer: scoreFilipino,
    // Ein Viertel einer Auszahlung sind 10 Punkte; bei Ron zahlt der Werfende doppelt, bei Bunot alle doppelt
    pay: simplePay((s) => 10 * s.points, ronFactor: 2, ronOthers: 1, tsumoFactor: 2),
    instant: const {'kanOpen': 1, 'kanClosed': 2, 'kanAdded': 2, 'noFlowers': 1, 'flowers13': 1},
    instantUnit: 10,
    startPoints: 2000,
  ),
  MjVariant.vietnam: MjRules(
    variant: MjVariant.vietnam,
    title: 'Vietnam',
    blurb: '176 Steine mit 24 Jokern in acht Arten, Wertung in Phán und Mủn',
    unitName: 'Einsätze',
    kinds: _allKinds,
    flowers: 8,
    vietnamSet: true,
    sevenPairs: false,
    scorer: scoreVietnam,
    // Auf einen Abwurf zahlen alle, der Werfende doppelt; selbst gezogen zahlen alle doppelt
    pay: simplePay((s) => 5 * s.points, ronFactor: 2, ronOthers: 1, tsumoFactor: 2),
    startPoints: 5000,
  ),
};
