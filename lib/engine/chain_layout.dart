import 'dart:math';
import 'package:flutter/material.dart';
import 'domino_engine.dart';

/// A tile positioned on the felt table, in table-local pixels.
class LaidTile {
  final Rect rect;
  final int first; // leading half: top when vertical, left when horizontal
  final int second;
  final bool vertical;
  final bool isDouble;
  final bool isSpinner;
  const LaidTile({
    required this.rect,
    required this.first,
    required this.second,
    required this.vertical,
    required this.isDouble,
    this.isSpinner = false,
  });
}

/// A tappable brass marker on an open end (shown during tile selection).
class OpenEndMarker {
  final Offset center;
  final ChainEnd end;
  const OpenEndMarker({required this.center, required this.end});
}

class _Placed {
  final int x, y, w, h; // cell rect
  final int dir; // 0=E 1=S 2=W 3=N : direction of travel at placement
  final PlacedTile tile;
  final int spinnerIndex; // -1 spine, else spinner
  final int armSide; // 0/1 for arms, -1 spine
  _Placed(this.x, this.y, this.w, this.h, this.dir, this.tile,
      this.spinnerIndex, this.armSide);
}

class _Walker {
  int x, y, dir;
  _Walker(this.x, this.y, this.dir);
}

/// Serpentine turtle layout for the domino chain plus spinner arms.
/// Tiles snake to fill the table; the whole arrangement is then scaled to
/// fit — the renderer never clips (RULES §12).
class ChainLayout {
  final List<LaidTile> tiles;
  final List<OpenEndMarker> ends;
  final double tileW;

  const ChainLayout._(this.tiles, this.ends, this.tileW);

  factory ChainLayout.build(DominoEngine e, Size table) {
    final placer = _Placer(table);
    if (e.spine.isEmpty) return const ChainLayout._([], [], 24);

    // ---- spine ------------------------------------------------------------
    final spineWalker = _Walker(0, 0, 0);
    final spinePlaced = <_Placed>[];
    for (int i = 0; i < e.spine.length; i++) {
      final t = e.spine[i];
      _Placed pl;
      if (i == 0) {
        pl = placer.force(0, 0, 2, 1, 0, t, -1, -1);
        spineWalker.x = 2;
      } else {
        pl = placer.place(spineWalker, t.isDouble, t, -1, -1);
      }
      spinePlaced.add(pl);
    }

    // tile seq -> placed record (spinners are created by their double tile)
    final bySeq = <int, _Placed>{for (final p in placer.placed) p.tile.seq: p};

    // ---- spinner arms ------------------------------------------------------
    final armPlaced = <int, List<List<_Placed>>>{
      for (int i = 0; i < e.spinners.length; i++)
        i: [
          <_Placed>[],
          <_Placed>[],
        ],
    };
    for (int i = 0; i < e.spinners.length; i++) {
      final sp = e.spinners[i];
      final host = bySeq[sp.seq - 1]; // the double tile that made the spinner
      if (host == null) continue;
      final verticalHost = host.h > host.w;
      for (int arm = 0; arm < 2; arm++) {
        final armTiles = arm == 0 ? sp.armA : sp.armB;
        if (armTiles.isEmpty) continue;
        // arms leave perpendicular to the spinner's long axis
        late _Walker w;
        if (verticalHost) {
          w = arm == 0
              ? _Walker(host.x + host.w, host.y, 0) // east
              : _Walker(host.x, host.y, 2); // west
        } else {
          w = arm == 0
              ? _Walker(host.x, host.y + host.h, 1) // south
              : _Walker(host.x, host.y, 3); // north
        }
        for (final t in armTiles) {
          final pl = placer.place(w, t.isDouble, t, i, arm);
          armPlaced[i]![arm].add(pl);
          bySeq[t.seq] = pl;
        }
      }
    }

    // ---- scale to fit ------------------------------------------------------
    var minX = 1 << 30, minY = 1 << 30, maxX = -(1 << 30), maxY = -(1 << 30);
    for (final p in placer.placed) {
      minX = min(minX, p.x);
      minY = min(minY, p.y);
      maxX = max(maxX, p.x + p.w);
      maxY = max(maxY, p.y + p.h);
    }
    const pad = 26.0; // room for end markers + shadows
    final cellW = min(
      (table.width - pad * 2) / max(1, maxX - minX),
      (table.height - pad * 2) / max(1, maxY - minY),
    );
    // keep tiles tactile: not microscopic, not oversized
    final tileW = cellW.clamp(table.width / 22, table.width / 7.5);
    final ox = (table.width - (maxX - minX) * tileW) / 2 - minX * tileW;
    final oy = (table.height - (maxY - minY) * tileW) / 2 - minY * tileW;

    final spinnerSeqs = {for (final s in e.spinners) s.seq - 1};
    final laid = <LaidTile>[];
    for (final p in placer.placed) {
      final rect = Rect.fromLTWH(
        ox + p.x * tileW,
        oy + p.y * tileW,
        p.w * tileW,
        p.h * tileW,
      );
      final vertical = p.h > p.w;
      // connect side depends on travel direction
      int first, second;
      if (p.tile.isDouble) {
        first = p.tile.connect;
        second = p.tile.open;
      } else if (p.dir == 0) {
        first = p.tile.connect;
        second = p.tile.open; // west edge touches previous
      } else if (p.dir == 2) {
        first = p.tile.open;
        second = p.tile.connect; // east edge touches previous
      } else if (p.dir == 1) {
        first = p.tile.connect;
        second = p.tile.open; // north edge touches previous
      } else {
        first = p.tile.open;
        second = p.tile.connect; // south edge touches previous
      }
      laid.add(LaidTile(
        rect: rect,
        first: first,
        second: second,
        vertical: vertical,
        isDouble: p.tile.isDouble,
        isSpinner: spinnerSeqs.contains(p.tile.seq),
      ));
    }

    // ---- open-end markers ---------------------------------------------------
    final markers = <OpenEndMarker>[];
    Offset at(_Placed p, int side) {
      // side: 0=W 1=N 2=E 3=S outer edge center, pushed outward
      final r = Rect.fromLTWH(
          ox + p.x * tileW, oy + p.y * tileW, p.w * tileW, p.h * tileW);
      const m = 16.0;
      switch (side) {
        case 0:
          return Offset(r.left - m, r.center.dy);
        case 1:
          return Offset(r.center.dx, r.top - m);
        case 3:
          return Offset(r.center.dx, r.bottom + m);
        default:
          return Offset(r.right + m, r.center.dy);
      }
    }

    for (final end in e.legalEnds()) {
      if (end.spinnerIndex < 0) {
        if (end.chainLeft) {
          markers.add(OpenEndMarker(center: at(spinePlaced.first, 0), end: end));
        } else {
          final last = spinePlaced.last;
          // open edge = travel direction of the last tile
          final side = last.dir == 0
              ? 2
              : last.dir == 2
                  ? 0
                  : last.dir == 1
                      ? 3
                      : 1;
          markers.add(OpenEndMarker(center: at(last, side), end: end));
        }
      } else {
        final arms = armPlaced[end.spinnerIndex]![end.arm];
        if (arms.isEmpty) {
          final host = bySeq[e.spinners[end.spinnerIndex].seq - 1]!;
          final verticalHost = host.h > host.w;
          final side = verticalHost ? (end.arm == 0 ? 2 : 0) : (end.arm == 0 ? 3 : 1);
          markers.add(OpenEndMarker(center: at(host, side), end: end));
        } else {
          final last = arms.last;
          final side = last.dir == 0
              ? 2
              : last.dir == 2
                  ? 0
                  : last.dir == 1
                      ? 3
                      : 1;
          markers.add(OpenEndMarker(center: at(last, side), end: end));
        }
      }
    }

    return ChainLayout._(laid, markers, tileW);
  }
}

