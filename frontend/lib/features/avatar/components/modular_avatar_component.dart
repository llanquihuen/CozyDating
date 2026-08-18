import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import '../../../core/models/avatar_config.dart';

enum AvatarDirection { down, up, left, right }

class ModularAvatarComponent extends PositionComponent {
  AvatarConfig config;
  AvatarDirection direction;
  bool isMoving;

  Image? _bodyImage;
  Image? _faceShapeImage;
  Image? _noseImage;
  Image? _mouthImage;
  Image? _eyesImage;
  Image? _eyebrowsImage;
  Image? _faceDetailImage;
  Image? _shoesImage;
  Image? _bottomImage;
  Image? _topImage;
  Image? _hairImage;
  Image? _accImage;

  double _animTimer = 0.0;
  int _currentFrame = 0;
  static const double _frameDuration = 0.16;

  bool get is32x64 => config.spriteResolution == '32x64';
  double get srcFrameWidth => is32x64 ? 32.0 : 64.0;
  double get srcFrameHeight => is32x64 ? 64.0 : 128.0;
  String get assetPrefix => is32x64 ? 'avatar/32x64' : 'avatar/64x128';

  ModularAvatarComponent({
    required this.config,
    this.direction = AvatarDirection.down,
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
    final needsReload = config.spriteResolution != newConfig.spriteResolution ||
        config.faceShape != newConfig.faceShape ||
        config.noseStyle != newConfig.noseStyle ||
        config.mouthStyle != newConfig.mouthStyle ||
        config.eyeStyle != newConfig.eyeStyle ||
        config.eyebrowStyle != newConfig.eyebrowStyle ||
        config.faceDetail != newConfig.faceDetail ||
        config.shoeStyle != newConfig.shoeStyle ||
        config.bottomStyle != newConfig.bottomStyle ||
        config.topStyle != newConfig.topStyle ||
        config.hairStyle != newConfig.hairStyle ||
        config.accessoryStyle != newConfig.accessoryStyle;

    config = newConfig;
    if (needsReload) {
      await reloadSprites();
    }
  }

  Future<void> reloadSprites() async {
    final prefix = assetPrefix;

    try {
      _bodyImage = await Flame.images.load('$prefix/body/base.png');
    } catch (_) {
      try {
        _bodyImage = await Flame.images.load('avatar/body/base.png');
      } catch (_) {
        _bodyImage = null;
      }
    }

    try {
      _faceShapeImage = await Flame.images.load('$prefix/face_shape/${config.faceShape}.png');
    } catch (_) {
      try {
        _faceShapeImage = await Flame.images.load('avatar/face_shape/${config.faceShape}.png');
      } catch (_) {
        _faceShapeImage = null;
      }
    }

    try {
      _noseImage = await Flame.images.load('$prefix/nose/${config.noseStyle}.png');
    } catch (_) {
      try {
        _noseImage = await Flame.images.load('avatar/nose/${config.noseStyle}.png');
      } catch (_) {
        _noseImage = null;
      }
    }

    try {
      _mouthImage = await Flame.images.load('$prefix/mouth/${config.mouthStyle}.png');
    } catch (_) {
      try {
        _mouthImage = await Flame.images.load('avatar/mouth/${config.mouthStyle}.png');
      } catch (_) {
        _mouthImage = null;
      }
    }

    try {
      _eyesImage = await Flame.images.load('$prefix/eyes/${config.eyeStyle}.png');
    } catch (_) {
      try {
        _eyesImage = await Flame.images.load('avatar/eyes/${config.eyeStyle}.png');
      } catch (_) {
        _eyesImage = null;
      }
    }

    try {
      _eyebrowsImage = await Flame.images.load('$prefix/eyebrows/${config.eyebrowStyle}.png');
    } catch (_) {
      try {
        _eyebrowsImage = await Flame.images.load('avatar/eyebrows/${config.eyebrowStyle}.png');
      } catch (_) {
        _eyebrowsImage = null;
      }
    }

    if (config.faceDetail != 'none') {
      try {
        _faceDetailImage = await Flame.images.load('$prefix/face_details/${config.faceDetail}.png');
      } catch (_) {
        try {
          _faceDetailImage = await Flame.images.load('avatar/face_details/${config.faceDetail}.png');
        } catch (_) {
          _faceDetailImage = null;
        }
      }
    } else {
      _faceDetailImage = null;
    }

    if (config.shoeStyle != 'none') {
      try {
        _shoesImage = await Flame.images.load('$prefix/shoes/${config.shoeStyle}.png');
      } catch (_) {
        try {
          _shoesImage = await Flame.images.load('avatar/shoes/${config.shoeStyle}.png');
        } catch (_) {
          _shoesImage = null;
        }
      }
    } else {
      _shoesImage = null;
    }

    if (config.bottomStyle != 'none') {
      try {
        _bottomImage = await Flame.images.load('$prefix/bottoms/${config.bottomStyle}.png');
      } catch (_) {
        try {
          _bottomImage = await Flame.images.load('avatar/bottoms/${config.bottomStyle}.png');
        } catch (_) {
          _bottomImage = null;
        }
      }
    } else {
      _bottomImage = null;
    }

    if (config.topStyle != 'none') {
      try {
        _topImage = await Flame.images.load('$prefix/tops/${config.topStyle}.png');
      } catch (_) {
        try {
          _topImage = await Flame.images.load('avatar/tops/${config.topStyle}.png');
        } catch (_) {
          _topImage = null;
        }
      }
    } else {
      _topImage = null;
    }

    if (config.hairStyle != 'none') {
      try {
        _hairImage = await Flame.images.load('$prefix/hair/${config.hairStyle}.png');
      } catch (_) {
        try {
          _hairImage = await Flame.images.load('avatar/hair/${config.hairStyle}.png');
        } catch (_) {
          _hairImage = null;
        }
      }
    } else {
      _hairImage = null;
    }

    if (config.accessoryStyle != 'none') {
      try {
        _accImage = await Flame.images.load('$prefix/accessories/${config.accessoryStyle}.png');
      } catch (_) {
        try {
          _accImage = await Flame.images.load('avatar/accessories/${config.accessoryStyle}.png');
        } catch (_) {
          _accImage = null;
        }
      }
    } else {
      _accImage = null;
    }
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

    final int row = direction.index; // 0: down, 1: up, 2: left, 3: right
    final int col = _currentFrame;

    final srcW = srcFrameWidth;
    final srcH = srcFrameHeight;

    final srcRect = Rect.fromLTWH(
      col * srcW,
      row * srcH,
      srcW,
      srcH,
    );

    final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);

    // Layer 1: Body Base (Skin Color)
    if (_bodyImage != null) {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.skinColor, BlendMode.modulate);
      canvas.drawImageRect(_bodyImage!, srcRect, dstRect, paint);
    }

