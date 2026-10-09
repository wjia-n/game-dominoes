import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_store.dart';
import '../theme/club_themes.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// The club's wardrobe: 12 table themes, 10 tile styles, 6 table accents,
/// and the custom theme creator. Locked items show a PRO badge.
class ThemeScreen extends StatelessWidget {
  final SettingsStore settings;
  final StoreService? store;
  const ThemeScreen({super.key, required this.settings, this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubPalette.darkSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ClubPalette.brassBright),
          onPressed: () {
            AudioService.instance.click();
            Navigator.of(context).pop();
          },
        ),
        title: Text('TABLE & TILES', style: ClubType.plaqueTitle(20)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (_, _) => SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SectionTitle('Table themes', 'Felt, wood & metal finishes'),
                const SizedBox(height: 8),
                _ThemeGrid(settings: settings, store: store),
                if (settings.customTheme != null) ...[
                  const SizedBox(height: 8),
                  _CustomRow(settings: settings, store: store),
                ],
                const SizedBox(height: 18),
                _SectionTitle('Tile styles', 'The bone in your hand'),
                const SizedBox(height: 8),
                _TileStyleGrid(settings: settings),
                const SizedBox(height: 18),
                _SectionTitle('Table accents', 'Name-plate & plaque trim'),
                const SizedBox(height: 8),
                _AccentRow(settings: settings),
                const SizedBox(height: 18),
                OxbloodButton(
                  label: 'Create your own theme',
                  onTap: () {
                    if (!settings.unlocked(isProItem: true)) {
                      _maybePro(context, settings, store, true);
                      return;
                    }
                    AudioService.instance.click();
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                            builder: (_) => CustomThemeScreen(
                                settings: settings)))
                        .then((_) {});
                  },
                ),
                const SizedBox(height: 8),
                if (!settings.pro)
                  Text(
                    'PRO unlocks every finish — one purchase, yours forever.',
                    textAlign: TextAlign.center,
                    style: ClubType.bodyText(13,
                        color: ClubPalette.parchment, italic: true),
                  ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title, sub;
  const _SectionTitle(this.title, this.sub);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: ClubType.label(13, color: ClubPalette.brassBright)),
        Text(sub,
            style: ClubType.bodyText(12.5, color: ClubPalette.parchment)),
      ],
    );
  }
}

void _maybePro(BuildContext context, SettingsStore settings,
    StoreService? store, bool locked) {
  if (!locked) return;
  AudioService.instance.invalid();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          if (store != null) {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    ProScreen(settings: settings, store: store)));
          }
        },
        child: Text('That finish is PRO — tap to see the club offer.',
            style: ClubType.bodyText(14, color: ClubPalette.brassPale)),
      ),
      backgroundColor: ClubPalette.walnut,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ),
  );
}

