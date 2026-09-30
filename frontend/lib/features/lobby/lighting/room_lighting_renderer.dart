import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'room_lighting_system.dart';

/// Screen position of a continuous sub-grid floor point. Same projection as the floor
/// matrix in the room background (and `IsometricCoords.subGridToScreen` for cell centers).
Offset lightingSubGridToScreen(double u, double v) => Offset((u - v) * 16.0, (u + v) * 8.0 - 16.0);

/// Inverse of [lightingSubGridToScreen]: floor-plane screen point → continuous sub-grid (u, v).
Offset lightingScreenToSubGrid(double x, double y) {
  final a = x / 16.0, b = (y + 16.0) / 8.0; // a = u - v, b = u + v
  return Offset((a + b) / 2, (b - a) / 2);
}

/// Paints the floor lightmap as one `drawVertices` mesh with per-vertex colours (Gouraud
/// shading gives the smooth gradient, no intermediate image) multiplied onto the floor.
///
/// Every cell owns its four vertices, and a corner only averages the cells that are
/// light-connected to that cell — so the gradient stops at a wall instead of bleeding under it.
/// Positions/indices are built once; colours are rewritten in place only when the lighting
/// system reports a change.
class RoomLightingFloorPainter {
  static const int _n = RoomLightingSystem.size;
  static const int _cells = RoomLightingSystem.cellCount;

  final RoomLightingSystem system;
  final Float32List _positions = Float32List(_cells * 4 * 2);
  final Uint16List _indices = Uint16List(_cells * 6);
  final Int32List _colors = Int32List(_cells * 4);

  /// For each (cell, corner): up to 4 contributing cell indices, -1 = none.
  final Int16List _cornerCells = Int16List(_cells * 4 * 4);
  LightOcclusion? _cornerOcclusion;

  ui.Vertices? _vertices;
  bool _dirty = true;
  final Paint _paint = Paint()..blendMode = BlendMode.multiply;

  RoomLightingFloorPainter(this.system) {
    for (int j = 0; j < _n; j++) {
      for (int i = 0; i < _n; i++) {
        final c = j * _n + i;
        final corners = [
          lightingSubGridToScreen(i.toDouble(), j.toDouble()),
          lightingSubGridToScreen(i + 1.0, j.toDouble()),
          lightingSubGridToScreen(i + 1.0, j + 1.0),
          lightingSubGridToScreen(i.toDouble(), j + 1.0),
        ];
        for (int k = 0; k < 4; k++) {
          _positions[(c * 4 + k) * 2] = corners[k].dx;
          _positions[(c * 4 + k) * 2 + 1] = corners[k].dy;
        }
        final base = c * 4;
        _indices.setAll(c * 6, [base, base + 1, base + 2, base, base + 2, base + 3]);
      }
    }
  }

  void markDirty() => _dirty = true;

  void render(Canvas canvas) {
    if (_dirty || _vertices == null) _rebuild();
    canvas.drawVertices(_vertices!, BlendMode.dst, _paint);
  }

  void _rebuildCornerTable() {
    final occ = system.occlusion;
    _cornerCells.fillRange(0, _cornerCells.length, -1);
    const cornerOffsets = [
      [0, 0],
      [1, 0],
      [1, 1],
      [0, 1]
    ];
    for (int j = 0; j < _n; j++) {
      for (int i = 0; i < _n; i++) {
        final c = j * _n + i;
        for (int k = 0; k < 4; k++) {
          final cx = i + cornerOffsets[k][0], cy = j + cornerOffsets[k][1];
          int slot = 0;
          for (int dy = -1; dy <= 0; dy++) {
            for (int dx = -1; dx <= 0; dx++) {
              final ni = cx + dx, nj = cy + dy;
              if (ni < 0 || nj < 0 || ni >= _n || nj >= _n) continue;
              if (!occ.lightConnected(i, j, ni, nj)) continue;
              _cornerCells[(c * 4 + k) * 4 + slot++] = nj * _n + ni;
            }
          }
        }
      }
    }
    _cornerOcclusion = occ;
  }

  void _rebuild() {
    if (!identical(_cornerOcclusion, system.occlusion)) _rebuildCornerTable();
    final rgb = system.rgb;
    for (int v = 0; v < _cells * 4; v++) {
      double r = 0, g = 0, b = 0;
      int count = 0;
      for (int s = 0; s < 4; s++) {
        final cell = _cornerCells[v * 4 + s];
        if (cell < 0) break;
        r += rgb[cell * 3];
        g += rgb[cell * 3 + 1];
        b += rgb[cell * 3 + 2];
        count++;
      }
      _colors[v] = count == 0
          ? 0xFFFFFFFF
          : (0xFF << 24) | (_to255(r / count) << 16) | (_to255(g / count) << 8) | _to255(b / count);
    }
    _vertices?.dispose();
    _vertices = ui.Vertices.raw(ui.VertexMode.triangles, _positions, colors: _colors, indices: _indices);
    _dirty = false;
  }

