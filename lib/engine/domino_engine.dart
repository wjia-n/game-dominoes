import 'dart:math';

/// Dominoes engine — standard double-six, Draw & Block modes, 2–4 players.
///
/// Pure Dart, no Flutter. Implements RULES.md authoritatively:
///  - 28 tiles, deal 7 (2P) / 5 (3–4P), boneyard in Draw mode, dead in Block.
///  - Opening: highest double, else heaviest tile (round 1); later rounds the
///    previous winner opens with their highest double / heaviest tile.
///  - Doubles are spinners placed crosswise: each opens two extra arms.
///    The main chain ends stay frozen until every spinner's arms are satisfied.
///  - Draw mode: stuck player draws until playable (played immediately) or the
///    boneyard is exhausted, then passes. Block mode: stuck player passes.
///  - Scoring: raw pip sums. Domino → sum of opponents' pips. Blocked → lowest
///    pips wins, collecting (opponents' pips − own pips). Match target wins.
///  - AI: Easy (random, occasional voluntary pass), Normal (diversity + shed +
///    doubles-early heuristics), Hard (+ 1-ply lookahead, passed-value memory).
enum GameMode { draw, block }

enum BotDifficulty { easy, normal, hard }

/// A domino tile, canonical a <= b.
class DomTile {
  final int a, b;
  const DomTile(this.a, this.b);
  int get pips => a + b;
  bool get isDouble => a == b;

  @override
  bool operator ==(Object other) =>
      other is DomTile && other.a == a && other.b == b;
  @override
  int get hashCode => a * 31 + b;
}

/// A tile committed to the table. [connect] touches the previous tile,
/// [open] is the new exposed value.
class PlacedTile {
  final int connect;
  final int open;
  final bool isDouble;
  final int seq;
  const PlacedTile(
      {required this.connect,
      required this.open,
      required this.isDouble,
      required this.seq});

  Map<String, int> toJson() =>
      {'c': connect, 'o': open, 'd': isDouble ? 1 : 0, 's': seq};
  factory PlacedTile.fromJson(Map<String, dynamic> j) => PlacedTile(
      connect: j['c'] as int,
      open: j['o'] as int,
      isDouble: (j['d'] as int) == 1,
      seq: j['s'] as int);
}

/// A double on the table acting as a spinner with two arms.
class SpinnerState {
  final int value;
  final List<PlacedTile> armA = [];
  final List<PlacedTile> armB = [];
  final int seq;
  SpinnerState({required this.value, required this.seq});

  bool get satisfied => armA.isNotEmpty && armB.isNotEmpty;
  int armOpen(int arm) {
    final l = arm == 0 ? armA : armB;
    return l.isEmpty ? value : l.last.open;
  }

  Map<String, dynamic> toJson() => {
        'v': value,
        's': seq,
        'a': armA.map((t) => t.toJson()).toList(),
        'b': armB.map((t) => t.toJson()).toList(),
      };
  factory SpinnerState.fromJson(Map<String, dynamic> j) {
    final s = SpinnerState(value: j['v'] as int, seq: j['s'] as int);
    s.armA.addAll(
        (j['a'] as List).map((t) => PlacedTile.fromJson(_asMap(t))));
    s.armB.addAll(
        (j['b'] as List).map((t) => PlacedTile.fromJson(_asMap(t))));
    return s;
  }
}

Map<String, dynamic> _asMap(dynamic v) => Map<String, dynamic>.from(v as Map);

/// One playable open end of the table.
class ChainEnd {
  final int value;
  final int spinnerIndex; // -1 => main chain
  final int arm; // 0/1 for spinner arms, -1 for main chain
  final bool chainLeft; // main chain: true = start side
  const ChainEnd._(this.value, this.spinnerIndex, this.arm, this.chainLeft);
  const ChainEnd.chainLeft(int v) : this._(v, -1, -1, true);
  const ChainEnd.chainRight(int v) : this._(v, -1, -1, false);
  const ChainEnd.arm(int v, int spinner, int armSide)
      : this._(v, spinner, armSide, false);

  @override
  bool operator ==(Object other) =>
      other is ChainEnd &&
      other.value == value &&
      other.spinnerIndex == spinnerIndex &&
      other.arm == arm &&
      other.chainLeft == chainLeft;
  @override
  int get hashCode => Object.hash(value, spinnerIndex, arm, chainLeft);
}

