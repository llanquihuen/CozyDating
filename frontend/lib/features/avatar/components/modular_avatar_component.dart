import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../../../core/models/avatar_config.dart';

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

class ModularAvatarComponent extends PositionComponent {
  AvatarConfig config;
  AvatarDirection direction;
  bool isMoving;
  bool isSitting;
  bool renderBacklegSeparately;

  // Cached OCTOPLAYER 8-direction individual frames
  final Map<String, Image> _octoImageCache = {};

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
    _sittingFrame = 0;
    _sitAnimTimer = 0.0;
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
        config.accessoryStyle != newConfig.accessoryStyle ||
        config.accessoryColor != newConfig.accessoryColor;

    config = newConfig;
    if (needsReload) {
      await reloadSprites();
    }
  }

  Future<void> _loadOctoFrame(String layerKey, String relativePath, String cacheKey) async {
    try {
      final img = await Flame.images.load('OCTOPLAYER/Avatar/$relativePath');
      _octoImageCache['$layerKey:$cacheKey'] = img;
    } catch (_) {
      // Ignored if specific file doesn't exist
    }
  }

  Future<void> _loadOctoEyesFrame(String relativePath, String cacheKey) async {
    try {
      final baseImg = await Flame.images.load('OCTOPLAYER/Avatar/$relativePath');
      final byteData = await baseImg.toByteData(format: ImageByteFormat.rawRgba);
      if (byteData == null) {
        _octoImageCache['eyes:$cacheKey'] = baseImg;
        return;
      }

      final buffer = byteData.buffer.asUint8List();
      final length = buffer.length;

      final eyeR = config.eyeColor.red;
      final eyeG = config.eyeColor.green;
      final eyeB = config.eyeColor.blue;

      final browR = config.eyebrowColor.red;
      final browG = config.eyebrowColor.green;
      final browB = config.eyebrowColor.blue;

      for (int i = 0; i < length; i += 4) {
        final a = buffer[i + 3];
        if (a == 0) continue;

        final r = buffer[i];
        final g = buffer[i + 1];
        final b = buffer[i + 2];

        // Red-dominant: Iris / Eye Color (red tint)
        if (r > g + 15 && r > b + 15) {
          final factor = r / 255.0;
          buffer[i] = (eyeR * factor).round().clamp(0, 255);
          buffer[i + 1] = (eyeG * factor).round().clamp(0, 255);
          buffer[i + 2] = (eyeB * factor).round().clamp(0, 255);
        }
        // Green-dominant: Eyebrows (green tint)
        else if (g > r + 15 && g > b + 15) {
          final factor = g / 255.0;
          buffer[i] = (browR * factor).round().clamp(0, 255);
          buffer[i + 1] = (browG * factor).round().clamp(0, 255);
          buffer[i + 2] = (browB * factor).round().clamp(0, 255);
        }
        // Other pixels (black eyeliner/lashes, white sclera) remain unchanged
      }

      final completer = Completer<Image>();
      decodeImageFromPixels(
        buffer,
        baseImg.width,
        baseImg.height,
        PixelFormat.rgba8888,
        completer.complete,
      );
      _octoImageCache['eyes:$cacheKey'] = await completer.future;
    } catch (_) {
      // Ignored if specific file doesn't exist
    }
  }

  Future<void> reloadSprites() async {
    _octoImageCache.clear();
    final futures = <Future<void>>[];

    final bodyType = (config.bodyType == 'male') ? 'male' : 'female';
    final hair = (config.hairStyle != 'none') ? config.hairStyle : 'long_flow';
    final top = (config.topStyle != 'none') ? config.topStyle : 'jacket';
    final bottom = (config.bottomStyle != 'none') ? config.bottomStyle : 'jeans';
    final eye = config.eyeStyle;
    final mouth = config.mouthStyle;
    final nose = config.noseStyle;
    final head = config.faceShape;

    for (int d = 1; d <= 8; d++) {
      final frameKeys = ['$d', '${d}_walk_f1', '${d}_walk_f2', '${d}_walk_f3', '${d}_walk_f4'];
      for (final k in frameKeys) {
        // Body (female / male)
        futures.add(_loadOctoFrame('body', 'body/$bodyType$k.png', k));

        // Hands (female / male)
        if (k == '$d') {
          futures.add(_loadOctoFrame('hands', 'body/${bodyType}_hands$d.png', k));
        } else {
          final isWalk = k.contains('_walk_f');
          final walkFrame = isWalk ? k.split('_walk_f').last : '1';
          futures.add(_loadOctoFrame('hands', 'body/${bodyType}${d}_walk_hands_f$walkFrame.png', k));
        }

        // Head (face shape with oval fallback)
        futures.add(_loadOctoFrame('head', 'head/$head$k.png', k).then((_) {
          if (!_octoImageCache.containsKey('head:$k')) {
            return _loadOctoFrame('head', 'head/oval$k.png', k);
          }
        }));

        // Nose (with standard fallback)
        futures.add(_loadOctoFrame('nose', 'nose/$nose$k.png', k).then((_) {
          if (!_octoImageCache.containsKey('nose:$k')) {
            return _loadOctoFrame('nose', 'nose/standard$k.png', k);
          }
        }));

        // Mouth (with catmouth fallback)
        futures.add(_loadOctoFrame('mouth', 'mouth/$mouth$k.png', k).then((_) {
          if (!_octoImageCache.containsKey('mouth:$k')) {
            return _loadOctoFrame('mouth', 'mouth/catmouth$k.png', k);
          }
        }));

        // Eyes (pixel-level dual tint for iris red & eyebrows green)
        futures.add(_loadOctoEyesFrame('eyes/$eye$k.png', k).then((_) {
          if (!_octoImageCache.containsKey('eyes:$k')) {
            return _loadOctoEyesFrame('eyes/cateyes$k.png', k);
          }
        }));

        // Hair Back & Front
        if (config.hairStyle != 'none') {
          if (AvatarConfig.hairsWithBack.contains(hair)) {
            futures.add(_loadOctoFrame('hair_back', 'hair/$hair/back/$hair$k.png', k));
          }
          futures.add(_loadOctoFrame('hair_front', 'hair/$hair/front/$hair$k.png', k));
        }

        // Tops
        if (config.topStyle != 'none') {
          futures.add(_loadOctoFrame('tops', 'tops/$top$k.png', k));
        }

        // Bottoms
        if (config.bottomStyle != 'none') {
          futures.add(_loadOctoFrame('bottoms', 'bottoms/$bottom$k.png', k));
        }

        // Shoes (if present)
        if (config.shoeStyle != 'none') {
          final cardinal = _dirToCardinal(d);
          final isWalk = k.contains('_walk_f');
          final walkFrame = isWalk ? k.split('_walk_f').last : '';
          final shoeFileName = isWalk
              ? '${config.shoeStyle}_${cardinal}_walk$walkFrame.png'
              : '${config.shoeStyle}_$cardinal.png';

          futures.add(_loadOctoFrame('shoes', 'shoes/$shoeFileName', k).then((_) {
            if (!_octoImageCache.containsKey('shoes:$k')) {
              return _loadOctoFrame('shoes', 'shoes/${config.shoeStyle}$k.png', k);
            }
          }));
        }

        // Accessories (if present)
        if (config.accessoryStyle != 'none') {
          futures.add(_loadOctoFrame('accessories', 'accessories/${config.accessoryStyle}$k.png', k));
        }
      }
    }

    // Load Sitting frames for diagonal directions [2, 4, 6, 8]
    for (final d in [2, 4, 6, 8]) {
      final cardinal = _dirToCardinal(d); // SE, NE, NW, SW
      for (int f = 1; f <= 3; f++) {
        final sitKey = '${d}_sitting_f$f';

        // Body sit frame
        futures.add(_loadOctoFrame('body', 'body/${bodyType}${d}_sitting_f$f.png', sitKey));

        // Hands sit frame
        futures.add(_loadOctoFrame('hands', 'body/${bodyType}${d}_sitting_hands_f$f.png', sitKey));

        // Tops sit frame: e.g. tops/jacket_SE_sit1.png
        if (config.topStyle != 'none') {
          futures.add(_loadOctoFrame('tops', 'tops/${top}_${cardinal}_sit$f.png', sitKey).then((_) {
            if (!_octoImageCache.containsKey('tops:$sitKey')) {
              return _loadOctoFrame('tops', 'tops/${top}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Bottoms sit frame: e.g. bottoms/jeans_SE_sit1.png
        if (config.bottomStyle != 'none') {
          futures.add(_loadOctoFrame('bottoms', 'bottoms/${bottom}_${cardinal}_sit$f.png', sitKey).then((_) {
            if (!_octoImageCache.containsKey('bottoms:$sitKey')) {
              return _loadOctoFrame('bottoms', 'bottoms/${bottom}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Shoes sit frame: e.g. shoes/boots_SE_sit1.png
        if (config.shoeStyle != 'none') {
          futures.add(_loadOctoFrame('shoes', 'shoes/${config.shoeStyle}_${cardinal}_sit$f.png', sitKey).then((_) {
            if (!_octoImageCache.containsKey('shoes:$sitKey')) {
              return _loadOctoFrame('shoes', 'shoes/${config.shoeStyle}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Backleg frame for sitting (only applicable to NE (4) and NW (6) at frame 3)
        if ((d == 4 || d == 6) && f == 3) {
          futures.add(_loadOctoFrame('body_backleg', 'body/${bodyType}${d}_sitting_f3_backleg.png', sitKey));
          if (config.bottomStyle != 'none') {
            futures.add(_loadOctoFrame('bottoms_backleg', 'bottoms/${bottom}_${cardinal}_backleg_sit3.png', sitKey));
          }
          if (config.shoeStyle != 'none') {
            futures.add(_loadOctoFrame('shoes_backleg', 'shoes/${config.shoeStyle}_${cardinal}_backleg_sit3.png', sitKey).then((_) {
              if (!_octoImageCache.containsKey('shoes_backleg:$sitKey')) {
                return _loadOctoFrame('shoes_backleg', 'shoes/${config.shoeStyle}${d}_sitting_f3_backleg.png', sitKey);
              }
            }));
          }
        }
      }
    }

    await Future.wait(futures);
  }

  String _dirToCardinal(int d) {
    switch (d) {
      case 1: return 'S';
      case 2: return 'SE';
      case 3: return 'E';
      case 4: return 'NE';
      case 5: return 'N';
      case 6: return 'NW';
      case 7: return 'W';
      case 8: return 'SW';
      default: return 'S';
    }
  }

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

  bool get hasBackleg {
    final int dirNum = direction.dirNumber;
    int sitDirNum = dirNum;
    if (dirNum % 2 != 0) {
      sitDirNum = (dirNum + 1) % 8;
      if (sitDirNum == 0) sitDirNum = 8;
    }
    final String frameKey = isSitting
        ? '${sitDirNum}_sitting_f${_sittingFrame + 1}'
        : (isMoving ? '${dirNum}_walk_f${_currentFrame + 1}' : '$dirNum');
    return _octoImageCache.containsKey('body_backleg:$frameKey') ||
        _octoImageCache.containsKey('bottoms_backleg:$frameKey') ||
        _octoImageCache.containsKey('shoes_backleg:$frameKey') ||
        _octoImageCache.containsKey('tops_backleg:$frameKey');
  }

  void renderBackleg(Canvas canvas, [Vector2? targetSize]) {
    if (!isSitting) return;

    final int dirNum = direction.dirNumber;
    int sitDirNum = dirNum;
    if (dirNum % 2 != 0) {
      sitDirNum = (dirNum + 1) % 8;
      if (sitDirNum == 0) sitDirNum = 8;
    }

    final String frameKey = '${sitDirNum}_sitting_f${_sittingFrame + 1}';
    final renderWidth = targetSize?.x ?? size.x;
    final renderHeight = targetSize?.y ?? size.y;
    final dstRect = Rect.fromLTWH(0, 0, renderWidth, renderHeight);

    void drawBacklegLayer(String layerKey, Color? tintColor) {
      final img = _octoImageCache['$layerKey:$frameKey'];
      if (img != null) {
        final srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final paint = Paint();
        if (tintColor != null) {
          paint.colorFilter = ColorFilter.mode(tintColor, BlendMode.modulate);
        }
        canvas.drawImageRect(img, srcRect, dstRect, paint);
      }
    }

    // Layer 1: Body backleg (Base skin)
    drawBacklegLayer('body_backleg', config.skinColor);

    // Layer 2: Bottoms backleg (e.g. Jeans - rendered over body skin)
    if (config.bottomStyle != 'none') {
      drawBacklegLayer('bottoms_backleg', config.bottomColor);
    }

    // Layer 3: Shoes backleg (rendered over pants/skin)
    if (config.shoeStyle != 'none') {
      drawBacklegLayer('shoes_backleg', config.shoeColor);
    }

    // Layer 4: Tops backleg (rendered over pants/skin)
    if (config.topStyle != 'none') {
      drawBacklegLayer('tops_backleg', config.topColor);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final int dirNum = direction.dirNumber;
    int sitDirNum = dirNum;
    if (dirNum % 2 != 0) {
      sitDirNum = (dirNum + 1) % 8;
      if (sitDirNum == 0) sitDirNum = 8;
    }

    final String frameKey = isSitting
        ? '${sitDirNum}_sitting_f${_sittingFrame + 1}'
        : (isMoving ? '${dirNum}_walk_f${_currentFrame + 1}' : '$dirNum');
    final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);

    void drawLayer(String layerKey, Color? tintColor) {
      Image? img;
      if (isSitting) {
        img = _octoImageCache['$layerKey:$frameKey'];
        // Facial and hair features don't have separate sitting frames; use seated direction frame
        if (img == null &&
            (layerKey == 'head' ||
             layerKey == 'nose' ||
             layerKey == 'mouth' ||
             layerKey == 'eyes' ||
             layerKey == 'hair_front' ||
             layerKey == 'hair_back' ||
             layerKey == 'accessories')) {
          img = _octoImageCache['$layerKey:$sitDirNum'];
        }
      } else {
        img = _octoImageCache['$layerKey:$frameKey'] ?? _octoImageCache['$layerKey:$dirNum'];
      }
      if (img != null) {
        final srcRect = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final paint = Paint();
        if (tintColor != null) {
          paint.colorFilter = ColorFilter.mode(tintColor, BlendMode.modulate);
        }
        canvas.drawImageRect(img, srcRect, dstRect, paint);
      }
    }

    // Layer 1: Hair Back (Behind body/head)
    if (config.hairStyle != 'none') {
      drawLayer('hair_back', config.hairColor);
    }

    // Layer 2a: Body Backleg (Only when NOT rendered separately behind furniture)
    if (!renderBacklegSeparately && isSitting) {
      drawLayer('body_backleg', config.skinColor);
    }

    // Layer 2: Body (Base Skin)
    drawLayer('body', config.skinColor);

    // Layer 3a: Bottoms Backleg (Only when NOT rendered separately behind furniture)
    if (!renderBacklegSeparately && isSitting && config.bottomStyle != 'none') {
      drawLayer('bottoms_backleg', config.bottomColor);
    }

    // Layer 3: Bottoms / Pants / Jeans
    if (config.bottomStyle != 'none') {
      drawLayer('bottoms', config.bottomColor);
    }

    // Layer 4: Hands (Skin Color - Rendered over pants so arms/hands aren't covered by bottoms)
    drawLayer('hands', config.skinColor);

    // Layer 5a: Shoes Backleg (Only when NOT rendered separately behind furniture)
    if (!renderBacklegSeparately && isSitting && config.shoeStyle != 'none') {
      drawLayer('shoes_backleg', config.shoeColor);
    }

    // Layer 5: Shoes / Boots
    if (config.shoeStyle != 'none') {
      drawLayer('shoes', config.shoeColor);
    }

    // Layer 6a: Tops Backleg (Only when NOT rendered separately behind furniture)
    if (!renderBacklegSeparately && isSitting && config.topStyle != 'none') {
      drawLayer('tops_backleg', config.topColor);
    }

    // Layer 6: Tops / Jacket / Shirt
    if (config.topStyle != 'none') {
      drawLayer('tops', config.topColor);
    }

    // Layer 7: Head / Face Shape (Skin Color, rendered over clothes)
    drawLayer('head', config.skinColor);

    // Layer 8: Nose (Skin Color outline)
    drawLayer('nose', config.skinColor);

    // Layer 9: Mouth
    drawLayer('mouth', null);

    // Layer 10: Eyes (Iris & Eyebrows are dual-tinted at pixel level)
    drawLayer('eyes', null);

    // Layer 11: Hair Front (Front locks / bangs)
    if (config.hairStyle != 'none') {
      drawLayer('hair_front', config.hairColor);
    }

    // Layer 12: Accessories
    if (config.accessoryStyle != 'none') {
      drawLayer('accessories', config.accessoryColor);
    }
  }
}
