import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/painting.dart' show Color;
import '../../../core/models/room_config.dart';

/// Room lighting engine (pure Dart, no Flame).
///
/// Works on the 16×16 sub-grid used by the pathfinder. Sub-cell (i, j) covers
/// [i, i+1) × [j, j+1) in sub-grid units, so a tile (gx, gy) spans sub-cells 2gx..2gx+1.
///
/// Two stages, split on purpose:
/// 1. **Propagation** — per light, how much of it reaches each cell (`influence`, 0..1),
///    blocked or attenuated by interior walls. Only recomputed when the topology changes
///    (walls, light position, radius).
/// 2. **Composition** — every frame that something changed:
///    `light = Σ influence_i × colour_i × intensity_i(t)`, then `cell = compress(ambient,
///    light)`. Animations and fades only touch `intensity_i` / `colour_i`, so they never
///    re-run propagation. Buffers are preallocated: no allocations per frame.
class RoomLightingSystem {
  static const int size = 16;
  static const int cellCount = size * size;
  static const double fadeSeconds = 0.25;
  /// Ambient changes (e.g. the clock turning day into evening) blend over this long.
  static const double ambientFadeSeconds = 2.0;
  static const double _eps = 0.004;

  LightOcclusion _occlusion = LightOcclusion.open();
  LightOcclusion get occlusion => _occlusion;

  final List<LightSource> _lights = [];
  List<LightSource> get lights => List.unmodifiable(_lights);

  AmbientMode _ambient = AmbientMode.day;
  AmbientMode get ambient => _ambient;
  bool _masterOn = true;
  bool get masterOn => _masterOn;

  /// Composed light per cell, RGB interleaved, 0..1. Index `(j * size + i) * 3`.
  final Float32List rgb = Float32List(cellCount * 3);

  /// How many single-light propagations have run (tests / profiling).
  int propagationCount = 0;

  double _time = 0;
  double get time => _time;
  bool _composeDirty = true;

  // Scratch buffers for propagation, shared by all lights.
  final Float32List _dist = Float32List(cellCount);
  final Float32List _trans = Float32List(cellCount);
  final Uint8List _done = Uint8List(cellCount);

  // --- Configuration -------------------------------------------------------------------

  void setOcclusion(LightOcclusion occlusion) {
    _occlusion = occlusion;
    for (final l in _lights) {
      l._influenceDirty = true;
    }
    _composeDirty = true;
  }

  Color _ambientFrom = ambientColor(AmbientMode.day);
  double _ambientT = 1;

  /// Ambient colour being rendered now (blends towards the target after [setAmbient]).
  Color get currentAmbientColor => _ambientT >= 1
      ? ambientColor(_ambient)
      : Color.lerp(_ambientFrom, ambientColor(_ambient), _ambientT)!;

  void setAmbient(AmbientMode mode) {
    if (_ambient == mode) return;
    _ambientFrom = currentAmbientColor;
    _ambient = mode;
    _ambientT = 0;
    _composeDirty = true;
  }

  void setMasterOn(bool on) {
    if (_masterOn == on) return;
    _masterOn = on;
    _composeDirty = true;
  }

  /// Replaces the light list. Lights are matched by id: a light that keeps its position
  /// and radius keeps its precomputed influence and its current fade level.
  void setLights(List<LightSourceDef> defs) {
    final previous = {for (final l in _lights) l.def.id: l};
    _lights.clear();
    for (final d in defs) {
      final old = previous[d.id];
      if (old != null) {
        final topologyChanged = old.def.u != d.u || old.def.v != d.v || old.def.radius != d.radius;
        old.def = d;
        if (topologyChanged) old._influenceDirty = true;
        _lights.add(old);
      } else {
        _lights.add(LightSource._(d));
      }
    }
    _composeDirty = true;
  }

  /// Switches one light. Survives [setMasterOn] toggles.
  void setLightOn(String id, bool on) {
    final l = _find(id);
    if (l == null || l.def.on == on) return;
    l.def = l.def.copyWith(on: on);
    _composeDirty = true;
  }

