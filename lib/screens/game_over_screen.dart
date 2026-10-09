import 'package:flutter/material.dart';
import '../engine/domino_engine.dart';
import '../services/audio_service.dart';
import '../services/save_store.dart';
import '../services/settings_store.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';

/// Victoria de Ronda — engraved ROUND WINNER plaque, walnut/ivory scoreboard,
/// brass trophy medallion, Next Round / Main Menu plaques (DESIGN.md).
class GameOverScreen extends StatelessWidget {
  final DominoEngine engine;
  final RoundResult result;
  final SettingsStore settings;
  const GameOverScreen(
      {super.key,
      required this.engine,
      required this.result,
      required this.settings});

  String _diffName(BotDifficulty d) => switch (d) {
        BotDifficulty.easy => 'Easy',
        BotDifficulty.normal => 'Normal',
        BotDifficulty.hard => 'Hard',
      };

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final r = result;
    final winnerName = e.names[r.winner];
    final matchDone = r.matchOver;
    final champion =
        matchDone ? e.names[r.matchWinner] : winnerName;

    return Scaffold(
      backgroundColor: ClubPalette.darkSurface,
      body: FeltTable(
        borderRadius: BorderRadius.circular(12),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                // brass trophy medallion
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.3, -0.35),
                        radius: 1.2,
                        colors: [
                          Color(0xFFE9C176),
                          Color(0xFFC5A059),
                          Color(0xFF8C6C30)
                        ],
                      ),
                      border: Border.all(
                          color: ClubPalette.brassDark, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withValues(alpha: 0.55),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Center(
                      child: Text('🏆', style: TextStyle(fontSize: 38)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                    matchDone
                        ? 'MATCH CHAMPION'
                        : r.domino
                            ? 'DOMINO!'
                            : 'ROUND WINNER',
                    textAlign: TextAlign.center,
                    style: ClubType.headline(34).copyWith(
                      shadows: const [
                        Shadow(
                            color: Color(0xAA000000),
                            offset: Offset(0, 3),
                            blurRadius: 4),
                      ],
                    )),
                const SizedBox(height: 4),
                Center(
                  child: NamePlate(
                      '$champion  +${r.points} pts',
                      fontSize: 15),
                ),
                const SizedBox(height: 6),
                Text(
                  matchDone
                      ? 'First to ${e.matchTarget} — the club salutes you.'
                      : r.tieBreakRound
                          ? 'Level on points — a decider round will settle it.'
                          : r.domino
                              ? '$winnerName went domino, sweeping ${r.points} points off the table.'
                              : 'Blocked! $winnerName held the fewest pips and banks ${r.points}.',
                  textAlign: TextAlign.center,
                  style: ClubType.bodyText(14,
                      color: ClubPalette.parchment, italic: true),
                ),
                const SizedBox(height: 18),
                // walnut / ivory scoreboard
                ClubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('SCOREBOARD',
                          textAlign: TextAlign.center,
                          style: ClubType.label(12,
                              color: ClubPalette.brassPale)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF0EAD6),
                              Color(0xFFE2D7BD)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: ClubPalette.brassDark),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < e.n; i++)
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8),
                                decoration: BoxDecoration(
                                  border: i < e.n - 1
                                      ? const Border(
                                          bottom: BorderSide(
                                              color:
                                                  Color(0xFF8F7F5C),
                                              width: 0.8))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    if (i == r.winner)
                                      const Text('👑 ',
                                          style:
                                              TextStyle(fontSize: 14)),
                                    Expanded(
                                      child: Text(
                                        '${e.names[i]}${e.isBot[i] ? '  (bot · ${_diffName(e.difficulty)})' : ''}',
                                        style: ClubType.bodyText(
                                            14.5,
                                            color: ClubPalette.deboss),
                                      ),
                                    ),
                                    Text(
                                      '${r.pipsLeft[i]} pips',
                                      style: ClubType.label(11,
                                          color: const Color(
                                              0xFF6B5B3E)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text('${e.scores[i]}',
                                        style: ClubType.number(
                                            17,
                                            color:
                                                ClubPalette.deboss)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Target ${e.matchTarget} pts · Round ${e.round}',
                          textAlign: TextAlign.center,
                          style: ClubType.bodyText(12.5,
                              color: ClubPalette.parchment,
                              italic: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                if (matchDone) ...[
                  BrassButton(
                      label: 'Play again',
                      onTap: () {
                        AudioService.instance.click();
                        SaveStore().clear();
                        Navigator.pop(context, 'again');
                      }),
                  const SizedBox(height: 10),
                  OxbloodButton(
                      label: 'Main menu',
                      onTap: () {
                        AudioService.instance.click();
                        SaveStore().clear();
                        Navigator.pop(context, 'menu');
                      }),
                ] else ...[
                  BrassButton(
                      label: r.tieBreakRound
                          ? 'Play decider round'
                          : 'Next round',
                      onTap: () {
                        AudioService.instance.click();
                        Navigator.pop(context, 'next');
                      }),
                  const SizedBox(height: 10),
                  OxbloodButton(
                      label: 'Main menu',
                      onTap: () {
                        AudioService.instance.click();
                        Navigator.pop(context, 'menu');
                      }),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
