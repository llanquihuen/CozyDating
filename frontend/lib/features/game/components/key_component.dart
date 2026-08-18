import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';
import '../dungeon_game.dart';

class KeyComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  final Paint _keyPaint = Paint()..color = const Color(0xFFF1C40F); // Gold
  final Paint _glowPaint = Paint()..color = const Color(0x88F39C12);
  final Paint _borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  KeyComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size) {
    add(RectangleHitbox());
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is ExplorerComponent) {
      print('[KEY LOG] Explorer collected the Golden Key!');
      gameRef.collectKey();
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final center = (size / 2).toOffset();

    // Outer glow
    canvas.drawCircle(center, 12, _glowPaint);

    // Key bow (head)
    canvas.drawCircle(center + const Offset(-4, 0), 6, _keyPaint);
    canvas.drawCircle(center + const Offset(-4, 0), 6, _borderPaint);
    canvas.drawCircle(center + const Offset(-4, 0), 2.5, Paint()..color = Colors.black87);

    // Key blade
    final bladeRect = Rect.fromLTWH(center.dx, center.dy - 2, 10, 4);
    final toothRect = Rect.fromLTWH(center.dx + 6, center.dy + 2, 3, 4);
    canvas.drawRect(bladeRect, _keyPaint);
    canvas.drawRect(toothRect, _keyPaint);
  }
}
