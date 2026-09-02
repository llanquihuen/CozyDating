import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class FloatingEmoteComponent extends PositionComponent {
  final String emote;
  final double floatHeight = 35.0;
  final double lifeDuration = 2.2;
  double _elapsed = 0.0;
  late final Vector2 _startPos;

  FloatingEmoteComponent({
    required this.emote,
    required Vector2 position,
  }) : super(position: position, size: Vector2(36, 36), anchor: Anchor.bottomCenter) {
    _startPos = position.clone();
    priority = 100; // Render on top of characters and overlays
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_elapsed >= lifeDuration) {
      removeFromParent();
      return;
    }

    // Smooth float upwards with easing
    final progress = _elapsed / lifeDuration;
    final curve = Curves.easeOutCubic.transform(progress);
    position.y = _startPos.y - (curve * floatHeight);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final progress = _elapsed / lifeDuration;
    // Scale up at start, fade out at end
    double scale = 1.0;
    double opacity = 1.0;

    if (progress < 0.2) {
      scale = Curves.elasticOut.transform(progress / 0.2);
    } else if (progress > 0.7) {
      opacity = (1.0 - progress) / 0.3;
    }

    final paintBg = Paint()
      ..color = Colors.black.withOpacity((0.85 * opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = Colors.amberAccent.withOpacity((0.9 * opacity).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final center = (size / 2).toOffset();
    final radius = (size.x / 2) * scale;

    canvas.drawCircle(center, radius, paintBg);
    canvas.drawCircle(center, radius, paintBorder);

    // Render Emoji in center
    final textPainter = TextPainter(
      text: TextSpan(
        text: emote,
        style: TextStyle(
          fontSize: 18.0 * scale,
          color: Colors.white.withOpacity(opacity.clamp(0.0, 1.0)),
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
}
