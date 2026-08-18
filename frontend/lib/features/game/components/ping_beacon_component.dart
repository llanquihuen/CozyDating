import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class PingBeaconComponent extends PositionComponent {
  final double lifespan = 3.0; // 3 seconds total lifespan
  double _elapsedTime = 0.0;

  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5;

  final Paint _corePaint = Paint()..color = const Color(0xFF00E5FF);

  PingBeaconComponent({
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size) {
    priority = 101; // Render ABOVE darkness overlay (priority 100) so Explorer sees it through fog!
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsedTime += dt;

    if (_elapsedTime >= lifespan) {
      removeFromParent(); // Auto-expire after 3s
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final progress = (_elapsedTime / lifespan).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final center = (size / 2).toOffset();

    // 1. Floor Glow (Radial)
    final floorGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF00E5FF).withOpacity(opacity * 0.6),
          const Color(0xFF00E5FF).withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: size.x * 1.2));
    canvas.drawCircle(center, size.x * 1.2, floorGlowPaint);

    // 2. Vertical Light Beam (The "Trazo de Luz")
    final double beamHeight = 160.0; // Fixed height in world space
    final double beamWidth = 10.0 * (1.0 - progress * 0.3);
    
    final beamRect = Rect.fromLTRB(
      center.dx - beamWidth / 2,
      center.dy - beamHeight,
      center.dx + beamWidth / 2,
      center.dy,
    );

    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFF00E5FF).withOpacity(opacity * 0.8),
          const Color(0xFF00E5FF).withOpacity(0.0),
        ],
      ).createShader(beamRect);

    canvas.drawRect(beamRect, beamPaint);

    // 3. Bright Impact Core
    final corePaint = Paint()..color = Colors.white.withOpacity(opacity);
    canvas.drawCircle(center, 4.0 * (1.0 - progress), corePaint);
  }
}
