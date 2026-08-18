import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';

class SanctuaryPlateComponent extends PositionComponent with CollisionCallbacks {
  bool isActivated = false;

  final Paint _platePaint = Paint()..color = const Color(0xFFD4AC0D); // Gold Altar
  final Paint _glowPaint = Paint()..color = const Color(0xFFF1C40F);
  final Paint _borderPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  final void Function()? onSanctuaryReached;

  SanctuaryPlateComponent({
    required Vector2 position,
    required Vector2 size,
    this.onSanctuaryReached,
  }) : super(position: position, size: size) {
    add(RectangleHitbox(
      position: Vector2(4, 4),
      size: size - Vector2(8, 8),
    ));
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is ExplorerComponent && !isActivated) {
      isActivated = true;
      print('[SANCTUARY LOG] Explorer reached the Central Sanctuary Altar! Triggering ROLE_SWAP for Act 2...');
      onSanctuaryReached?.call();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = size.toRect();
    final center = (size / 2).toOffset();

    canvas.drawRect(rect, _platePaint);
    canvas.drawCircle(center, size.x * 0.35, _glowPaint);
    canvas.drawRect(rect, _borderPaint);
  }
}