enum BotActionType { play, draw, pass }

class BotAction {
  final BotActionType type;
  final DomTile? tile;
  final ChainEnd? end;
  /// True for the Easy bot's sanctioned dawdle (RULES §11): drawing/passing
  /// even when a move exists. The engine relaxes the must-play/must-draw
  /// checks for these only.
  final bool relaxed;
  const BotAction.play(this.tile, this.end)
      : type = BotActionType.play,
        relaxed = false;
  const BotAction.draw({this.relaxed = false})
      : type = BotActionType.draw,
        tile = null,
        end = null;
  const BotAction.pass({this.relaxed = false})
      : type = BotActionType.pass,
        tile = null,
        end = null;
}

class RoundResult {
  final int winner;
  final int points;
  final bool domino;
  final List<int> pipsLeft;
  final bool matchOver;
  final int matchWinner;
  final bool tieBreakRound;
  const RoundResult({
    required this.winner,
    required this.points,
    required this.domino,
    required this.pipsLeft,
    required this.matchOver,
    required this.matchWinner,
    required this.tieBreakRound,
  });
}

class DominoEngine {
  final GameMode mode;
  final List<String> names;
  final List<bool> isBot;
  final BotDifficulty difficulty;
  final int matchTarget;
  final Random _rand;

  late List<List<DomTile>> hands;
  late List<DomTile> boneyard;
  late List<PlacedTile> spine;
  late List<SpinnerState> spinners;
  late int leftVal, rightVal;
  late int turn;
  late int round;
  late int passes;
  late List<int> scores;
  late List<Set<int>> passedValues;
  int prevWinner = -1;
  bool roundOver = false;
  bool matchOver = false;
  int matchWinner = -1;
  bool tieBreak = false; // final tie-break round: winner takes the match
  RoundResult? lastResult; // set by endRound for the UI layer
  int _seq = 0;

  int get n => names.length;
  int handCount(int p) => hands[p].length;

  DominoEngine({
    required this.mode,
    required this.names,
    required this.isBot,
    required this.difficulty,
    required this.matchTarget,
    int? seed,
  }) : _rand = Random(seed);

  void newMatch() {
    scores = List.filled(n, 0);
    round = 0;
    prevWinner = -1;
    matchOver = false;
    matchWinner = -1;
    tieBreak = false;
    startRound();
  }

  // ------------------------------------------------------------- round setup
  void startRound() {
    final tiles = <DomTile>[
      for (int a = 0; a <= 6; a++)
        for (int b = a; b <= 6; b++) DomTile(a, b),
    ]..shuffle(_rand);
    // RULES §10: the final tie-break round plays Draw-mode rules with
    // "2 players' worth of tiles" — 7 each, like a 2-player deal.
    final per = (n == 2 || tieBreak) ? 7 : 5;
    hands = List.generate(n, (_) => <DomTile>[]);
    for (int i = 0; i < per * n; i++) {
      hands[i % n].add(tiles.removeLast());
    }
    // Block mode: the boneyard is dead. Tie-break rounds always draw.
    boneyard = (mode == GameMode.draw || tieBreak) ? tiles : <DomTile>[];
    for (final h in hands) {
      h.sort((x, y) => y.pips.compareTo(x.pips));
    }
    spine = [];
    spinners = [];
    passes = 0;
    roundOver = false;
    passedValues = List.generate(n, (_) => <int>{});
    round++;

    int opener;
    late DomTile first;
    if (round == 1 || prevWinner < 0) {
      final s = _findGlobalStarter();
      opener = s.$1;
      first = s.$2;
    } else {
      opener = prevWinner;
      first = _bestOpener(hands[opener]);
    }
    hands[opener].remove(first);
    placeFirst(first);
    turn = (opener + 1) % n;
  }

  /// Places the round's opening tile (always legal). Public so custom
  /// table states can be assembled in tests.
  void placeFirst(DomTile tile) {
    spine.add(PlacedTile(
        connect: tile.a,
        open: tile.b,
        isDouble: tile.isDouble,
        seq: _seq++));
    leftVal = tile.a;
    rightVal = tile.b;
    if (tile.isDouble) {
      spinners.add(SpinnerState(value: tile.a, seq: _seq++));
    }
  }

