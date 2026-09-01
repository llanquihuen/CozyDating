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

  // Cached OCTOPLAYER 8-direction individual frames
  final Map<String, Image> _octoImageCache = {};

  double _animTimer = 0.0;
  int _currentFrame = 0;
  static const double _frameDuration = 0.16;

  ModularAvatarComponent({
    required this.config,
    this.direction = AvatarDirection.south,
    this.isMoving = false,
    Vector2? position,
    Vector2? size,
  }) : super(
          position: position ?? Vector2.zero(),
          size: size ?? Vector2(64.0, 128.0),
        );

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
          if (hair == 'long_flow' || hair == 'flow') {
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
          futures.add(_loadOctoFrame('shoes', 'shoes/${config.shoeStyle}$k.png', k));
        }

        // Accessories (if present)
        if (config.accessoryStyle != 'none') {
          futures.add(_loadOctoFrame('accessories', 'accessories/${config.accessoryStyle}$k.png', k));
        }
      }
    }

    await Future.wait(futures);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isMoving) {
      _animTimer += dt;
      if (_animTimer >= _frameDuration) {
        _animTimer -= _frameDuration;
        _currentFrame = (_currentFrame + 1) % 4;
      }
    } else {
      _currentFrame = 0;
      _animTimer = 0.0;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final int dirNum = direction.dirNumber;
    final String frameKey = isMoving ? '${dirNum}_walk_f${_currentFrame + 1}' : '$dirNum';
    final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);

    void drawLayer(String layerKey, Color? tintColor) {
      final img = _octoImageCache['$layerKey:$frameKey'] ?? _octoImageCache['$layerKey:$dirNum'];
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

    // Layer 2: Body (Base Skin)
    drawLayer('body', config.skinColor);

    // Layer 3: Bottoms / Pants / Jeans
    if (config.bottomStyle != 'none') {
      drawLayer('bottoms', config.bottomColor);
    }

    // Layer 4: Shoes / Boots
    if (config.shoeStyle != 'none') {
      drawLayer('shoes', config.shoeColor);
    }

    // Layer 5: Tops / Jacket / Shirt
    if (config.topStyle != 'none') {
      drawLayer('tops', config.topColor);
    }

    // Layer 6: Head / Face Shape (Skin Color, rendered over clothes)
    drawLayer('head', config.skinColor);

    // Layer 7: Nose (Skin Color outline)
    drawLayer('nose', config.skinColor);

    // Layer 8: Mouth
    drawLayer('mouth', null);

    // Layer 9: Eyes (Iris & Eyebrows are dual-tinted at pixel level)
    drawLayer('eyes', null);

    // Layer 10: Hair Front (Front locks / bangs)
    if (config.hairStyle != 'none') {
      drawLayer('hair_front', config.hairColor);
    }

    // Layer 11: Accessories
    if (config.accessoryStyle != 'none') {
      drawLayer('accessories', config.accessoryColor);
    }
  }
}
