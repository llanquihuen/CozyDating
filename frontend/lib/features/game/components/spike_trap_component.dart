import 'dart:async' as async;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';

enum SpikeTrapVisualState {
  active,
  disarming,
  disarmed,
  reactivating,
}

class SpikeTrapComponent extends PositionComponent with CollisionCallbacks {
  bool isActive = true; // Traps are ACTIVE (dangerous) by default!
  async.Timer? _disarmTimer;

  List<Sprite>? sprites;
  SpikeTrapVisualState _visualState = SpikeTrapVisualState.active;
  int _animFrame = 0; // 0: spike-off1, 1: spike-off2, 2: spike-off3, 3: spike-off4
  double _animTimer = 0.0;
  final double _frameDuration = 0.07; // ~70ms per frame

  final double cycleDuration;
  final bool isPeriodic;
  double _cycleTimer = 0.0;

  final Paint _gratePaint = Paint()..color = const Color(0xFF1E272C);
  final Paint _spikePaint = Paint()..color = const Color(0xFFE74C3C);
  final Paint _metallicPaint = Paint()..color = const Color(0xFFBDC3C7);
  final Paint _disarmedPaint = Paint()..color = const Color(0xFF27AE60);
  final Paint _borderPaint = Paint()
    ..color = const Color(0xFF34495E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  SpikeTrapComponent({
    required Vector2 position,
    required Vector2 size,
    this.sprites,
    this.isPeriodic = false,
    this.cycleDuration = 3.0,
  }) : super(position: position, size: size) {
    priority = 0;
    add(RectangleHitbox());
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (sprites == null || sprites!.isEmpty) {
      try {
        sprites = [
          await Sprite.load('spike-off1.png'),
          await Sprite.load('spike-off2.png'),
          await Sprite.load('spike-off3.png'),
          await Sprite.load('spike-off4.png'),
        ];
      } catch (_) {
        // Fallback gracefully in headless/test environments
      }
    }
  }

  void setActive(bool active) {
    if (isActive == active) return;
    isActive = active;
    if (!isActive) {
      _visualState = SpikeTrapVisualState.disarming;
    } else {
      _visualState = SpikeTrapVisualState.reactivating;
    }
    _animTimer = 0.0;
  }

  /// Disarms the trap temporarily for [duration], after which it automatically reactivates.
  void disarmTemporarily(Duration duration) {
    print('[TRAP LOG] Trap disarmed for ${duration.inSeconds} seconds by Guide...');
    setActive(false);
    _disarmTimer?.cancel();
    _disarmTimer = async.Timer(duration, () {
      setActive(true);
      print('[TRAP LOG] Trap REACTIVATED!');
    });
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isPeriodic && _disarmTimer == null) {
      _cycleTimer += dt;
      if (_cycleTimer >= cycleDuration) {
        _cycleTimer = 0.0;
        setActive(!isActive);
      }
    }

    // Process transition animation frames
    if (_visualState == SpikeTrapVisualState.disarming) {
      _animTimer += dt;
      if (_animTimer >= _frameDuration) {
        _animTimer = 0.0;
        _animFrame++;
        if (_animFrame >= 3) {
          _animFrame = 3;
          _visualState = SpikeTrapVisualState.disarmed;
        }
      }
    } else if (_visualState == SpikeTrapVisualState.reactivating) {
      _animTimer += dt;
      if (_animTimer >= _frameDuration) {
        _animTimer = 0.0;
        _animFrame--;
        if (_animFrame <= 0) {
          _animFrame = 0;
          _visualState = SpikeTrapVisualState.active;
        }
      }
    } else if (_visualState == SpikeTrapVisualState.active) {
      _animFrame = 0;
    } else if (_visualState == SpikeTrapVisualState.disarmed) {
      _animFrame = 3;
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is ExplorerComponent && isActive) {
      print('[TRAP LOG] Explorer stepped on ACTIVE spike trap!');
      other.takeDamageAnimation();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (sprites != null && sprites!.length >= 4) {
      // The sprite is 32x64 (1:2 ratio).
      // The bottom 32x32 is the base where the hitbox/collision is located (size.x by size.y).
      // The top 32px is the vertical spike graphic extending upwards into the cell above.
      sprites![_animFrame].render(
        canvas,
        position: Vector2(0, -size.y),
        size: Vector2(size.x, size.y * 2),
      );
      return;
    }

    // Fallback vector drawing if sprites are not loaded
    final rect = size.toRect();
    canvas.drawRect(rect, _gratePaint);
    canvas.drawRect(rect, _borderPaint);

    if (isActive) {
      final double gridStep = size.x / 3;
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          final center = Offset((i + 0.5) * gridStep, (j + 0.5) * gridStep);
          canvas.drawCircle(center, 4, _spikePaint);
          canvas.drawCircle(center, 2, _metallicPaint);
        }
      }
    } else {
      final double gridStep = size.x / 3;
      for (int i = 0; i < 3; i++) {
        for (int j = 0; j < 3; j++) {
          final center = Offset((i + 0.5) * gridStep, (j + 0.5) * gridStep);
          canvas.drawCircle(center, 3.0, _disarmedPaint);
        }
      }
    }
  }
}
