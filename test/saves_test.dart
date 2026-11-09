import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gluckspfennig/core/saves.dart';
import 'package:gluckspfennig/games/arschloch/ah_engine.dart';
import 'package:gluckspfennig/games/cards/playing_card.dart';
import 'package:gluckspfennig/games/mahjong/american/am_engine.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_bot.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_engine.dart';
import 'package:gluckspfennig/games/mahjong/classic/mj_rules.dart';
import 'package:gluckspfennig/games/mahjong/riichi_bot.dart';
import 'package:gluckspfennig/games/mahjong/riichi_engine.dart';
import 'package:gluckspfennig/games/pikdame/pd_engine.dart';
import 'package:gluckspfennig/games/skat/skat_bot.dart';
import 'package:gluckspfennig/games/skat/skat_engine.dart';

/// Wie im echten Spielstand: einmal durch JSON.
List<dynamic> viaJson(List<List<Object?>> log) => jsonDecode(jsonEncode(log)) as List<dynamic>;

void main() {
  test('Kartencodes', () {
    for (final s in Suit.values) {
      for (var r = 2; r <= 14; r++) {
        final c = PlayingCard(r, s);
        expect(cardFromCode(cardCode(c)), c);
      }
    }
  });

  for (final v in [MjVariant.sichuanRiver, MjVariant.hongKong, MjVariant.taiwan]) {
    test('Mahjong ${v.name}: Nachspielen ergibt denselben Stand', () {
      final rng = Random(5);
      final g = MjGame(mjRules[v]!, rng: Random(42))..start();
      for (var i = 0; i < 700 && g.phase != MjPhase.gameOver; i++) {
        switch (g.phase) {
          case MjPhase.exchange:
            g.submitExchange(0, g.botExchange(0));
          case MjPhase.voidChoice:
            g.chooseVoid(0, g.botVoid(0));
          case MjPhase.discard:
            switch (mjBotTurn(g, g.current, rng)) {
              case MjBotWin():
                g.tsumo(g.current);
              case MjBotKan(:final tile):
                g.kan(g.current, tile);
              case MjBotDiscard(:final tile):
                g.discard(g.current, tile);
            }
          case MjPhase.claim:
            g.resolveClaims({for (final e in g.claims.entries) e.key: mjBotClaim(g, e.key, e.value)});
          case MjPhase.handOver:
            g.nextHand();
          case MjPhase.gameOver:
            break;
        }
      }
      final r = MjGame(mjRules[v]!, rng: Random(42))..start();
      for (final a in viaJson(g.actionLog)) {
        mjApply(r, a as List);
      }
      expect(r.phase, g.phase);
      expect(r.wall, g.wall);
      for (var p = 0; p < g.n; p++) {
        expect(r.players[p].hand, g.players[p].hand);
        expect(r.players[p].points, g.players[p].points);
      }
    });
  }

  test('Riichi: Nachspielen', () {
    final rng = Random(3);
    final g = RiichiGame(rng: Random(9))..start();
    for (var i = 0; i < 600 && g.phase != RPhase.gameOver; i++) {
      switch (g.phase) {
        case RPhase.discard:
          switch (botTurn(g, g.current, rng)) {
            case BotTsumo():
              g.tsumo(g.current);
            case BotKan(:final tile):
              g.kan(g.current, tile);
            case BotDiscard(:final tile, :final riichi):
              g.discard(g.current, tile, riichi: riichi);
          }
        case RPhase.claim:
          g.resolveClaims({for (final e in g.claims.entries) e.key: botClaim(g, e.key, e.value)});
        case RPhase.handOver:
          g.nextHand();
        case RPhase.gameOver:
          break;
      }
    }
    final r = RiichiGame(rng: Random(9))..start();
    for (final a in viaJson(g.actionLog)) {
      riichiApply(r, a as List);
    }
    expect(r.phase, g.phase);
    for (var p = 0; p < 4; p++) {
      expect(r.players[p].hand, g.players[p].hand);
      expect(r.players[p].points, g.players[p].points);
    }
  });

  test('American: Nachspielen', () {
    final rng = Random(2);
    final g = AmGame(rng: Random(11))..start();
    for (var i = 0; i < 400 && g.phase != AmPhase.gameOver; i++) {
      switch (g.phase) {
        case AmPhase.charleston:
          g.submitPass(0, g.botPass(0, rng));
        case AmPhase.discard:
          switch (amBotTurn(g, g.current, rng)) {
            case AmBotMahjong():
              g.mahjong(g.current);
            case AmBotSwap(:final owner, :final index):
              g.swapJoker(g.current, owner, index);
            case AmBotDiscard(:final tile):
              g.discard(g.current, tile);
          }
        case AmPhase.claim:
          g.resolveClaims({for (final e in g.claims.entries) e.key: amBotClaim(g, e.key, e.value)});
        case AmPhase.handOver:
          g.nextHand();
        case AmPhase.gameOver:
          break;
      }
    }
    final r = AmGame(rng: Random(11))..start();
    for (final a in viaJson(g.actionLog)) {
      amApply(r, a as List);
    }
    expect(r.phase, g.phase);
    for (var p = 0; p < 4; p++) {
      expect(r.players[p].hand, g.players[p].hand);
      expect(r.players[p].points, g.players[p].points);
    }
  });

  test('Pik Dame: Nachspielen', () {
    final rng = Random(4);
    const o = PdOptions(players: 3, target: 500, maxJokers: 2);
    final g = PdGame(o, rng: Random(21))..start();
    for (var i = 0; i < 60 && g.phase != PdPhase.gameOver; i++) {
      if (g.phase == PdPhase.roundOver) {
        g.nextRound();
      } else {
        pdBotTurn(g, g.current, rng);
      }
    }
    final r = PdGame(o, rng: Random(21))..start();
    for (final a in viaJson(g.actionLog)) {
      pdApply(r, a as List);
    }
    expect(r.phase, g.phase);
    expect([for (final c in r.pile) c.id], [for (final c in g.pile) c.id]);
    for (var p = 0; p < 3; p++) {
      expect([for (final c in r.players[p].hand) c.id], [for (final c in g.players[p].hand) c.id]);
      expect(r.players[p].score, g.players[p].score);
    }
  });

  test('Skat: Nachspielen', () {
    final rng = Random(6);
    final g = SkatGame(rng: Random(13))..start();
    for (var i = 0; i < 150 && g.phase != SkatPhase.matchOver; i++) {
      switch (g.phase) {
        case SkatPhase.bidding:
          final p = g.bidTurn;
          if (skatMaxBid(g.players[p].hand) >= g.askedValue) {
            g.bidYes(p);
          } else {
            g.bidPass(p);
          }
        case SkatPhase.skatChoice:
          g.takeSkat();
        case SkatPhase.discard:
          final cards = g.players[g.declarer].hand;
          g.discard(skatDiscard(cards, skatChooseGame(g, cards)));
        case SkatPhase.declare:
          g.declare(skatChooseGame(g, [...g.players[g.declarer].hand, ...g.skat]));
        case SkatPhase.playing:
          g.play(g.current, skatBotCard(g, g.current, rng));
        case SkatPhase.dealOver:
          g.nextDeal();
        case SkatPhase.matchOver:
          break;
      }
    }
    final r = SkatGame(rng: Random(13))..start();
    for (final a in viaJson(g.actionLog)) {
      skatApply(r, a as List);
    }
    expect(r.phase, g.phase);
    for (var p = 0; p < 3; p++) {
      expect(r.players[p].hand, g.players[p].hand);
      expect(r.players[p].score, g.players[p].score);
    }
  });

  test('Arschloch: Nachspielen', () {
    final g = AhGame(rng: Random(8))..start();
    for (var i = 0; i < 120 && g.phase != AhPhase.gameOver; i++) {
      switch (g.phase) {
        case AhPhase.exchange:
          g.humanGiveBack(sortAh(g.players[0].hand).take(g.humanGives).toList());
        case AhPhase.roundOver:
          g.nextRound();
        case AhPhase.play:
          final m = ahBotMove(g, g.current);
          if (m == null) {
            g.pass(g.current);
          } else {
            g.play(g.current, m);
          }
        case AhPhase.gameOver:
          break;
      }
    }
    final r = AhGame(rng: Random(8))..start();
    for (final a in viaJson(g.actionLog)) {
      ahApply(r, a as List);
    }
    expect(r.phase, g.phase);
    for (var p = 0; p < 4; p++) {
      expect(r.players[p].hand, g.players[p].hand);
      expect(r.players[p].points, g.players[p].points);
    }
  });
}
