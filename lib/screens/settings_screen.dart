import 'package:flutter/material.dart';
import '../engine/domino_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_store.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';

/// Ajustes — walnut panel, felt inlays, brass toggles & slider (DESIGN.md).
class SettingsScreen extends StatefulWidget {
  final SettingsStore settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      backgroundColor: ClubPalette.darkSurface,
      body: FeltTable(
        borderRadius: BorderRadius.circular(12),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        AudioService.instance.click();
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: ClubPalette.brassFace,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: ClubPalette.brassDark, width: 1.4),
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: ClubPalette.deboss, size: 20),
                      ),
                    ),
                    Expanded(
                      child: Text('AJUSTES',
                          textAlign: TextAlign.center,
                          style: ClubType.plaqueTitle(22)),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 16),
                ClubPanel(
                  child: Column(
                    children: [
                      _Row(
                        title: 'Music',
                        sub: 'Warm hall ambience',
                        control: BrassToggle(
                            value: s.musicOn,
                            onChanged: (v) {
                              s.setMusic(v);
                              setState(() {});
                            }),
                      ),
                      const _Divider(),
                      _Row(
                        title: 'Sound effects',
                        sub: 'Tile clacks & brass chimes',
                        control: BrassToggle(
                            value: s.sfxOn,
                            onChanged: (v) {
                              s.setSfx(v);
                              if (v) AudioService.instance.click();
                              setState(() {});
                            }),
                      ),
                      const _Divider(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('VOLUME',
                            style: ClubType.label(12,
                                color: ClubPalette.brassPale)),
                      ),
                      const SizedBox(height: 4),
                      BrassSlider(
                          value: s.volume,
                          onChanged: (v) {
                            s.setVolume(v);
                            setState(() {});
                          }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ClubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('BOT DIFFICULTY',
                          style: ClubType.label(12,
                              color: ClubPalette.brassPale)),
                      const SizedBox(height: 4),
                      Text('How sharp the house rivals play',
                          style: ClubType.bodyText(13,
                              color: ClubPalette.parchment)),
                      const SizedBox(height: 10),
                      Row(
                        children: BotDifficulty.values
                            .map((d) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: _Chip(
                                      label: _diffName(d),
                                      selected: s.difficulty == d,
                                      onTap: () {
                                        AudioService.instance.click();
                                        s.setDifficulty(d);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                ClubPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('MATCH TARGET',
                          style: ClubType.label(12,
                              color: ClubPalette.brassPale)),
                      const SizedBox(height: 4),
                      Text('Points needed to take the match',
                          style: ClubType.bodyText(13,
                              color: ClubPalette.parchment)),
                      const SizedBox(height: 10),
                      Row(
                        children: [100, 150, 200]
                            .map((t) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: _Chip(
                                      label: '$t',
                                      selected: s.matchTarget == t,
                                      onTap: () {
                                        AudioService.instance.click();
                                        s.setMatchTarget(t);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text('Takes effect on the next match',
                      style: ClubType.bodyText(13,
                          color: ClubPalette.parchment, italic: true)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _diffName(BotDifficulty d) => switch (d) {
        BotDifficulty.easy => 'Easy',
        BotDifficulty.normal => 'Normal',
        BotDifficulty.hard => 'Hard',
      };
}

class _Row extends StatelessWidget {
  final String title, sub;
  final Widget control;
  const _Row({required this.title, required this.sub, required this.control});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style:
                      ClubType.label(14, color: ClubPalette.brassPale)),
              Text(sub,
                  style:
                      ClubType.bodyText(12.5, color: ClubPalette.parchment)),
            ],
          ),
        ),
        control,
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 1,
      color: ClubPalette.brassDark.withValues(alpha: 0.5),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? ClubPalette.brassFace
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF2A2118), Color(0xFF171008)],
                ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected ? ClubPalette.brassDark : const Color(0xFF5C5140),
              width: 1.4),
        ),
        child: Text(label.toUpperCase(),
            textAlign: TextAlign.center,
            style: selected
                ? ClubType.engraved(14)
                : ClubType.label(13, color: ClubPalette.parchment)),
      ),
    );
  }
}
