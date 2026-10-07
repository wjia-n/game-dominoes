import 'dart:math';
import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

/// Dominoes — draw-mode tile matching for 2-4 players. Draw 7 tiles, match the
/// open ends, draw from the boneyard when stuck, and race to 100 match points.
/// Highest-pip bot included.
class DominoesScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;

  const DominoesScreen({super.key, required this.players, required this.callbacks});

  @override
  State<DominoesScreen> createState() => _DominoesScreenState();
}

class _Tile {
  final int a, b; // a <= b
  _Tile(this.a, this.b);
  int get pips => a + b;
}

/// WORKAROUND (core bug): shell solo setup yields a single bot seat instead of
/// human+bot. Synthesize the missing bot locally so solo mode stays playable.
List<Player> _effectivePlayers(List<Player> src) {
  if (src.length > 1) return src;
  final h = src.first;
  return [
    Player(name: h.name, color: h.color, emoji: h.emoji, isBot: false),
    PlayerPresets.make(1, isBot: true),
  ];
}

class _DominoesScreenState extends State<DominoesScreen> {
  late final List<Player> _ps;
  late List<List<_Tile>> _hands;
  late List<_Tile> _boneyard;
  late List<_Tile> _line; // display-oriented: (leftPip, rightPip) in order
  int _left = -1, _right = -1;
  int _turn = 0;
  int _round = 0;
  int _passes = 0;
  bool _busy = false;
  bool _matchOver = false;
  String _banner = '';
  final _rand = Random();
  final _boardScroll = ScrollController();

  int get _n => _ps.length;
  Player get _me => _ps[_turn];
  bool get _solo => _ps.length != widget.players.length;

  @override
  void initState() {
    super.initState();
    _ps = _effectivePlayers(widget.players);
    _hands = [];
    _boneyard = [];
    _line = [];
    _startRound();
  }

