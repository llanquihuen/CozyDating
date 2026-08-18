import 'dart:ui';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import '../../../core/models/avatar_config.dart';
import '../components/modular_avatar_component.dart';

class CharacterPreviewGame extends FlameGame {
  AvatarConfig config;
  late ModularAvatarComponent avatar;
  AvatarDirection currentDirection = AvatarDirection.down;
  bool isWalking = false;

  CharacterPreviewGame({required this.config});

  @override
  Color backgroundColor() => const Color(0x00000000); // Transparent

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    avatar = ModularAvatarComponent(
      config: config,
      direction: currentDirection,
      isMoving: isWalking,
      size: Vector2(80, 160), // Exact 1:2 aspect ratio for 64x128 frames
    );
    avatar.anchor = Anchor.center;
    avatar.position = Vector2.zero(); // Exact center of camera viewport

    world.add(avatar);
  }

  void rotateRight() {
    final nextIndex = (currentDirection.index + 1) % 4;
    currentDirection = AvatarDirection.values[nextIndex];
    avatar.direction = currentDirection;
  }

  void rotateLeft() {
    final prevIndex = (currentDirection.index + 3) % 4;
    currentDirection = AvatarDirection.values[prevIndex];
    avatar.direction = currentDirection;
  }

  void toggleWalk() {
    isWalking = !isWalking;
    avatar.isMoving = isWalking;
  }

  Future<void> updateConfig(AvatarConfig newConfig) async {
    config = newConfig;
    await avatar.updateConfig(newConfig);
  }
}
