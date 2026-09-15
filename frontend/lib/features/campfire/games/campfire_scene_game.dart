import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/components/modular_avatar_component.dart';
import '../../game/components/floating_emote_component.dart';
import '../../game/components/speech_bubble_component.dart';

class CampfireSceneGame extends FlameGame {
  final AvatarConfig localAvatarConfig;
  final AvatarConfig? partnerAvatarConfig;

  late final ModularAvatarComponent leftAvatar;
  late final ModularAvatarComponent rightAvatar;

  CampfireSceneGame({
    required this.localAvatarConfig,
    this.partnerAvatarConfig,
  }) {
    final partnerConfig = partnerAvatarConfig ??
        const AvatarConfig(
          bodyType: 'female',
          hairStyle: 'braids',
          hairColor: Colors.brown,
          skinColor: Color(0xFFF1C27D),
          topStyle: 'hoodie',
          topColor: Colors.deepPurple,
        );

    // Left avatar seated on the left log facing South-East (SE)
    leftAvatar = ModularAvatarComponent(
      config: localAvatarConfig,
      direction: AvatarDirection.southEast,
      isMoving: false,
      isSitting: true,
      size: Vector2(46, 92),
    );

    // Right avatar seated on the right log facing South-West (SW)
    rightAvatar = ModularAvatarComponent(
      config: partnerConfig,
      direction: AvatarDirection.southWest,
      isMoving: false,
      isSitting: true,
      size: Vector2(46, 92),
    );
  }

  @override
  Color backgroundColor() => const Color(0x00000000); // Fully transparent so campfire.gif shows behind

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    leftAvatar.sitDown();
    rightAvatar.sitDown();
    world.add(leftAvatar);
    world.add(rightAvatar);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    // Map avatar positions precisely to the logs in campfire.gif (704 x 384)
    // using the exact BoxFit.cover projection
    const imgW = 704.0;
    const imgH = 384.0;
    const imgAspect = imgW / imgH;
    final viewAspect = size.x / size.y;

    double scale;
    double offsetX = 0.0;
    double offsetY = 0.0;

    if (viewAspect > imgAspect) {
      // Container is wider than the image: scale by width, crop top/bottom
      scale = size.x / imgW;
      offsetY = (size.y - (imgH * scale)) / 2;
    } else {
      // Container is taller than the image: scale by height, crop left/right
      scale = size.y / imgH;
      offsetX = (size.x - (imgW * scale)) / 2;
    }

    // Scale avatars in realistic proportion with the pixel art campfire and logs
    final avatarWidth = 46.0 * scale;
    final avatarHeight = 92.0 * scale;

    leftAvatar.size = Vector2(avatarWidth, avatarHeight);
    rightAvatar.size = Vector2(avatarWidth, avatarHeight);

    // Left log seating spot in 704x384 image: X = 270, log top Y = 236
    // When seated, the hips/seat rest on the log surface (~72% down the sprite)
    final leftSeatX = offsetX + (270.0 * scale);
    final leftSeatY = offsetY + (236.0 * scale);
    leftAvatar.position = Vector2(
      leftSeatX - (avatarWidth / 2),
      leftSeatY - (avatarHeight * 0.72),
    );

    // Right log seating spot in 704x384 image: X = 434, log top Y = 234
    final rightSeatX = offsetX + (434.0 * scale);
    final rightSeatY = offsetY + (234.0 * scale);
    rightAvatar.position = Vector2(
      rightSeatX - (avatarWidth / 2),
      rightSeatY - (avatarHeight * 0.72),
    );
  }

  void triggerEmote(String emote, {bool onLeft = true}) {
    final target = onLeft ? leftAvatar : rightAvatar;
    world.add(
      FloatingEmoteComponent(
        emote: emote,
        position: target.position + Vector2(target.size.x / 2, -12),
      ),
    );
  }

  void triggerSpeechBubble(String text, {bool onLeft = true}) {
    final target = onLeft ? leftAvatar : rightAvatar;
    world.add(
      SpeechBubbleComponent(
        text: text,
        position: target.position + Vector2(target.size.x / 2, -14),
        isPartner: !onLeft,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
  }
}