  static int _to255(double x) => (x.clamp(0.0, 1.0) * 255).round();

  void dispose() {
    _vertices?.dispose();
    _vertices = null;
  }
}

/// Additive glow for each lit source: a soft pool on the floor plus a halo at the source's
/// height. Shaders and colour filters are cached per light and only replaced when the
/// (quantized) colour changes — nothing is allocated on a steady frame.
class RoomLightingGlowPainter {
  final RoomLightingSystem system;

  static final Shader _radial = ui.Gradient.radial(
    Offset.zero,
    1.0,
    const [Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
    const [0.0, 0.35, 1.0],
  );

  final Map<String, _GlowCache> _cache = {};

  RoomLightingGlowPainter(this.system);

  /// Pool strength on the floor and halo strength at the source, per unit of intensity.
  static const double poolAlpha = 0.14;
  static const double haloAlpha = 0.55;

  /// Ceiling fixtures only show their emission point while decorating (where they can be
  /// moved); in normal play you only see the light they cast. Lamps/TV/fireplace always
  /// keep their halo, since the glow comes from the object itself.
  void render(Canvas canvas, {bool showCeilingMarkers = false}) {
    // Glows read as light only against darkness: none on the floor by day, just a faint
    // halo on the bulb; full strength at night.
    final amb = system.currentAmbientColor;
    final darkness = 1 - (amb.red + amb.green + amb.blue) / (3 * 255);
    final poolFactor = darkness;
    final haloFactor = 0.35 + 0.65 * darkness;

    for (final l in system.lights) {
      if (l.level <= 0) continue;
      final d = l.def;
      final anim = LightAnimator.evaluate(d, system.time, system.ambient);
      final strength = (d.intensity * l.level * anim.intensity).clamp(0.0, 1.5);
      if (strength <= 0.01) continue;

      final cache = _cache.putIfAbsent(d.id, () => _GlowCache());
      final key = (_q(anim.r) << 16) | (_q(anim.g) << 8) | _q(anim.b);
      if (cache.colorKey != key) {
        cache.colorKey = key;
        final color = Color.fromARGB(255, _q(anim.r) * 4, _q(anim.g) * 4, _q(anim.b) * 4);
        cache.paint
          ..shader = _radial
          ..blendMode = BlendMode.plus
          ..colorFilter = ColorFilter.mode(color, BlendMode.modulate);
      }

      final base = lightingSubGridToScreen(d.u, d.v);

      // Floor pool: a circle in floor space is a 2:1 ellipse on screen.
      final poolRadius = d.radius * 16.0 * sqrt2 * 0.55;
      final poolA = (poolAlpha * strength * poolFactor).clamp(0.0, 1.0);
      if (poolA > 0.005) {
        cache.paint.color = Color.fromRGBO(255, 255, 255, poolA);
        canvas.save();
        canvas.translate(base.dx, base.dy);
        canvas.scale(poolRadius, poolRadius * 0.5);
        canvas.drawCircle(Offset.zero, 1.0, cache.paint);
        canvas.restore();
      }

      // Halo at the bulb.
      if (d.glowHeight > 0 && (!d.isCeiling || showCeilingMarkers)) {
        const haloRadius = 18.0;
        cache.paint.color = Color.fromRGBO(255, 255, 255, (haloAlpha * strength * haloFactor).clamp(0.0, 1.0));
        canvas.save();
        canvas.translate(base.dx, base.dy - d.glowHeight);
        canvas.scale(haloRadius, haloRadius);
        canvas.drawCircle(Offset.zero, 1.0, cache.paint);
        canvas.restore();
      }
    }
  }

  /// 64 levels per channel: colour filters are only rebuilt on a visible change.
  static int _q(double x) => (x.clamp(0.0, 1.0) * 63).round();
}

class _GlowCache {
  int colorKey = -1;
  final Paint paint = Paint();
}

/// Per-component light tint: one [Paint] owned by the component, mutated in place.
/// The [ColorFilter] is only replaced when the colour changes at 64 levels per channel,
/// and a (near) white tint switches itself off so daytime rendering is untouched.
class LightTint {
  final Paint paint = Paint();
  int _key = -1;
  bool active = false;
  Color color = const Color(0xFFFFFFFF);

