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

  bool _isFaceZoom = true;
  bool get isFaceZoom => _isFaceZoom;

  double _targetZoom = 2.35;
  double _targetAvatarY = 50.0;

  CharacterPreviewGame({required this.config, bool initialFaceZoom = true}) {
    _isFaceZoom = initialFaceZoom;
    if (_isFaceZoom) {
      _targetZoom = 2.35;
      _targetAvatarY = 50.0;
    } else {
      _targetZoom = 1.20;
      _targetAvatarY = 9.0;
    }
  }

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
    avatar.position = Vector2(0, _targetAvatarY);

    world.add(avatar);

    // Initialize viewfinder
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.zoom = _targetZoom;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isLoaded) return;

    // Smooth interpolation for zoom and avatar vertical position
    final currentZoom = camera.viewfinder.zoom;
    final newZoom = lerpDouble(currentZoom, _targetZoom, (dt * 8.0).clamp(0.0, 1.0)) ?? _targetZoom;
    camera.viewfinder.zoom = newZoom;

    final currentY = avatar.position.y;
    final newY = lerpDouble(currentY, _targetAvatarY, (dt * 8.0).clamp(0.0, 1.0)) ?? _targetAvatarY;
    avatar.position.y = newY;
  }

  void setFaceFocus(bool faceFocus) {
    _isFaceZoom = faceFocus;
    if (faceFocus) {
      _targetZoom = 2.35;
      _targetAvatarY = 50.0;
    } else {
      _targetZoom = 1.20;
      _targetAvatarY = 9.0;
    }
  }

  void toggleFaceFocus() {
    setFaceFocus(!_isFaceZoom);
  }

  void rotateRight() {
    final nextIndex = (currentDirection.index + 1) % 8;
    currentDirection = AvatarDirection.values[nextIndex];
    avatar.direction = currentDirection;
  }

  void rotateLeft() {
    final prevIndex = (currentDirection.index + 7) % 8;
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
