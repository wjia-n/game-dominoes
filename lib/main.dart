import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const DominoesApp());

class DominoesApp extends StatelessWidget {
  const DominoesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.neonArcade,
      title: 'Dominoes',
      tagline: 'Match the ends, empty your hand, race to 100! 🀄',
      emoji: '🀄',
      slug: 'dominoes',
      howToPlay: '• Each player draws 7 tiles — highest double starts\n'
          '• Tap a tile to play it on a matching open end\n'
          '• Stuck? Draw from the boneyard until you can play\n'
          '• Empty your hand to shout DOMINO! 🎉\n'
          '• If everyone is blocked, fewest pips wins the round\n'
          '• Round winner scores opponents\' leftover pips — first to 100 wins!',
      playerOptions: const [1, 2, 3, 4],
      supportsBots: true,
      gameBuilder: (ctx, players, cb) => DominoesScreen(players: players, callbacks: cb),
    );
  }
}