  void setLightColor(String id, Color color) {
    final l = _find(id);
    if (l == null) return;
    l.def = l.def.copyWith(color: color);
    _composeDirty = true;
  }

  LightSource? _find(String id) {
    for (final l in _lights) {
      if (l.def.id == id) return l;
    }
    return null;
  }

  LightSource? lightById(String id) => _find(id);

  // --- Per-frame -----------------------------------------------------------------------

  /// Advances fades/animations and recomposes if needed. Returns true when [rgb] changed.
  bool update(double dt) {
    _time += dt;
    bool changed = _composeDirty;
    if (_ambientT < 1) {
      _ambientT = min(1.0, _ambientT + dt / ambientFadeSeconds);
      changed = true;
    }

    for (final l in _lights) {
      if (l._influenceDirty) {
        _propagate(l);
        changed = true;
      }
      final target = isEffectivelyOn(l.def) ? 1.0 : 0.0;
      if (l.level != target) {
        final step = dt / fadeSeconds;
        l.level = target > l.level ? min(target, l.level + step) : max(target, l.level - step);
        changed = true;
      }
      if (l.level > 0 && l.def.anim != LightAnim.none && l.def.anim != LightAnim.daylight) {
        changed = true;
      }
    }

    if (changed) {
      _compose();
      _composeDirty = false;
    }
    return changed;
  }

  /// Skips fades: every light jumps to its target level. Useful on load.
  void settle() {
    _ambientT = 1;
    for (final l in _lights) {
      if (l._influenceDirty) _propagate(l);
      l.level = isEffectivelyOn(l.def) ? 1.0 : 0.0;
    }
    _compose();
    _composeDirty = false;
  }

  bool isEffectivelyOn(LightSourceDef d) => d.on && (_masterOn || !d.affectedByMaster);

  bool get hasAnimatedLights =>
      _lights.any((l) => l.level > 0 && l.def.anim != LightAnim.none && l.def.anim != LightAnim.daylight);

  // --- Queries -------------------------------------------------------------------------

  static Color ambientColor(AmbientMode mode) {
    switch (mode) {
      case AmbientMode.day:
        // Pure white: daytime is a visual no-op, so tints switch off and cost nothing.
        return const Color(0xFFFFFFFF);
      case AmbientMode.evening:
        return const Color(0xFF9E8070); // tenue terracota
      case AmbientMode.night:
        return const Color(0xFF2B2E4D); // azul marino / lavanda, nunca negro
    }
  }

  /// Colour of a single cell (clamped to the grid).
  void cellInto(int i, int j, Float32List out) {
    final idx = (j.clamp(0, size - 1) * size + i.clamp(0, size - 1)) * 3;
    out[0] = rgb[idx];
    out[1] = rgb[idx + 1];
    out[2] = rgb[idx + 2];
  }

  /// Bilinear sample at a continuous sub-grid point, wall-aware: cells on the other side of
  /// a solid wall from the point's own cell are ignored, so an avatar standing next to a wall
  /// never picks up light from the far side. Writes RGB into [out] (no allocation).
  void sampleInto(double u, double v, Float32List out) {
    final homeI = u.floor().clamp(0, size - 1);
    final homeJ = v.floor().clamp(0, size - 1);
    final x = u - 0.5, y = v - 0.5;
    final i0 = x.floor(), j0 = y.floor();
    final fx = x - i0, fy = y - j0;

    double r = 0, g = 0, b = 0, wSum = 0;
    for (int dj = 0; dj <= 1; dj++) {
      for (int di = 0; di <= 1; di++) {
        final w = (di == 0 ? 1 - fx : fx) * (dj == 0 ? 1 - fy : fy);
        if (w <= 0) continue;
        final ci = (i0 + di).clamp(0, size - 1);
        final cj = (j0 + dj).clamp(0, size - 1);
        if (!_occlusion.lightConnected(homeI, homeJ, ci, cj)) continue;
        final idx = (cj * size + ci) * 3;
        r += rgb[idx] * w;
        g += rgb[idx + 1] * w;
        b += rgb[idx + 2] * w;
        wSum += w;
      }
    }
    if (wSum <= 0) {
      cellInto(homeI, homeJ, out);
      return;
    }
    out[0] = r / wSum;
    out[1] = g / wSum;
    out[2] = b / wSum;
  }

