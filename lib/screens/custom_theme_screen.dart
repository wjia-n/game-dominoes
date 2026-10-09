import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_store.dart';
import '../theme/club_themes.dart';
import '../theme/palette.dart';
import '../theme/physical.dart';

/// Build-your-own club theme: felt, wood, metal, tile face & pips from
/// curated club-appropriate swatches. PRO only — Free players see the offer.
class CustomThemeScreen extends StatefulWidget {
  final SettingsStore settings;
  const CustomThemeScreen({super.key, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  late final TextEditingController _name;
  late int _felt, _feltDeep, _walnut, _accent, _tileFace, _tilePip;

  static const _felts = [
    0xFF1B382B, 0xFF0E3B2E, 0xFF5E1F16, 0xFF1B2A4A, 0xFF243B1E, 0xFF4A3018,
    0xFF2B2B2E, 0xFF3A2415, 0xFF2E4430, 0xFF8A6F45, 0xFF1E2F5E, 0xFF3E3A34,
  ];
  static const _woods = [
    0xFF2C1D11, 0xFF38220F, 0xFF33200E, 0xFF221D30, 0xFF2B2010, 0xFF331E0C,
    0xFF1B1917, 0xFF28180A, 0xFF2E2614, 0xFF4A3016, 0xFF20160C, 0xFF1D1812,
  ];
  static const _metals = [
    0xFFC5A059, 0xFFB87333, 0xFFB9C2D4, 0xFFD4AF37, 0xFFC9A227, 0xFFA9713D,
    0xFFA8A9AD, 0xFFE0B45C, 0xFF8FAE6B, 0xFFD9A93F, 0xFFCBB26A, 0xFFD4A72C,
  ];
  static const _faces = [
    0xFFF0EAD6, 0xFFE4D3A8, 0xFF1E1C18, 0xFFF7F4EC, 0xFF6B4426, 0xFFC5A059,
    0xFFEFE6DA, 0xFFEFF3F8, 0xFF7A4A22, 0xFF3E6B52, 0xFF8A3324, 0xFF3E3A34,
  ];
  static const _pips = [
    0xFF141414, 0xFF1E1A12, 0xFFF0EAD6, 0xFF2A2A30, 0xFFF5EEDC, 0xFF2B1D0C,
    0xFF4A3B2A, 0xFF1E3A5E, 0xFFF8F0DC, 0xFFF0EAD6, 0xFFF5EBD4, 0xFFD4AF37,
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.settings.customTheme ?? const CustomClubTheme();
    _name = TextEditingController(text: c.name);
    _felt = c.felt;
    _feltDeep = c.feltDeep;
    _walnut = c.walnut;
    _accent = c.accent;
    _tileFace = c.tileFace;
    _tilePip = c.tilePip;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  CustomClubTheme get _built => CustomClubTheme(
        name: _name.text.trim().isEmpty ? 'Mi Mesa' : _name.text.trim(),
        felt: _felt,
        feltDeep: _feltDeep,
        walnut: _walnut,
        accent: _accent,
        tileFace: _tileFace,
        tilePip: _tilePip,
      );

  void _save() {
    if (!widget.settings.unlocked(isProItem: true)) {
      AudioService.instance.invalid();
      Navigator.of(context).pop();
      return;
    }
    AudioService.instance.click();
    widget.settings.setCustomTheme(_built);
    widget.settings.setThemeId('custom');
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Your table is dressed — enjoy, ${_built.name}.',
            style: ClubType.bodyText(14)),
        backgroundColor: ClubPalette.walnut,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _built.toThemeDef();
    final tilePreview = TileStyleDef(
      id: 'custom',
      name: 'Custom',
      face: Color(_tileFace),
      faceShadow: Color(_feltDeep),
      pip: Color(_tilePip),
      rivet: Color(_accent),
      divider: Color(_feltDeep),
    );
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
        title: Text('YOUR TABLE', style: ClubType.plaqueTitle(20)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Live preview.
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ClubPalette.brassDark, width: 1.6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: FeltTable(
                    theme: preview,
                    child: Center(
                      child: DominoTile(
                          first: 6,
                          second: 4,
                          width: 40,
                          vertical: false,
                          style: tilePreview),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _NameField(controller: _name, onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              _SwatchRow(
                  label: 'Felt',
                  options: _felts,
                  value: _felt,
                  onPick: (v) => setState(() => _felt = v)),
              _SwatchRow(
                  label: 'Felt depth',
                  options: _felts,
                  value: _feltDeep,
                  onPick: (v) => setState(() => _feltDeep = v)),
              _SwatchRow(
                  label: 'Wood rails',
                  options: _woods,
                  value: _walnut,
                  onPick: (v) => setState(() => _walnut = v)),
              _SwatchRow(
                  label: 'Metal fittings',
                  options: _metals,
                  value: _accent,
                  onPick: (v) => setState(() => _accent = v)),
              _SwatchRow(
                  label: 'Tile face',
                  options: _faces,
                  value: _tileFace,
                  onPick: (v) => setState(() => _tileFace = v)),
              _SwatchRow(
                  label: 'Pips',
                  options: _pips,
                  value: _tilePip,
                  onPick: (v) => setState(() => _tilePip = v)),
              const SizedBox(height: 16),
              BrassButton(label: 'Dress the table', onTap: _save),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _NameField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TABLE NAME',
            style: ClubType.label(12, color: ClubPalette.brassBright)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          onChanged: onChanged,
          maxLength: 18,
          style: ClubType.bodyText(16),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: ClubPalette.feltDeep,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: ClubPalette.brassDark, width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: ClubPalette.brassBright, width: 1.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwatchRow extends StatelessWidget {
  final String label;
  final List<int> options;
  final int value;
  final ValueChanged<int> onPick;
  const _SwatchRow(
      {required this.label,
      required this.options,
      required this.value,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: ClubType.label(12, color: ClubPalette.brassBright)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((c) {
              final selected = c == value;
              return GestureDetector(
                onTap: () {
                  AudioService.instance.click();
                  onPick(c);
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(c),
                    border: Border.all(
                        color: selected
                            ? ClubPalette.brassBright
                            : Colors.black.withValues(alpha: 0.5),
                        width: selected ? 2.6 : 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
