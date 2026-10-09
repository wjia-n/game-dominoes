import 'dart:math';
import 'package:flutter/material.dart';
import 'club_themes.dart';
import 'palette.dart';

// ---------------------------------------------------------------------------
// Felt — billiard baize table surface with cloth grain, tungsten top-light
// and a perimeter vignette. Single overhead light, no glow.
// ---------------------------------------------------------------------------
class FeltPainter extends CustomPainter {
  final int seed;
  final ClubThemeDef? theme;
  const FeltPainter({this.seed = 7, this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final t = theme;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = t?.felt ?? ClubPalette.felt);

    // cloth grain
    final rng = Random(seed);
    for (int i = 0; i < 1500; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final light = rng.nextBool();
      canvas.drawCircle(
        Offset(x, y),
        0.6 + rng.nextDouble() * 0.9,
        Paint()
          ..color = light
              ? Colors.white.withValues(alpha: 0.016 + rng.nextDouble() * 0.02)
              : Colors.black.withValues(alpha: 0.03 + rng.nextDouble() * 0.04),
      );
    }
    // faint weave lines
    final weave = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 0.6;
    for (double y = 0; y < size.height; y += 5) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), weave);
    }

    // warm tungsten wash from the top
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x12FFE9C0), Color(0x00000000)],
          stops: [0.0, 0.45],
        ).createShader(rect),
    );
    // perimeter vignette
    final vig = t?.feltVignette ?? const Color(0xFF101F18);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.15),
          radius: 1.25,
          colors: [const Color(0x00000000), vig.withValues(alpha: 0.85)],
          stops: const [0.45, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant FeltPainter old) =>
      old.seed != seed || old.theme?.id != theme?.id;
}