  /// Ids of the lights whose source sits in the same sector as sub-cell (i, j).
  List<String> lightIdsInSectorOf(int i, int j) {
    final s = _occlusion.sectorAt(i, j);
    return [
      for (final l in _lights)
        if (_occlusion.sectorAt(l.def.u.floor(), l.def.v.floor()) == s) l.def.id
    ];
  }

  // --- Propagation ---------------------------------------------------------------------

  /// Smooth radial falloff: 1 at the source, 0 at [radius], zero slope at both ends.
  static double falloff(double d, double radius) {
    if (radius <= 0) return 0;
    final x = d / radius;
    if (x >= 1) return 0;
    final k = 1 - x * x;
    return k * k;
  }

  /// "Max-value Dijkstra": each cell keeps the best `falloff(pathLength) × Π transmittance`
  /// over paths from the source. 8-connected; a diagonal step is only allowed when both
  /// L-shaped routes are fully open, so light never slips through a wall corner.
  void _propagate(LightSource l) {
    propagationCount++;
    final inf = l.influence;
    final d = l.def;
    final occ = _occlusion;
    final radius = d.radius;
    inf.fillRange(0, cellCount, 0);
    _done.fillRange(0, cellCount, 0);
    _dist.fillRange(0, cellCount, double.infinity);
    _trans.fillRange(0, cellCount, 0);

    final si = d.u.floor().clamp(0, size - 1);
    final sj = d.v.floor().clamp(0, size - 1);

    // Seed the source cell and its directly reachable neighbours with their true Euclidean
    // distance, so a light sitting on a cell corner lights the four cells around it evenly.
    for (int dj = -1; dj <= 1; dj++) {
      for (int di = -1; di <= 1; di++) {
        final ci = si + di, cj = sj + dj;
        if (ci < 0 || cj < 0 || ci >= size || cj >= size) continue;
        double t;
        if (di == 0 && dj == 0) {
          t = 1;
        } else if (di == 0 || dj == 0) {
          t = occ.transmittance(si, sj, ci, cj);
        } else {
          t = occ.diagonalOpen(si, sj, ci, cj) ? 1 : 0;
        }
        if (t <= 0) continue;
        final dist = sqrt(pow(ci + 0.5 - d.u, 2) + pow(cj + 0.5 - d.v, 2));
        final idx = cj * size + ci;
        final val = falloff(dist, radius) * t;
        if (val > inf[idx]) {
          inf[idx] = val;
          _dist[idx] = dist;
          _trans[idx] = t;
        }
      }
    }

    while (true) {
      int best = -1;
      double bestVal = _eps;
      for (int k = 0; k < cellCount; k++) {
        if (_done[k] == 0 && inf[k] > bestVal) {
          bestVal = inf[k];
          best = k;
        }
      }
      if (best < 0) break;
      _done[best] = 1;
      final bi = best % size, bj = best ~/ size;
      final bd = _dist[best], bt = _trans[best];

      for (int dj = -1; dj <= 1; dj++) {
        for (int di = -1; di <= 1; di++) {
          if (di == 0 && dj == 0) continue;
          final ni = bi + di, nj = bj + dj;
          if (ni < 0 || nj < 0 || ni >= size || nj >= size) continue;
          final nIdx = nj * size + ni;
          if (_done[nIdx] == 1) continue;
          double t, step;
          if (di == 0 || dj == 0) {
            t = occ.transmittance(bi, bj, ni, nj);
            step = 1;
          } else {
            t = occ.diagonalOpen(bi, bj, ni, nj) ? 1 : 0;
            step = sqrt2;
          }
          if (t <= 0) continue;
          final nd = bd + step, nt = bt * t;
          final nv = falloff(nd, radius) * nt;
          if (nv > inf[nIdx]) {
            inf[nIdx] = nv;
            _dist[nIdx] = nd;
            _trans[nIdx] = nt;
          }
        }
      }
    }
    l._influenceDirty = false;
  }

