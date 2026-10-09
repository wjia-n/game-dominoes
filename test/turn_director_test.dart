import 'package:dominoes/engine/domino_engine.dart';
import 'package:dominoes/engine/turn_director.dart';
import 'package:flutter_test/flutter_test.dart';

DominoEngine botEngine(
        {int n = 2,
        GameMode mode = GameMode.draw,
        BotDifficulty difficulty = BotDifficulty.normal,
        int target = 100,
        int seed = 7}) =>
    DominoEngine(
      mode: mode,
      names: List.generate(n, (i) => 'Bot$i'),
      isBot: List.filled(n, true),
      difficulty: difficulty,
      matchTarget: target,
      seed: seed,
    )..newMatch();

/// Drive an all-bot engine to match completion, purely and synchronously,
/// honoring RULES §7 (a drawn playable tile is played immediately).
/// Returns the number of turns taken. Throws if the engine ever has no
/// legal forward action (a stuck state).
int runBotMatch(DominoEngine e, {int maxTurns = 30000}) {
  var turns = 0;
  while (!e.matchOver) {
    if (turns >= maxTurns) {
      throw StateError('match did not terminate within $maxTurns turns');
    }
    while (!e.roundOver) {
      if (turns >= maxTurns) {
        throw StateError('round did not terminate within $maxTurns turns');
      }
      final p = e.turn;
      if (!e.isBot[p]) throw StateError('expected a bot seat');
      final a = e.botDecision(p);
      switch (a.type) {
        case BotActionType.play:
          e.playTile(p, a.tile!, a.end!);
        case BotActionType.draw:
          final t = e.drawTile(p, relaxed: a.relaxed);
          if (t == null) {
            e.pass(p, relaxed: a.relaxed);
            break;
          }
          final moves =
              e.legalMoves(p).where((m) => m.$1 == t).toList();
          if (moves.isEmpty) continue; // still stuck — draw again
          final d2 = e.botDecision(p);
          if (d2.type == BotActionType.play &&
              d2.tile != null &&
              d2.end != null) {
            e.playTile(p, d2.tile!, d2.end!);
          } else {
            // Defensive: never leave a turn without a forward action.
            e.pass(p, relaxed: true);
          }
        case BotActionType.pass:
          e.pass(p, relaxed: a.relaxed);
      }
      turns++;
    }
    final res = e.lastResult;
    if (res != null && res.tieBreakRound && !e.matchOver) {
      e.beginTieBreak();
    } else if (!e.matchOver) {
      e.startRound();
    }
  }
  return turns;
}

void main() {
  group('bot-vs-bot: no stuck states possible', () {
    for (final mode in GameMode.values) {
      for (final diff in BotDifficulty.values) {
        for (final n in [2, 3, 4]) {
          test(
              '${mode.name}/${diff.name}/$n players completes a full match',
              () {
            for (int seed = 1; seed <= 6; seed++) {
              final e = botEngine(
                  n: n, mode: mode, difficulty: diff, seed: seed);
              final turns = runBotMatch(e);
              expect(e.matchOver, isTrue);
              expect(e.matchWinner, inInclusiveRange(0, n - 1));
              expect(e.scores[e.matchWinner], greaterThanOrEqualTo(100));
              expect(turns, greaterThan(0));
            }
          });
        }
      }
    }

    test('low target + many seeds: matches always terminate', () {
      for (int seed = 100; seed < 160; seed++) {
        final e = botEngine(
            n: 4,
            mode: GameMode.draw,
            difficulty: BotDifficulty.hard,
            target: 25,
            seed: seed);
        runBotMatch(e);
        expect(e.matchOver, isTrue);
      }
    });

    test('block mode: consecutive passes always end the round', () {
      for (int seed = 1; seed <= 10; seed++) {
        final e = botEngine(
            n: 4, mode: GameMode.block, difficulty: BotDifficulty.easy,
            seed: seed);
        var rounds = 0;
        while (!e.matchOver && rounds < 40) {
          while (!e.roundOver) {
            final p = e.turn;
            final a = e.botDecision(p);
            switch (a.type) {
              case BotActionType.play:
                e.playTile(p, a.tile!, a.end!);
              case BotActionType.draw:
                e.drawTile(p, relaxed: a.relaxed);
              case BotActionType.pass:
                e.pass(p, relaxed: a.relaxed);
            }
          }
          rounds++;
          final res = e.lastResult;
          if (res != null && res.tieBreakRound && !e.matchOver) {
            e.beginTieBreak();
          } else if (!e.matchOver) {
            e.startRound();
          }
        }
        expect(e.matchOver, isTrue);
      }
    });
  });

  group('TurnDirector', () {
    test('emits RoundEndedEvent when the engine is already done', () async {
      final e = botEngine(n: 2)..newMatch();
      e.endRound(domino: 0);
      expect(e.roundOver, isTrue);
      final events = <DirectorEvent>[];
      final d =
          TurnDirector(engine: e, onEvent: events.add)..start();
      expect(events, hasLength(1));
      expect(events.first, isA<RoundEndedEvent>());
      d.dispose();
    });

    test('watchdog re-kicks a dropped bot timer', () async {
      final e = botEngine(n: 2);
      final events = <DirectorEvent>[];
      final d =
          TurnDirector(engine: e, onEvent: events.add)..start();
      expect(d.phase, DirectorPhase.botThinking);
      expect(d.hasPendingTimer, isTrue);
      expect(events.first, isA<BotThinkingEvent>());

      // Simulate the platform dropping the timer.
      d.dropPendingTimer();
      expect(d.hasPendingTimer, isFalse);

      // The watchdog must recover the phase without any UI involvement.
      d.watchdogTick();
      expect(d.phase, DirectorPhase.botThinking);
      expect(d.hasPendingTimer, isTrue);
      d.dispose();
    });

    test('watchdog surfaces a round end the UI missed', () async {
      final e = botEngine(n: 2);
      final events = <DirectorEvent>[];
      final d =
          TurnDirector(engine: e, onEvent: events.add)..start();
      // Round ends behind the director's back (e.g. a human committed).
      e.endRound(domino: 1);
      d.watchdogTick();
      expect(d.phase, DirectorPhase.roundEnded);
      expect(events.last, isA<RoundEndedEvent>());
      d.dispose();
    });

    test('human turn waits; director does not auto-advance it', () async {
      final e = DominoEngine(
        mode: GameMode.draw,
        names: const ['You', 'Bot'],
        isBot: const [false, true],
        difficulty: BotDifficulty.normal,
        matchTarget: 100,
        seed: 3,
      )..newMatch();
      e.turn = 0; // the human seat
      final events = <DirectorEvent>[];
      final d =
          TurnDirector(engine: e, onEvent: events.add)..start();
      expect(events, hasLength(1));
      expect(events.single, isA<HumanTurnEvent>());
      await Future.delayed(const Duration(milliseconds: 300));
      expect(d.phase, DirectorPhase.awaitingHuman);
      expect(d.hasPendingTimer, isFalse); // resting phase needs no timer
      d.dispose();
    });
  });
}
