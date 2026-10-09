import 'package:flutter/material.dart';

/// "Club de Dominó Habana" theme catalog — every theme stays inside the
/// vintage Havana club material world (real woods, brass/copper/silver,
/// bone tiles, billiard felts). Variety comes from different felts, woods,
/// metal accents and tile materials — never neon, never generic.
///
/// The first 4 themes and 4 tile styles are FREE; the rest unlock with PRO.
class ClubThemeDef {
  final String id;
  final String name;
  final String mood;
  final Color felt;
  final Color feltDeep;
  final Color feltVignette;
  final Color walnutDeep;
  final Color walnut;
  final Color walnutLight;
  final Color accent; // brass / copper / silver …
  final Color accentBright;
  final Color accentDeep;
  final Color creamText;
  final Color parchment;
  final Color deboss;
  final bool pro;

  const ClubThemeDef({
    required this.id,
    required this.name,
    required this.mood,
    required this.felt,
    required this.feltDeep,
    required this.feltVignette,
    required this.walnutDeep,
    required this.walnut,
    required this.walnutLight,
    required this.accent,
    required this.accentBright,
    required this.accentDeep,
    required this.creamText,
    required this.parchment,
    required this.deboss,
    this.pro = false,
  });
}

/// Physical domino tile material.
class TileStyleDef {
  final String id;
  final String name;
  final Color face;
  final Color faceShadow;
  final Color pip;
  final Color rivet;
  final Color divider;
  final bool pro;

  const TileStyleDef({
    required this.id,
    required this.name,
    required this.face,
    required this.faceShadow,
    required this.pip,
    required this.rivet,
    required this.divider,
    this.pro = false,
  });
}

/// Table accent trim for name plates / plaques.
class TableAccentDef {
  final String id;
  final String name;
  final Color color;
  final Color deep;
  final bool pro;

  const TableAccentDef({
    required this.id,
    required this.name,
    required this.color,
    required this.deep,
    this.pro = false,
  });
}

class ClubThemes {
  static const List<String> freeThemeIds = [
    'habana',
    'esmeralda',
    'oxblood',
    'medianoche',
  ];