  // --- Composition ---------------------------------------------------------------------

  void _compose() {
    // First accumulate the light added on top of the ambient, then compress per channel.
    rgb.fillRange(0, cellCount * 3, 0);

    for (final l in _lights) {
      if (l.level <= 0) continue;
      final anim = LightAnimator.evaluate(l.def, _time, _ambient);
      final intensity = l.def.intensity * l.level * anim.intensity;
      if (intensity <= 0) continue;
      final lr = anim.r * intensity, lg = anim.g * intensity, lb = anim.b * intensity;
      final inf = l.influence;
      for (int k = 0; k < cellCount; k++) {
        final w = inf[k];
        if (w <= 0) continue;
        rgb[k * 3] += w * lr;
        rgb[k * 3 + 1] += w * lg;
        rgb[k * 3 + 2] += w * lb;
      }
    }

    final amb = currentAmbientColor;
    final a = [amb.red / 255.0, amb.green / 255.0, amb.blue / 255.0];
    for (int k = 0; k < cellCount; k++) {
      for (int c = 0; c < 3; c++) {
        rgb[k * 3 + c] = compress(a[c], rgb[k * 3 + c]);
      }
    }
  }

  /// Adds [light] on top of [ambient] with an exponential shoulder: linear (slope 1) for
  /// small amounts, easing asymptotically towards 1 so overlapping lights never blow out
  /// to flat white. A white ambient stays exactly 1, so daytime is a true no-op.
  static double compress(double ambient, double light) {
    final headroom = 1 - ambient;
    if (headroom <= 1e-4 || light <= 0) return ambient;
    return ambient + headroom * (1 - exp(-light / headroom));
  }
}

/// Immutable description of a light, as derived from the room config.
class LightSourceDef {
  final String id;
  final double u; // continuous sub-grid position
  final double v;
  final double radius; // sub-cells
  final Color color;
  final double intensity;
  final LightAnim anim;
  final bool on;

  /// Only ceiling lights are gated by the master switch; lamps, other emitters and
  /// windows ignore it.
  final bool affectedByMaster;
  /// Whether the player can switch this light (false for windows).
  final bool toggleable;
  final int seed;
  final bool isCeiling;

  /// See [EmitterLightSpec.selfLit]. Ceiling lights have no sprite, so it's unused there.
  final double selfLit;

  /// Pixels above the floor point where the bulb halo is drawn (0 = no halo).
  final double glowHeight;

  const LightSourceDef({
    required this.id,
    required this.u,
    required this.v,
    required this.radius,
    required this.color,
    this.intensity = 1.0,
    this.anim = LightAnim.none,
    this.on = true,
    this.affectedByMaster = true,
    this.toggleable = true,
    this.seed = 0,
    this.isCeiling = false,
    this.selfLit = 1.0,
    this.glowHeight = 0,
  });

  LightSourceDef copyWith({bool? on, Color? color}) => LightSourceDef(
        id: id,
        u: u,
        v: v,
        radius: radius,
        color: color ?? this.color,
        intensity: intensity,
        anim: anim,
        on: on ?? this.on,
        affectedByMaster: affectedByMaster,
        toggleable: toggleable,
        seed: seed,
        isCeiling: isCeiling,
        selfLit: selfLit,
        glowHeight: glowHeight,
      );
}

class LightSource {
  LightSourceDef def;
  final Float32List influence = Float32List(RoomLightingSystem.cellCount);

  /// Fade level, 0 (off) .. 1 (fully on).
  double level = 0;
  bool _influenceDirty = true;

  LightSource._(this.def);
}

/// Result of evaluating a light's animation at time t (normalized RGB × intensity factor).
class LightAnimSample {
  double r = 1, g = 1, b = 1, intensity = 1;
}

/// Time-based intensity/colour for animated emitters. Deterministic (no Random), and it
/// never changes the radius — the precomputed influence stays valid.
class LightAnimator {
  static final LightAnimSample _sample = LightAnimSample();

