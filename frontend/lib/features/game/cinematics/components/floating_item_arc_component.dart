import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Renders a mystical glowing item (emoji / icon) that flies from [startPos] to [endPos]
/// in a graceful parabolic arc over [duration] seconds.
class FloatingItemArcComponent extends PositionComponent {
  final String iconText;
  final Vector2 startPos;
  final Vector2 endPos;
  final double arcHeight;
  final double duration;
  final VoidCallback? onCompleted;

  double _elapsed = 0.0;
  late final TextPaint _textPaint;

  FloatingItemArcComponent({
    required this.iconText,
    required this.startPos,
    required this.endPos,
    this.arcHeight = 60.0,
    this.duration = 1.4,
    this.onCompleted,
  }) : super(position: startPos.clone(), size: Vector2(36, 36), anchor: Anchor.center) {
    _textPaint = TextPaint(
      style: const TextStyle(
        fontSize: 28,
        shadows: [
          Shadow(
            color: Colors.amberAccent,
            blurRadius: 14,
          ),
        ],
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    final progress = (_elapsed / duration).clamp(0.0, 1.0);

    // Linear interpolation for X and base Y
    final currentX = startPos.x + (endPos.x - startPos.x) * progress;
    final baseY = startPos.y + (endPos.y - startPos.y) * progress;

    // Parabolic arc offset: sin(pi * progress) * arcHeight
    final arcOffset = sin(pi * progress) * arcHeight;
    position = Vector2(currentX, baseY - arcOffset);

    // Gentle pulsing scale
    final scaleFactor = 1.0 + 0.25 * sin(pi * progress);
    scale = Vector2.all(scaleFactor);

    if (progress >= 1.0) {
      if (!isDone) {
        isDone = true;
        onCompleted?.call();
      }
    }
  }

  bool isDone = false;

  @override
  void render(Canvas canvas) {
    if (isDone) return;
    super.render(canvas);
    // Draw magic aura ring
    final auraPaint = Paint()
      ..color = Colors.amberAccent.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 16, auraPaint);

    _textPaint.render(
      canvas,
      iconText,
      Vector2(size.x / 2, size.y / 2),
      anchor: Anchor.center,
    );
  }
}