  static const List<ClubThemeDef> all = [
    ClubThemeDef(
      id: 'habana',
      name: 'Habana Clásica',
      mood: 'The house table — green baize, walnut, aged brass',
      felt: Color(0xFF1B382B),
      feltDeep: Color(0xFF14281E),
      feltVignette: Color(0xFF101F18),
      walnutDeep: Color(0xFF1A120B),
      walnut: Color(0xFF2C1D11),
      walnutLight: Color(0xFF4A3020),
      accent: Color(0xFFC5A059),
      accentBright: Color(0xFFE9C176),
      accentDeep: Color(0xFF7A5C28),
      creamText: Color(0xFFE8E2CF),
      parchment: Color(0xFFD1C5B4),
      deboss: Color(0xFF2B1D0C),
    ),
    ClubThemeDef(
      id: 'esmeralda',
      name: 'Esmeralda',
      mood: 'Deep casino green with copper fittings',
      felt: Color(0xFF0E3B2E),
      feltDeep: Color(0xFF0A2B21),
      feltVignette: Color(0xFF071F18),
      walnutDeep: Color(0xFF201208),
      walnut: Color(0xFF38220F),
      walnutLight: Color(0xFF5A3A1E),
      accent: Color(0xFFB87333),
      accentBright: Color(0xFFE8A35C),
      accentDeep: Color(0xFF7A4A1E),
      creamText: Color(0xFFF0EAD6),
      parchment: Color(0xFFD8CDB4),
      deboss: Color(0xFF2B1A0C),
    ),
    ClubThemeDef(
      id: 'oxblood',
      name: 'Oxblood Salón',
      mood: 'Ox-red felt, dark mahogany, bright brass',
      felt: Color(0xFF5E1F16),
      feltDeep: Color(0xFF471710),
      feltVignette: Color(0xFF33110B),
      walnutDeep: Color(0xFF1E0E06),
      walnut: Color(0xFF33200E),
      walnutLight: Color(0xFF553620),
      accent: Color(0xFFD4AF37),
      accentBright: Color(0xFFF3DC8E),
      accentDeep: Color(0xFF96702A),
      creamText: Color(0xFFF5EEDC),
      parchment: Color(0xFFE0D3B8),
      deboss: Color(0xFF2E1C08),
    ),
    ClubThemeDef(
      id: 'medianoche',
      name: 'Medianoche',
      mood: 'Midnight-blue felt, silvered fittings',
      felt: Color(0xFF1B2A4A),
      feltDeep: Color(0xFF141E36),
      feltVignette: Color(0xFF0E1526),
      walnutDeep: Color(0xFF12101A),
      walnut: Color(0xFF221D30),
      walnutLight: Color(0xFF3A3048),
      accent: Color(0xFFB9C2D4),
      accentBright: Color(0xFFE8ECF5),
      accentDeep: Color(0xFF6E7688),
      creamText: Color(0xFFF0EDE2),
      parchment: Color(0xFFD6D2C2),
      deboss: Color(0xFF1E2030),
    ),
    ClubThemeDef(
      id: 'sierra',
      name: 'Sierra Maestra',
      mood: 'Forest felt, smoked oak, antique gold',
      felt: Color(0xFF243B1E),
      feltDeep: Color(0xFF1A2C15),
      feltVignette: Color(0xFF121F0F),
      walnutDeep: Color(0xFF171006),
      walnut: Color(0xFF2B2010),
      walnutLight: Color(0xFF4A3820),
      accent: Color(0xFFC9A227),
      accentBright: Color(0xFFEFD27A),
      accentDeep: Color(0xFF86690F),
      creamText: Color(0xFFF2ECDA),
      parchment: Color(0xFFD8CEB2),
      deboss: Color(0xFF2A2108),
      pro: true,
    ),
    ClubThemeDef(
      id: 'cobre',
      name: 'Cobre Viejo',
      mood: 'Tobacco felt, chestnut rails, old copper',
      felt: Color(0xFF4A3018),
      feltDeep: Color(0xFF38230F),
      feltVignette: Color(0xFF261809),
      walnutDeep: Color(0xFF1C1006),
      walnut: Color(0xFF331E0C),
      walnutLight: Color(0xFF57351C),
      accent: Color(0xFFA9713D),
      accentBright: Color(0xFFDEA468),
      accentDeep: Color(0xFF6E4420),
      creamText: Color(0xFFF5EBD4),
      parchment: Color(0xFFE0D2B0),
      deboss: Color(0xFF2E1E0A),
      pro: true,
    ),
    ClubThemeDef(
      id: 'plata',
      name: 'Plata Antigua',
      mood: 'Charcoal felt, ebonized wood, tarnished silver',
      felt: Color(0xFF2B2B2E),
      feltDeep: Color(0xFF1F1F22),
      feltVignette: Color(0xFF151517),
      walnutDeep: Color(0xFF0C0B0A),
      walnut: Color(0xFF1B1917),
      walnutLight: Color(0xFF35302A),
      accent: Color(0xFFA8A9AD),
      accentBright: Color(0xFFDCDDE0),
      accentDeep: Color(0xFF636468),
      creamText: Color(0xFFF2EFE6),
      parchment: Color(0xFFD5D1C4),
      deboss: Color(0xFF232326),
      pro: true,
    ),
    ClubThemeDef(
      id: 'cafe',
      name: 'Café Cubano',
      mood: 'Espresso felt, cedar rails, bright brass',
      felt: Color(0xFF3A2415),
      feltDeep: Color(0xFF2A1A0E),
      feltVignette: Color(0xFF1D1209),
      walnutDeep: Color(0xFF140C05),
      walnut: Color(0xFF28180A),
      walnutLight: Color(0xFF482E16),
      accent: Color(0xFFE0B45C),
      accentBright: Color(0xFFF7D894),
      accentDeep: Color(0xFF9A7430),
      creamText: Color(0xFFF8F0DC),
      parchment: Color(0xFFE4D6B4),
      deboss: Color(0xFF33200C),
      pro: true,
    ),
    ClubThemeDef(
      id: 'jardin',
      name: 'Jardín Secreto',
      mood: 'Moss felt, olivewood rails, verdigris brass',
      felt: Color(0xFF2E4430),
      feltDeep: Color(0xFF223322),
      feltVignette: Color(0xFF182418),
      walnutDeep: Color(0xFF1A1408),
      walnut: Color(0xFF2E2614),
      walnutLight: Color(0xFF50401F),
      accent: Color(0xFF8FAE6B),
      accentBright: Color(0xFFC2D69B),
      accentDeep: Color(0xFF5C723F),
      creamText: Color(0xFFF0EAD6),
      parchment: Color(0xFFD2C8AC),
      deboss: Color(0xFF23301A),
      pro: true,
    ),
    ClubThemeDef(
      id: 'madera',
      name: 'Madera Clara',
      mood: 'Sand felt, honey-oak rails, polished brass',
      felt: Color(0xFF8A6F45),
      feltDeep: Color(0xFF6B5533),
      feltVignette: Color(0xFF4D3D24),
      walnutDeep: Color(0xFF2A1C0C),
      walnut: Color(0xFF4A3016),
      walnutLight: Color(0xFF7A5526),
      accent: Color(0xFFD9A93F),
      accentBright: Color(0xFFF5D47E),
      accentDeep: Color(0xFF966F1E),
      creamText: Color(0xFF2B1D0C),
      parchment: Color(0xFF4A3820),
      deboss: Color(0xFFF5EBD4),
      pro: true,
    ),
    ClubThemeDef(
      id: 'tinta',
      name: 'Tinta Azul',
      mood: 'Ink-blue felt, walnut, champagne gold',
      felt: Color(0xFF1E2F5E),
      feltDeep: Color(0xFF162344),
      feltVignette: Color(0xFF0F1830),
      walnutDeep: Color(0xFF100C08),
      walnut: Color(0xFF20160C),
      walnutLight: Color(0xFF3E2C16),
      accent: Color(0xFFCBB26A),
      accentBright: Color(0xFFF0D894),
      accentDeep: Color(0xFF8A7136),
      creamText: Color(0xFFF2EDDC),
      parchment: Color(0xFFD8D0B4),
      deboss: Color(0xFF25200E),
      pro: true,
    ),
    ClubThemeDef(
      id: 'ceniza',
      name: 'Ceniza y Oro',
      mood: 'Ash-grey felt, blackwood, rich gold',
      felt: Color(0xFF3E3A34),
      feltDeep: Color(0xFF2D2A25),
      feltVignette: Color(0xFF1E1C18),
      walnutDeep: Color(0xFF0E0B08),
      walnut: Color(0xFF1D1812),
      walnutLight: Color(0xFF38301F),
      accent: Color(0xFFD4A72C),
      accentBright: Color(0xFFF2CE6E),
      accentDeep: Color(0xFF8F6D14),
      creamText: Color(0xFFF4EEDC),
      parchment: Color(0xFFDAD2B8),
      deboss: Color(0xFF2E2308),
      pro: true,
    ),
  ];

