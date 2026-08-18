import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class LightTrailComponent extends PositionComponent {
  final double lifespan = 0.8; // Short lifespan for a trail effect
  double _elapsedTime = 0.0;

  LightTrailComponent({
    required Vector2 position,
  }) : super(position: position, size: Vector2.all(12)) {
    anchor = Anchor.center;
    priority = 101; // Above darkness
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsedTime += dt;
    if (_elapsedTime >= lifespan) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final progress = (_elapsedTime / lifespan).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    
    // Glowing particle
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), size.x / 2, paint);
    
    // Inner core
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2), 
      size.x / 3, 
      Paint()..color = Colors.white.withOpacity(opacity)
    );
  }
}
