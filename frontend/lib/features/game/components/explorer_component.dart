import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../avatar/components/modular_avatar_component.dart';
import '../dungeon_game.dart';

class ExplorerComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  Vector2 targetPosition = Vector2.zero();
  Vector2 direction = Vector2.zero();
  bool isMoving = false;
  final double stepSpeed = 220.0;

  double _damageShakeTimer = 0.0;
  final double _shakeDuration = 0.4;
  final double _shakeIntensity = 4.0;
  final void Function(Vector2 position)? onPositionChanged;
  final void Function(Vector2 position, AvatarDirection direction, bool isMoving)? onPositionChangedFull;
  final AvatarConfig avatarConfig;
  late ModularAvatarComponent avatarRenderer;

  String get directionName {
    switch (avatarRenderer.direction) {
      case AvatarDirection.south:
        return 'down';
      case AvatarDirection.southEast:
        return 'southeast';
      case AvatarDirection.east:
        return 'right';
      case AvatarDirection.northEast:
        return 'northeast';
      case AvatarDirection.north:
        return 'up';
      case AvatarDirection.northWest:
        return 'northwest';
      case AvatarDirection.west:
        return 'left';
      case AvatarDirection.southWest:
        return 'southwest';
    }
  }

  ExplorerComponent({
    required Vector2 position,
    required Vector2 size,
    AvatarConfig? avatarConfig,
    this.onPositionChanged,
    this.onPositionChangedFull,
  })  : avatarConfig = avatarConfig ?? AvatarStorageService.loadConfig(),
        super(position: position, size: size) {
    anchor = Anchor.topLeft;
    priority = 3; // Renders in front of floors, traps, and back walls
    targetPosition = position.clone();

    // Hitbox situated strictly at the feet (bottom ground contact area)
    add(RectangleHitbox(
      position: Vector2(3, size.y - size.x * 0.75),
      size: Vector2(size.x - 6, size.x * 0.70),
    ));

    // Modular Pixel Art Avatar Child Component
    avatarRenderer = ModularAvatarComponent(
      config: this.avatarConfig,
      direction: AvatarDirection.down,
      isMoving: false,
      size: size,
    );
    add(avatarRenderer);
  }

  /// Point corresponding to the explorer's feet touching the ground tile
  Vector2 get feetPosition => Vector2(position.x + size.x / 2, position.y + size.y - size.x / 2);

  /// Calculates top-left position that places the character's feet base inside cell (col, row)
  /// with the 1.5-tile height extending upwards into 2.5D vertical space.
  static Vector2 getCenteredTilePosition(int col, int row, double tileSize, Vector2 spriteSize) {
    final marginX = (tileSize - spriteSize.x) / 2;
    final marginY = (tileSize - spriteSize.x) / 2 - (spriteSize.y - spriteSize.x);
    return Vector2((col * tileSize) + marginX, (row * tileSize) + marginY);
  }

  /// Initiates a discrete 1-tile grid step towards [dir]
  void setMovementDirection(Vector2 dir) {
    if (isMoving) return;

    final tileSize = gameRef.tileSize;
    final marginX = (tileSize - size.x) / 2;
    final marginY = (tileSize - size.x) / 2 - (size.y - size.x);

    // 1. Calculate current grid column and row
    final currentCol = ((position.x - marginX) / tileSize).round();
    final currentRow = ((position.y - marginY) / tileSize).round();

    // 2. Snap position to exact tile center offset
    position = getCenteredTilePosition(currentCol, currentRow, tileSize, size);

    // 3. Calculate target grid cell column and row
    final targetCol = currentCol + dir.x.round();
    final targetRow = currentRow + dir.y.round();

    final targetCellTopLeft = Vector2(targetCol * tileSize, targetRow * tileSize);
    final potentialTargetPosition = getCenteredTilePosition(targetCol, targetRow, tileSize, size);

    // Update avatar facing direction
    if (dir.y > 0) {
      avatarRenderer.direction = AvatarDirection.down;
    } else if (dir.y < 0) {
      avatarRenderer.direction = AvatarDirection.up;
    } else if (dir.x < 0) {
      avatarRenderer.direction = AvatarDirection.left;
    } else if (dir.x > 0) {
      avatarRenderer.direction = AvatarDirection.right;
    }

    // 4. Check collision against walls or obstacles at target grid cell
    if (gameRef.isTileOccupied(targetCellTopLeft)) {
      if (gameRef.isActiveSpikeAt(targetCellTopLeft)) {
        takeDamageAnimation();
      }
      print('[EXPLORER LOG] Movement blocked by obstacle at grid cell ($targetCol, $targetRow)');
      return;
    }

    direction = dir.clone();
    targetPosition = potentialTargetPosition;
    isMoving = true;
    avatarRenderer.isMoving = true;
    onPositionChanged?.call(position);
    onPositionChangedFull?.call(position, avatarRenderer.direction, true);
  }

  void stopMovement() {
    // In-flight grid steps complete cleanly to target centered cell position
  }

  void takeDamageAnimation() {
    _damageShakeTimer = _shakeDuration;
  }

  /// Resets position and snaps 100% centered inside discrete grid cell
  void resetPosition(Vector2 cellTopLeft) {
    final tileSize = gameRef.tileSize;
    final col = (cellTopLeft.x / tileSize).round();
    final row = (cellTopLeft.y / tileSize).round();
    final centeredPos = getCenteredTilePosition(col, row, tileSize, size);

    position = centeredPos.clone();
    targetPosition = centeredPos.clone();
    direction = Vector2.zero();
    isMoving = false;
    avatarRenderer.isMoving = false;
    onPositionChanged?.call(position);
    onPositionChangedFull?.call(position, avatarRenderer.direction, false);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_damageShakeTimer > 0) {
      _damageShakeTimer -= dt;
    }

    if (isMoving) {
      final distanceToTarget = (targetPosition - position).length;
      final moveDistance = stepSpeed * dt;

      if (moveDistance >= distanceToTarget) {
        position = targetPosition.clone();
        isMoving = false;
        avatarRenderer.isMoving = false;
        direction = Vector2.zero();
        onPositionChanged?.call(position);
        onPositionChangedFull?.call(position, avatarRenderer.direction, false);
      } else {
        position += direction * moveDistance;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_damageShakeTimer > 0) {
      final random = Random();
      canvas.translate(
        (random.nextDouble() * 2 - 1) * _shakeIntensity,
        (random.nextDouble() * 2 - 1) * _shakeIntensity,
      );
    }
    super.render(canvas);
  }
}
