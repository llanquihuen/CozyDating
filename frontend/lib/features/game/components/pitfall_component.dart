import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';
import '../dungeon_game.dart';

class PitfallComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  List<Sprite>? sprites;
  int _animFrame = 0; // 0: floor-crack1, 1: floor-crack2, 2: floor-crack3, 3: floor-crack4
  bool _isTriggered = false;
  bool _isAnimating = false;
  double _animTimer = 0.0;
  final double _frameDuration = 0.08; // ~80ms per frame

  final Paint _guidePitPaint = Paint()..color = const Color(0xFFC0392B); // Crimson Red
  final Paint _guideBorderPaint = Paint()
    ..color = Colors.redAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

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
          await Sprite.load('floor-crack1.png'),
          await Sprite.load('floor-crack2.png'),
          await Sprite.load('floor-crack3.png'),
          await Sprite.load('floor-crack4.png'),
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
    if (other is ExplorerComponent) {
      if (!_isTriggered) {
        _isTriggered = true;
        _isAnimating = true;
        _animTimer = 0.0;
        _animFrame = 0;
        print('[PITFALL LOG] Explorer stepped on Pitfall Trap! Breaking floor...');
        other.takeDamageAnimation();

        // Respawn after the floor crack animation
        Future.delayed(const Duration(milliseconds: 320), () {
          gameRef.respawnExplorerAtStart();
        });
      }
    }
  }

  void resetTrap() {
    _isTriggered = false;
    _isAnimating = false;
    _animFrame = 0;
    _animTimer = 0.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (sprites != null && sprites!.length >= 4) {
      sprites![_animFrame].render(canvas, size: size);

      // In Guide Mode, render a warning overlay
      if (gameRef.isGuideMode && !_isTriggered) {
        final center = (size / 2).toOffset();
        final xPaint = Paint()..color = Colors.redAccent..strokeWidth = 2.0;
        canvas.drawLine(center + const Offset(-5, -5), center + const Offset(5, 5), xPaint);
        canvas.drawLine(center + const Offset(5, -5), center + const Offset(-5, 5), xPaint);
      }
      return;
    }

    // Fallback vector drawing if sprites are not loaded
    if (gameRef.isGuideMode || _isTriggered) {
      final rect = size.toRect();
      final center = (size / 2).toOffset();

      canvas.drawRect(rect, _guidePitPaint);
      canvas.drawRect(rect, _guideBorderPaint);

      // Draw Skull warning X
      final xPaint = Paint()..color = Colors.white..strokeWidth = 2.5;
      canvas.drawLine(center + const Offset(-6, -6), center + const Offset(6, 6), xPaint);
      canvas.drawLine(center + const Offset(6, -6), center + const Offset(-6, 6), xPaint);
    }
  }
}
