import 'dart:async';

import 'package:meta/meta.dart';

import 'domino_engine.dart';

/// Turn phases owned by the director (the engine layer, never UI timers).
enum DirectorPhase {
  idle,
  awaitingHuman,
  botThinking,
  botAnimating,
  roundEnded,
}

/// Events the director emits; the UI renders them and never drives turns.
sealed class DirectorEvent {
  const DirectorEvent();
}

class HumanTurnEvent extends DirectorEvent {
  final int player;
  const HumanTurnEvent(this.player);
}

class BotThinkingEvent extends DirectorEvent {
  final int player;
  const BotThinkingEvent(this.player);
}

class BotDrewEvent extends DirectorEvent {
  final int player;
  final int boneyardLeft;
  const BotDrewEvent(this.player, this.boneyardLeft);
}

class BotPlayedEvent extends DirectorEvent {
  final int player;
  final DomTile tile;
  final ChainEnd end;
  final bool spinner;
  const BotPlayedEvent(this.player, this.tile, this.end, this.spinner);
}

class BotPassedEvent extends DirectorEvent {
  final int player;
  const BotPassedEvent(this.player);
}

class RoundEndedEvent extends DirectorEvent {
  final RoundResult result;
  const RoundEndedEvent(this.result);
}

/// Owns turn state for bot seats: decides, narrates, and advances turns on
/// engine timers. Human turns simply report [DirectorPhase.awaitingHuman]
/// and wait for the UI to call [humanPlayed]/[humanDrew]/[humanPassed].
///
/// A watchdog ([watchdogTick], driven by [startWatchdog]) re-kicks the
/// director whenever a phase is found without a live timer, so a dropped
/// timer can never freeze the table. Stuck states are impossible by
/// construction: every scheduled step either advances the engine or emits
/// [RoundEndedEvent].
class TurnDirector {
  final DominoEngine engine;
  final void Function(DirectorEvent) onEvent;

  DirectorPhase phase = DirectorPhase.idle;
  Timer? _pending;
  Timer? _watchdog;
  bool _disposed = false;

  TurnDirector({required this.engine, required this.onEvent});

  /// Begin directing from the engine's current turn.
  void start() {
    _disposed = false;
    _kick();
  }

