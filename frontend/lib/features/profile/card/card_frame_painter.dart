import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'card_themes.dart';

/// The character face's frame: an accent border plus the theme's ornaments.
class CardFramePainter extends CustomPainter {
  const CardFramePainter({required this.frame, required this.accent, required this.second, this.radius = 18});

  final CardFrame frame;
  final Color accent;
  final Color second;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = accent;
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(1.5), Radius.circular(radius)), border);
    final thin = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final fill = Paint();

    switch (frame) {
      case CardFrame.studs:
        fill.color = second;
        for (var t = 0; t < 12; t++) {
          final x = 14 + t * (size.width - 28) / 11;
          canvas.drawCircle(Offset(x, 1.5), 2.6, fill);
          canvas.drawCircle(Offset(x, size.height - 1.5), 2.6, fill);
        }
      case CardFrame.wood:
        thin.color = second;
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(6), Radius.circular(radius - 5)), thin);
        for (var t = 0; t < 7; t++) {
          final x = 24 + t * 38.0;
          if (x + 14 > size.width - 20) break;
          canvas.drawLine(Offset(x, 1.5), Offset(x + 14, 1.5), thin..strokeWidth = 1.2);
        }
      case CardFrame.bows:
        for (final c in [const Offset(6, 6), Offset(size.width - 6, 6)]) {
          _bow(canvas, c, accent, second);
        }
      case CardFrame.neon:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2), Radius.circular(radius + 2)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = second.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
        thin.color = second;
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(6), Radius.circular(radius - 5)), thin);
      case CardFrame.stars:
        fill.color = accent;
        for (final c in [
          const Offset(16, 3),
          Offset(size.width - 16, 3),
          Offset(3, size.height - 18),
          Offset(size.width - 3, size.height - 18),
          Offset(size.width / 2, size.height - 1.5),
        ]) {
          canvas.drawPath(_star(c, 6), fill);
        }
      case CardFrame.stripes:
        for (final (i, c) in [accent, second].indexed) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(6.0 + i * 5), Radius.circular(radius - 5 - i * 5)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = c,
          );
        }
      case CardFrame.thin:
        thin.color = second;
        canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(6), Radius.circular(radius - 5)), thin);
      case CardFrame.rope:
        final rope = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = second;
        for (var x = 10.0; x < size.width - 10; x += 9) {
          for (final y in [1.5, size.height - 1.5]) {
            canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: 4), math.pi * 1.1, math.pi * 0.8, false, rope);
          }
        }
      case CardFrame.plain:
        break;
    }
  }

  static void _bow(Canvas canvas, Offset c, Color wings, Color knot) {
    final p = Paint()..color = wings;
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 11, c.dy - 7)
        ..lineTo(c.dx, c.dy)
        ..lineTo(c.dx - 11, c.dy + 7)
        ..close(),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 11, c.dy - 7)
        ..lineTo(c.dx, c.dy)
        ..lineTo(c.dx + 11, c.dy + 7)
        ..close(),
      p,
    );
    canvas.drawCircle(c, 3.2, Paint()..color = knot);
  }

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 - math.pi / 2;
      final rr = i.isEven ? r : r * 0.3;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(CardFramePainter old) =>
      old.frame != frame || old.accent != accent || old.second != second || old.radius != radius;
}