  static const List<int> _tvPalette = [
    0xFF9EC9FF,
    0xFFB8F0FF,
    0xFFFFE3B0,
    0xFFB5FFC8,
    0xFFE0B8FF,
    0xFFFFFFFF,
  ];

  /// Returns a shared sample object (overwritten on each call; copy what you need).
  static LightAnimSample evaluate(LightSourceDef d, double t, AmbientMode ambient) {
    final s = _sample;
    var c = d.color;
    double k = 1;
    switch (d.anim) {
      case LightAnim.none:
        break;
      case LightAnim.flicker:
        final p = d.seed * 1.7;
        k = 0.84 + 0.08 * sin(t * 7.3 + p) + 0.05 * sin(t * 13.1 + p * 2) + 0.03 * sin(t * 23.7 + p * 3);
        break;
      case LightAnim.pulse:
        k = 0.78 + 0.22 * sin(t * 0.8 + d.seed);
        break;
      case LightAnim.tv:
        // A new "shot" every ~0.6–1.8 s: colour and brightness jump like a real screen.
        final segment = (t * 0.9 + d.seed).floor();
        final h = _hash(segment + d.seed * 31);
        c = Color(_tvPalette[h % _tvPalette.length]);
        k = 0.7 + 0.3 * ((h >> 8) % 100) / 100.0;
        break;
      case LightAnim.rgb:
        // Gamer RGB: slow hue cycle at full saturation, written straight into the sample
        // (no Color allocation). The configured colour only sets where the cycle starts.
        final start = _hueOf(d.color);
        final hue = (start + t * 0.06 + d.seed * 0.13) % 1.0;
        _hsvToRgb(hue, s);
        s.intensity = 0.9 + 0.1 * sin(t * 2.1 + d.seed);
        return s;
      case LightAnim.daylight:
        switch (ambient) {
          case AmbientMode.day:
            k = 1.0;
            break;
          case AmbientMode.evening:
            k = 0.45;
            c = const Color(0xFFFFB27A);
            break;
          case AmbientMode.night:
            k = 0.15; // moonlight
            c = const Color(0xFF9FB4FF);
            break;
        }
        break;
    }
    s.r = c.red / 255.0;
    s.g = c.green / 255.0;
    s.b = c.blue / 255.0;
    s.intensity = k;
    return s;
  }

  /// Full-saturation, full-value HSV → RGB into [s].
  static void _hsvToRgb(double h, LightAnimSample s) {
    final x = h * 6;
    final i = x.floor() % 6;
    final f = x - x.floor();
    switch (i) {
      case 0:
        s.r = 1;
        s.g = f;
        s.b = 0;
        break;
      case 1:
        s.r = 1 - f;
        s.g = 1;
        s.b = 0;
        break;
      case 2:
        s.r = 0;
        s.g = 1;
        s.b = f;
        break;
      case 3:
        s.r = 0;
        s.g = 1 - f;
        s.b = 1;
        break;
      case 4:
        s.r = f;
        s.g = 0;
        s.b = 1;
        break;
      default:
        s.r = 1;
        s.g = 0;
        s.b = 1 - f;
    }
  }

  static double _hueOf(Color c) {
    final r = c.red / 255.0, g = c.green / 255.0, b = c.blue / 255.0;
    final mx = max(r, max(g, b)), mn = min(r, min(g, b));
    final d = mx - mn;
    if (d <= 0) return 0;
    double h;
    if (mx == r) {
      h = ((g - b) / d) % 6;
    } else if (mx == g) {
      h = (b - r) / d + 2;
    } else {
      h = (r - g) / d + 4;
    }
    return (h / 6) % 1.0;
  }

  static int _hash(int x) {
    var h = x * 0x45d9f3b;
    h = ((h >> 16) ^ h) * 0x45d9f3b;
    h = (h >> 16) ^ h;
    return h & 0x7fffffff;
  }
}

/// Per-edge light transmittance on the sub-grid, derived from interior walls, plus the
/// sectors (rooms) they enclose.
class LightOcclusion {
  static const int size = RoomLightingSystem.size;

  /// Edge between (i, j) and (i, j-1). Index j * size + i; row 0 unused.
  final Float32List _northT;

