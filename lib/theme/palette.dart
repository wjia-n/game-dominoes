import 'package:flutter/material.dart';

/// "Club de Dominó Habana" design tokens — the Stitch design system is the
/// visual source of truth. Vintage Havana social club: ivory tiles with brass
/// spinners on green baize felt, dark walnut rails, warm tungsten lamplight.
/// No neon, no glow, no cyberpunk — tactile pseudo-3D physical materials.
abstract final class ClubPalette {
  // Brass
  static const Color brass = Color(0xFFC5A059); // aged brass (primary)
  static const Color brassBright = Color(0xFFE9C176); // highlight
  static const Color brassPale = Color(0xFFE8D19F);
  static const Color brassDeep = Color(0xFF8C6C30); // shadow / borders
  static const Color brassDark = Color(0xFF7A5C28); // debossed edges

  // Felt
  static const Color felt = Color(0xFF1B382B); // billiard baize
  static const Color feltDeep = Color(0xFF14281E); // recessed wells
  static const Color feltVignette = Color(0xFF101F18); // perimeter vignette

  // Ivory
  static const Color ivory = Color(0xFFF0EAD6); // antique bone
  static const Color ivoryShadow = Color(0xFFE2D7BD); // tile edge shading
  static const Color carbon = Color(0xFF141414); // pips, carved inlays

  // Wood & leather
  static const Color oxblood = Color(0xFF8A3324);
  static const Color walnutDeep = Color(0xFF1A120B);
  static const Color walnut = Color(0xFF2C1D11);
  static const Color walnutLight = Color(0xFF4A3020);

  // Surfaces & text
  static const Color darkSurface = Color(0xFF151408);
  static const Color creamText = Color(0xFFE8E2CF);
  static const Color parchment = Color(0xFFD1C5B4);
  static const Color deboss = Color(0xFF2B1D0C); // engraved text on brass

  static const LinearGradient brassFace = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD8B878), Color(0xFFA9803C)],
  );
  static const LinearGradient walnutFace = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A2A18), Color(0xFF1A120B)],
  );
}

/// Type system: Libre Caslon Text (headlines), EB Garamond (body),
/// Space Grotesk (labels / numbers, letterspaced, stamped-brass feel).
abstract final class ClubType {
  static const String serif = 'LibreCaslon';
  static const String body = 'EBGaramond';
  static const String stamped = 'SpaceGrotesk';

  static TextStyle headline(double size, {Color? color}) => TextStyle(
        fontFamily: serif,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: color ?? ClubPalette.brassBright,
        letterSpacing: 1.2,
      );

  static TextStyle plaqueTitle(double size) => TextStyle(
        fontFamily: serif,
        fontWeight: FontWeight.w700,
        fontSize: size,
        color: ClubPalette.brassPale,
        letterSpacing: 2.0,
      );

  /// Engraved label on brass.
  static TextStyle engraved(double size, {bool bold = true}) => TextStyle(
        fontFamily: stamped,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        fontSize: size,
        color: ClubPalette.deboss,
        letterSpacing: 1.6,
      );

  static TextStyle label(double size, {Color? color}) => TextStyle(
        fontFamily: stamped,
        fontWeight: FontWeight.w600,
        fontSize: size,
        color: color ?? ClubPalette.parchment,
        letterSpacing: 1.4,
      );

  static TextStyle number(double size, {Color? color, bool bold = true}) =>
      TextStyle(
        fontFamily: stamped,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        fontSize: size,
        color: color ?? ClubPalette.brassBright,
        letterSpacing: 1.0,
      );

  static TextStyle bodyText(double size, {Color? color, bool italic = false}) =>
      TextStyle(
        fontFamily: body,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        fontSize: size,
        color: color ?? ClubPalette.creamText,
        height: 1.35,
      );
}