class FeltTable extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry borderRadius;
  final ClubThemeDef? theme;
  const FeltTable(
      {super.key,
      required this.child,
      this.borderRadius = BorderRadius.zero,
      this.theme});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: CustomPaint(painter: FeltPainter(theme: theme), child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// Domino tile — aged bone with carved carbon pips, divider groove and a
// centered brass rivet. Cast shadow + micro-bevel sell the physical weight.
// ---------------------------------------------------------------------------

/// Standard pip layouts on a 3x3 grid (indices 0..8).
const Map<int, List<int>> pipLayouts = {
  0: [],
  1: [4],
  2: [2, 6],
  3: [2, 4, 6],
  4: [0, 2, 6, 8],
  5: [0, 2, 4, 6, 8],
  6: [0, 2, 3, 5, 6, 8],
};

class DominoTilePainter extends CustomPainter {
  /// Pips on the leading half (top when vertical, left when horizontal).
  final int first;
  final int second;
  final bool vertical;
  final bool faceDown;
  final double elevation;
  final TileStyleDef? style;

  const DominoTilePainter({
    required this.first,
    required this.second,
    this.vertical = true,
    this.faceDown = false,
    this.elevation = 1.0,
    this.style,
  });

  Color get _face => style?.face ?? ClubPalette.ivory;
  Color get _faceShadow => style?.faceShadow ?? ClubPalette.ivoryShadow;
  Color get _pip => style?.pip ?? ClubPalette.carbon;
  Color get _rivet => style?.rivet ?? ClubPalette.brass;
  Color get _divider => style?.divider ?? const Color(0xFFB8A87F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final radius = min(w, h) * 0.16;
    final body =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));

    // cast shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.42 * elevation)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.save();
    canvas.translate(0, 3.5 * elevation);
    canvas.drawRRect(body, shadowPaint);
    canvas.restore();
    // ambient occlusion contact edge
    canvas.drawRRect(
      body,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    if (faceDown) {
      _paintBack(canvas, size, body, radius);
      return;
    }

    // bone body: radial face fade, lit from top-center
    final faceMid = Color.lerp(_face, _faceShadow, 0.45) ?? _face;
    canvas.drawRRect(
      body,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.45),
          radius: 1.15,
          colors: [_face, faceMid, _faceShadow],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
    // 1px ivory top highlight (micro-bevel catching the lamp)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(1.5, 1.5, w - 3, h - 3),
        Radius.circular(radius * 0.85),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xA6FFFDF2),
    );
    // lower edge shade
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = const Color(0x8C9C8B66),
    );

    if (vertical) {
      _paintHalf(canvas, first, Rect.fromLTWH(0, 0, w, h / 2));
      _paintHalf(canvas, second, Rect.fromLTWH(0, h / 2, w, h / 2));
      _paintGroove(canvas, Offset(w / 2, h / 2), true, w);
    } else {
      _paintHalf(canvas, first, Rect.fromLTWH(0, 0, w / 2, h));
      _paintHalf(canvas, second, Rect.fromLTWH(w / 2, 0, w / 2, h));
      _paintGroove(canvas, Offset(w / 2, h / 2), false, h);
    }
  }

  void _paintHalf(Canvas canvas, int value, Rect half) {
    final spots = pipLayouts[value] ?? const [];
    final cellW = half.width / 3, cellH = half.height / 3;
    final r = min(cellW, cellH) * 0.30;
    for (final s in spots) {
      final cx = half.left + (s % 3 + 0.5) * cellW;
      final cy = half.top + (s ~/ 3 + 0.5) * cellH;
      // carved recess: soft dark pocket, pip, faint top-left catchlight
      canvas.drawCircle(Offset(cx, cy + r * 0.35), r,
          Paint()..color = Colors.black.withValues(alpha: 0.30));
      canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _pip);
      canvas.drawCircle(Offset(cx - r * 0.25, cy - r * 0.3), r * 0.32,
          Paint()..color = const Color(0x29F0EAD6));
    }
  }

  void _paintGroove(Canvas canvas, Offset center, bool horizontal, double len) {
    final half = len * 0.36;
    final p1 =
        horizontal ? center + Offset(-half, 0) : center + Offset(0, -half);
    final p2 =
        horizontal ? center + Offset(half, 0) : center + Offset(0, half);
    final divDark =
        Color.lerp(_divider, Colors.black, 0.25) ?? _divider;
    // recessed channel
    canvas.drawLine(
        p1 + const Offset(0, 1.2),
        p2 + const Offset(0, 1.2),
        Paint()
          ..color = divDark
          ..strokeWidth = 3.2);
    canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = _divider
          ..strokeWidth = 2.2);
    // centered rivet
    final rr = len * 0.075;
    final rivetLight = Color.lerp(_rivet, Colors.white, 0.35) ?? _rivet;
    final rivetDark = Color.lerp(_rivet, Colors.black, 0.4) ?? _rivet;
    canvas.drawCircle(center + const Offset(0, 1), rr,
        Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawCircle(
      center,
      rr,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          radius: 1.0,
          colors: [rivetLight, _rivet, rivetDark],
        ).createShader(Rect.fromCircle(center: center, radius: rr)),
    );
    canvas.drawCircle(
        center,
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = rivetDark);
  }

  void _paintBack(Canvas canvas, Size size, RRect body, double radius) {
    final w = size.width, h = size.height;
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2A18), Color(0xFF241610), Color(0xFF1A120B)],
        ).createShader(Offset.zero & size),
    );
    // brass inlay frame
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.08, w * 0.72, h * 0.84),
        Radius.circular(radius * 0.7),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.2, w * 0.035)
        ..color = ClubPalette.brass.withValues(alpha: 0.9),
    );
    // center brass diamond
    final c = Offset(w / 2, h / 2);
    final d = w * 0.16;
    final diamond = Path()
      ..moveTo(c.dx, c.dy - d)
      ..lineTo(c.dx + d, c.dy)
      ..lineTo(c.dx, c.dy + d)
      ..lineTo(c.dx - d, c.dy)
      ..close();
    canvas.drawPath(
        diamond, Paint()..color = ClubPalette.brass.withValues(alpha: 0.85));
    canvas.drawPath(
        diamond,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ClubPalette.brassDark);
  }

  @override
  bool shouldRepaint(covariant DominoTilePainter old) =>
      old.first != first ||
      old.second != second ||
      old.vertical != vertical ||
      old.faceDown != faceDown ||
      old.style?.id != style?.id;
}

/// A physical domino tile widget.
class DominoTile extends StatelessWidget {
  final int first;
  final int second;
  final bool vertical;
  final bool faceDown;
  final double width;
  final double elevation;
  final TileStyleDef? style;

  const DominoTile({
    super.key,
    required this.first,
    required this.second,
    this.vertical = true,
    this.faceDown = false,
    required this.width,
    this.elevation = 1.0,
    this.style,
  });