  /// Highest double across all hands (ties → earliest in turn order),
  /// else heaviest tile (ties → earliest).
  (int, DomTile) _findGlobalStarter() {
    int pi = 0;
    DomTile? best;
    for (int p = 0; p < n; p++) {
      for (final t in hands[p]) {
        if (t.isDouble && (best == null || !best.isDouble || t.a > best.a)) {
          best = t;
          pi = p;
        }
      }
    }
    if (best != null) return (pi, best);
    int bestPips = -1;
    for (int p = 0; p < n; p++) {
      for (final t in hands[p]) {
        if (t.pips > bestPips) {
          bestPips = t.pips;
          best = t;
          pi = p;
        }
      }
    }
    return (pi, best!);
  }

  DomTile _bestOpener(List<DomTile> hand) {
    DomTile best = hand.first;
    for (final t in hand) {
      if (t.isDouble && (!best.isDouble || t.a > best.a)) best = t;
    }
    if (best.isDouble) return best;
    for (final t in hand) {
      if (t.pips > best.pips) best = t;
    }
    return best;
  }

  // ------------------------------------------------------------------ moves
  /// All currently playable open ends. The main chain ends are frozen while
  /// any spinner has an unsatisfied arm (classic spinner house rule).
  List<ChainEnd> legalEnds() {
    final ends = <ChainEnd>[];
    if (!spinners.any((s) => !s.satisfied)) {
      ends.add(ChainEnd.chainLeft(leftVal));
      // A lone opening tile exposes one end value on both sides; listing the
      // right end separately keeps two-end choice dialogs consistent.
      ends.add(ChainEnd.chainRight(rightVal));
    }
    for (int i = 0; i < spinners.length; i++) {
      ends.add(ChainEnd.arm(spinners[i].armOpen(0), i, 0));
      ends.add(ChainEnd.arm(spinners[i].armOpen(1), i, 1));
    }
    return ends;
  }

  List<ChainEnd> endsFor(DomTile t) => legalEnds()
      .where((e) => t.a == e.value || t.b == e.value)
      .toList();

  bool hasPlay(int p) => hands[p].any((t) => endsFor(t).isNotEmpty);

  /// All legal (tile, end) pairs for [p].
  List<(DomTile, ChainEnd)> legalMoves(int p) {
    final out = <(DomTile, ChainEnd)>[];
    for (final t in hands[p]) {
      for (final e in endsFor(t)) {
        out.add((t, e));
      }
    }
    return out;
  }

  /// Play [tile] of player [p] on [end]. Throws [StateError] on illegal moves.
  /// Returns true when the tile created a new spinner.
  bool playTile(int p, DomTile tile, ChainEnd end) {
    if (roundOver) throw StateError('round is over');
    if (p != turn) throw StateError('not your turn');
    final idx = hands[p].indexOf(tile);
    if (idx < 0) throw StateError('tile not in hand');
    final legal = endsFor(tile);
    if (!legal.contains(end)) throw StateError('tile does not match that end');

    hands[p].removeAt(idx);
    final connect = end.value;
    final open = tile.a == end.value ? tile.b : tile.a;
    final placed = PlacedTile(
        connect: connect, open: open, isDouble: tile.isDouble, seq: _seq++);
    if (end.spinnerIndex < 0) {
      if (end.chainLeft) {
        spine.insert(0, placed);
        leftVal = open;
      } else {
        spine.add(placed);
        rightVal = open;
      }
    } else {
      final s = spinners[end.spinnerIndex];
      (end.arm == 0 ? s.armA : s.armB).add(placed);
    }
    final madeSpinner = tile.isDouble;
    if (madeSpinner) {
      spinners.add(SpinnerState(value: tile.a, seq: _seq++));
    }
    passes = 0;

    if (hands[p].isEmpty) {
      endRound(domino: p);
      return madeSpinner;
    }
    turn = (p + 1) % n;
    return madeSpinner;
  }

  /// Draw one tile for [p]. Returns null when the boneyard is empty.
  /// Throws when the player holds a playable tile (draw is never optional),
  /// unless [relaxed] (Easy-bot dawdle, RULES §11).
  DomTile? drawTile(int p, {bool relaxed = false}) {
    if (roundOver) throw StateError('round is over');
    if (p != turn) throw StateError('not your turn');
    if (hasPlay(p) && !relaxed) {
      throw StateError('must play: a legal tile is held');
    }
    if (boneyard.isEmpty) return null;
    final t = boneyard.removeLast();
    hands[p].add(t);
    hands[p].sort((x, y) => y.pips.compareTo(x.pips));
    return t;
  }

