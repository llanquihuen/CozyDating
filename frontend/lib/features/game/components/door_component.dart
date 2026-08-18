import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';
import 'wall_component.dart';
import '../dungeon_game.dart';

class DoorComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  final void Function()? onDoorUnlocked;

  final Paint _doorPaint = Paint()..color = const Color(0xFF6E2C00); // Dark Mahogany Wood
  final Paint _ironFramePaint = Paint()..color = const Color(0xFF2E4053);
  final Paint _unlockedPaint = Paint()..color = const Color(0xFF27AE60);
  final Paint _lockedPaint = Paint()..color = const Color(0xFFC0392B);

  DoorComponent({
    required Vector2 position,
    required Vector2 size,
    this.onDoorUnlocked,
  }) : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is ExplorerComponent) {
      if (gameRef.hasKey) {
        print('[DOOR LOG] Explorer unlocked the Dungeon Exit Door with Golden Key! Triggering Act 2 ROLE_SWAP...');
        onDoorUnlocked?.call();
      } else {
        print('[DOOR LOG] Door is LOCKED! Find the Golden Key first.');
        // Act as solid obstacle if locked
        other.position = (other.position - other.direction * 4.0);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = size.toRect();
    final center = (size / 2).toOffset();

    // 1. Draw door background frame
    canvas.drawRect(rect, _doorPaint);
    canvas.drawRect(rect, Paint()..color = Colors.black45..style = PaintingStyle.stroke..strokeWidth = 3);

    // 2. Draw iron straps
    final strap1 = Rect.fromLTWH(0, 6, size.x, 4);
    final strap2 = Rect.fromLTWH(0, size.y - 10, size.x, 4);
    canvas.drawRect(strap1, _ironFramePaint);
    canvas.drawRect(strap2, _ironFramePaint);

    // 3. Draw lock indicator
    final isUnlocked = gameRef.hasKey;
    final lockPaint = isUnlocked ? _unlockedPaint : _lockedPaint;
    canvas.drawCircle(center, 7, lockPaint);
    canvas.drawCircle(center, 7, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
}