  @override
  void dispose() {
    _boardScroll.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ round setup
  void _startRound() {
    final tiles = <_Tile>[
      for (int a = 0; a <= 6; a++)
        for (int b = a; b <= 6; b++) _Tile(a, b),
    ]..shuffle(_rand);
    _hands = List.generate(_n, (_) => <_Tile>[]);
    for (int i = 0; i < 7 * _n; i++) {
      _hands[i % _n].add(tiles.removeLast());
    }
    _boneyard = tiles;
    for (final h in _hands) {
      h.sort((x, y) => y.pips.compareTo(x.pips));
    }
    _line = [];
    _passes = 0;
    _busy = false;
    _round++;

    final sp = _findStarter();
    _Tile first = _hands[sp].firstWhere((t) => t.a == t.b,
        orElse: () => _hands[sp].reduce((a, b) => a.pips >= b.pips ? a : b));
    // prefer the starter's highest double
    _Tile best = first;
    for (final t in _hands[sp]) {
      if (t.a == t.b && t.a > best.a) best = t;
    }
    first = best;
    _hands[sp].remove(first);
    _line.add(first);
    _left = first.a;
    _right = first.b;
    _turn = (sp + 1) % _n;
    _banner = ' • ${_ps[sp].name} opens with [${first.a}|${first.b}]! 🀄';
    Sfx.click();
    if (mounted) setState(() {});
    widget.callbacks.setActivePlayer(min(_turn, widget.players.length - 1));
    _scrollBoardToEnd();
    _maybeBot();
  }

  int _findStarter() {
    int bestPi = 0, bestDouble = -1;
    for (int p = 0; p < _n; p++) {
      for (final t in _hands[p]) {
        if (t.a == t.b && t.a > bestDouble) {
          bestDouble = t.a;
          bestPi = p;
        }
      }
    }
    if (bestDouble >= 0) return bestPi;
    int bestPips = -1;
    for (int p = 0; p < _n; p++) {
      for (final t in _hands[p]) {
        if (t.pips > bestPips) {
          bestPips = t.pips;
          bestPi = p;
        }
      }
    }
    return bestPi;
  }

  void _scrollBoardToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_boardScroll.hasClients) {
        _boardScroll.jumpTo(_boardScroll.position.maxScrollExtent);
      }
    });
  }

  // ---------------------------------------------------------------- gameplay
  bool _matches(_Tile t) =>
      t.a == _left || t.b == _left || t.a == _right || t.b == _right;

  void _maybeBot() {
    if (_matchOver || _busy || !_me.isBot) return;
    Future.delayed(const Duration(milliseconds: 750), () {
      if (!mounted || _matchOver || _busy || !_me.isBot) return;
      _botTurn();
    });
  }

  Future<void> _botTurn() async {
    if (_matchOver) return;
    _busy = true;
    setState(() => _banner = ' • ${_me.name} is thinking… 🤖');
    await Future.delayed(const Duration(milliseconds: 700));
    while (mounted && !_matchOver) {
      final hand = _hands[_turn];
      final playable = hand.where(_matches).toList()
        ..sort((a, b) => b.pips.compareTo(a.pips));
      if (playable.isEmpty) {
        if (_boneyard.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 380));
          if (!mounted || _matchOver) return;
          final drawn = _boneyard.removeLast();
          setState(() {
            hand.add(drawn);
            hand.sort((a, b) => b.pips.compareTo(a.pips));
            _banner = ' • ${_me.name} draws a tile… 🎲';
          });
          Sfx.tap();
          continue;
        }
        _busy = false;
        _pass();
        return;
      }
      final tile = playable.first;
      await Future.delayed(const Duration(milliseconds: 480));
      if (!mounted || _matchOver) return;
      _busy = false;
      _place(_turn, tile, _botSide(tile, hand));
      return;
    }
    _busy = false;
  }

  /// Bot plays its highest-pip tile; when both ends fit, chains the value it
  /// holds most of.
  bool _botSide(_Tile tile, List<_Tile> hand) {
    final canL = tile.a == _left || tile.b == _left;
    final canR = tile.a == _right || tile.b == _right;
    if (canL && !canR) return true;
    if (canR && !canL) return false;
    final otherL = tile.a == _left ? tile.b : tile.a;
    final otherR = tile.a == _right ? tile.b : tile.a;
    int freq(int v) => hand.where((t) => t.a == v || t.b == v).length;
    final fl = freq(otherL), fr = freq(otherR);
    if (fl != fr) return fl > fr;
    return _rand.nextBool();
  }

  void _onTileTap(_Tile tile) async {
    if (_matchOver || _busy || _me.isBot) return;
    if (!_hands[_turn].contains(tile)) return;
    if (!_matches(tile)) {
      setState(() => _banner = ' • that tile matches neither end 🙈');
      Sfx.tap();
      return;
    }
    final canL = tile.a == _left || tile.b == _left;
    final canR = tile.a == _right || tile.b == _right;
    if (canL && canR && _left != _right) {
      final toLeft = await showDialog<bool>(
        context: context,
        builder: (ctx) => WajihaDialog(
          title: 'Play where?',
          emoji: '🀄',
          children: [
            WajihaButton(
                label: 'Left end ($_left)', emoji: '⬅️',
                onTap: () => Navigator.pop(ctx, true)),
            const SizedBox(height: 10),
            WajihaButton(
                label: 'Right end ($_right)', emoji: '➡️',
                primary: false,
                onTap: () => Navigator.pop(ctx, false)),
          ],
        ),
      );
      if (toLeft == null || !mounted || _matchOver || _me.isBot) return;
      if (!_hands[_turn].contains(tile)) return;
      _place(_turn, tile, toLeft);
    } else {
      _place(_turn, tile, canL);
    }
  }

  void _place(int pi, _Tile tile, bool toLeft) {
    if (_matchOver) return;
    _hands[pi].remove(tile);
    if (toLeft) {
      final other = tile.a == _left ? tile.b : tile.a;
      _line.insert(0, _Tile(other, _left));
      _left = other;
    } else {
      final other = tile.a == _right ? tile.b : tile.a;
      _line.add(_Tile(_right, other));
      _right = other;
    }
    _passes = 0;
    Sfx.move();
    setState(() => _banner = ' • ${_ps[pi].name} plays [${tile.a}|${tile.b}]! 🀄');
    _scrollBoardToEnd();
    if (_hands[pi].isEmpty) {
      _roundEnd(domino: pi);
      return;
    }
    _nextTurn();
  }

  void _humanDraw() {
    if (_matchOver || _busy || _me.isBot || _boneyard.isEmpty) return;
    if (_hands[_turn].any(_matches)) return;
    final t = _boneyard.removeLast();
    setState(() {
      _hands[_turn].add(t);
      _hands[_turn].sort((a, b) => b.pips.compareTo(a.pips));
      _banner = _matches(t)
          ? ' • drew [${t.a}|${t.b}] — it fits! Play it! 🎉'
          : ' • drew [${t.a}|${t.b}] — still stuck, draw again 🎲';
    });
    Sfx.tap();
  }

  void _humanPass() {
    if (_matchOver || _busy || _me.isBot) return;
    if (_boneyard.isNotEmpty || _hands[_turn].any(_matches)) return;
    _pass();
  }

  void _pass() {
    _passes++;
    setState(() => _banner = ' • ${_me.name} passes ⏭');
    Sfx.tap();
    if (_passes >= _n) {
      _roundEnd(); // everybody blocked
    } else {
      _nextTurn();
    }
  }

  void _nextTurn() {
    if (_matchOver) return;
    _turn = (_turn + 1) % _n;
    setState(() => _banner = ' • ${_ps[_turn].name}\'s turn 🀄');
    widget.callbacks.setActivePlayer(min(_turn, widget.players.length - 1));
    _maybeBot();
  }

  // ---------------------------------------------------------------- scoring
  void _roundEnd({int? domino}) {
    final pips = [
      for (int i = 0; i < _n; i++) _hands[i].fold(0, (s, t) => s + t.pips),
    ];
    int winner;
    if (domino != null) {
      winner = domino;
    } else {
      winner = 0;
      for (int i = 1; i < _n; i++) {
        if (pips[i] < pips[winner]) winner = i;
      }
    }
    int pts = 0;
    for (int i = 0; i < _n; i++) {
      if (i != winner) pts += pips[i];
    }
    _ps[winner].score += pts;
    if (winner < widget.players.length) {
      widget.players[winner].score = _ps[winner].score;
    }
    widget.callbacks.refreshHud();
    Sfx.win();
    final w = _ps[winner];
    if (w.score >= 100) {
      _finishMatch(winner);
      return;
    }
    setState(() => _banner = ' • round $_round → ${w.name} +$pts pts! 🎉');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final t = ThemeController.of(ctx).theme;
        return WajihaDialog(
          title: domino != null ? '🎉 DOMINO!' : '🚧 Blocked!',
          emoji: w.emoji,
          children: [
            Text(
              '${w.name} takes the round: +$pts pts',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 10),
            for (int i = 0; i < _n; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${_ps[i].emoji} ${_ps[i].name}: ${pips[i]} pips left → ${_ps[i].score} match pts',
                  style: TextStyle(color: t.muted, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 14),
            WajihaButton(
              label: 'Next round',
              emoji: '▶️',
              onTap: () {
                Navigator.pop(ctx);
                _startRound();
              },
            ),
          ],
        );
      },
    );
  }

  void _finishMatch(int pi) {
    if (_matchOver) return;
    _matchOver = true;
    final w = _ps[pi];
    widget.callbacks.finish(
      winner: w,
      headline: '🏆 ${w.name} wins the match!',
      subline: 'First to 100 match points. Domino royalty! 🀄👑',
    );
  }

  // ------------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final t = ThemeController.of(context).theme;
    final myHand = _hands[_turn];
    final stuck = !myHand.any(_matches);
    final humanTurn = !_matchOver && !_busy && !_me.isBot;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            const SizedBox(height: 4),
            TurnBanner(player: _me, action: _banner),
            const SizedBox(height: 6),
            Text(
              '🎯 Round $_round • first to 100 match pts',
              style: TextStyle(color: t.muted, fontWeight: FontWeight.w700),
            ),
            if (_solo) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _n; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '${_ps[i].emoji} ${_ps[i].score}',
                        style: TextStyle(
                            color: t.text, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            // board
            Container(
              height: 132,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                    child: Row(
                      children: [
                        _endBadge(t, '⬅ $_left'),
                        const Spacer(),
                        Text('🀄 ${_line.length} tiles',
                            style: TextStyle(
                                color: t.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                        const Spacer(),
                        _endBadge(t, '$_right ➡'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _boardScroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      itemCount: _line.length,
                      itemBuilder: (_, i) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _DominoTileView(a: _line[i].a, b: _line[i].b, w: 34, theme: t),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (humanTurn && stuck && _boneyard.isNotEmpty)
                  WajihaButton(
                    label: 'Draw (${_boneyard.length})',
                    emoji: '🎲',
                    onTap: _humanDraw,
                    fontSize: 16,
                  ),
                if (humanTurn && stuck && _boneyard.isEmpty)
                  WajihaButton(
                    label: 'Pass',
                    emoji: '⏭',
                    primary: false,
                    onTap: _humanPass,
                    fontSize: 16,
                  ),
                if (!(humanTurn && stuck))
                  Text(
                    _matchOver
                        ? ''
                        : _me.isBot
                            ? '${_me.name} is playing… 🤖'
                            : _busy
                                ? '…'
                                : stuck
                                    ? ''
                                    : 'Tap a glowing tile to play ✨',
                    style: TextStyle(color: t.muted, fontWeight: FontWeight.w700),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // hand
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_me.emoji} ${_me.name}\'s hand (${myHand.length})',
                style: TextStyle(color: t.text, fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 118,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: myHand.length,
                itemBuilder: (_, i) {
                  final tile = myHand[i];
                  final playable = humanTurn && _matches(tile);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _DominoTileView(
                      a: tile.a,
                      b: tile.b,
                      w: 56,
                      theme: t,
                      dim: humanTurn && !playable,
                      glow: playable,
                      onTap: playable ? () => _onTileTap(tile) : null,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _endBadge(GameTheme t, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.primary.withValues(alpha: 0.18),
        borderRadius: t.radius,
        border: Border.all(color: t.primary, width: 2),
      ),
      child: Text(label,
          style: TextStyle(color: t.text, fontWeight: FontWeight.w900, fontSize: 16)),
    );
  }
}

// ---------------------------------------------------------------------------
// Domino tile widget with real pip faces
// ---------------------------------------------------------------------------
const _pipMap = <int, Set<int>>{
  0: {},
  1: {4},
  2: {2, 6},
  3: {2, 4, 6},
  4: {0, 2, 6, 8},
  5: {0, 2, 4, 6, 8},
  6: {0, 2, 3, 5, 6, 8},
};

class _DominoTileView extends StatelessWidget {
  final int a, b;
  final double w;
  final GameTheme theme;
  final bool dim;
  final bool glow;
  final VoidCallback? onTap;

  const _DominoTileView({
    required this.a,
    required this.b,
    required this.w,
    required this.theme,
    this.dim = false,
    this.glow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final face = w * 0.86;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dim ? 0.4 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: w,
          padding: EdgeInsets.all(w * 0.07),
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: BorderRadius.circular(w * 0.18),
            border: Border.all(
              color: glow ? t.primary : t.muted.withValues(alpha: 0.35),
              width: glow ? 3 : 1.5,
            ),
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: t.primary.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PipFace(n: a, size: face, color: t.text),
              Container(
                  height: 2, color: t.muted.withValues(alpha: 0.4),
                  margin: EdgeInsets.symmetric(vertical: w * 0.06)),
              _PipFace(n: b, size: face, color: t.text),
            ],
          ),
        ),
      ),
    );
  }
}

class _PipFace extends StatelessWidget {
  final int n;
  final double size;
  final Color color;

  const _PipFace({required this.n, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final spots = _pipMap[n]!;
    return SizedBox(
      width: size,
      height: size,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.all(size * 0.1),
        children: [
          for (int i = 0; i < 9; i++)
            Center(
              child: spots.contains(i)
                  ? Container(
                      width: size * 0.2,
                      height: size * 0.2,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    )
                  : const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}