  /// Pass for [p]. Throws when the player could legally play or draw,
  /// unless [relaxed] (Easy-bot dawdle, RULES §11).
  void pass(int p, {bool relaxed = false}) {
    if (roundOver) throw StateError('round is over');
    if (p != turn) throw StateError('not your turn');
    if (!relaxed) {
      if (hasPlay(p)) {
        throw StateError('cannot pass while holding a playable tile');
      }
      if (boneyard.isNotEmpty) throw StateError('must draw first');
    }
    passedValues[p].addAll(legalEnds().map((e) => e.value));
    passes++;
    if (passes >= n) {
      endRound();
    } else {
      turn = (p + 1) % n;
    }
  }

  // ---------------------------------------------------------------- scoring
  RoundResult endRound({int? domino}) {
    final pips = [
      for (int i = 0; i < n; i++) hands[i].fold(0, (s, t) => s + t.pips),
    ];
    int winner;
    if (domino != null) {
      winner = domino;
    } else {
      winner = 0;
      for (int i = 1; i < n; i++) {
        if (pips[i] < pips[winner]) winner = i; // ties → earliest in turn order
      }
    }
    int pts = 0;
    for (int i = 0; i < n; i++) {
      if (i != winner) pts += pips[i];
    }
    if (domino == null) pts -= pips[winner]; // blocked: minus own pips
    scores[winner] += pts;
    prevWinner = winner;
    roundOver = true;

    bool over = false;
    int champ = -1;
    bool needTieBreak = false;
    if (tieBreak) {
      over = true; // tie-break round: winner takes the match
      champ = winner;
    } else if (scores[winner] >= matchTarget) {
      final best = scores.reduce(max);
      final leaders = [
        for (int i = 0; i < n; i++)
          if (scores[i] == best) i,
      ];
      if (leaders.length == 1) {
        over = true;
        champ = leaders.first;
      } else {
        needTieBreak = true; // same final round, still tied → decider round
      }
    }
    matchOver = over;
    matchWinner = champ;
    final res = RoundResult(
      winner: winner,
      points: pts,
      domino: domino != null,
      pipsLeft: pips,
      matchOver: over,
      matchWinner: champ,
      tieBreakRound: needTieBreak,
    );
    lastResult = res;
    return res;
  }

  void beginTieBreak() {
    tieBreak = true;
    startRound();
  }
}

// ------------------------------------------------------------------- AI ----
extension DominoBot on DominoEngine {
  /// Decide the bot's move for player [p]. Pure & deterministic given the seed.
  BotAction botDecision(int p) {
    final moves = legalMoves(p);
    if (moves.isEmpty) {
      if (mode == GameMode.draw && boneyard.isNotEmpty) {
        return const BotAction.draw();
      }
      return const BotAction.pass();
    }
    if (difficulty == BotDifficulty.easy) {
      // Random legal move; occasionally dawdles (<=25%) per RULES §11.
      if (_rand.nextDouble() < 0.25) {
        if (mode == GameMode.draw && boneyard.isNotEmpty) {
          return const BotAction.draw(relaxed: true);
        }
        return const BotAction.pass(relaxed: true);
      }
      final m = moves[_rand.nextInt(moves.length)];
      return BotAction.play(m.$1, m.$2);
    }

    final hard = difficulty == BotDifficulty.hard;
    double bestScore = double.negativeInfinity;
    (DomTile, ChainEnd)? best;
    for (final m in moves) {
      final s = _scoreMove(p, m.$1, m.$2, hard: hard);
      if (s > bestScore || (s == bestScore && _rand.nextBool())) {
        bestScore = s;
        best = m;
      }
    }
    return BotAction.play(best!.$1, best.$2);
  }

