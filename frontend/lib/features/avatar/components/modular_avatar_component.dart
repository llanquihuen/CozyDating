import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/services.dart' show rootBundle;
import '../../../core/models/avatar_catalog.dart';
import '../../../core/models/avatar_config.dart';
import 'face_makeup.dart';

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
        !listEquals(config.marks, newConfig.marks) ||
        !mapEquals(config.accessories, newConfig.accessories) ||
        config.accessoryColor != newConfig.accessoryColor ||
        !mapEquals(config.makeup, newConfig.makeup) ||
        !mapEquals(config.makeupColors, newConfig.makeupColors);

    config = newConfig;
    if (needsReload) {
      await reloadSprites();
    }
  }

  static const _assetRoot = 'assets/images/OCTOPLAYER/Avatar/';
  static final Map<String, Future<Image?>> _sprites = {};

  /// An avatar sprite, or null when it does not ship with the app (optional frames: body-fitted
  /// clothes, fallbacks). Loaded straight from the bundle instead of through Flame's image cache,
  /// which reports a missing asset as an uncaught error even when the caller catches it. Shared by
  /// every avatar, like that cache.
  static Future<Image?> _loadSprite(String relativePath) {
    return _sprites.putIfAbsent(relativePath, () async {
      try {
        final data = await rootBundle.load('$_assetRoot$relativePath');
        final codec = await instantiateImageCodec(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
        return (await codec.getNextFrame()).image;
      } catch (_) {
        return null;
      }
    });
  }

  Future<void> _loadOctoFrame(String layerKey, String relativePath, String cacheKey) async {
    final img = await _loadSprite(relativePath);
    if (img != null) _octoImageCache['$layerKey:$cacheKey'] = img;
  }

  Future<void> _loadOctoEyesFrame(String relativePath, String cacheKey,
      {List<int> up = FaceMakeup.standingUp}) async {
    final baseImg = await _loadSprite(relativePath);
    if (baseImg == null) return;
    try {
      final byteData = await baseImg.toByteData(format: ImageByteFormat.rawRgba);
      if (byteData == null) {
        _octoImageCache['eyes:$cacheKey'] = baseImg;
        return;
      }

      final buffer = byteData.buffer.asUint8List();
      final length = buffer.length;

      // Eyeshadow is found on the colour-coded layer, then painted over the tinted result.
      final shadow = config.makeup[AvatarCatalog.eyeshadow];
      final shadowTargets = shadow == null
          ? null
          : FaceMakeup.eyeshadowTargets(buffer, baseImg.width, baseImg.height,
              up: up, smoky: shadow == 'shadow_smoky');

      final eyeR = config.eyeColor.red;
      final eyeG = config.eyeColor.green;
      final eyeB = config.eyeColor.blue;

      final browR = config.eyebrowColor.red;
      final browG = config.eyebrowColor.green;
      final browB = config.eyebrowColor.blue;

      final skinR = config.skinColor.red;
      final skinG = config.skinColor.green;
      final skinB = config.skinColor.blue;

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
        // Blue-dominant: Sombra o delineado de ojos (si no hay azul, queda transparente)
        else if (b > r + 15 && b > g + 15 && b >= 40) {
          if (b >= 180) {
            // Sombra suave de piel
            buffer[i] = (skinR * 0.82).round().clamp(0, 255);
            buffer[i + 1] = (skinG * 0.70).round().clamp(0, 255);
            buffer[i + 2] = (skinB * 0.65).round().clamp(0, 255);
          } else if (b >= 120) {
            // Sombra profunda / pliegue de párpado
            buffer[i] = (skinR * 0.60).round().clamp(0, 255);
            buffer[i + 1] = (skinG * 0.46).round().clamp(0, 255);
            buffer[i + 2] = (skinB * 0.42).round().clamp(0, 255);
          } else {
            // Delineado oscuro carbón
            buffer[i] = 32;
            buffer[i + 1] = 24;
            buffer[i + 2] = 38;
          }
        }
        // Other pixels (black eyeliner/lashes, white sclera) remain unchanged
      }
      if (shadowTargets != null) {
        FaceMakeup.paint(buffer, shadowTargets, config.makeupColor(AvatarCatalog.eyeshadow));
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

  /// Mouth layer, with lipstick painted on when worn.
  Future<void> _loadOctoMouthFrame(String relativePath, String cacheKey,
      {List<int> up = FaceMakeup.standingUp}) async {
    final lipstick = config.makeup[AvatarCatalog.lipstick];
    if (lipstick == null) return _loadOctoFrame('mouth', relativePath, cacheKey);
    final baseImg = await _loadSprite(relativePath);
    if (baseImg == null) return;
    try {
      final byteData = await baseImg.toByteData(format: ImageByteFormat.rawRgba);
      if (byteData == null) {
        _octoImageCache['mouth:$cacheKey'] = baseImg;
        return;
      }
      final buffer = byteData.buffer.asUint8List();
      FaceMakeup.paintLipstick(buffer, baseImg.width, baseImg.height,
          up: up, color: config.makeupColor(AvatarCatalog.lipstick), bold: lipstick == 'lip_bold');
      final completer = Completer<Image>();
      decodeImageFromPixels(buffer, baseImg.width, baseImg.height, PixelFormat.rgba8888, completer.complete);
      _octoImageCache['mouth:$cacheKey'] = await completer.future;
    } catch (_) {
      // Ignored if specific file doesn't exist
    }
  }

  /// Garment frame fitted to the body type (`<style>_<body><suffix>`), else the style's generic one
  /// (shared by both bodies, like the original jacket and jeans).
  Future<void> _loadFitted(String layerKey, String folder, String style, String suffix, String cacheKey,
      String bodyType) {
    return _loadOctoFrame(layerKey, '$folder/${style}_$bodyType$suffix', cacheKey).then((_) {
      if (!_octoImageCache.containsKey('$layerKey:$cacheKey')) {
        return _loadOctoFrame(layerKey, '$folder/$style$suffix', cacheKey);
      }
    });
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
        futures.add(_loadOctoMouthFrame('mouth/$mouth$k.png', k).then((_) {
          if (!_octoImageCache.containsKey('mouth:$k')) {
            return _loadOctoMouthFrame('mouth/catmouth$k.png', k);
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
          if (AvatarCatalog.find(AvatarCatalog.hair, hair)?.hasBack ?? false) {
            futures.add(_loadOctoFrame('hair_back', 'hair/$hair/back/$hair$k.png', k));
          }
          futures.add(_loadOctoFrame('hair_front', 'hair/$hair/front/$hair$k.png', k));
        }

        // Tops
        if (config.topStyle != 'none') {
          futures.add(_loadFitted('tops', 'tops', top, '$k.png', k, bodyType));
        }

        // Bottoms
        if (config.bottomStyle != 'none') {
          futures.add(_loadFitted('bottoms', 'bottoms', bottom, '$k.png', k, bodyType));
        }

        // Shoes (if present)
        if (config.shoeStyle != 'none') {
          final cardinal = _dirToCardinal(d);
          final isWalk = k.contains('_walk_f');
          final walkFrame = isWalk ? k.split('_walk_f').last : '';
          final shoeFileName = isWalk
              ? '${config.shoeStyle}_${cardinal}_walk$walkFrame.png'
              : '${config.shoeStyle}_$cardinal.png';

          // body-fitted frames first (sneakers_female1.png), then the shared cardinal / numbered ones
          futures.add(_loadOctoFrame('shoes', 'shoes/${config.shoeStyle}_$bodyType$k.png', k).then((_) {
            if (_octoImageCache.containsKey('shoes:$k')) return null;
            return _loadOctoFrame('shoes', 'shoes/$shoeFileName', k);
          }).then((_) {
            if (!_octoImageCache.containsKey('shoes:$k')) {
              return _loadOctoFrame('shoes', 'shoes/${config.shoeStyle}$k.png', k);
            }
          }));
        }

        // Body marks (several at once): face marks over the head, body tattoos on the skin in two
        // layers (over the body sprite / over the swinging near arm)
        for (final mark in config.marks) {
          if (_isBodyArt(mark)) {
            futures.add(_loadOctoFrame('tattoo_$mark', 'tattoos/${mark}_$bodyType$k.png', k));
            futures.add(_loadOctoFrame('tattoo_hands_$mark', 'tattoos/${mark}_${bodyType}_hands$k.png', k));
          } else {
            futures.add(_loadOctoFrame('mark_$mark', 'marks/$mark$k.png', k));
          }
        }

        // Worn accessories (one per slot)
        config.accessories.forEach((slot, style) {
          futures.add(_loadOctoFrame('accessory_$slot', 'accessories/$slot/$style$k.png', k));
        });

        // Blush (tinted with its makeup colour); eyeshadow and lipstick are painted onto eyes/mouth
        final blush = config.makeup[AvatarCatalog.blush];
        if (blush != null) {
          futures.add(_loadOctoFrame('makeup_blush', 'makeup/blush/$blush$k.png', k));
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

        // Body tattoos sit frames
        for (final mark in config.marks.where(_isBodyArt)) {
          futures.add(_loadOctoFrame('tattoo_$mark', 'tattoos/${mark}_${bodyType}_${cardinal}_sit$f.png', sitKey));
          futures.add(_loadOctoFrame(
              'tattoo_hands_$mark', 'tattoos/${mark}_${bodyType}_hands_${cardinal}_sit$f.png', sitKey));
        }

        // Hands sit frame
        futures.add(_loadOctoFrame('hands', 'body/${bodyType}${d}_sitting_hands_f$f.png', sitKey));

        // Tops sit frame: e.g. tops/jacket_SE_sit1.png
        if (config.topStyle != 'none') {
          futures.add(_loadFitted('tops', 'tops', top, '_${cardinal}_sit$f.png', sitKey, bodyType).then((_) {
            if (!_octoImageCache.containsKey('tops:$sitKey')) {
              return _loadOctoFrame('tops', 'tops/${top}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Bottoms sit frame: e.g. bottoms/jeans_SE_sit1.png
        if (config.bottomStyle != 'none') {
          futures.add(_loadFitted('bottoms', 'bottoms', bottom, '_${cardinal}_sit$f.png', sitKey, bodyType).then((_) {
            if (!_octoImageCache.containsKey('bottoms:$sitKey')) {
              return _loadOctoFrame('bottoms', 'bottoms/${bottom}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Shoes sit frame: e.g. shoes/boots_SE_sit1.png
        if (config.shoeStyle != 'none') {
          futures.add(_loadFitted('shoes', 'shoes', config.shoeStyle, '_${cardinal}_sit$f.png', sitKey, bodyType).then((_) {
            if (!_octoImageCache.containsKey('shoes:$sitKey')) {
              return _loadOctoFrame('shoes', 'shoes/${config.shoeStyle}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Backleg frame for sitting (only applicable to NE (4) and NW (6) at frame 3)
        if ((d == 4 || d == 6) && f == 3) {
          futures.add(_loadOctoFrame('body_backleg', 'body/${bodyType}${d}_sitting_f3_backleg.png', sitKey));
          if (config.bottomStyle != 'none') {
            futures.add(_loadFitted('bottoms_backleg', 'bottoms', bottom, '_${cardinal}_backleg_sit3.png', sitKey, bodyType));
          }
          if (config.shoeStyle != 'none') {
            futures.add(_loadFitted('shoes_backleg', 'shoes', config.shoeStyle, '_${cardinal}_backleg_sit3.png', sitKey, bodyType).then((_) {
              if (!_octoImageCache.containsKey('shoes_backleg:$sitKey')) {
                return _loadOctoFrame('shoes_backleg', 'shoes/${config.shoeStyle}${d}_sitting_f3_backleg.png', sitKey);
              }
            }));
          }
        }
      }
    }

    _addLyingLoads(futures, bodyType: bodyType, hair: hair, top: top, bottom: bottom, eye: eye, mouth: mouth, nose: nose);

    await Future.wait(futures);
  }

  /// Lying layers live in OCTOPLAYER/Avatar/lying/ (160x128 canvas, views A/B). Only some
  /// styles have lying art yet, so each layer falls back to a default style that does.
  void _addLyingLoads(
    List<Future<void>> futures, {
    required String bodyType,
    required String hair,
    required String top,
    required String bottom,
    required String eye,
    required String mouth,
    required String nose,
  }) {
    Future<void> withFallback(String layerKey, String path, String fallbackPath, String key) {
      return _loadOctoFrame(layerKey, path, key).then((_) {
        if (!_octoImageCache.containsKey('$layerKey:$key')) {
          return _loadOctoFrame(layerKey, fallbackPath, key);
        }
      });
    }

    for (final v in const ['A', 'B']) {
      final key = 'lie$v';
      futures.add(_loadOctoFrame('body', 'lying/body/${bodyType}_lie$v.png', key));
      futures.add(withFallback('nose', 'lying/nose/${nose}_lie$v.png', 'lying/nose/standard_lie$v.png', key));
      final up = FaceMakeup.lyingUp[v]!;
      futures.add(_loadOctoMouthFrame('lying/mouth/${mouth}_lie$v.png', key, up: up).then((_) {
        if (!_octoImageCache.containsKey('mouth:$key')) {
          return _loadOctoMouthFrame('lying/mouth/catmouth_lie$v.png', key, up: up);
        }
      }));
      futures.add(_loadOctoEyesFrame('lying/eyes/${eye}_lie$v.png', key, up: up).then((_) {
        if (!_octoImageCache.containsKey('eyes:$key')) {
          return _loadOctoEyesFrame('lying/eyes/cateyes_lie$v.png', key, up: up);
        }
      }));
      final blush = config.makeup[AvatarCatalog.blush];
      if (blush != null) {
        futures.add(_loadOctoFrame('makeup_blush', 'lying/makeup/blush/${blush}_lie$v.png', key));
      }
      // Body marks have no fallback: a mark without lying art is simply not drawn.
      for (final mark in config.marks) {
        futures.add(_isBodyArt(mark)
            ? _loadOctoFrame('tattoo_$mark', 'lying/tattoos/${mark}_${bodyType}_lie$v.png', key)
            : _loadOctoFrame('mark_$mark', 'lying/marks/${mark}_lie$v.png', key));
      }
      // Asleep under the covers the eyes are always closed, whatever the chosen style.
      futures.add(_loadOctoEyesFrame('lying/eyes/closedeyes_lie$v.png', '${key}_closed', up: up));
      // Clothes are fitted per body type (e.g. jacket_female_lieA); then the style's generic
      // lying version, then the default garment.
      Future<void> garment(String layerKey, String folder, String style, String fallbackStyle) {
        return _loadOctoFrame(layerKey, 'lying/$folder/${style}_${bodyType}_lie$v.png', key).then((_) {
          if (!_octoImageCache.containsKey('$layerKey:$key')) {
            return withFallback(layerKey, 'lying/$folder/${style}_lie$v.png', 'lying/$folder/${fallbackStyle}_lie$v.png', key);
          }
        });
      }

      if (config.topStyle != 'none') {
        futures.add(garment('tops', 'tops', top, 'jacket'));
      }
      if (config.bottomStyle != 'none') {
        futures.add(garment('bottoms', 'bottoms', bottom, 'jeans'));
      }
      if (config.hairStyle != 'none') {
        futures.add(_loadOctoFrame('hair_front', 'lying/hair/$hair/${hair}_lie$v.png', key));
      }
      // Shoes and accessories have no default fallback: without lying art they are not drawn.
      if (config.shoeStyle != 'none') {
        final shoe = config.shoeStyle;
        futures.add(withFallback(
            'shoes', 'lying/shoes/${shoe}_${bodyType}_lie$v.png', 'lying/shoes/${shoe}_lie$v.png', key));
      }
      config.accessories.forEach((slot, style) {
        futures.add(_loadOctoFrame('accessory_$slot', 'lying/accessories/$slot/${style}_lie$v.png', key));
      });
    }
  }

  static bool _isBodyArt(String mark) => AvatarCatalog.find(AvatarCatalog.mark, mark)?.underClothes ?? false;

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
      if (config.bottomStyle != 'none') draw('bottoms', key, config.bottomColor);
      if (config.shoeStyle != 'none' && !pose.barefoot) draw('shoes', key, config.shoeColor);
      if (config.topStyle != 'none') draw('tops', key, config.topColor);
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
             layerKey.startsWith('mark_') ||
             layerKey.startsWith('makeup_') ||
             layerKey.startsWith('accessory_'))) {
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

    // Layer 2b: Body tattoos on the body sprite (clothes are drawn over them)
    for (final mark in config.marks.where(_isBodyArt)) {
      drawLayer('tattoo_$mark', null);
    }

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

    // Layer 4b: Body tattoos on the near arm, which swings over the body
    for (final mark in config.marks.where(_isBodyArt)) {
      drawLayer('tattoo_hands_$mark', null);
    }

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

    // Layer 7b: Body marks (own colors, drawn on the skin under the facial features)
    for (final mark in config.marks) {
      drawLayer('mark_$mark', null);
    }

    // Layer 7c: Blush (makeup colour); eyeshadow and lipstick are already in the eyes/mouth layers
    if (config.makeup.containsKey(AvatarCatalog.blush)) {
      drawLayer('makeup_blush', config.makeupColor(AvatarCatalog.blush));
    }

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

    // Layer 12: Worn accessories, in slot order
    for (final slot in AvatarCatalog.accessorySlots) {
      if (config.accessories.containsKey(slot)) {
        drawLayer('accessory_$slot', config.accessoryColor);
      }
    }
  }
}
