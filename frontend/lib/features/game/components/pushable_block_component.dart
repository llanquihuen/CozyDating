import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../dungeon_game.dart';

class PushableBlockComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  final Paint _blockPaint = Paint()..color = const Color(0xFF7F8C8D); // Stone Gray
  final Paint _innerPaint = Paint()..color = const Color(0xFF95A5A6);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF34495E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  bool isMoving = false;
  Vector2? _targetPos;
  final double pushSpeed = 160.0;

  PushableBlockComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  /// Attempts to push the stone block 1 tile in [direction]. Returns true if push succeeds.
  bool tryPush(Vector2 direction) {
    if (isMoving) return false;

    // Normalize direction vector to grid cardinal direction
    final gridDir = Vector2(
      direction.x.abs() > direction.y.abs() ? (direction.x > 0 ? 1.0 : -1.0) : 0.0,
      direction.y.abs() >= direction.x.abs() ? (direction.y > 0 ? 1.0 : -1.0) : 0.0,
    );

    if (gridDir.isZero()) return false;

    final targetTilePos = position + (gridDir * gameRef.tileSize);

    // Check if the destination tile is free of walls or other blocks
    if (gameRef.isTileOccupied(targetTilePos, currentBlock: this)) {
      return false; // Push blocked by wall or object
    }

    _targetPos = targetTilePos.clone();
    isMoving = true;
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isMoving && _targetPos != null) {
      final step = (_targetPos! - position);
      if (step.length < 2.0) {
        position = _targetPos!.clone();
        _targetPos = null;
        isMoving = false;
      } else {
        position.add(step.normalized() * pushSpeed * dt);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = size.toRect();
    final innerRect = Rect.fromLTWH(4, 4, size.x - 8, size.y - 8);

    canvas.drawRect(rect, _blockPaint);
    canvas.drawRect(innerRect, _innerPaint);
    canvas.drawRect(rect, _borderPaint);
  }
}
