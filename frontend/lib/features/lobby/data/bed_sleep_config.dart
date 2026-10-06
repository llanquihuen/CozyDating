import 'dart:ui';

/// The two lying sprite views. A: head toward the back of the bed (headboard behind),
/// feet toward the camera. B: head toward the front (headboard in front of the head).
enum LieView { a, b }

/// How an avatar lies on one rotation of a bed.
class SleepSpot {
  /// Which lying sprite set to use.
  final LieView view;

  /// Rotations 1/3 are the horizontal mirror of 0/2: the lying sprites are drawn flipped.
  final bool mirror;

  /// Where the head point of the lying sprite goes, in bed-sprite pixels of the UNMIRRORED
  /// base rotation (0 or 2). Tuned against CreateSprites/lying_pipeline previews.
  final Offset baseHead;

  /// Rotation whose overlay sprites apply (overlays are per real rotation, already mirrored).
  final int maskRotation;

  /// A point on the blanket's folded edge (unmirrored base-rotation bed pixels). Under the covers
  /// the body is not drawn past this edge; the bed's blanket overlay is drawn over it instead.
  /// The edge runs along the bed's short axis, direction (2, 1).
  final Offset blanketEdge;

  /// Which side of the edge is under the blanket: toward the camera (view A, feet in front)
  /// or toward the back (view B, head in front).
  final bool coveredBelow;

  const SleepSpot({
    required this.view,
    required this.mirror,
    required this.baseHead,
    required this.maskRotation,
    required this.blanketEdge,
    required this.coveredBelow,
  });
}

/// Beds the avatar can lie on, per rotation (0: SW, 1: SE, 2: NE, 3: NW).
/// Overlays come from CreateSprites/lying_pipeline/make_bed_overlays.py; keep edges in sync.
///
/// A bed for two has one entry per side: 'king_bed' is side 0 and 'king_bed:1' side 1. In the
/// base rotation side 1 is the half nearer the camera, so it is drawn over side 0.
class BedSleepConfig {
  /// Canvas size of the lying layers (assets/images/OCTOPLAYER/Avatar/lying/**).
  static const Size lieCanvas = Size(160, 128);

  /// Head point inside the lying canvas, per view.
  static const Map<LieView, Offset> headInCanvas = {
    LieView.a: Offset(114, 40),
    LieView.b: Offset(47, 91),
  };

  static const Map<String, Map<int, SleepSpot>> _spots = {
    'single_bed': {
      0: SleepSpot(view: LieView.a, mirror: false, baseHead: Offset(156, 36), maskRotation: 0, blanketEdge: Offset(145, 42), coveredBelow: true),
      1: SleepSpot(view: LieView.a, mirror: true, baseHead: Offset(156, 36), maskRotation: 1, blanketEdge: Offset(145, 42), coveredBelow: true),
      2: SleepSpot(view: LieView.b, mirror: false, baseHead: Offset(64, 90), maskRotation: 2, blanketEdge: Offset(76, 84), coveredBelow: false),
      3: SleepSpot(view: LieView.b, mirror: true, baseHead: Offset(64, 90), maskRotation: 3, blanketEdge: Offset(76, 84), coveredBelow: false),
    },
    'king_bed': {
      0: SleepSpot(view: LieView.a, mirror: false, baseHead: Offset(140, 41), maskRotation: 0, blanketEdge: Offset(138, 58), coveredBelow: true),
      1: SleepSpot(view: LieView.a, mirror: true, baseHead: Offset(140, 41), maskRotation: 1, blanketEdge: Offset(138, 58), coveredBelow: true),
      2: SleepSpot(view: LieView.b, mirror: false, baseHead: Offset(55, 101), maskRotation: 2, blanketEdge: Offset(64, 86), coveredBelow: false),
      3: SleepSpot(view: LieView.b, mirror: true, baseHead: Offset(55, 101), maskRotation: 3, blanketEdge: Offset(64, 86), coveredBelow: false),
    },
    'king_bed:1': {
      0: SleepSpot(view: LieView.a, mirror: false, baseHead: Offset(204, 73), maskRotation: 0, blanketEdge: Offset(202, 90), coveredBelow: true),
      1: SleepSpot(view: LieView.a, mirror: true, baseHead: Offset(204, 73), maskRotation: 1, blanketEdge: Offset(202, 90), coveredBelow: true),
      2: SleepSpot(view: LieView.b, mirror: false, baseHead: Offset(119, 133), maskRotation: 2, blanketEdge: Offset(128, 118), coveredBelow: false),
      3: SleepSpot(view: LieView.b, mirror: true, baseHead: Offset(119, 133), maskRotation: 3, blanketEdge: Offset(128, 118), coveredBelow: false),
    },
    'single_high_bed': {
      0: SleepSpot(view: LieView.a, mirror: false, baseHead: Offset(140, 25), maskRotation: 0, blanketEdge: Offset(138, 42), coveredBelow: true),
      1: SleepSpot(view: LieView.a, mirror: true, baseHead: Offset(140, 25), maskRotation: 1, blanketEdge: Offset(138, 42), coveredBelow: true),
      2: SleepSpot(view: LieView.b, mirror: false, baseHead: Offset(55, 85), maskRotation: 2, blanketEdge: Offset(64, 70), coveredBelow: false),
      3: SleepSpot(view: LieView.b, mirror: true, baseHead: Offset(55, 85), maskRotation: 3, blanketEdge: Offset(64, 70), coveredBelow: false),
    },
  };

