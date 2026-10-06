import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import '../../../core/models/avatar_catalog.dart';
import '../../../core/models/avatar_config.dart';
import 'avatar_layers.dart';

enum AvatarDirection {
  south,     // 1: Facing down / screen bottom
  southEast, // 2: Facing down-right
  east,      // 3: Facing right
  northEast, // 4: Facing up-right
  north,     // 5: Facing up / screen top
  northWest, // 6: Facing up-left
  west,      // 7: Facing left
  southWest; // 8: Facing down-left

  static const AvatarDirection down = AvatarDirection.south;
  static const AvatarDirection up = AvatarDirection.north;
  static const AvatarDirection left = AvatarDirection.west;
  static const AvatarDirection right = AvatarDirection.east;

  int get dirNumber => index + 1;
}

/// Everything the renderer needs to draw the avatar lying on a bed. Coordinates are in
/// bed-sprite pixels with (0,0) at the bed sprite's top-left, which is where the parent
/// places this component while lying.
class LyingPose {
  /// 'A' (head at the back) or 'B' (head at the front): picks the lying sprite set.
  final String view;

  /// Draw the lying layers horizontally flipped across the bed sprite (rotations 1/3).
  final bool mirror;

  /// Under the blanket: asleep, so closed eyes, the "under" masks, and worn accessories taken off.
  final bool under;

  /// Shoes taken off (lying on a bed). Lying on the floor or in a park keeps them on.
  final bool barefoot;

  /// Top-left of the 160x128 lying canvas, in unmirrored bed-sprite pixels.
  final Offset canvasOrigin;

  /// Bed sprite width in pixels (mirror axis).
  final double bedWidth;

  /// World units per bed-sprite pixel.
  final double scale;

  /// Under the covers: a point on the blanket's folded edge (unmirrored bed pixels, the edge runs
  /// along (2, 1)) and which side of it is covered. The body is not drawn on the covered side;
  /// the bed's blanket overlay sprite is drawn over that area instead.
  final Offset? blanketEdge;
  final bool coveredBelow;

  const LyingPose({
    required this.view,
    required this.mirror,
    required this.under,
    this.barefoot = false,
    required this.canvasOrigin,
    required this.bedWidth,
    required this.scale,
    this.blanketEdge,
    this.coveredBelow = true,
  });
}

class ModularAvatarComponent extends PositionComponent {
  AvatarConfig config;
  AvatarDirection direction;
  bool isMoving;
  bool isSitting;
  bool renderBacklegSeparately;

  double _animTimer = 0.0;
  int _currentFrame = 0;
  static const double _frameDuration = 0.16;

  int _sittingFrame = 0;
  double _sitAnimTimer = 0.0;
  static const double _sitFrameDuration = 0.12;

  ModularAvatarComponent({
    required this.config,
    this.direction = AvatarDirection.south,
    this.isMoving = false,
    this.isSitting = false,
    this.renderBacklegSeparately = false,
    Vector2? position,
    Vector2? size,
  }) : super(
          position: position ?? Vector2.zero(),
          size: size ?? Vector2(64.0, 128.0),
        );

  void sitDown() {
    isSitting = true;
    isMoving = false;
    _sittingFrame = 0;
    _sitAnimTimer = 0.0;
  }

  void standUp() {
    isSitting = false;
    lyingPose = null;
    _sittingFrame = 0;
    _sitAnimTimer = 0.0;
  }

  /// Non-null while lying on a bed (see [LyingPose]).
  LyingPose? lyingPose;
  bool get isLying => lyingPose != null;

  void lieDown(LyingPose pose) {
    isSitting = false;
    isMoving = false;
    lyingPose = pose;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await reloadSprites();
  }

  Future<void> updateConfig(AvatarConfig newConfig) async {
    final needsReload = config.bodyType != newConfig.bodyType ||
        config.spriteResolution != newConfig.spriteResolution ||
        config.faceShape != newConfig.faceShape ||
        config.noseStyle != newConfig.noseStyle ||
        config.mouthStyle != newConfig.mouthStyle ||
        config.eyeStyle != newConfig.eyeStyle ||
        config.eyeColor != newConfig.eyeColor ||
        config.eyebrowColor != newConfig.eyebrowColor ||
        config.hairStyle != newConfig.hairStyle ||
        config.hairColor != newConfig.hairColor ||
        config.topStyle != newConfig.topStyle ||
        config.topColor != newConfig.topColor ||
        config.bottomStyle != newConfig.bottomStyle ||
        config.bottomColor != newConfig.bottomColor ||
        config.skinColor != newConfig.skinColor ||
        config.shoeStyle != newConfig.shoeStyle ||
        config.shoeColor != newConfig.shoeColor ||
        config.dressStyle != newConfig.dressStyle ||
        config.dressColor != newConfig.dressColor ||
        !listEquals(config.marks, newConfig.marks) ||
        !mapEquals(config.accessories, newConfig.accessories) ||
        config.accessoryColor != newConfig.accessoryColor ||
        !mapEquals(config.makeup, newConfig.makeup) ||
        !mapEquals(config.makeupColors, newConfig.makeupColors);

    config = newConfig;
    if (needsReload) {
      await reloadSprites();
    } else {
      _layers.config = newConfig;
    }
  }

  /// Sprites for [config]. A reload builds a new set and swaps it in when complete, so the avatar
  /// keeps showing the previous look meanwhile; a reload overtaken by a newer one is dropped.
  AvatarLayers _layers = AvatarLayers(const AvatarConfig());
  int _loadGeneration = 0;

  Map<String, Image> get _octoImageCache => _layers.images;

  Future<void> reloadSprites() async {
    final generation = ++_loadGeneration;
    final layers = AvatarLayers(config);
    await layers.loadAll();
    if (generation == _loadGeneration) _layers = layers;
  }

