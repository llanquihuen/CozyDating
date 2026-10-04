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
  /// base rotation (0 or 2). Tuned against CreateSprites/scratch/lie_sprites previews.
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
/// Overlays come from CreateSprites/scratch/lie_sprites/make_bed_overlays.py; keep edges in sync.
class BedSleepConfig {
  /// Canvas size of the lying layers (assets/images/OCTOPLAYER/Avatar/lying/**).
  static const Size lieCanvas = Size(160, 128);

  /// Head point inside the lying canvas, per view.
  static const Map<LieView, Offset> headInCanvas = {
    LieView.a: Offset(114, 40),
    LieView.b: Offset(47, 91),
  };

  /// Bed sprite width in pixels (mirror axis).
  static const double bedSpriteWidth = 192;

  static const Map<String, Map<int, SleepSpot>> _spots = {
    'single_bed': {
      0: SleepSpot(view: LieView.a, mirror: false, baseHead: Offset(156, 36), maskRotation: 0, blanketEdge: Offset(145, 42), coveredBelow: true),
      1: SleepSpot(view: LieView.a, mirror: true, baseHead: Offset(156, 36), maskRotation: 1, blanketEdge: Offset(145, 42), coveredBelow: true),
      2: SleepSpot(view: LieView.b, mirror: false, baseHead: Offset(64, 90), maskRotation: 2, blanketEdge: Offset(76, 84), coveredBelow: false),
      3: SleepSpot(view: LieView.b, mirror: true, baseHead: Offset(64, 90), maskRotation: 3, blanketEdge: Offset(76, 84), coveredBelow: false),
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
    final keys = _spots.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final name in [typeName, id]) {
      if (_spots.containsKey(name)) return name;
      for (final k in keys) {
        if (name.startsWith(k)) return k;
      }
    }
    return null;
  }

  static bool supports(String id, String typeName) => _key(id, typeName) != null;

  static SleepSpot? spotFor(String id, String typeName, int rotation) {
    final k = _key(id, typeName);
    return k == null ? null : _spots[k]![rotation % 4];
  }

  /// Asset path (relative to assets/images/) of a bed overlay drawn in front of the sleeper:
  /// [blanket] = the blanket with the body's bulge (only while someone is under the covers),
  /// otherwise the head/footboard wood standing in front of the pillow end.
  static String? overlayPath(String id, String typeName, int rotation, {required bool blanket}) {
    final k = _key(id, typeName);
    if (k == null) return null;
    return 'furniture/sleep_overlays/${k}_rot${rotation % 4}_${blanket ? 'blanket' : 'front'}.png';
  }
}