  /// Edge between (i, j) and (i-1, j). Index j * size + i; column 0 unused.
  final Float32List _westT;
  final Int16List _sector = Int16List(size * size);
  int _sectorCount = 0;
  int get sectorCount => _sectorCount;

  LightOcclusion._(this._northT, this._westT) {
    _computeSectors();
  }

  factory LightOcclusion.open() => LightOcclusion._(
        Float32List(size * size)..fillRange(0, size * size, 1),
        Float32List(size * size)..fillRange(0, size * size, 1),
      );

  /// How much light passes through an interior wall. Solid walls block it completely;
  /// doorways, glass and paper let part of it through.
  static double transmittanceFor(InteriorWallConfig w) {
    double t;
    switch (w.style) {
      case 'bathroom_glass':
        t = 0.6;
        break;
      case 'japanese_shoji':
        t = 0.35;
        break;
      case 'doorway_frame':
        t = 0.5;
        break;
      default:
        t = 0.0;
    }
    if (w.hasDoorway) t = max(t, 0.5);
    return t;
  }

  /// Same edge mapping as `CozyRoomGame._recalculateObstacles` (pathfinding), but keeps
  /// doorways/glass as partial blockers instead of fully open.
  factory LightOcclusion.fromWalls(Iterable<InteriorWallConfig> walls) {
    final north = Float32List(size * size)..fillRange(0, size * size, 1);
    final west = Float32List(size * size)..fillRange(0, size * size, 1);
    void setMin(Float32List arr, int i, int j, double t) {
      if (i < 0 || j < 0 || i >= size || j >= size) return;
      final idx = j * size + i;
      if (t < arr[idx]) arr[idx] = t;
    }

    for (final w in walls) {
      final t = transmittanceFor(w);
      final baseU = w.gridX * 2;
      final baseV = w.gridY * 2;
      if (w.orientation == 'north') {
        if (w.gridY > 0) {
          setMin(north, baseU, baseV, t);
          setMin(north, baseU + 1, baseV, t);
        }
      } else {
        if (w.gridX > 0) {
          setMin(west, baseU, baseV, t);
          setMin(west, baseU, baseV + 1, t);
        }
      }
    }
    return LightOcclusion._(north, west);
  }

  /// Transmittance between two orthogonally adjacent cells (1 = open, 0 = solid wall).
  double transmittance(int i1, int j1, int i2, int j2) {
    if (i1 == i2) {
      if ((j1 - j2).abs() != 1) return 0;
      return _northT[max(j1, j2) * size + i1];
    }
    if (j1 == j2) {
      if ((i1 - i2).abs() != 1) return 0;
      return _westT[j1 * size + max(i1, i2)];
    }
    return 0;
  }

  /// A diagonal step is open only if both L-shaped routes around it are fully open.
  bool diagonalOpen(int i1, int j1, int i2, int j2) {
    return transmittance(i1, j1, i2, j1) >= 1 &&
        transmittance(i2, j1, i2, j2) >= 1 &&
        transmittance(i1, j1, i1, j2) >= 1 &&
        transmittance(i1, j2, i2, j2) >= 1;
  }

  /// Whether light at (i1, j1) may be blended with (i2, j2) when sampling: same cell,
  /// adjacent through a non-solid edge, or diagonal with at least one non-solid L route.
  bool lightConnected(int i1, int j1, int i2, int j2) {
    final di = (i1 - i2).abs(), dj = (j1 - j2).abs();
    if (di == 0 && dj == 0) return true;
    if (di + dj == 1) return transmittance(i1, j1, i2, j2) > 0;
    if (di == 1 && dj == 1) {
      return (transmittance(i1, j1, i2, j1) > 0 && transmittance(i2, j1, i2, j2) > 0) ||
          (transmittance(i1, j1, i1, j2) > 0 && transmittance(i1, j2, i2, j2) > 0);
    }
    return false;
  }

  int sectorAt(int i, int j) => _sector[j.clamp(0, size - 1) * size + i.clamp(0, size - 1)];