  /// The bed KIND comes from [typeName]; [id] only names the placed instance and can be
  /// misleading (rooms place a 'single_high_bed' with id 'single_bed'), so it is a last resort.
  static String? _key(String id, String typeName) {
    // Longest first so 'single_high_bed_2' never resolves to a shorter key by prefix.
    final keys = _spots.keys.where((k) => !k.contains(':')).toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final name in [typeName, id]) {
      if (_spots.containsKey(name)) return name;
      for (final k in keys) {
        if (name.startsWith(k)) return k;
      }
    }
    return null;
  }

  static bool supports(String id, String typeName) => _key(id, typeName) != null;

  /// How many people fit side by side (1 for single beds, 2 for the king bed).
  static int sideCount(String id, String typeName) {
    final k = _key(id, typeName);
    if (k == null) return 0;
    var n = 1;
    while (_spots.containsKey('$k:$n')) {
      n++;
    }
    return n;
  }

  static SleepSpot? spotFor(String id, String typeName, int rotation, {int side = 0}) {
    final k = _key(id, typeName);
    if (k == null) return null;
    return _spots[side == 0 ? k : '$k:$side']?[rotation % 4];
  }

  /// The side of a bed for two under [bedPixel] (bed-sprite pixels of the drawn rotation): the
  /// side of the line along the bed's long axis (2, -1) halfway between the two heads.
  static int sideAt(String id, String typeName, int rotation, Offset bedPixel, double bedWidth) {
    final a = spotFor(id, typeName, rotation);
    final b = spotFor(id, typeName, rotation, side: 1);
    if (a == null || b == null) return 0;
    final p = a.mirror ? Offset(bedWidth - bedPixel.dx, bedPixel.dy) : bedPixel;
    final mid = (a.baseHead + b.baseHead) / 2;
    // Same sign as side 1's head relative to the line.
    double cross(Offset q) => 2 * (q.dy - mid.dy) + (q.dx - mid.dx);
    return cross(p) * cross(b.baseHead) > 0 ? 1 : 0;
  }

  /// Asset path (relative to assets/images/) of the head/footboard wood standing in front of a
  /// sleeper's pillow end (always drawn).
  static String? frontOverlayPath(String id, String typeName, int rotation) {
    final k = _key(id, typeName);
    if (k == null) return null;
    return 'furniture/sleep_overlays/${k}_rot${rotation % 4}_front.png';
  }

  /// Asset path of the blanket redrawn with the bulge of the bodies under it, for the [sides]
  /// that have someone under the covers (null when nobody is). Beds for two have one blanket per
  /// side, covering only that half (so whoever lies on top of the other half is not hidden),
  /// plus one with both bulges.
  static String? blanketOverlayPath(String id, String typeName, int rotation, Set<int> sides) {
    final k = _key(id, typeName);
    if (k == null || sides.isEmpty) return null;
    final suffix = sideCount(id, typeName) == 1 || sides.length > 1 ? '' : '${sides.single}';
    return 'furniture/sleep_overlays/${k}_rot${rotation % 4}_blanket$suffix.png';
  }
}