  void startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      watchdogTick();
    });
  }

  /// The watchdog: if a non-idle, non-awaitingHuman phase has no live timer,
  /// something dropped it — re-kick. Also surfaces a round end the UI may
  /// have missed.
  void watchdogTick() {
    if (_disposed) return;
    if (engine.roundOver && phase != DirectorPhase.roundEnded) {
      _setPhase(DirectorPhase.roundEnded);
      onEvent(RoundEndedEvent(engine.lastResult!));
      return;
    }
    if (_pending != null) return;
    switch (phase) {
      case DirectorPhase.idle:
      case DirectorPhase.awaitingHuman:
      case DirectorPhase.roundEnded:
        break; // resting phases need no timer
      case DirectorPhase.botThinking:
      case DirectorPhase.botAnimating:
        _kick(); // dropped timer — recover
    }
  }

  void dispose() {
    _disposed = true;
    _pending?.cancel();
    _watchdog?.cancel();
    _pending = null;
  }

  /// Test hook: simulate a dropped timer (the watchdog must recover).
  @visibleForTesting
  void dropPendingTimer() {
    _pending?.cancel();
    _pending = null;
  }

  /// Test hook: true while a step timer is armed.
  @visibleForTesting
  bool get hasPendingTimer => _pending != null;

  void _setPhase(DirectorPhase p) {
    phase = p;
  }

  void _after(Duration d, void Function() fn) {
    _pending?.cancel();
    _pending = Timer(d, () {
      _pending = null;
      if (_disposed) return;
      fn();
    });
  }

  /// Examine the engine state and schedule the next step.
  void _kick() {
    if (_disposed) return;
    if (engine.roundOver) {
      // Guarded: the watchdog may already have surfaced this round end.
      if (phase != DirectorPhase.roundEnded) {
        _setPhase(DirectorPhase.roundEnded);
        onEvent(RoundEndedEvent(engine.lastResult!));
      }
      return;
    }
    final p = engine.turn;
    if (engine.isBot[p]) {
      _setPhase(DirectorPhase.botThinking);
      onEvent(BotThinkingEvent(p));
      _after(const Duration(milliseconds: 700), () => _botAct(p));
    } else {
      _setPhase(DirectorPhase.awaitingHuman);
      onEvent(HumanTurnEvent(p));
    }
  }

  /// One bot micro-step, always visible: think → draw/play → animate → next.
  void _botAct(int p) {
    if (_disposed || engine.roundOver || engine.turn != p) {
      _kick();
      return;
    }
    final action = engine.botDecision(p);
    switch (action.type) {
      case BotActionType.draw:
        final drawn = engine.drawTile(p, relaxed: action.relaxed);
        _setPhase(DirectorPhase.botAnimating);
        if (drawn == null) {
          // Boneyard exhausted mid-turn → pass.
          engine.pass(p, relaxed: action.relaxed);
          onEvent(BotPassedEvent(p));
          _after(const Duration(milliseconds: 500), _kick);
          return;
        }
        onEvent(BotDrewEvent(p, engine.boneyard.length));
        // RULES §7: a drawn playable tile must be played immediately.
        _after(const Duration(milliseconds: 650), () {
          if (_disposed || engine.roundOver || engine.turn != p) {
            _kick();
            return;
          }
          final moves =
              engine.legalMoves(p).where((m) => m.$1 == drawn).toList();
          if (moves.isEmpty) {
            _botAct(p); // still stuck — draw again / pass
            return;
          }
          // Re-decide; the drawn tile is the only legal one the bot holds.
          _botPlay(p, engine.botDecision(p));
        });
      case BotActionType.pass:
        _setPhase(DirectorPhase.botAnimating);
        engine.pass(p, relaxed: action.relaxed);
        onEvent(BotPassedEvent(p));
        _after(const Duration(milliseconds: 600), _kick);
      case BotActionType.play:
        _botPlay(p, action);
    }
  }

  void _botPlay(int p, BotAction action) {
    if (action.type != BotActionType.play ||
        action.tile == null ||
        action.end == null) {
      _botAct(p); // decision went stale — re-decide
      return;
    }
    if (_disposed || engine.roundOver || engine.turn != p) {
      _kick();
      return;
    }
    final tile = action.tile!;
    final spinner = engine.playTile(p, tile, action.end!);
    _setPhase(DirectorPhase.botAnimating);
    onEvent(BotPlayedEvent(p, tile, action.end!, spinner));
    _after(const Duration(milliseconds: 650), _kick);
  }

  // ------------------------------------------------------------ human API
  /// The UI calls these after the human commits a move through the engine.
  /// Each validates the engine state and advances the director.
  void humanPlayed() => _afterHuman();
  void humanDrew() => _afterHuman();
  void humanPassed() => _afterHuman();

  void _afterHuman() {
    if (_disposed) return;
    if (engine.roundOver) {
      if (phase != DirectorPhase.roundEnded) {
        _setPhase(DirectorPhase.roundEnded);
        onEvent(RoundEndedEvent(engine.lastResult!));
      }
      return;
    }
    _setPhase(DirectorPhase.idle);
    // Small beat so the human's placement lands before the next turn.
    _after(const Duration(milliseconds: 350), _kick);
  }

  /// Advance to the next round after the UI dismisses the round-end sheet.
  void nextRound() {
    if (_disposed) return;
    final res = engine.lastResult;
    if (res != null && res.tieBreakRound) {
      engine.beginTieBreak();
    } else if (!engine.matchOver) {
      engine.startRound();
    }
    _setPhase(DirectorPhase.idle);
    _kick();
  }
}
