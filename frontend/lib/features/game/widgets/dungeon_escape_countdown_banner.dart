import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';

/// Digital countdown overlay shown when the Rune Gate opens and the escape begins.
///
/// Behavior:
/// - Appears in large format with the urgent escape warning ("00:15 - ¡HUYE! EL PORTAL SE CIERRA EN:")
/// - Smoothly shrinks down after ~1 second into a compact 36px-tall banner at the top of the dungeon.
/// - Renders real 7-segment digital LED digits with neon glow.
class DungeonEscapeCountdownBanner extends StatefulWidget {
  final int secondsRemaining;

  const DungeonEscapeCountdownBanner({
    super.key,
    required this.secondsRemaining,
  });

  @override
  State<DungeonEscapeCountdownBanner> createState() => _DungeonEscapeCountdownBannerState();
}

class _DungeonEscapeCountdownBannerState extends State<DungeonEscapeCountdownBanner>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shrinkController;
  late Animation<double> _shrinkAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _shrinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    // Hold large for ~900ms, then smoothly shrink to compact 36px mode over ~700ms
    _shrinkAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 56,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 44,
      ),
    ]).animate(_shrinkController);

    _shrinkController.forward();
  }

  @override
  void didUpdateWidget(covariant DungeonEscapeCountdownBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restart shrink animation if a new countdown begins
    if (oldWidget.secondsRemaining <= 0 && widget.secondsRemaining > 0) {
      _shrinkController.reset();
      _shrinkController.forward();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shrinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.secondsRemaining <= 0) {
      return const SizedBox.shrink();
    }

    final minutes = (widget.secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (widget.secondsRemaining % 60).toString().padLeft(2, '0');
    final isUrgent = widget.secondsRemaining <= 4;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _shrinkAnimation]),
      builder: (context, child) {
        final shrinkProgress = _shrinkAnimation.value;
        final pulseValue = _pulseController.value;

        // When fully shrunk, return the exact 36px-tall compact banner
        if (shrinkProgress >= 1.0) {
          return SizedBox(
            height: 36.0,
            child: _buildCompactBanner(minutes, seconds, isUrgent, pulseValue),
          );
        }

        // Interpolate smoothly during the shrink transition
        final currentHeight = lerpDouble(90.0, 36.0, shrinkProgress)!;
        final translateY = lerpDouble(20.0, 0.0, shrinkProgress)!;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: SizedBox(
            height: currentHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Large initial intro banner (fades out as it shrinks)
                if (shrinkProgress < 0.95)
                  Opacity(
                    opacity: (1.0 - shrinkProgress * 1.25).clamp(0.0, 1.0),
                    child: _buildLargeBanner(minutes, seconds, isUrgent, pulseValue),
                  ),

                // 2. Compact 36px banner (fades in as it reaches destination)
                if (shrinkProgress > 0.3)
                  Opacity(
                    opacity: ((shrinkProgress - 0.3) / 0.7).clamp(0.0, 1.0),
                    child: SizedBox(
                      height: 36.0,
                      child: _buildCompactBanner(minutes, seconds, isUrgent, pulseValue),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Initial large appearance (matches reference image before shrinking)
  Widget _buildLargeBanner(String minutes, String seconds, bool isUrgent, double pulse) {
    final scale = isUrgent ? 1.0 + (pulse * 0.05) : 1.0 + (pulse * 0.02);

    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUrgent
                ? Colors.redAccent.withValues(alpha: 0.85)
                : const Color(0xFFD4FF00).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? Colors.redAccent : const Color(0xFFD4FF00))
                  .withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SevenSegmentTimeDisplay(
              timeText: '$minutes:$seconds',
              digitWidth: 26.0,
              digitHeight: 44.0,
              colonWidth: 14.0,
              litColor: isUrgent ? const Color(0xFFFF3333) : const Color(0xFFD4FF00),
            ),
            const SizedBox(height: 4),
            const Text(
              '¡HUYE! EL PORTAL SE CIERRA EN:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFF9C4),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 2)),
                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, -2)),
                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 0)),
                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(-2, 0)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Compact header banner measuring strictly 36px in height at the top of the dungeon
  Widget _buildCompactBanner(String minutes, String seconds, bool isUrgent, double pulse) {
    return Container(
      height: 36.0,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isUrgent
              ? Colors.redAccent.withValues(alpha: 0.85)
              : const Color(0xFFD4FF00).withValues(alpha: 0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.redAccent : const Color(0xFFD4FF00))
                .withValues(alpha: 0.25),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isUrgent ? Icons.warning_rounded : Icons.timer_outlined,
            color: isUrgent ? Colors.redAccent : const Color(0xFFD4FF00),
            size: 16,
          ),
          const SizedBox(width: 6),
          const Text(
            '¡HUYE! PORTAL:',
            style: TextStyle(
              color: Color(0xFFFFF9C4),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          _SevenSegmentTimeDisplay(
            timeText: '$minutes:$seconds',
            digitWidth: 12.0,
            digitHeight: 20.0,
            colonWidth: 8.0,
            litColor: isUrgent ? const Color(0xFFFF3333) : const Color(0xFFD4FF00),
          ),
        ],
      ),
    );
  }
}

/// Renders a time string (e.g. "00:15") using individual 7-segment digit painters
class _SevenSegmentTimeDisplay extends StatelessWidget {
  final String timeText;
  final double digitWidth;
  final double digitHeight;
  final double colonWidth;
  final Color litColor;

