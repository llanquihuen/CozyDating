import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';
import '../dungeon_game.dart';

class PitfallComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  List<Sprite>? sprites;
  int _animFrame = 0; // 0: floor-crack1, 1: floor-crack2, 2: floor-crack3, 3: floor-crack4
  bool _isTriggered = false;
  bool get isTriggered => _isTriggered;
  bool _isAnimating = false;
  bool isRepaired = false;
  double _animTimer = 0.0;
  final double _frameDuration = 0.08; // ~80ms per frame

  final Paint _guidePitPaint = Paint()..color = const Color(0xFFC0392B); // Crimson Red
  final Paint _guideBorderPaint = Paint()
    ..color = Colors.redAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  final Paint _plankPaint = Paint()..color = const Color(0xFF8D6E63); // Cozy Wood Plank Brown
  final Paint _plankBorderPaint = Paint()
    ..color = const Color(0xFF5D4037)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  final Paint _nailPaint = Paint()..color = const Color(0xFFD7CCC8);

  PitfallComponent({
    required Vector2 position,
    required Vector2 size,
    this.sprites,
  }) : super(position: position, size: size) {
    priority = 0;
    add(RectangleHitbox(
      position: Vector2(4, 4),
      size: size - Vector2(8, 8),
    ));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (sprites == null || sprites!.isEmpty) {
      try {
        sprites = [
          await Sprite.load('dungeon/floor-crack1.png'),
          await Sprite.load('dungeon/floor-crack2.png'),
          await Sprite.load('dungeon/floor-crack3.png'),
          await Sprite.load('dungeon/floor-crack4.png'),
        ];
      } catch (_) {
        // Fallback gracefully in headless test environments
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isAnimating) {
      _animTimer += dt;
      if (_animTimer >= _frameDuration) {
        _animTimer = 0.0;
        _animFrame++;
        if (_animFrame >= 3) {
          _animFrame = 3; // Stays collapsed at floor-crack4
          _isAnimating = false;
        }
      }
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (isRepaired) return; // Repaired pitfall is completely safe!

    if (other is ExplorerComponent) {
      if (!_isTriggered) {
        _isTriggered = true;
        _isAnimating = true;
        _animTimer = 0.0;
        _animFrame = 0;
        print('[PITFALL LOG] Explorer stepped on Pitfall Trap! Trapping in place...');
        
        other.triggerTrappedInPitfall(position);
        gameRef.handleExplorerTrapped(position);
      }
    }
  }

  /// Repairs the broken pitfall with solid wooden planks, allowing safe passage.
  void repairAndRescue() {
    isRepaired = true;
    _isTriggered = false;
    _isAnimating = false;
    _animFrame = 3; // Show cracked base beneath planks
    print('[PITFALL LOG] Pitfall repaired! Planks secured over hole.');
  }

  void resetTrap() {
    _isTriggered = false;
    _isAnimating = false;
    isRepaired = false;
    _animFrame = 0;
    _animTimer = 0.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (sprites != null && sprites!.length >= 4) {
      sprites![_animFrame].render(canvas, size: size);

      // If repaired, render solid wooden planks across the pitfall
      if (isRepaired) {
        _renderRepairedPlanks(canvas);
        return;
      }

      // In Guide Mode, render an unmistakable large red 'X' warning overlay
      if (gameRef.isGuideMode && !_isTriggered) {
        _renderGuideWarningX(canvas);
      }
      return;
    }

    // Fallback vector drawing if sprites are not loaded
    if (isRepaired) {
      _renderRepairedPlanks(canvas);
      return;
    }

    if (gameRef.isGuideMode || _isTriggered) {
      final rect = size.toRect();
      canvas.drawRect(rect, _guidePitPaint);
      canvas.drawRect(rect, _guideBorderPaint);
      if (gameRef.isGuideMode && !_isTriggered) {
        _renderGuideWarningX(canvas);
      }
    }
  }

  /// Renders a large, unmistakable red 'X' with dark shadow, red glow, and alert border for the Guide
  void _renderGuideWarningX(Canvas canvas) {
    final rect = size.toRect();
    final center = (size / 2).toOffset();
    final span = (size.x * 0.36); // Spans ~26px across a 36px tile

    // 1. Subtle translucent crimson alert background on the tile
    final alertBgPaint = Paint()..color = const Color(0x35E53935);
    canvas.drawRect(rect, alertBgPaint);

    // 2. Clear alert border
    final alertBorderPaint = Paint()
      ..color = const Color(0xAAFF1744)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(rect.deflate(1.0), alertBorderPaint);

    // 3. High-contrast dark outer shadow for the X
    final shadowPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center + Offset(-span, -span), center + Offset(span, span), shadowPaint);
    canvas.drawLine(center + Offset(span, -span), center + Offset(-span, span), shadowPaint);

    // 4. Large glowing red X
    final glowPaint = Paint()
      ..color = const Color(0xFFFF1744).withValues(alpha: 0.7)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(center + Offset(-span, -span), center + Offset(span, span), glowPaint);
    canvas.drawLine(center + Offset(span, -span), center + Offset(-span, span), glowPaint);

    // 5. Bright vivid core X
    final corePaint = Paint()
      ..color = const Color(0xFFFF1744)
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center + Offset(-span, -span), center + Offset(span, span), corePaint);
    canvas.drawLine(center + Offset(span, -span), center + Offset(-span, span), corePaint);
  }

  void _renderRepairedPlanks(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    final plankHeight = h / 3.2;

    // Draw 3 sturdy wooden planks across the crack
    for (int i = 0; i < 3; i++) {
      final y = 2.0 + (i * (plankHeight + 1.5));
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(1, y, w - 2, plankHeight),
        const Radius.circular(2.0),
      );
      canvas.drawRRect(rect, _plankPaint);
      canvas.drawRRect(rect, _plankBorderPaint);

      // Little nails on ends
      canvas.drawCircle(Offset(4, y + plankHeight / 2), 1.0, _nailPaint);
      canvas.drawCircle(Offset(w - 4, y + plankHeight / 2), 1.0, _nailPaint);
    }
  }
}