class _ThemeGrid extends StatelessWidget {
  final SettingsStore settings;
  final StoreService? store;
  const _ThemeGrid({required this.settings, required this.store});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: ClubThemes.all.length,
      itemBuilder: (_, i) {
        final t = ClubThemes.all[i];
        final selected = settings.themeId == t.id;
        final locked = !settings.unlocked(isProItem: t.pro);
        return GestureDetector(
          onTap: () {
            if (locked) {
              _maybePro(context, settings, store, true);
              return;
            }
            AudioService.instance.click();
            settings.setThemeId(t.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: selected
                      ? ClubPalette.brassBright
                      : ClubPalette.brassDark.withValues(alpha: 0.5),
                  width: selected ? 2.4 : 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: t.felt),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            t.walnutLight.withValues(alpha: 0.55),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 7,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(t.name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ClubType.label(11.5,
                                      color: t.creamText)),
                            ),
                            if (t.pro && !settings.pro)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: t.accentBright, width: 1),
                                ),
                                child: Text('PRO',
                                    style: ClubType.label(9,
                                        color: t.accentBright)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // felt + wood + metal swatches
                        Row(
                          children: [
                            _Swatch(t.felt),
                            _Swatch(t.walnut),
                            _Swatch(t.accent),
                            _Swatch(t.accentBright),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      right: 6,
                      top: 6,
                      child: Icon(Icons.check_circle,
                          color: ClubPalette.brassBright, size: 20),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Swatch extends StatelessWidget {
  final Color color;
  const _Swatch(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(right: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
            color: Colors.black.withValues(alpha: 0.5), width: 1),
      ),
    );
  }
}

class _CustomRow extends StatelessWidget {
  final SettingsStore settings;
  final StoreService? store;
  const _CustomRow({required this.settings, this.store});

  @override
  Widget build(BuildContext context) {
    final c = settings.customTheme!;
    final selected = settings.themeId == 'custom';
    return GestureDetector(
      onTap: () {
        if (!settings.unlocked(isProItem: true)) {
          _maybePro(context, settings, store, true);
          return;
        }
        AudioService.instance.click();
        settings.setThemeId('custom');
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? ClubPalette.brassBright
                  : ClubPalette.brassDark.withValues(alpha: 0.5),
              width: selected ? 2.4 : 1.2),
          color: Color(c.felt),
        ),
        child: Row(
          children: [
            _Swatch(Color(c.felt)),
            _Swatch(Color(c.walnut)),
            _Swatch(Color(c.accent)),
            _Swatch(Color(c.tileFace)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(c.name,
                  style: ClubType.label(13, color: Colors.white)),
            ),
            if (selected)
              const Icon(Icons.check_circle,
                  color: ClubPalette.brassBright, size: 20),
          ],
        ),
      ),
    );
  }
}

class _TileStyleGrid extends StatelessWidget {
  final SettingsStore settings;
  const _TileStyleGrid({required this.settings});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: TileStyles.all.length,
      itemBuilder: (_, i) {
        final s = TileStyles.all[i];
        final selected = settings.tileStyleId == s.id;
        final locked = !settings.unlocked(isProItem: s.pro);
        return GestureDetector(
          onTap: () {
            if (locked) {
              _maybePro(context, settings, null, true);
              return;
            }
            AudioService.instance.click();
            settings.setTileStyleId(s.id);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF1E150C),
              border: Border.all(
                  color: selected
                      ? ClubPalette.brassBright
                      : ClubPalette.brassDark.withValues(alpha: 0.5),
                  width: selected ? 2.4 : 1.2),
            ),
            child: Row(
              children: [
                DominoTile(
                    first: 6,
                    second: 3,
                    width: 26,
                    vertical: true,
                    style: s),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ClubType.label(11.5,
                              color: ClubPalette.creamText)),
                      if (s.pro && !settings.pro)
                        Text('PRO',
                            style: ClubType.label(9,
                                color: ClubPalette.brassBright)),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle,
                      color: ClubPalette.brassBright, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AccentRow extends StatelessWidget {
  final SettingsStore settings;
  const _AccentRow({required this.settings});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: TableAccents.all.map((a) {
        final selected = settings.tableAccentId == a.id;
        final locked = !settings.unlocked(isProItem: a.pro);
        return GestureDetector(
          onTap: () {
            if (locked) {
              _maybePro(context, settings, null, true);
              return;
            }
            AudioService.instance.click();
            settings.setTableAccentId(a.id);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.35),
                    radius: 1.15,
                    colors: [
                      Color.lerp(a.color, Colors.white, 0.3) ?? a.color,
                      a.color,
                      a.deep,
                    ],
                  ),
                  border: Border.all(
                      color: selected
                          ? ClubPalette.brassBright
                          : a.deep,
                      width: selected ? 2.6 : 1.4),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 5,
                        offset: const Offset(0, 2.5)),
                  ],
                ),
                child: locked && !settings.pro
                    ? const Icon(Icons.lock,
                        color: Colors.white70, size: 18)
                    : selected
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 20)
                        : null,
              ),
              const SizedBox(height: 4),
              Text(a.name,
                  style: ClubType.label(10,
                      color: selected
                          ? ClubPalette.brassBright
                          : ClubPalette.parchment)),
            ],
          ),
        );
      }).toList(),
    );
  }
}
