import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';
import 'pushable_block_component.dart';

class FloorSwitchComponent extends PositionComponent with CollisionCallbacks {
  bool isPressed = false;
  final Set<PositionComponent> _pressingEntities = {};

  final Paint _unpressedPaint = Paint()..color = const Color(0xFFD35400); // Amber Brown
  final Paint _pressedPaint = Paint()..color = const Color(0xFF1ABC9C);   // Glowing Cyan
  final Paint _borderPaint = Paint()
    ..color = Colors.white70
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  FloorSwitchComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size) {
    add(RectangleHitbox(
      position: Vector2(4, 4),
      size: size - Vector2(8, 8),
    ));
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is ExplorerComponent || other is PushableBlockComponent) {
      _pressingEntities.add(other);
      if (!isPressed) {
        isPressed = true;
        print('[SWITCH LOG] Floor Switch ACTIVATED!');
      }
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExplorerComponent || other is PushableBlockComponent) {
      _pressingEntities.remove(other);
      if (_pressingEntities.isEmpty && isPressed) {
        isPressed = false;
        print('[SWITCH LOG] Floor Switch DEACTIVATED!');
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(2, 2, size.x - 4, size.y - 4);
    final innerRect = Rect.fromLTWH(6, 6, size.x - 12, size.y - 12);

    canvas.drawRect(rect, isPressed ? _pressedPaint : _unpressedPaint);
    canvas.drawRect(innerRect, Paint()..color = isPressed ? Colors.cyanAccent : Colors.amberAccent);
    canvas.drawRect(rect, _borderPaint);
  }
}
