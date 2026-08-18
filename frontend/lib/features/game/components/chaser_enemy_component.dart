import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';
import '../dungeon_game.dart';

class ChaserEnemyComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  final double speed = 14.0; // Very slow creepy ghost creep speed (px/sec)
  final void Function(Vector2 pos)? onPositionChanged;
  double _moveNotifyTimer = 0.0;

  final Paint _bodyPaint = Paint()..color = const Color(0xFF8E44AD); // Deep Purple Shadow
  final Paint _auraPaint = Paint()..color = const Color(0x889B59B6);
  final Paint _eyePaint = Paint()..color = Colors.redAccent;
  final Paint _borderPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  ChaserEnemyComponent({
    required Vector2 position,
    required Vector2 size,
    this.onPositionChanged,
  }) : super(position: position, size: size) {
    priority = 101; // Render ABOVE darkness overlay (priority 100) so visible through fog!
    add(RectangleHitbox(
      position: Vector2(2, 2),
      size: size - Vector2(4, 4),
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!gameRef.isGuideMode) {
      final target = gameRef.explorer.center;
      final current = center;
      final direction = (target - current);

      if (direction.length > 4.0) {
        final moveStep = direction.normalized() * speed * dt;
        position.add(moveStep);

        _moveNotifyTimer += dt;
        if (_moveNotifyTimer >= 0.1) {
          _moveNotifyTimer = 0.0;
          onPositionChanged?.call(position);
        }
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is ExplorerComponent) {
      print('[CHASER ENEMY LOG] Shadow Monster caught the Explorer!');
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final centerPos = (size / 2).toOffset();
    final radius = size.x / 2;

    // Draw ominous shadow aura
    canvas.drawCircle(centerPos, radius + 4, _auraPaint);
    // Draw main enemy body
    canvas.drawCircle(centerPos, radius, _bodyPaint);
    canvas.drawCircle(centerPos, radius, _borderPaint);

    // Draw glowing red eyes piercing through darkness
    canvas.drawCircle(centerPos + const Offset(-4, -2), 3.5, _eyePaint);
    canvas.drawCircle(centerPos + const Offset(4, -2), 3.5, _eyePaint);
  }
}