  static ClubThemeDef byId(String id, {CustomClubTheme? custom}) {
    if (id == 'custom' && custom != null) {
      return custom.toThemeDef();
    }
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }

  /// A custom (player-built) club theme.
  static ClubThemeDef customDef(CustomClubTheme c) => c.toThemeDef();
}

/// Custom theme built in the theme creator.
class CustomClubTheme {
  final String name;
  final int felt;
  final int feltDeep;
  final int walnut;
  final int accent;
  final int tileFace;
  final int tilePip;

  const CustomClubTheme({
    this.name = 'Mi Mesa',
    this.felt = 0xFF1B382B,
    this.feltDeep = 0xFF14281E,
    this.walnut = 0xFF2C1D11,
    this.accent = 0xFFC5A059,
    this.tileFace = 0xFFF0EAD6,
    this.tilePip = 0xFF141414,
  });

  ClubThemeDef toThemeDef() => ClubThemeDef(
        id: 'custom',
        name: name,
        mood: 'Built at your own table',
        felt: Color(felt),
        feltDeep: Color(feltDeep),
        feltVignette: Color(feltDeep),
        walnutDeep: const Color(0xFF14100A),
        walnut: Color(walnut),
        walnutLight: Color(walnut),
        accent: Color(accent),
        accentBright: Color(accent),
        accentDeep: Color(accent),
        creamText: const Color(0xFFE8E2CF),
        parchment: const Color(0xFFD1C5B4),
        deboss: const Color(0xFF2B1D0C),
        pro: true,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'felt': felt,
        'feltDeep': feltDeep,
        'walnut': walnut,
        'accent': accent,
        'tileFace': tileFace,
        'tilePip': tilePip,
      };

  factory CustomClubTheme.fromJson(Map<String, dynamic> j) => CustomClubTheme(
        name: j['name'] as String? ?? 'Mi Mesa',
        felt: (j['felt'] as num?)?.toInt() ?? 0xFF1B382B,
        feltDeep: (j['feltDeep'] as num?)?.toInt() ?? 0xFF14281E,
        walnut: (j['walnut'] as num?)?.toInt() ?? 0xFF2C1D11,
        accent: (j['accent'] as num?)?.toInt() ?? 0xFFC5A059,
        tileFace: (j['tileFace'] as num?)?.toInt() ?? 0xFFF0EAD6,
        tilePip: (j['tilePip'] as num?)?.toInt() ?? 0xFF141414,
      );
}

class TileStyles {
  static const List<String> freeStyleIds = [
    'hueso',
    'envejecido',
    'ebano',
    'marmol',
  ];