  /// Sectors = connected areas where any interior wall (even a doorway) is a boundary.
  void _computeSectors() {
    _sector.fillRange(0, size * size, -1);
    final stack = <int>[];
    int next = 0;
    for (int start = 0; start < size * size; start++) {
      if (_sector[start] != -1) continue;
      _sector[start] = next;
      stack.add(start);
      while (stack.isNotEmpty) {
        final k = stack.removeLast();
        final i = k % size, j = k ~/ size;
        void visit(int ni, int nj) {
          if (ni < 0 || nj < 0 || ni >= size || nj >= size) return;
          final nk = nj * size + ni;
          if (_sector[nk] != -1) return;
          if (transmittance(i, j, ni, nj) < 1) return;
          _sector[nk] = next;
          stack.add(nk);
        }

        visit(i + 1, j);
        visit(i - 1, j);
        visit(i, j + 1);
        visit(i, j - 1);
      }
      next++;
    }
    _sectorCount = next;
  }
}

/// Builds the light list from a room config.
class RoomLightSources {
  /// Just under the top of a full-height wall (68 px).
  static const double ceilingGlowHeight = 60;

  /// [specFor] resolves a furniture type to its emitter spec (defaults to the built-in
  /// table in [EmitterLightSpec.defaultFor]; the game passes the catalog lookup).
  /// [activeIds]: furniture currently activated (see [EmitterLightSpec.followsActivation]).
  static List<LightSourceDef> fromRoomConfig(
    RoomConfig config, {
    EmitterLightSpec? Function(String typeName)? specFor,
    Set<String> activeIds = const {},
  }) {
    final lookup = specFor ?? EmitterLightSpec.defaultFor;
    final result = <LightSourceDef>[];
    int seed = 0;

    for (final c in config.lighting.ceilingLights) {
      result.add(LightSourceDef(
        id: c.id,
        u: c.gridX * 2,
        v: c.gridY * 2,
        radius: c.radius * 2,
        color: c.color.color,
        intensity: c.intensity,
        on: c.on,
        seed: seed++,
        isCeiling: true,
        glowHeight: ceilingGlowHeight,
      ));
    }

    for (final f in config.furniture) {
      final spec = lookup(f.typeName) ?? lookup(f.id);
      if (spec == null) continue;
      final pos = emitterPosition(f, spec);
      result.add(LightSourceDef(
        id: f.id,
        u: pos.x,
        v: pos.y,
        radius: spec.radius * 2,
        color: (f.lightColor ?? spec.color).color,
        intensity: spec.intensity,
        anim: spec.anim,
        on: spec.followsActivation
            ? activeIds.contains(f.id)
            : (spec.toggleable ? (f.lightOn ?? spec.defaultOn) : true),
        affectedByMaster: false,
        toggleable: spec.toggleable,
        seed: seed++,
        selfLit: spec.anim == LightAnim.daylight ? 0 : spec.selfLit,
        glowHeight: spec.anim == LightAnim.daylight ? 0 : spec.height,
      ));
    }
    return result;
  }

  /// Sub-grid point the light radiates from. Wall items are pushed into the room (a window
  /// further than a sconce) so their light lands on the floor, not inside the wall.
  static Point<double> emitterPosition(PlacedFurnitureConfig f, EmitterLightSpec spec) {
    final isWallItem = f.typeName.endsWith('_n') ||
        f.typeName.endsWith('_w') ||
        f.id.endsWith('_n') ||
        f.id.endsWith('_w') ||
        f.typeName.contains('window') ||
        f.typeName.contains('wall');
    if (isWallItem) {
      final inward = spec.anim == LightAnim.daylight ? 1.5 : 1.0;
      final isWest = f.typeName.endsWith('_w') ||
          f.id.endsWith('_w') ||
          (f.gridX == 0 && f.gridY > 0 && !f.typeName.endsWith('_n') && !f.id.endsWith('_n'));
      if (isWest) return Point(inward, f.gridY * 2 + 1);
      return Point(f.gridX * 2 + 1, inward);
    }
    return Point(f.gridX * 2 + f.gridWidth, f.gridY * 2 + f.gridHeight);
  }
}