  double get height => vertical ? width * 2 : width / 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: DominoTilePainter(
          first: first,
          second: second,
          vertical: vertical,
          faceDown: faceDown,
          elevation: elevation,
          style: style,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Buttons — engraved brass plates & oxblood leather with stitched borders.
// ---------------------------------------------------------------------------
class BrassButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  final bool compact;
  const BrassButton({
    super.key,
    required this.label,
    this.onTap,
    this.fontSize = 17,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? () => onTap!() : null,
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 14 : 22, vertical: compact ? 8 : 13),
          decoration: BoxDecoration(
            gradient: ClubPalette.brassFace,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ClubPalette.brassDark, width: 1.6),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 6,
                  offset: const Offset(0, 3)),
              BoxShadow(
                  color: Colors.white.withValues(alpha: 0.22),
                  blurRadius: 1,
                  offset: const Offset(0, 1)),
            ],
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: ClubType.engraved(fontSize).copyWith(
              shadows: const [
                Shadow(
                    color: Color(0x99FFF3D6),
                    offset: Offset(0, 1),
                    blurRadius: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
        const Radius.circular(8));
    final path = Path()..addRRect(r);
    final paint = Paint()
      ..color = ClubPalette.brass.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const dash = 5.0, gap = 4.0;
    double dist = 0;
    final metrics = path.computeMetrics().first;
    final total = metrics.length;
    while (dist < total) {
      canvas.drawPath(metrics.extractPath(dist, min(dist + dash, total)), paint);
      dist += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class OxbloodButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final double fontSize;
  const OxbloodButton(
      {super.key, required this.label, this.onTap, this.fontSize = 16});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? () => onTap!() : null,
        child: CustomPaint(
          painter: _StitchPainter(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF9C3D2C), Color(0xFF6E2418)],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4A130C), width: 1.4),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: ClubType.label(fontSize, color: ClubPalette.brassPale),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brass mechanical toggle & slider.
// ---------------------------------------------------------------------------
class BrassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const BrassToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 58,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: value ? ClubPalette.feltDeep : const Color(0xFF0D0B06),
          border: Border.all(color: ClubPalette.brassDark, width: 1.6),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.35),
                radius: 1.1,
                colors: value
                    ? const [
                        Color(0xFFE9C176),
                        Color(0xFFC5A059),
                        Color(0xFF8C6C30)
                      ]
                    : const [
                        Color(0xFF8A7A5C),
                        Color(0xFF5C5140),
                        Color(0xFF3A352A)
                      ],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 3,
                    offset: const Offset(0, 1.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BrassSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  const BrassSlider({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        void update(Offset local) {
          onChanged((local.dx / w).clamp(0.0, 1.0));
        }

        return GestureDetector(
          onHorizontalDragUpdate: (d) => update(d.localPosition),
          onTapDown: (d) => update(d.localPosition),
          child: SizedBox(
            height: 34,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0E0A06), Color(0xFF241708)],
                    ),
                    border: Border.all(color: ClubPalette.brassDark, width: 1),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 6,
                    width: max(0.0, w * value - 14),
                    margin: const EdgeInsets.only(left: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: ClubPalette.brassFace,
                    ),
                  ),
                ),
                Positioned(
                  left: (w - 30) * value,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        center: Alignment(-0.3, -0.35),
                        radius: 1.15,
                        colors: [
                          Color(0xFFE9C176),
                          Color(0xFFC5A059),
                          Color(0xFF8C6C30)
                        ],
                      ),
                      border:
                          Border.all(color: ClubPalette.brassDark, width: 1.4),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            blurRadius: 5,
                            offset: const Offset(0, 2.5)),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              ClubPalette.brassDark.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Walnut bezel — bevelled physical table frame hugging the viewport.
// ---------------------------------------------------------------------------
class WalnutBezel extends StatelessWidget {
  final Widget child;
  final ClubThemeDef? theme;
  const WalnutBezel({super.key, required this.child, this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t?.walnutLight ?? const Color(0xFF4A3020),
            t?.walnut ?? const Color(0xFF2C1D11),
            t?.walnutDeep ?? const Color(0xFF1A120B),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0D0805), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 10,
                offset: const Offset(0, 4)),
            BoxShadow(
                color: const Color(0x596B4E2E),
                blurRadius: 2,
                offset: const Offset(0, -1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                  color: ClubPalette.brassDark.withValues(alpha: 0.55),
                  width: 1.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Walnut panel with brass trim (settings rows, dialogs).
class ClubPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const ClubPanel(
      {super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: ClubPalette.walnutFace,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClubPalette.brassDark, width: 1.6),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

/// Brass name plate with engraved text.
class NamePlate extends StatelessWidget {
  final String text;
  final double fontSize;
  const NamePlate(this.text, {super.key, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: ClubPalette.brassFace,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ClubPalette.brassDark, width: 1.2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        text.toUpperCase(),
        style: ClubType.engraved(fontSize).copyWith(
          shadows: const [
            Shadow(
                color: Color(0x99FFF3D6),
                offset: Offset(0, 1),
                blurRadius: 0),
          ],
        ),
      ),
    );
  }
}

/// Machined rivet for walnut rails and panel corners.
class BrassRivet extends StatelessWidget {
  final double size;
  const BrassRivet({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 1.1,
          colors: [Color(0xFFE9C176), Color(0xFFC5A059), Color(0xFF7A5C28)],
        ),
        border: Border.all(color: ClubPalette.brassDark, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 2,
              offset: const Offset(0, 1)),
        ],
      ),
    );
  }
}
