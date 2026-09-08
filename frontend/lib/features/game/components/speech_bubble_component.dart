import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Floating speech bubble component rendered over an avatar in isometric space.
///
/// Features:
/// - Rounded card with comic speech tail pointing down to the avatar's head
/// - Text auto-wrapping with nice typography
/// - Soft shadow and border
/// - Elastic pop-in entry and fade-out exit
/// - High priority to ensure it renders above all furniture and walls (priority: 2000000)
class SpeechBubbleComponent extends PositionComponent {
  final String text;
  final double lifeDuration;
  final bool isPartner;

  double _elapsed = 0.0;
  late final Vector2 _startPos;
  late final TextPainter _textPainter;
  late final double _bubbleWidth;
  late final double _bubbleHeight;

  SpeechBubbleComponent({
    required this.text,
    required Vector2 position,
    this.lifeDuration = 4.5,
    this.isPartner = false,
  }) : super(position: position, anchor: Anchor.bottomCenter) {
    _startPos = position.clone();
    priority = 2000000; // Far above furniture, walls and avatars

    // Precalculate text layout
    final span = TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFF1E1B2E),
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        fontFamily: 'Roboto',
      ),
    );

    _textPainter = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    );

    // Layout with max width limit for neat speech bubble size
    const double maxTextWidth = 160.0;
    _textPainter.layout(maxWidth: maxTextWidth);

    _bubbleWidth = (_textPainter.width + 18.0).clamp(48.0, 180.0);
    _bubbleHeight = _textPainter.height + 14.0;
    size = Vector2(_bubbleWidth, _bubbleHeight + 6.0); // +6 for speech tail
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;

    if (_elapsed >= lifeDuration) {
      removeFromParent();
      return;
    }

    // Gentle upward hover
    final progress = _elapsed / lifeDuration;
    final hoverOffset = (progress < 0.2) ? (Curves.easeOutBack.transform(progress / 0.2) * 6.0) : 6.0;
    position.y = _startPos.y - hoverOffset;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final progress = _elapsed / lifeDuration;
    double scale = 1.0;
    double opacity = 1.0;

    if (progress < 0.15) {
      scale = Curves.elasticOut.transform(progress / 0.15);
    } else if (progress > 0.8) {
      opacity = (1.0 - progress) / 0.2;
    }

    final alpha = (opacity * 255).clamp(0, 255).toInt();
    if (alpha <= 0) return;

    canvas.save();
    // Anchor center scaling for pop effect
    final pivotX = size.x / 2;
    final pivotY = size.y;
    canvas.translate(pivotX, pivotY);
    canvas.scale(scale, scale);
    canvas.translate(-pivotX, -pivotY);

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, _bubbleWidth, _bubbleHeight),
      const Radius.circular(10),
    );

    // Bubble Background (warm cozy ivory/cream for partner, soft pastel blush for local)
    final bgPaint = Paint()
      ..color = (isPartner ? const Color(0xFFFFFBEA) : const Color(0xFFFFFFFF)).withAlpha(alpha)
      ..style = PaintingStyle.fill;

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha((alpha * 0.25).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    canvas.drawRRect(rect.shift(const Offset(0, 2)), shadowPaint);

    // Bubble Body
    canvas.drawRRect(rect, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = (isPartner ? const Color(0xFFFFD54F) : const Color(0xFFFF8DA1)).withAlpha(alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawRRect(rect, borderPaint);

    // Speech Tail (triangle pointing down at bottom center)
    final tailPath = Path();
    final centerX = _bubbleWidth / 2;
    final bottomY = _bubbleHeight;
    tailPath.moveTo(centerX - 5, bottomY);
    tailPath.lineTo(centerX, bottomY + 5);
    tailPath.lineTo(centerX + 5, bottomY);
    tailPath.close();

    canvas.drawPath(tailPath, bgPaint);
    canvas.drawPath(tailPath, borderPaint);

    // Render Text inside bubble
    final textOffset = Offset(
      (_bubbleWidth - _textPainter.width) / 2,
      (_bubbleHeight - _textPainter.height) / 2,
    );
    _textPainter.paint(canvas, textOffset);

    canvas.restore();
  }
}