  /// Heuristic score for playing [tile] on [end] (Normal per RULES §11;
  /// Hard adds 1-ply opponent lookahead + always-on end-value counting).
  double _scoreMove(int p, DomTile tile, ChainEnd end, {required bool hard}) {
    final hand = hands[p].where((t) => t != tile).toList();
    final newOpen = tile.a == end.value ? tile.b : tile.a;

    // Open values after the move.
    final vals = <int>{newOpen};
    for (final o in legalEnds()) {
      if (o != end) vals.add(o.value);
    }
    if (tile.isDouble) vals.add(tile.a); // fresh spinner arms

    // Matching diversity: keep tiles covering the widest spread of ends.
    var diversity = 0;
    for (final v in vals) {
      if (hand.any((t) => t.a == v || t.b == v)) diversity++;
    }
    var score = diversity * 3.0 + tile.pips * 0.6;
    if (tile.isDouble) score += 2.5; // spinners early when safe

    // Defensive end play: prefer ends opponents have passed on (they likely
    // lack those values). Normal uses it in the endgame; Hard always.
    final endgame =
        List.generate(n, (i) => i).any((i) => i != p && hands[i].length <= 2);
    if (hard || endgame) {
      for (final v in vals) {
        for (int i = 0; i < n; i++) {
          if (i != p && passedValues[i].contains(v)) score += 1.5;
        }
      }
    }

    if (hard) {
      // 1-ply lookahead: penalize the opponent's best reply value.
      var reply = 0.0;
      for (int i = 0; i < n; i++) {
        if (i == p) continue;
        var bestReply = 0.0;
        for (final t in hands[i]) {
          if (vals.any((v) => t.a == v || t.b == v)) {
            final r = t.pips * 0.5 + (t.isDouble ? 1.5 : 0.0);
            if (r > bestReply) bestReply = r;
          }
        }
        reply = max(reply, bestReply);
      }
      score -= reply * 0.8;
    }
    return score;
  }
}

// ---------------------------------------------------------- serialization --
extension DominoSave on DominoEngine {
  Map<String, dynamic> toJson() => {
        'v': 1,
        'mode': mode.index,
        'names': names,
        'isBot': isBot,
        'difficulty': difficulty.index,
        'matchTarget': matchTarget,
        'hands': hands
            .map((h) => h.map((t) => [t.a, t.b]).toList())
            .toList(),
        'boneyard': boneyard.map((t) => [t.a, t.b]).toList(),
        'spine': spine.map((t) => t.toJson()).toList(),
        'spinners': spinners.map((s) => s.toJson()).toList(),
        'leftVal': leftVal,
        'rightVal': rightVal,
        'turn': turn,
        'round': round,
        'passes': passes,
        'scores': scores,
        'prevWinner': prevWinner,
        'roundOver': roundOver,
        'matchOver': matchOver,
        'matchWinner': matchWinner,
        'tieBreak': tieBreak,
        'seq': _seq,
        'passed': passedValues.map((s) => s.toList()).toList(),
      };

  static DominoEngine fromJson(Map<String, dynamic> j) {
    final e = DominoEngine(
      mode: GameMode.values[j['mode'] as int],
      names: List<String>.from(j['names'] as List),
      isBot: List<bool>.from(j['isBot'] as List),
      difficulty: BotDifficulty.values[j['difficulty'] as int],
      matchTarget: j['matchTarget'] as int,
    );
    DomTile tile(List v) => DomTile(v[0] as int, v[1] as int);
    e.hands = (j['hands'] as List)
        .map((h) => (h as List).map((t) => tile(t as List)).toList())
        .toList();
    e.boneyard =
        (j['boneyard'] as List).map((t) => tile(t as List)).toList();
    e.spine = (j['spine'] as List)
        .map((t) => PlacedTile.fromJson(_asMap(t)))
        .toList();
    e.spinners = (j['spinners'] as List)
        .map((s) => SpinnerState.fromJson(_asMap(s)))
        .toList();
    e.leftVal = j['leftVal'] as int;
    e.rightVal = j['rightVal'] as int;
    e.turn = j['turn'] as int;
    e.round = j['round'] as int;
    e.passes = j['passes'] as int;
    e.scores = List<int>.from(j['scores'] as List);
    e.prevWinner = j['prevWinner'] as int;
    e.roundOver = j['roundOver'] as bool;
    e.matchOver = j['matchOver'] as bool;
    e.matchWinner = j['matchWinner'] as int;
    e.tieBreak = j['tieBreak'] as bool;
    e._seq = j['seq'] as int;
    e.passedValues = (j['passed'] as List)
        .map((s) => Set<int>.from((s as List).map((x) => x as int)))
        .toList();
    return e;
  }
}