  void set(double r, double g, double b) {
    final qr = _q(r), qg = _q(g), qb = _q(b);
    if (qr >= 62 && qg >= 62 && qb >= 62) {
      active = false;
      return;
    }
    active = true;
    final key = (qr << 16) | (qg << 8) | qb;
    if (key == _key) return;
    _key = key;
    color = Color.fromARGB(255, _c(qr), _c(qg), _c(qb));
    paint.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
  }

  void clear() => active = false;

  /// Paint for `Sprite.render(overridePaint:)`, or null to render untouched.
  Paint? get overridePaint => active ? paint : null;

  static int _q(double x) => (x.clamp(0.0, 1.0) * 63).round();
  static int _c(int q) => (q * 255 / 63).round();
}

/// Lights the two exterior walls with the light of the floor row running along them.
/// Drawn in each wall's own local space (x = along the wall, 32 px per tile, so 16 px per
/// sub-cell; y = 0 at the top, [wallHeight] at the floor), multiplied onto the wallpaper.
/// Like the floor mesh, each sub-cell segment owns its vertices so an interior wall that
/// meets the exterior wall produces a hard edge instead of a gradient bleeding past it.
class RoomLightingWallPainter {
  static const int _n = RoomLightingSystem.size;
  final RoomLightingSystem system;
  final Paint _paint = Paint()..blendMode = BlendMode.multiply;
  final Float32List _positions = Float32List(_n * 4 * 2);
  final Uint16List _indices = Uint16List(_n * 6);
  final Int32List _northColors = Int32List(_n * 4);
  final Int32List _westColors = Int32List(_n * 4);
  ui.Vertices? _north, _west;
  double _builtHeight = -1;
  bool _dirty = true;

  RoomLightingWallPainter(this.system) {
    for (int k = 0; k < _n; k++) {
      final base = k * 4;
      _indices.setAll(k * 6, [base, base + 1, base + 2, base, base + 2, base + 3]);
    }
  }

  void markDirty() => _dirty = true;

  void renderNorth(Canvas canvas, double wallHeight) {
    _ensure(wallHeight);
    canvas.drawVertices(_north!, BlendMode.dst, _paint);
  }

  void renderWest(Canvas canvas, double wallHeight) {
    _ensure(wallHeight);
    canvas.drawVertices(_west!, BlendMode.dst, _paint);
  }

  void _ensure(double wallHeight) {
    if (!_dirty && _north != null && wallHeight == _builtHeight) return;
    for (int k = 0; k < _n; k++) {
      final x0 = k * 16.0, x1 = x0 + 16.0;
      _positions.setAll(k * 8, [x0, 0, x1, 0, x1, wallHeight, x0, wallHeight]);
    }
    _fillRow(_northColors, (k) => k, (k) => 0);
    _fillRow(_westColors, (k) => 0, (k) => k);
    _north?.dispose();
    _west?.dispose();
    _north = ui.Vertices.raw(ui.VertexMode.triangles, _positions, colors: _northColors, indices: _indices);
    _west = ui.Vertices.raw(ui.VertexMode.triangles, _positions, colors: _westColors, indices: _indices);
    _builtHeight = wallHeight;
    _dirty = false;
  }

  /// Vertex order per segment: top-left, top-right, bottom-right, bottom-left.
  void _fillRow(Int32List out, int Function(int) ci, int Function(int) cj) {
    final occ = system.occlusion;
    for (int k = 0; k < _n; k++) {
      final i = ci(k), j = cj(k);
      final own = _cell(i, j);
      int edge(int nk) {
        if (nk < 0 || nk >= _n) return own;
        final ni = ci(nk), nj = cj(nk);
        if (!occ.lightConnected(i, j, ni, nj)) return own;
        return _avg(own, _cell(ni, nj));
      }

      final left = edge(k - 1), right = edge(k + 1);
      out.setAll(k * 4, [left, right, right, left]);
    }
  }

  int _cell(int i, int j) {
    final idx = (j * _n + i) * 3;
    final rgb = system.rgb;
    return (0xFF << 24) | (_to255(rgb[idx]) << 16) | (_to255(rgb[idx + 1]) << 8) | _to255(rgb[idx + 2]);
  }

  static int _avg(int a, int b) =>
      (0xFF << 24) |
      ((((a >> 16) & 0xFF) + ((b >> 16) & 0xFF)) ~/ 2) << 16 |
      ((((a >> 8) & 0xFF) + ((b >> 8) & 0xFF)) ~/ 2) << 8 |
      (((a & 0xFF) + (b & 0xFF)) ~/ 2);

  static int _to255(double x) => (x.clamp(0.0, 1.0) * 255).round();

  void dispose() {
    _north?.dispose();
    _west?.dispose();
    _north = _west = null;
  }
}