  bool get _hasTop => _layers.hasTop;
  bool get _hasBottom => _layers.hasBottom;
  Color get _topTint => _layers.topTint;
  Color get _bottomTint => _layers.bottomTint;
  static bool _isBodyArt(String mark) => AvatarLayers.isBodyArt(mark);

  @override
  void update(double dt) {
    super.update(dt);
    if (isMoving) {
      isSitting = false;
      _animTimer += dt;
      if (_animTimer >= _frameDuration) {
        _animTimer -= _frameDuration;
        _currentFrame = (_currentFrame + 1) % 4;
      }
    } else if (isSitting) {
      _currentFrame = 0;
      _animTimer = 0.0;
      if (_sittingFrame < 2) {
        _sitAnimTimer += dt;
        if (_sitAnimTimer >= _sitFrameDuration) {
          _sitAnimTimer -= _sitFrameDuration;
          _sittingFrame++;
        }
      }
    } else {
      _currentFrame = 0;
      _animTimer = 0.0;
      _sittingFrame = 0;
      _sitAnimTimer = 0.0;
    }
  }

  /// The current standing/walking/sitting frame key (see [AvatarLayers.paint]).
  String get _frameKey {
    final int dirNum = direction.dirNumber;
    if (!isSitting) return isMoving ? '${dirNum}_walk_f${_currentFrame + 1}' : '$dirNum';
    // Sitting art exists for the diagonals only: odd directions turn to the next one.
    int sitDirNum = dirNum;
    if (dirNum % 2 != 0) {
      sitDirNum = (dirNum + 1) % 8;
      if (sitDirNum == 0) sitDirNum = 8;
    }
    return '${sitDirNum}_sitting_f${_sittingFrame + 1}';
  }

  bool get hasBackleg => _layers.hasBackleg(_frameKey);

  void renderBackleg(Canvas canvas, [Vector2? targetSize]) {
    if (!isSitting) return;
    _layers.paintBackleg(canvas, Rect.fromLTWH(0, 0, targetSize?.x ?? size.x, targetSize?.y ?? size.y), _frameKey);
  }


  void _renderLying(Canvas canvas, LyingPose pose) {
    final key = 'lie${pose.view}';
    canvas.save();
    canvas.scale(pose.scale);

    void drawLayers(void Function(void Function(String layerKey, String cacheKey, Color? tint) draw) body,
        {bool clipToBlanket = false}) {
      canvas.save();
      if (pose.mirror) {
        canvas.translate(pose.bedWidth, 0);
        canvas.scale(-1, 1);
      }
      final edge = pose.blanketEdge;
      if (clipToBlanket && pose.under && edge != null) {
        // Keep only the head side of the blanket edge (in unmirrored bed pixels).
        const along = Offset(2, 1);
        final toHead = pose.coveredBelow ? const Offset(1, -2) : const Offset(-1, 2);
        canvas.clipPath(Path()
          ..moveTo(edge.dx - along.dx * 200, edge.dy - along.dy * 200)
          ..lineTo(edge.dx + along.dx * 200, edge.dy + along.dy * 200)
          ..lineTo(edge.dx + along.dx * 200 + toHead.dx * 200, edge.dy + along.dy * 200 + toHead.dy * 200)
          ..lineTo(edge.dx - along.dx * 200 + toHead.dx * 200, edge.dy - along.dy * 200 + toHead.dy * 200)
          ..close());
      }
      body((layerKey, cacheKey, tint) {
        final img = _octoImageCache['$layerKey:$cacheKey'];
        if (img == null) return;
        final paint = Paint()..filterQuality = FilterQuality.none;
        if (tint != null) paint.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
        canvas.drawImage(img, pose.canvasOrigin, paint);
      });
      canvas.restore();
    }

    // Whatever stands in front of the sleeper (blanket, head/footboard) is the bed's own overlay
    // sprites drawn above this component (BedFrontOverlayComponent), like a chair's backrest.
    drawLayers((draw) {
      draw('body', key, config.skinColor);
      for (final mark in config.marks.where(_isBodyArt)) {
        draw('tattoo_$mark', key, null);
      }
      draw('nose', key, config.skinColor);
      // Marks stay under the covers too (unlike worn accessories, which are never drawn lying).
      for (final mark in config.marks) {
        draw('mark_$mark', key, null);
      }
      if (config.makeup.containsKey(AvatarCatalog.blush)) {
        draw('makeup_blush', key, config.makeupColor(AvatarCatalog.blush));
      }
      draw('mouth', key, null);
      draw('eyes', pose.under ? '${key}_closed' : key, null);
      if (_hasBottom) draw('bottoms', key, _bottomTint);
      if (config.shoeStyle != 'none' && !pose.barefoot) draw('shoes', key, config.shoeColor);
      if (_hasTop) draw('tops', key, _topTint);
    }, clipToBlanket: true);

    // The hairstyle is never cropped.
    if (config.hairStyle != 'none') {
      drawLayers((draw) => draw('hair_front', key, config.hairColor));
    }

    // Worn accessories stay on while lying awake; asleep under the covers they are taken off.
    if (!pose.under) {
      drawLayers((draw) {
        for (final slot in AvatarCatalog.accessorySlots) {
          if (config.accessories.containsKey(slot)) draw('accessory_$slot', key, config.accessoryColor);
        }
      });
    }

    canvas.restore();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final lying = lyingPose;
    if (lying != null) {
      _renderLying(canvas, lying);
      return;
    }

    _layers.paint(canvas, Rect.fromLTWH(0, 0, size.x, size.y), _frameKey,
        separateBackleg: renderBacklegSeparately);
  }
}
