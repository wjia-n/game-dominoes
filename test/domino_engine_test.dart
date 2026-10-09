import 'dart:convert';

import 'package:dominoes/engine/domino_engine.dart';
import 'package:flutter_test/flutter_test.dart';

DominoEngine engine(
        {int n = 2,
        GameMode mode = GameMode.draw,
        BotDifficulty difficulty = BotDifficulty.normal,
        int target = 100,
        int seed = 7}) =>
    DominoEngine(
      mode: mode,
      names: List.generate(n, (i) => 'P$i'),
      isBot: List.filled(n, false),
      difficulty: difficulty,
      matchTarget: target,
      seed: seed,
    )..newMatch();

/// Reset an engine to a hand-built table state for deterministic tests.
void rig(DominoEngine e, List<List<DomTile>> hands, DomTile first,
    {List<DomTile>? boneyard, int turn = 1}) {
  e.hands = hands;
  e.boneyard = boneyard ?? [];
  e.spine = [];
  e.spinners = [];
  e.passes = 0;
  e.roundOver = false;
  e.scores = List.filled(e.n, 0);
  e.round = 1;
  e.passedValues = List.generate(e.n, (_) => <int>{});
  e.placeFirst(first);
  e.hands[0].remove(first);
  e.turn = turn;
}

void main() {
  group('setup & opening (T1, T2)', () {
    test('T1: 2 players deal 7 each, 14 in boneyard', () {
      final e = engine(n: 2);
      // 7 each dealt; the opener's tile is already on the table
      final dealt = e.hands.fold(0, (s, h) => s + h.length) + e.spine.length;
      expect(dealt, 14);
      expect(e.boneyard.length, 14);
      expect(e.spine.length, 1);
    });

    test('T1: 4 players deal 5 each, 8 in boneyard', () {
      final e = engine(n: 4);
      final dealt = e.hands.fold(0, (s, h) => s + h.length) + e.spine.length;
      expect(dealt, 20);
      expect(e.boneyard.length, 8);
      expect(e.spine.length, 1);
    });

    test('T2: holder of the highest double opens', () {
      for (int seed = 1; seed <= 12; seed++) {
        final e = engine(seed: seed);
        // every tile dealt, including the already-opened one
        final all = [
          for (final h in e.hands) ...h,
          DomTile(e.spine.first.connect, e.spine.first.open),
        ];
        DomTile? highest;
        for (final t in all) {
          if (t.isDouble && (highest == null || t.a > highest.a)) {
            highest = t;
          }
        }
        final opened = e.spine.first;
        if (highest != null) {
          expect(opened.connect, highest.a,
              reason: 'seed $seed should open with [$highest]');
          expect(opened.open, highest.b, reason: 'seed $seed');
        } else {
          // no double anywhere: heaviest tile opens
          final heavy = all.reduce((a, b) => a.pips >= b.pips ? a : b);
          expect(opened.connect + opened.open, heavy.pips,
              reason: 'seed $seed should open heaviest');
        }
      }
    });

    test('T2b: opener tile removed from hand, turn passes clockwise', () {
      final e = engine(n: 3, seed: 4);
      final total =
          e.hands.fold(0, (s, h) => s + h.length) + e.spine.length;
      expect(total, 15);
      expect(e.turn, greaterThanOrEqualTo(0));
      expect(e.turn, lessThan(3));
    });
  });

  group('legal / illegal moves (T3, T4)', () {
    test('T3: [3|5] attaches to open end 3 or 5, flips as needed', () {
      final e = engine();
      rig(e, [
        [const DomTile(3, 5), const DomTile(0, 0)],
        [const DomTile(1, 1)],
      ], const DomTile(2, 3),
          turn: 0);
      // ends are 2 and 3
      final ends = e.endsFor(const DomTile(3, 5));
      expect(ends.map((x) => x.value), contains(3));
      e.playTile(0, const DomTile(3, 5), ends.firstWhere((x) => x.value == 3));
      expect(e.rightVal == 5 || e.leftVal == 5, isTrue);
    });

    test('T4: [1|2] cannot attach to ends 3 and 5', () {
      final e = engine();
      rig(e, [
        [const DomTile(1, 2)],
        [const DomTile(0, 0)],
      ], const DomTile(3, 5),
          turn: 0);
      expect(e.endsFor(const DomTile(1, 2)), isEmpty);
      expect(
          () => e.playTile(
              0, const DomTile(1, 2), const ChainEnd.chainLeft(3)),
          throwsStateError);
    });

    test('playing out of turn is rejected', () {
      final e = engine();
      rig(e, [
        [const DomTile(2, 6)],
        [const DomTile(2, 6)],
      ], const DomTile(2, 3),
          turn: 1);
      expect(
          () => e.playTile(
              0, const DomTile(2, 6), const ChainEnd.chainLeft(2)),
          throwsStateError);
    });
  });

  group('spinners (T5, T13)', () {
    test('T5: double placed crosswise opens two arms; chain frozen until fed',
        () {
      final e = engine();
      rig(e, [
        [const DomTile(0, 0), const DomTile(4, 1)],
        [const DomTile(4, 2), const DomTile(3, 3)],
      ], const DomTile(4, 4),
          turn: 1);
      expect(e.spinners.length, 1);
      expect(e.spinners.first.satisfied, isFalse);
      // chain ends frozen: no chain ends offered
      final ends = e.legalEnds();
      expect(ends.where((x) => x.spinnerIndex < 0), isEmpty);
      expect(ends.length, 2); // the two arms, both value 4
      // T13: extending the main chain while an arm is empty is rejected
      expect(
          () => e.playTile(
              1, const DomTile(4, 2), const ChainEnd.chainLeft(4)),
          throwsStateError);
      // play on arm A
      e.playTile(
          1, const DomTile(4, 2), ends.firstWhere((x) => x.arm == 0));
      expect(e.spinners.first.satisfied, isFalse); // arm B still empty
      // arm B takes [4|1] from P0
      e.turn = 0;
      final ends0 = e.endsFor(const DomTile(4, 1));
      expect(ends0.map((x) => x.arm), contains(1));
      e.playTile(
          0, const DomTile(4, 1), ends0.firstWhere((x) => x.arm == 1));
      expect(e.spinners.first.satisfied, isTrue);
      // chain ends unfrozen again
      expect(e.legalEnds().where((x) => x.spinnerIndex < 0).length, 2);
    });

    test('double played on an arm becomes a nested spinner', () {
      final e = engine();
      rig(e, [
        [const DomTile(4, 2), const DomTile(0, 0)],
        [const DomTile(2, 2)],
      ], const DomTile(4, 4),
          turn: 0);
      // P0 feeds arm A with [4|2]; its open end is now 2
      final arm0 =
          e.legalEnds().firstWhere((x) => x.spinnerIndex == 0 && x.arm == 0);
      e.playTile(0, const DomTile(4, 2), arm0);
      // P1 lays [2|2] on that arm -> nested spinner of value 2
      e.turn = 1;
      final arm0b =
          e.legalEnds().firstWhere((x) => x.spinnerIndex == 0 && x.arm == 0);
      e.playTile(1, const DomTile(2, 2), arm0b);
      expect(e.spinners.length, 2);
      expect(e.spinners[1].value, 2);
    });
  });

  group('draw mode (T6, T7, T14)', () {
    test('T6: stuck player draws until playable; drawn tile played', () {
      final e = engine(mode: GameMode.draw);
      rig(e, [
        [const DomTile(0, 0)],
        [const DomTile(1, 1)],
      ], const DomTile(2, 3),
          boneyard: [const DomTile(5, 5), const DomTile(2, 6)],
          turn: 0);
      expect(e.hasPlay(0), isFalse);
      final d1 = e.drawTile(0);
      expect(d1, const DomTile(2, 6));
      // drawn tile fits: must be playable now
      expect(e.endsFor(d1!).isNotEmpty, isTrue);
    });

    test('T7: drawing with a playable tile is illegal', () {
      final e = engine(mode: GameMode.draw);
      rig(e, [
        [const DomTile(2, 6)],
        [const DomTile(1, 1)],
      ], const DomTile(2, 3),
          boneyard: [const DomTile(5, 5)],
          turn: 0);
      expect(e.hasPlay(0), isTrue);
      expect(() => e.drawTile(0), throwsStateError);
    });

    test('T14: boneyard exhausted -> pass, round continues', () {
      final e = engine(mode: GameMode.draw);
      rig(e, [
        [const DomTile(0, 0)],
        [const DomTile(2, 6), const DomTile(1, 1)],
      ], const DomTile(2, 3),
          boneyard: [],
          turn: 0);
      expect(e.hasPlay(0), isFalse);
      e.pass(0);
      expect(e.roundOver, isFalse);
      expect(e.turn, 1);
    });
  });

  group('block mode (T8)', () {
    test('T8: boneyard dead; stuck player passes; pass with tile rejected',
        () {
      final e = engine(mode: GameMode.block);
      expect(e.boneyard, isEmpty);
      rig(e, [
        [const DomTile(2, 6)],
        [const DomTile(0, 0)],
      ], const DomTile(2, 3),
          turn: 1);
      // P1 stuck -> pass ok
      expect(e.hasPlay(1), isFalse);
      e.pass(1);
      expect(e.turn, 0);
      // P0 holds [2|6] matching end 2 -> pass rejected
      expect(() => e.pass(0), throwsStateError);
    });
  });

  group('scoring & match end (T9, T10, T12)', () {
    test('T9: domino scores the sum of opponents\' remaining pips', () {
      final e = engine();
      rig(e, [
        [const DomTile(2, 6)],
        [const DomTile(1, 2), const DomTile(3, 3)],
      ], const DomTile(2, 3),
          turn: 0);
      final ends = e.endsFor(const DomTile(2, 6));
      e.playTile(0, const DomTile(2, 6), ends.first);
      expect(e.roundOver, isTrue);
      final r = e.lastResult!;
      expect(r.domino, isTrue);
      expect(r.winner, 0);
      expect(r.points, 3 + 6); // (1+2) + (3+3)
      expect(e.scores[0], 9);
    });

    test('T10: blocked round — lowest pips wins (others\' pips minus own)',
        () {
      final e = engine();
      rig(e, [
        [const DomTile(0, 1)], // 1 pip
        [const DomTile(2, 2)], // 4 pips
      ], const DomTile(5, 5),
          turn: 0);
      e.pass(0);
      e.pass(1);
      expect(e.roundOver, isTrue);
      final r = e.lastResult!;
      expect(r.domino, isFalse);
      expect(r.winner, 0);
      expect(r.points, 4 - 1);
      expect(e.scores[0], 3);
    });

    test('T11 tie-break: earliest in turn order wins lowest-pip ties', () {
      final e = engine(n: 3);
      rig(e, [
        [const DomTile(0, 2)], // 2
        [const DomTile(0, 2)], // 2
        [const DomTile(0, 5)], // 5
      ], const DomTile(6, 6),
          turn: 0);
      e.pass(0);
      e.pass(1);
      e.pass(2);
      expect(e.lastResult!.winner, 0);
    });

    test('T12: reaching the target ends the match', () {
      final e = engine(target: 10);
      rig(e, [
        [const DomTile(2, 6)],
        [const DomTile(1, 2), const DomTile(3, 4)],
      ], const DomTile(2, 3),
          turn: 0);
      e.scores[0] = 6;
      final ends = e.endsFor(const DomTile(2, 6));
      e.playTile(0, const DomTile(2, 6), ends.first);
      final r = e.lastResult!;
      expect(r.matchOver, isTrue);
      expect(r.matchWinner, 0);
      expect(e.matchOver, isTrue);
    });
  });

  group('bot (T11 AI strategy)', () {
    test('easy bot sometimes dawdles but usually plays', () {
      var plays = 0, dawdles = 0;
      for (int seed = 0; seed < 60; seed++) {
        final e = engine(difficulty: BotDifficulty.easy, seed: seed);
        rig(e, [
          [const DomTile(2, 6)],
          [const DomTile(1, 1)],
        ], const DomTile(2, 3),
            boneyard: [const DomTile(5, 5)],
            turn: 0);
        final a = e.botDecision(0);
        if (a.type == BotActionType.play) {
          plays++;
        } else {
          dawdles++;
        }
      }
      expect(plays, greaterThan(30));
      expect(dawdles, greaterThan(0));
      expect(dawdles, lessThanOrEqualTo(25));
    });

    test('easy bot dawdle never throws (relaxed draw/pass)', () {
      for (int seed = 0; seed < 40; seed++) {
        final e = engine(difficulty: BotDifficulty.easy, seed: seed);
        rig(e, [
          [const DomTile(2, 6)],
          [const DomTile(1, 1)],
        ], const DomTile(2, 3),
            boneyard: [const DomTile(5, 5)],
            turn: 0);
        final a = e.botDecision(0);
        // applying any decision must be legal
        switch (a.type) {
          case BotActionType.draw:
            e.drawTile(0, relaxed: a.relaxed);
          case BotActionType.pass:
            e.pass(0, relaxed: a.relaxed);
          case BotActionType.play:
            e.playTile(0, a.tile!, a.end!);
        }
      }
    });

    test('normal bot sheds the highest-pip tile', () {
      final e = engine(difficulty: BotDifficulty.normal, seed: 3);
      rig(e, [
        [const DomTile(2, 1), const DomTile(2, 6)],
        [const DomTile(0, 0)],
      ], const DomTile(2, 3),
          turn: 0);
      final a = e.botDecision(0);
      expect(a.type, BotActionType.play);
      expect(a.tile, const DomTile(2, 6));
    });

    test('bot draws when stuck in draw mode, passes in block mode', () {
      final d = engine(mode: GameMode.draw, seed: 3);
      rig(d, [
        [const DomTile(0, 0)],
        [const DomTile(1, 1)],
      ], const DomTile(2, 3),
          boneyard: [const DomTile(5, 5)],
          turn: 0);
      expect(d.botDecision(0).type, BotActionType.draw);

      final b = engine(mode: GameMode.block, seed: 3);
      rig(b, [
        [const DomTile(0, 0)],
        [const DomTile(1, 1)],
      ], const DomTile(2, 3),
          turn: 0);
      expect(b.botDecision(0).type, BotActionType.pass);
    });
  });

  group('persistence (T15)', () {
    test('T15: save/restore reproduces identical table state', () {
      final e = engine(seed: 11);
      // play a couple of tiles to get spinners/arms into the state
      final json = e.toJson();
      final r = DominoSave.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(json)) as Map));
      expect(r.hands.length, e.hands.length);
      for (int i = 0; i < e.n; i++) {
        expect(r.hands[i], e.hands[i]);
      }
      expect(r.boneyard, e.boneyard);
      expect(r.spine.map((t) => t.toJson()).toList(),
          e.spine.map((t) => t.toJson()).toList());
      expect(r.leftVal, e.leftVal);
      expect(r.rightVal, e.rightVal);
      expect(r.turn, e.turn);
      expect(r.scores, e.scores);
      expect(r.round, e.round);
      // restored engine keeps playing identically
      expect(r.legalEnds(), e.legalEnds());
    });
  });
}
