import 'dart:async' as async;
import 'dart:math';
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';

class RuneGateComponent extends PositionComponent with CollisionCallbacks {
  bool isLocked = true;
  bool _hasTriggeredSwap = false;
  RectangleHitbox? _hitbox;
  async.Timer? _lockTimer;
  final void Function()? onGatePassed;

  List<Sprite>? runeSprites;
  double _orbitAngle = 0.0;
  double _pulseTimer = 0.0;

  final Paint _basePlinthPaint = Paint()..color = const Color(0xFF1B2631);
  final Paint _baseBorderPaint = Paint()
    ..color = const Color(0xFF34495E)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;

  RuneGateComponent({
    required Vector2 position,
    required Vector2 size,
    this.onGatePassed,
    this.runeSprites,
  }) : super(position: position, size: size) {
    priority = 3;
    _hitbox = RectangleHitbox();
    add(_hitbox!);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (runeSprites == null || runeSprites!.isEmpty) {
      try {
        runeSprites = [
          await Sprite.load('sun-on.png'),
          await Sprite.load('moon-on.png'),
          await Sprite.load('snake-on.png'),
          await Sprite.load('lighting-on.png'),
        ];
      } catch (_) {
        // Fallback for headless test environments
      }
    }
  }

  /// Unlocks the gate temporarily for [duration], after which it automatically relocks.
  void unlockForDuration(Duration duration, {void Function()? onRelocked}) {
    print('[RUNE GATE LOG] Rune Gate UNLOCKED for ${duration.inSeconds} seconds!');
    isLocked = false;

    _lockTimer?.cancel();
    _lockTimer = async.Timer(duration, () {
      isLocked = true;
      _hasTriggeredSwap = false;
      onRelocked?.call();
      print('[RUNE GATE LOG] Rune Gate RELOCKED!');
    });
  }

  void unlock() {
    unlockForDuration(const Duration(seconds: 8));
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    // Speed up orbital rotation when portal is active/unlocked
    final speed = isLocked ? 1.0 : 2.6;
    _orbitAngle = (_orbitAngle + dt * speed) % (2 * pi);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is ExplorerComponent) {
      if (!isLocked && !_hasTriggeredSwap) {
        _hasTriggeredSwap = true;
        print('[RUNE GATE LOG] Explorer entered unlocked Sanctuary Portal! Triggering Act 2 ROLE_SWAP...');
        onGatePassed?.call();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = size.toRect();
    final center = (size / 2).toOffset();

    // 1. Draw base stone plinth
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), _basePlinthPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), _baseBorderPaint);

    // 2. Inner portal void
    final portalVoidRect = Rect.fromCenter(
      center: center,
      width: size.x * 0.76,
      height: size.y * 0.62,
    );
    final voidPaint = Paint()
      ..color = isLocked ? const Color(0xFF0D1B2A) : const Color(0xFF001F3F);
    canvas.drawOval(portalVoidRect, voidPaint);

    // 3. 2.5D Elevation & Elliptical Orbit
    // Elevate the floating ring above the stone base (~16px up) to show clear levitation in 2.5D
    final elevation = -size.y * 0.45;
    final floatY = sin(_pulseTimer * 3.5) * 1.8;
    final floatingCenter = center.translate(0, elevation + floatY);

    final rx = size.x * 0.40;
    final ry = size.y * 0.22;

    final pulse = sin(_pulseTimer * 4.0) * 0.2 + 0.8;
    final ringColor = isLocked
        ? const Color(0xFF00E5FF).withValues(alpha: 0.65 * pulse)
        : const Color(0xFF00FF9D).withValues(alpha: 0.95 * pulse);

    // 4. Subtle vertical energy pillar connecting the ground base to the floating ring
    final energyStreamerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          (isLocked ? Colors.cyanAccent : Colors.greenAccent).withValues(alpha: 0.05),
          (isLocked ? Colors.cyanAccent : Colors.greenAccent).withValues(alpha: 0.25 * pulse),
        ],
      ).createShader(Rect.fromPoints(
        Offset(center.dx - rx * 0.8, center.dy),
        Offset(center.dx + rx * 0.8, floatingCenter.dy),
      ));

    final path = Path()
      ..moveTo(center.dx - rx * 0.65, center.dy)
      ..lineTo(floatingCenter.dx - rx * 0.85, floatingCenter.dy)
      ..lineTo(floatingCenter.dx + rx * 0.85, floatingCenter.dy)
      ..lineTo(center.dx + rx * 0.65, center.dy)
      ..close();
    canvas.drawPath(path, energyStreamerPaint);

    final runeCount = runeSprites?.length ?? 4;

    // Helper to render a single orbiting rune
    void renderRuneAt(int index, double angle) {
      final posX = floatingCenter.dx + rx * cos(angle);
      final posY = floatingCenter.dy + ry * sin(angle);

      // 2.5D Depth factor: 0.0 (top/back) to 1.0 (bottom/front)
      final depthFactor = (sin(angle) + 1.0) / 2.0;
      final runeSize = isLocked ? (11.0 + depthFactor * 3.5) : (14.0 + depthFactor * 5.0);

      if (runeSprites != null && index < runeSprites!.length) {
        // Draw magical aura glow behind active rune
        final auraColor = isLocked
            ? Colors.cyanAccent.withValues(alpha: 0.35 * depthFactor)
            : Colors.greenAccent.withValues(alpha: 0.6 * depthFactor);
        canvas.drawCircle(Offset(posX, posY), runeSize * 0.6, Paint()..color = auraColor);

        runeSprites![index].render(
          canvas,
          position: Vector2(posX - runeSize / 2, posY - runeSize / 2),
          size: Vector2(runeSize, runeSize),
        );
      } else {
        // Fallback dot
        final dotColor = isLocked ? Colors.cyanAccent : Colors.greenAccent;
        canvas.drawCircle(Offset(posX, posY), runeSize * 0.3, Paint()..color = dotColor);
      }
    }

    // 5. Render BACK Runes (sin(angle) <= 0) behind the floating ring
    for (int i = 0; i < runeCount; i++) {
      final angle = _orbitAngle + (i * (2 * pi / runeCount));
      if (sin(angle) <= 0) {
        renderRuneAt(i, angle);
      }
    }

    // 6. Draw Glowing Elliptical Floating Portal Ring
    final glowPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = isLocked ? 3.0 : 4.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawOval(
      Rect.fromCenter(center: floatingCenter, width: rx * 2, height: ry * 2),
      glowPaint,
    );

    final coreRingPaint = Paint()
      ..color = isLocked ? Colors.white.withValues(alpha: 0.8) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(center: floatingCenter, width: rx * 2, height: ry * 2),
      coreRingPaint,
    );

    // 7. Render FRONT Runes (sin(angle) > 0) in front of the floating ring
    for (int i = 0; i < runeCount; i++) {
      final angle = _orbitAngle + (i * (2 * pi / runeCount));
      if (sin(angle) > 0) {
        renderRuneAt(i, angle);
      }
    }

    // 8. Unlocked central pillar of light / sparkles
    if (!isLocked) {
      final beamPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.45 * pulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);
      canvas.drawCircle(floatingCenter, 10 * pulse, beamPaint);
      canvas.drawCircle(floatingCenter, 4.5, Paint()..color = Colors.white);
    }
  }
}
