import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

import '../../../core/models/avatar_catalog.dart';
import '../../../core/models/avatar_config.dart';
import 'face_makeup.dart';

/// The sprite layers of one avatar config, loaded from OCTOPLAYER/Avatar/ and keyed
/// `layer:frame` (frames: `'1'`..`'8'` standing, `'3_walk_f2'`, `'4_sitting_f1'`, `'lieA'`...),
/// plus the standing/sitting draw order. Shared by [ModularAvatarComponent] (every frame) and
/// still renders such as the editor thumbnails ([loadStill] + [renderStill]: one frame only).
class AvatarLayers {
  AvatarLayers(this.config);

  /// The config these layers were loaded for. Only fields that do not change any sprite (see
  /// [ModularAvatarComponent.updateConfig]) may be swapped without reloading.
  AvatarConfig config;

  final Map<String, Image> images = {};

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
    if (img != null) images['$layerKey:$cacheKey'] = img;
  }

  Future<void> _loadOctoEyesFrame(String relativePath, String cacheKey,
      {List<int> up = FaceMakeup.standingUp}) async {
    final baseImg = await _loadSprite(relativePath);
    if (baseImg == null) return;
    try {
      final byteData = await baseImg.toByteData(format: ImageByteFormat.rawRgba);
      if (byteData == null) {
        images['eyes:$cacheKey'] = baseImg;
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

      final linerColor = config.makeup.containsKey(AvatarCatalog.eyeliner)
          ? config.makeupColor(AvatarCatalog.eyeliner)
          : null;

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
        // Blue-dominant: the liner drawn over the lid. Invisible unless an eyeliner is worn; then its
        // colour, from the lightest blue (soft lid shadow) to the darkest (the line), premultiplied.
        else if (b > r + 15 && b > g + 15 && b >= 40) {
          if (linerColor == null) {
            buffer[i] = buffer[i + 1] = buffer[i + 2] = buffer[i + 3] = 0;
          } else {
            final k = (b >= 180 ? 0.95 : (b >= 120 ? 0.75 : 0.55)) * a / 255;
            buffer[i] = (linerColor.red * k).round();
            buffer[i + 1] = (linerColor.green * k).round();
            buffer[i + 2] = (linerColor.blue * k).round();
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
      images['eyes:$cacheKey'] = await completer.future;
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
        images['mouth:$cacheKey'] = baseImg;
        return;
      }
      final buffer = byteData.buffer.asUint8List();
      FaceMakeup.paintLipstick(buffer, baseImg.width, baseImg.height,
          up: up, color: config.makeupColor(AvatarCatalog.lipstick), bold: lipstick == 'lip_bold');
      final completer = Completer<Image>();
      decodeImageFromPixels(buffer, baseImg.width, baseImg.height, PixelFormat.rgba8888, completer.complete);
      images['mouth:$cacheKey'] = await completer.future;
    } catch (_) {
      // Ignored if specific file doesn't exist
    }
  }

  /// Garment frame fitted to the body type (`<style>_<body><suffix>`), else the style's generic one
  /// (shared by both bodies, like the original jacket and jeans).
  Future<void> _loadFitted(String layerKey, String folder, String style, String suffix, String cacheKey,
      String bodyType) {
    return _loadOctoFrame(layerKey, '$folder/${style}_$bodyType$suffix', cacheKey).then((_) {
      if (!images.containsKey('$layerKey:$cacheKey')) {
        return _loadOctoFrame(layerKey, '$folder/$style$suffix', cacheKey);
      }
    });
  }

  String get _bodyType => config.bodyType == 'male' ? 'male' : 'female';

  /// Every frame the avatar can show: 8 directions standing and walking, sitting, lying.
  Future<void> loadAll() async {
    final futures = <Future<void>>[];
    for (int d = 1; d <= 8; d++) {
      for (final k in ['$d', '${d}_walk_f1', '${d}_walk_f2', '${d}_walk_f3', '${d}_walk_f4']) {
        _addStandingLoads(futures, d, k);
      }
    }
    _addSittingLoads(futures);
    _addLyingLoads(futures);
    await Future.wait(futures);
  }

  /// Only the idle frame of one direction (1 = facing the viewer): enough for a still render.
  Future<void> loadStill({int direction = 1}) async {
    final futures = <Future<void>>[];
    _addStandingLoads(futures, direction, '$direction');
    await Future.wait(futures);
  }

  /// The sprite canvas every standing layer is drawn on.
  static const Rect canvasRect = Rect.fromLTWH(0, 0, 64, 128);

  /// [config] standing still, drawn at sprite resolution: the whole 64x128 canvas, or only the
  /// [crop] part of it (in canvas pixels).
  static Future<Image> renderStill(AvatarConfig config, {int direction = 1, Rect crop = canvasRect}) async {
    final layers = AvatarLayers(config);
    await layers.loadStill(direction: direction);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder)..translate(-crop.left, -crop.top);
    layers.paint(canvas, canvasRect, '$direction');
    return recorder.endRecording().toImage(crop.width.round(), crop.height.round());
  }

  void _addStandingLoads(List<Future<void>> futures, int d, String k) {
    final bodyType = _bodyType;
    final hair = (config.hairStyle != 'none') ? config.hairStyle : 'long_flow';
    final top = (config.topStyle != 'none') ? config.topStyle : 'jacket';
    final bottom = (config.bottomStyle != 'none') ? config.bottomStyle : 'jeans';
    final eye = config.eyeStyle;
    final mouth = config.mouthStyle;
    final nose = config.noseStyle;
    final head = config.faceShape;

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
      if (!images.containsKey('head:$k')) {
        return _loadOctoFrame('head', 'head/oval$k.png', k);
      }
    }));

    // Nose (with standard fallback)
    futures.add(_loadOctoFrame('nose', 'nose/$nose$k.png', k).then((_) {
      if (!images.containsKey('nose:$k')) {
        return _loadOctoFrame('nose', 'nose/standard$k.png', k);
      }
    }));

    // Mouth (with catmouth fallback)
    futures.add(_loadOctoMouthFrame('mouth/$mouth$k.png', k).then((_) {
      if (!images.containsKey('mouth:$k')) {
        return _loadOctoMouthFrame('mouth/catmouth$k.png', k);
      }
    }));

    // Eyes (pixel-level dual tint for iris red & eyebrows green)
    futures.add(_loadOctoEyesFrame('eyes/$eye$k.png', k).then((_) {
      if (!images.containsKey('eyes:$k')) {
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

    // A dress fills both garment layers: bodice as the top, skirt as the bottom
    if (wearsDress) {
      final dress = 'dresses/${config.dressStyle}_$bodyType';
      futures.add(_loadOctoFrame('tops', '$dress$k.png', k));
      futures.add(_loadOctoFrame('bottoms', '${dress}_skirt$k.png', k));
    } else {
      // Tops
      if (config.topStyle != 'none') {
        futures.add(_loadFitted('tops', 'tops', top, '$k.png', k, bodyType));
      }

      // Bottoms
      if (config.bottomStyle != 'none') {
        futures.add(_loadFitted('bottoms', 'bottoms', bottom, '$k.png', k, bodyType));
      }
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
        if (images.containsKey('shoes:$k')) return null;
        return _loadOctoFrame('shoes', 'shoes/$shoeFileName', k);
      }).then((_) {
        if (!images.containsKey('shoes:$k')) {
          return _loadOctoFrame('shoes', 'shoes/${config.shoeStyle}$k.png', k);
        }
      }));
    }

    // Body marks (several at once): face marks over the head, body tattoos on the skin in two
    // layers (over the body sprite / over the swinging near arm)
    for (final mark in config.marks) {
      if (isBodyArt(mark)) {
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

  void _addSittingLoads(List<Future<void>> futures) {
    final bodyType = _bodyType;
    final top = (config.topStyle != 'none') ? config.topStyle : 'jacket';
    final bottom = (config.bottomStyle != 'none') ? config.bottomStyle : 'jeans';

    // Load Sitting frames for diagonal directions [2, 4, 6, 8]
    for (final d in [2, 4, 6, 8]) {
      final cardinal = _dirToCardinal(d); // SE, NE, NW, SW
      for (int f = 1; f <= 3; f++) {
        final sitKey = '${d}_sitting_f$f';

        // Body sit frame
        futures.add(_loadOctoFrame('body', 'body/${bodyType}${d}_sitting_f$f.png', sitKey));

        // Body tattoos sit frames
        for (final mark in config.marks.where(isBodyArt)) {
          futures.add(_loadOctoFrame('tattoo_$mark', 'tattoos/${mark}_${bodyType}_${cardinal}_sit$f.png', sitKey));
          futures.add(_loadOctoFrame(
              'tattoo_hands_$mark', 'tattoos/${mark}_${bodyType}_hands_${cardinal}_sit$f.png', sitKey));
        }

        // Hands sit frame
        futures.add(_loadOctoFrame('hands', 'body/${bodyType}${d}_sitting_hands_f$f.png', sitKey));

        if (wearsDress) {
          final dress = 'dresses/${config.dressStyle}_$bodyType';
          futures.add(_loadOctoFrame('tops', '${dress}_${cardinal}_sit$f.png', sitKey));
          futures.add(_loadOctoFrame('bottoms', '${dress}_skirt_${cardinal}_sit$f.png', sitKey));
        }

        // Tops sit frame: e.g. tops/jacket_SE_sit1.png
        if (!wearsDress && config.topStyle != 'none') {
          futures.add(_loadFitted('tops', 'tops', top, '_${cardinal}_sit$f.png', sitKey, bodyType).then((_) {
            if (!images.containsKey('tops:$sitKey')) {
              return _loadOctoFrame('tops', 'tops/${top}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Bottoms sit frame: e.g. bottoms/jeans_SE_sit1.png
        if (!wearsDress && config.bottomStyle != 'none') {
          futures.add(_loadFitted('bottoms', 'bottoms', bottom, '_${cardinal}_sit$f.png', sitKey, bodyType).then((_) {
            if (!images.containsKey('bottoms:$sitKey')) {
              return _loadOctoFrame('bottoms', 'bottoms/${bottom}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Shoes sit frame: e.g. shoes/boots_SE_sit1.png
        if (config.shoeStyle != 'none') {
          futures.add(_loadFitted('shoes', 'shoes', config.shoeStyle, '_${cardinal}_sit$f.png', sitKey, bodyType).then((_) {
            if (!images.containsKey('shoes:$sitKey')) {
              return _loadOctoFrame('shoes', 'shoes/${config.shoeStyle}${d}_sitting_f$f.png', sitKey);
            }
          }));
        }

        // Backleg frame for sitting (only applicable to NE (4) and NW (6) at frame 3)
        if ((d == 4 || d == 6) && f == 3) {
          futures.add(_loadOctoFrame('body_backleg', 'body/${bodyType}${d}_sitting_f3_backleg.png', sitKey));
          if (wearsDress) {
            futures.add(_loadOctoFrame('bottoms_backleg',
                'dresses/${config.dressStyle}_${bodyType}_skirt_${cardinal}_backleg_sit3.png', sitKey));
          } else if (config.bottomStyle != 'none') {
            futures.add(_loadFitted('bottoms_backleg', 'bottoms', bottom, '_${cardinal}_backleg_sit3.png', sitKey, bodyType));
          }
          if (config.shoeStyle != 'none') {
            futures.add(_loadFitted('shoes_backleg', 'shoes', config.shoeStyle, '_${cardinal}_backleg_sit3.png', sitKey, bodyType).then((_) {
              if (!images.containsKey('shoes_backleg:$sitKey')) {
                return _loadOctoFrame('shoes_backleg', 'shoes/${config.shoeStyle}${d}_sitting_f3_backleg.png', sitKey);
              }
            }));
          }
        }
      }
    }
  }

  /// Lying layers live in OCTOPLAYER/Avatar/lying/ (160x128 canvas, views A/B). Only some
  /// styles have lying art yet, so each layer falls back to a default style that does.
  void _addLyingLoads(List<Future<void>> futures) {
    final bodyType = _bodyType;
    final hair = (config.hairStyle != 'none') ? config.hairStyle : 'long_flow';
    final top = (config.topStyle != 'none') ? config.topStyle : 'jacket';
    final bottom = (config.bottomStyle != 'none') ? config.bottomStyle : 'jeans';
    final eye = config.eyeStyle;
    final mouth = config.mouthStyle;
    final nose = config.noseStyle;

    Future<void> withFallback(String layerKey, String path, String fallbackPath, String key) {
      return _loadOctoFrame(layerKey, path, key).then((_) {
        if (!images.containsKey('$layerKey:$key')) {
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
        if (!images.containsKey('mouth:$key')) {
          return _loadOctoMouthFrame('lying/mouth/catmouth_lie$v.png', key, up: up);
        }
      }));
      futures.add(_loadOctoEyesFrame('lying/eyes/${eye}_lie$v.png', key, up: up).then((_) {
        if (!images.containsKey('eyes:$key')) {
          return _loadOctoEyesFrame('lying/eyes/cateyes_lie$v.png', key, up: up);
        }
      }));
      final blush = config.makeup[AvatarCatalog.blush];
      if (blush != null) {
        futures.add(_loadOctoFrame('makeup_blush', 'lying/makeup/blush/${blush}_lie$v.png', key));
      }
      // Body marks have no fallback: a mark without lying art is simply not drawn.
      for (final mark in config.marks) {
        futures.add(isBodyArt(mark)
            ? _loadOctoFrame('tattoo_$mark', 'lying/tattoos/${mark}_${bodyType}_lie$v.png', key)
            : _loadOctoFrame('mark_$mark', 'lying/marks/${mark}_lie$v.png', key));
      }
      // Asleep under the covers the eyes are always closed, whatever the chosen style.
      futures.add(_loadOctoEyesFrame('lying/eyes/closedeyes_lie$v.png', '${key}_closed', up: up));
      // Clothes are fitted per body type (e.g. jacket_female_lieA); then the style's generic
      // lying version, then the default garment.
      Future<void> garment(String layerKey, String folder, String style, String fallbackStyle) {
        return _loadOctoFrame(layerKey, 'lying/$folder/${style}_${bodyType}_lie$v.png', key).then((_) {
          if (!images.containsKey('$layerKey:$key')) {
            return withFallback(layerKey, 'lying/$folder/${style}_lie$v.png', 'lying/$folder/${fallbackStyle}_lie$v.png', key);
          }
        });
      }

      if (wearsDress) {
        // lying, the whole dress is one layer
        futures.add(_loadOctoFrame('tops', 'lying/dresses/${config.dressStyle}_${bodyType}_lie$v.png', key));
      } else {
        if (config.topStyle != 'none') {
          futures.add(garment('tops', 'tops', top, 'jacket'));
        }
        if (config.bottomStyle != 'none') {
          futures.add(garment('bottoms', 'bottoms', bottom, 'jeans'));
        }
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

  /// A dress (one-piece) is drawn through the top and bottom layers and hides the worn top/bottom.
  bool get wearsDress => config.dressStyle != 'none';
  bool get hasTop => wearsDress || config.topStyle != 'none';
  bool get hasBottom => wearsDress || config.bottomStyle != 'none';
  Color get topTint => wearsDress ? config.dressColor : config.topColor;
  Color get bottomTint => wearsDress ? config.dressColor : config.bottomColor;

  static bool isBodyArt(String mark) => AvatarCatalog.find(AvatarCatalog.mark, mark)?.underClothes ?? false;

  static String _dirToCardinal(int d) {
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

  /// Draws the standing or sitting avatar for [frameKey] (`'3'`, `'3_walk_f2'`,
  /// `'4_sitting_f1'`) into [dstRect], back to front. With [separateBackleg] the sitting back leg
  /// is left out: the caller draws it behind the furniture with [paintBackleg].
  void paint(Canvas canvas, Rect dstRect, String frameKey, {bool separateBackleg = false}) {
    final dirNum = int.parse(frameKey.split('_').first);
    final isSitting = frameKey.contains('_sitting_');

    void drawLayer(String layerKey, Color? tintColor) {
      Image? img;
      if (isSitting) {
        img = images['$layerKey:$frameKey'];
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
          img = images['$layerKey:$dirNum'];
        }
      } else {
        img = images['$layerKey:$frameKey'] ?? images['$layerKey:$dirNum'];
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
    if (isSitting && !separateBackleg) {
      drawLayer('body_backleg', config.skinColor);
    }

    // Layer 2: Body (Base Skin)
    drawLayer('body', config.skinColor);

    // Layer 2b: Body tattoos on the body sprite (clothes are drawn over them)
    for (final mark in config.marks.where(isBodyArt)) {
      drawLayer('tattoo_$mark', null);
    }

    // Layer 3a: Bottoms Backleg (Only when NOT rendered separately behind furniture)
    if (isSitting && !separateBackleg && hasBottom) {
      drawLayer('bottoms_backleg', bottomTint);
    }

    // Layer 3: Bottoms / Pants / Jeans
    if (hasBottom) {
      drawLayer('bottoms', bottomTint);
    }

    // Layer 4: Hands (Skin Color - Rendered over pants so arms/hands aren't covered by bottoms)
    drawLayer('hands', config.skinColor);

    // Layer 4b: Body tattoos on the near arm, which swings over the body
    for (final mark in config.marks.where(isBodyArt)) {
      drawLayer('tattoo_hands_$mark', null);
    }

    // Layer 5a: Shoes Backleg (Only when NOT rendered separately behind furniture)
    if (isSitting && !separateBackleg && config.shoeStyle != 'none') {
      drawLayer('shoes_backleg', config.shoeColor);
    }

    // Layer 5: Shoes / Boots
    if (config.shoeStyle != 'none') {
      drawLayer('shoes', config.shoeColor);
    }

    // Layer 6a: Tops Backleg (Only when NOT rendered separately behind furniture)
    if (isSitting && !separateBackleg && hasTop) {
      drawLayer('tops_backleg', topTint);
    }

    // Layer 6: Tops / Jacket / Shirt
    if (hasTop) {
      drawLayer('tops', topTint);
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

  /// The sitting back leg (body, then trousers, shoes and top), for drawing behind the seat.
  void paintBackleg(Canvas canvas, Rect dstRect, String frameKey) {
    void drawBacklegLayer(String layerKey, Color? tintColor) {
      final img = images['$layerKey:$frameKey'];
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
    if (hasBottom) {
      drawBacklegLayer('bottoms_backleg', bottomTint);
    }

    // Layer 3: Shoes backleg (rendered over pants/skin)
    if (config.shoeStyle != 'none') {
      drawBacklegLayer('shoes_backleg', config.shoeColor);
    }

    // Layer 4: Tops backleg (rendered over pants/skin)
    if (hasTop) {
      drawBacklegLayer('tops_backleg', topTint);
    }
  }

  /// Whether [frameKey] has a back-leg layer to draw behind the seat.
  bool hasBackleg(String frameKey) => const ['body_backleg', 'bottoms_backleg', 'shoes_backleg', 'tops_backleg']
      .any((layer) => images.containsKey('$layer:$frameKey'));
}