    // Layer 2: Face Shape (Skin Color)
    if (_faceShapeImage != null) {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.skinColor, BlendMode.modulate);
      canvas.drawImageRect(_faceShapeImage!, srcRect, dstRect, paint);
    }

    // Layer 3: Nose (Natural / Skin outline)
    if (_noseImage != null) {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.skinColor, BlendMode.modulate);
      canvas.drawImageRect(_noseImage!, srcRect, dstRect, paint);
    }

    // Layer 4: Mouth
    if (_mouthImage != null) {
      final paint = Paint();
      canvas.drawImageRect(_mouthImage!, srcRect, dstRect, paint);
    }

    // Layer 5: Eyes (Iris Color)
    if (_eyesImage != null) {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.eyeColor, BlendMode.modulate);
      canvas.drawImageRect(_eyesImage!, srcRect, dstRect, paint);
    }

    // Layer 6: Eyebrows
    if (_eyebrowsImage != null) {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.eyebrowColor, BlendMode.modulate);
      canvas.drawImageRect(_eyebrowsImage!, srcRect, dstRect, paint);
    }

    // Layer 7: Face Details (Blush / Freckles / Scar)
    if (_faceDetailImage != null && config.faceDetail != 'none') {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.faceDetailColor, BlendMode.modulate);
      canvas.drawImageRect(_faceDetailImage!, srcRect, dstRect, paint);
    }

    // Layer 8: Shoes / Boots
    if (_shoesImage != null && config.shoeStyle != 'none') {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.shoeColor, BlendMode.modulate);
      canvas.drawImageRect(_shoesImage!, srcRect, dstRect, paint);
    }

    // Layer 9: Bottoms / Pants / Skirt
    if (_bottomImage != null && config.bottomStyle != 'none') {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.bottomColor, BlendMode.modulate);
      canvas.drawImageRect(_bottomImage!, srcRect, dstRect, paint);
    }

    // Layer 10: Tops / Shirt / Jacket
    if (_topImage != null && config.topStyle != 'none') {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.topColor, BlendMode.modulate);
      canvas.drawImageRect(_topImage!, srcRect, dstRect, paint);
    }

    // Layer 11: Hair
    if (_hairImage != null && config.hairStyle != 'none') {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.hairColor, BlendMode.modulate);
      canvas.drawImageRect(_hairImage!, srcRect, dstRect, paint);
    }

    // Layer 12: Accessories
    if (_accImage != null && config.accessoryStyle != 'none') {
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(config.accessoryColor, BlendMode.modulate);
      canvas.drawImageRect(_accImage!, srcRect, dstRect, paint);
    }
  }
}