  const _SevenSegmentTimeDisplay({
    required this.timeText,
    this.digitWidth = 26.0,
    this.digitHeight = 44.0,
    this.colonWidth = 14.0,
    required this.litColor,
  });

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];

    for (int i = 0; i < timeText.length; i++) {
      final char = timeText[i];
      if (char == ':') {
        widgets.add(
          SizedBox(
            width: colonWidth,
            height: digitHeight,
            child: CustomPaint(
              painter: _SevenSegmentColonPainter(litColor: litColor),
            ),
          ),
        );
      } else {
        final digit = int.tryParse(char) ?? 0;
        widgets.add(
          SizedBox(
            width: digitWidth,
            height: digitHeight,
            child: CustomPaint(
              painter: _SevenSegmentDigitPainter(
                digit: digit,
                litColor: litColor,
                unlitColor: const Color(0x283A4A00),
              ),
            ),
          ),
        );
      }
      if (i < timeText.length - 1) {
        widgets.add(const SizedBox(width: 3));
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: widgets,
    );
  }
}

/// Custom painter that draws a single 7-segment digit (0-9) scaled to any canvas size
class _SevenSegmentDigitPainter extends CustomPainter {
  final int digit;
  final Color litColor;
  final Color unlitColor;

  _SevenSegmentDigitPainter({
    required this.digit,
    required this.litColor,
    required this.unlitColor,
  });

  static const Map<int, List<bool>> _digitSegments = {
    0: [true,  true,  true,  true,  true,  true,  false], // a,b,c,d,e,f
    1: [false, true,  true,  false, false, false, false], // b,c
    2: [true,  true,  false, true,  true,  false, true ], // a,b,g,e,d
    3: [true,  true,  true,  true,  false, false, true ], // a,b,g,c,d
    4: [false, true,  true,  false, false, true,  true ], // f,g,b,c
    5: [true,  false, true,  true,  false, true,  true ], // a,f,g,c,d
    6: [true,  false, true,  true,  true,  true,  true ], // a,f,g,e,c,d
    7: [true,  true,  true,  false, false, false, false], // a,b,c
    8: [true,  true,  true,  true,  true,  true,  true ], // a,b,c,d,e,f,g
    9: [true,  true,  true,  true,  false, true,  true ], // a,b,f,g,c,d
  };

  @override
  void paint(Canvas canvas, Size size) {
    final segments = _digitSegments[digit] ?? _digitSegments[0]!;

    final w = size.width;
    final h = size.height;
    final t = (w * 0.19).clamp(2.0, 5.0);
    final pad = (w * 0.08).clamp(1.0, 2.0);
    final halfH = h / 2;

    final segRects = [
      // a: top
      Rect.fromLTWH(t + pad, 0, w - 2 * (t + pad), t),
      // b: top-right
      Rect.fromLTWH(w - t, t + pad, t, halfH - t - 2 * pad),
      // c: bottom-right
      Rect.fromLTWH(w - t, halfH + pad, t, halfH - t - 2 * pad),
      // d: bottom
      Rect.fromLTWH(t + pad, h - t, w - 2 * (t + pad), t),
      // e: bottom-left
      Rect.fromLTWH(0, halfH + pad, t, halfH - t - 2 * pad),
      // f: top-left
      Rect.fromLTWH(0, t + pad, t, halfH - t - 2 * pad),
      // g: middle
      Rect.fromLTWH(t + pad, halfH - (t / 2), w - 2 * (t + pad), t),
    ];

    final unlitPaint = Paint()
      ..color = unlitColor
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 7; i++) {
      if (!segments[i]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(segRects[i], Radius.circular(t * 0.3)),
          unlitPaint,
        );
      }
    }

    final glowPaint = Paint()
      ..color = litColor.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, t * 0.9)
      ..style = PaintingStyle.fill;

    final corePaint = Paint()
      ..color = litColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 7; i++) {
      if (segments[i]) {
        final rrect = RRect.fromRectAndRadius(segRects[i], Radius.circular(t * 0.3));
        canvas.drawRRect(rrect, glowPaint);
        canvas.drawRRect(rrect, corePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SevenSegmentDigitPainter oldDelegate) {
    return oldDelegate.digit != digit || oldDelegate.litColor != litColor;
  }
}

/// Custom painter for the colon ':' scaled to canvas size
class _SevenSegmentColonPainter extends CustomPainter {
  final Color litColor;

  _SevenSegmentColonPainter({required this.litColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final dotSize = (w * 0.36).clamp(2.0, 5.0);
    final centerX = w / 2;

    final topDot = Rect.fromCenter(center: Offset(centerX, h * 0.35), width: dotSize, height: dotSize);
    final bottomDot = Rect.fromCenter(center: Offset(centerX, h * 0.65), width: dotSize, height: dotSize);

    final glowPaint = Paint()
      ..color = litColor.withValues(alpha: 0.55)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotSize * 0.8);

    final corePaint = Paint()..color = litColor;

    canvas.drawRRect(RRect.fromRectAndRadius(topDot, Radius.circular(dotSize * 0.25)), glowPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(topDot, Radius.circular(dotSize * 0.25)), corePaint);

    canvas.drawRRect(RRect.fromRectAndRadius(bottomDot, Radius.circular(dotSize * 0.25)), glowPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(bottomDot, Radius.circular(dotSize * 0.25)), corePaint);
  }

  @override
  bool shouldRepaint(covariant _SevenSegmentColonPainter oldDelegate) {
    return oldDelegate.litColor != litColor;
  }
}