  static const List<TileStyleDef> all = [
    TileStyleDef(
      id: 'hueso',
      name: 'Hueso Clásico',
      face: Color(0xFFF0EAD6),
      faceShadow: Color(0xFFE2D7BD),
      pip: Color(0xFF141414),
      rivet: Color(0xFFC5A059),
      divider: Color(0xFFB8A87F),
    ),
    TileStyleDef(
      id: 'envejecido',
      name: 'Hueso Envejecido',
      face: Color(0xFFE4D3A8),
      faceShadow: Color(0xFFCDB684),
      pip: Color(0xFF1E1A12),
      rivet: Color(0xFF8C6C30),
      divider: Color(0xFFB09B62),
    ),
    TileStyleDef(
      id: 'ebano',
      name: 'Ébano',
      face: Color(0xFF1E1C18),
      faceShadow: Color(0xFF0E0D0B),
      pip: Color(0xFFF0EAD6),
      rivet: Color(0xFFC5A059),
      divider: Color(0xFF3A362E),
    ),
    TileStyleDef(
      id: 'marmol',
      name: 'Mármol Blanco',
      face: Color(0xFFF7F4EC),
      faceShadow: Color(0xFFDCD6C4),
      pip: Color(0xFF2A2A30),
      rivet: Color(0xFFB9C2D4),
      divider: Color(0xFFC4BCA6),
    ),
    TileStyleDef(
      id: 'nogal',
      name: 'Nogal Tallado',
      face: Color(0xFF6B4426),
      faceShadow: Color(0xFF4A2D16),
      pip: Color(0xFFF5EEDC),
      rivet: Color(0xFFE9C176),
      divider: Color(0xFF3E2410),
      pro: true,
    ),
    TileStyleDef(
      id: 'laton',
      name: 'Latón Macizo',
      face: Color(0xFFC5A059),
      faceShadow: Color(0xFF8C6C30),
      pip: Color(0xFF2B1D0C),
      rivet: Color(0xFF5E451A),
      divider: Color(0xFF8C6C30),
      pro: true,
    ),
    TileStyleDef(
      id: 'perla',
      name: 'Madreperla',
      face: Color(0xFFEFE6DA),
      faceShadow: Color(0xFFD3C6B4),
      pip: Color(0xFF4A3B2A),
      rivet: Color(0xFFD4AF37),
      divider: Color(0xFFB8A88E),
      pro: true,
    ),
    TileStyleDef(
      id: 'porcelana',
      name: 'Porcelana Azul',
      face: Color(0xFFEFF3F8),
      faceShadow: Color(0xFFCBD6E2),
      pip: Color(0xFF1E3A5E),
      rivet: Color(0xFFCBB26A),
      divider: Color(0xFFA9B8CC),
      pro: true,
    ),
    TileStyleDef(
      id: 'carey',
      name: 'Carey',
      face: Color(0xFF7A4A22),
      faceShadow: Color(0xFF542F12),
      pip: Color(0xFFF8F0DC),
      rivet: Color(0xFFC5A059),
      divider: Color(0xFF45260C),
      pro: true,
    ),
    TileStyleDef(
      id: 'jade',
      name: 'Jade Antiguo',
      face: Color(0xFF3E6B52),
      faceShadow: Color(0xFF2A4A38),
      pip: Color(0xFFF0EAD6),
      rivet: Color(0xFFD4AF37),
      divider: Color(0xFF1E3328),
      pro: true,
    ),
  ];

  static TileStyleDef byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return all.first;
  }
}

class TableAccents {
  static const List<TableAccentDef> all = [
    TableAccentDef(
        id: 'laton',
        name: 'Latón',
        color: Color(0xFFC5A059),
        deep: Color(0xFF7A5C28)),
    TableAccentDef(
        id: 'cobre',
        name: 'Cobre',
        color: Color(0xFFB87333),
        deep: Color(0xFF6E4420)),
    TableAccentDef(
        id: 'plata',
        name: 'Plata',
        color: Color(0xFFB9C2D4),
        deep: Color(0xFF636468)),
    TableAccentDef(
        id: 'sangre',
        name: 'Oxblood',
        color: Color(0xFF8A3324),
        deep: Color(0xFF471710)),
    TableAccentDef(
        id: 'esmeralda',
        name: 'Esmeralda',
        color: Color(0xFF1B7A4D),
        deep: Color(0xFF0E3B2E),
        pro: true),
    TableAccentDef(
        id: 'tinta',
        name: 'Tinta',
        color: Color(0xFF1E3A5E),
        deep: Color(0xFF0F1830),
        pro: true),
  ];

  static TableAccentDef byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return all.first;
  }
}