class _Placer {
  final Size table;
  final Set<String> occupied = {};
  final List<_Placed> placed = [];
  late int laneW, laneH;

  _Placer(this.table) {
    laneW = 40;
    laneH = 30;
  }

  bool _free(int x, int y, int w, int h) {
    for (int i = 0; i < w; i++) {
      for (int j = 0; j < h; j++) {
        if (occupied.contains('${x + i},${y + j}')) return false;
      }
    }
    return true;
  }

  void _fill(int x, int y, int w, int h) {
    for (int i = 0; i < w; i++) {
      for (int j = 0; j < h; j++) {
        occupied.add('${x + i},${y + j}');
      }
    }
  }

  _Placed force(int x, int y, int w, int h, int dir, PlacedTile t, int si, int arm) {
    _fill(x, y, w, h);
    final p = _Placed(x, y, w, h, dir, t, si, arm);
    placed.add(p);
    return p;
  }

  /// Place one tile from [w], trying [w.dir] then snake turns.
  _Placed place(_Walker w, bool crosswise, PlacedTile t, int si, int arm) {
    (int, int) footprint(int d) {
      final horiz = (d == 0 || d == 2) != crosswise;
      return horiz ? (2, 1) : (1, 2);
    }

    bool attempt(int d) {
      final (tw, th) = footprint(d);
      var nx = w.x, ny = w.y;
      if (d == 2) nx -= tw;
      if (d == 3) ny -= th;
      if (nx < -laneW ~/ 2 ||
          nx + tw > laneW ~/ 2 ||
          ny < -laneH ~/ 2 ||
          ny + th > laneH ~/ 2) {
        return false;
      }
      if (!_free(nx, ny, tw, th)) return false;
      _fill(nx, ny, tw, th);
      placed.add(_Placed(nx, ny, tw, th, d, t, si, arm));
      w.x = d == 2 ? nx : nx + (d == 0 ? tw : 0);
      w.y = d == 3 ? ny : ny + (d == 1 ? th : 0);
      w.dir = d;
      return true;
    }

    final order = [w.dir, (w.dir + 1) % 4, (w.dir + 3) % 4, (w.dir + 2) % 4];
    for (final d in order) {
      if (attempt(d)) return placed.last;
    }
    laneW += 16;
    laneH += 12;
    for (final d in order) {
      if (attempt(d)) return placed.last;
    }
    // last resort: overlap-free far slot (should not happen)
    return force(w.x + 4, w.y + 4, footprint(w.dir).$1, footprint(w.dir).$2,
        w.dir, t, si, arm);
  }
}
