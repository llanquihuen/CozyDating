import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/components/modular_avatar_component.dart';
import '../../game/components/floating_emote_component.dart';

class CampfireEmber {
  Vector2 pos;
  double speedY;
  double speedX;
  double life;
  double maxLife;
  double radius;
  Color color;

  CampfireEmber({
    required this.pos,
    required this.speedY,
    required this.speedX,
    required this.maxLife,
    required this.radius,
    required this.color,
  }) : life = maxLife;
}

class CampfireSceneGame extends FlameGame {
  final AvatarConfig localAvatarConfig;
  final AvatarConfig? partnerAvatarConfig;

  late final ModularAvatarComponent leftAvatar;
  late final ModularAvatarComponent rightAvatar;

  final List<CampfireEmber> _embers = [];
  final Random _rng = Random();
  double _flickerTimer = 0.0;

  CampfireSceneGame({
    required this.localAvatarConfig,
    this.partnerAvatarConfig,
  }) {
    final partnerConfig = partnerAvatarConfig ??
        const AvatarConfig(
          bodyType: 'female',
          hairStyle: 'braids',
          hairColor: Colors.brown,
          skinColor: Color(0xFFF1C27D),
          topStyle: 'hoodie',
          topColor: Colors.deepPurple,
        );

    leftAvatar = ModularAvatarComponent(
      config: localAvatarConfig,
      direction: AvatarDirection.east,
      isMoving: false,
      size: Vector2(56, 112),
    );

    rightAvatar = ModularAvatarComponent(
      config: partnerConfig,
      direction: AvatarDirection.west,
      isMoving: false,
      size: Vector2(56, 112),
    );
  }

  @override
  Color backgroundColor() => const Color(0xFF090A10);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    world.add(leftAvatar);
    world.add(rightAvatar);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final centerX = size.x / 2;
    final groundY = size.y * 0.42;

    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    // Place avatars on opposite sides of the central campfire
    leftAvatar.position = Vector2(centerX - 95, groundY);
    rightAvatar.position = Vector2(centerX + 39, groundY);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _flickerTimer += dt * 4;

    // Spawn new embers
    if (_embers.length < 24 && size.x > 0) {
      final centerX = size.x / 2;
      final fireBaseY = size.y * 0.42 + 90;
      _embers.add(
        CampfireEmber(
          pos: Vector2(centerX + (_rng.nextDouble() - 0.5) * 28, fireBaseY),
          speedY: 25 + _rng.nextDouble() * 35,
          speedX: (_rng.nextDouble() - 0.5) * 16,
          maxLife: 1.2 + _rng.nextDouble() * 1.0,
          radius: 1.5 + _rng.nextDouble() * 2.0,
          color: _rng.nextBool() ? Colors.amberAccent : Colors.deepOrangeAccent,
        ),
      );
    }

    // Update active embers
    for (int i = _embers.length - 1; i >= 0; i--) {
      final ember = _embers[i];
      ember.life -= dt;
      ember.pos.y -= ember.speedY * dt;
      ember.pos.x += ember.speedX * dt;
      if (ember.life <= 0) {
        _embers.removeAt(i);
      }
    }
  }

  void triggerEmote(String emote, {bool onLeft = true}) {
    final target = onLeft ? leftAvatar : rightAvatar;
    world.add(
      FloatingEmoteComponent(
        emote: emote,
        position: target.position + Vector2(28, -8),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    // 1. Starry Night Atmosphere Background
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF06070D), Color(0xFF0F121C), Color(0xFF141720)],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), bgPaint);

    final centerX = size.x / 2;
    final groundY = size.y * 0.42 + 96;

    // 2. Crescent Moon in the sky
    final moonPaint = Paint()..color = const Color(0xFFFDE68A).withOpacity(0.85);
    final moonAura = Paint()
      ..color = const Color(0xFFFDE68A).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(Offset(size.x * 0.82, size.y * 0.2), 16, moonAura);
    canvas.drawCircle(Offset(size.x * 0.82, size.y * 0.2), 14, moonPaint);
    // Dark mask to create crescent
    final moonCutPaint = Paint()..color = const Color(0xFF0A0C14);
    canvas.drawCircle(Offset(size.x * 0.82 + 6, size.y * 0.2 - 3), 13, moonCutPaint);

    // 3. Ground / Meadow
    final groundPaint = Paint()..color = const Color(0xFF161B18);
    final grassTopPaint = Paint()
      ..color = const Color(0xFF263328)
      ..strokeWidth = 3;
    canvas.drawRect(Rect.fromLTWH(0, groundY, size.x, size.y - groundY), groundPaint);
    canvas.drawLine(Offset(0, groundY), Offset(size.x, groundY), grassTopPaint);

    // 4. Fire Warmth Glow (Pulsing Aura)
    final pulse = sin(_flickerTimer) * 6;
    final glowPaint = Paint()
      ..color = const Color(0xFFFF9900).withOpacity(0.18 + (sin(_flickerTimer * 1.5) * 0.04))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 28 + pulse);
    canvas.drawCircle(Offset(centerX, groundY - 8), 45 + pulse, glowPaint);

    // 5. Firewood Logs
    final logPaint = Paint()..color = const Color(0xFF422817);
    final logHighlight = Paint()
      ..color = const Color(0xFF6B4226)
      ..strokeWidth = 2;

    // Left log angled
    canvas.save();
    canvas.translate(centerX - 8, groundY - 4);
    canvas.rotate(-0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -4, 32, 8), const Radius.circular(4)), logPaint);
    canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), logHighlight);
    canvas.restore();

    // Right log angled
    canvas.save();
    canvas.translate(centerX + 8, groundY - 4);
    canvas.rotate(0.35);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -4, 32, 8), const Radius.circular(4)), logPaint);
    canvas.drawLine(const Offset(-14, 0), const Offset(14, 0), logHighlight);
    canvas.restore();

    // 6. Campfire Flame Body
    final flameOuterPaint = Paint()..color = const Color(0xFFFF5722);
    final flameInnerPaint = Paint()..color = const Color(0xFFFFD54F);

    final flamePath = Path();
    flamePath.moveTo(centerX - 12, groundY - 4);
    flamePath.quadraticBezierTo(centerX - 16, groundY - 24 + sin(_flickerTimer) * 3, centerX, groundY - 38 + pulse);
    flamePath.quadraticBezierTo(centerX + 16, groundY - 24 - sin(_flickerTimer) * 3, centerX + 12, groundY - 4);
    flamePath.close();
    canvas.drawPath(flamePath, flameOuterPaint);

    final innerPath = Path();
    innerPath.moveTo(centerX - 6, groundY - 4);
    innerPath.quadraticBezierTo(centerX - 8, groundY - 18, centerX, groundY - 28 + pulse * 0.5);
    innerPath.quadraticBezierTo(centerX + 8, groundY - 18, centerX + 6, groundY - 4);
    innerPath.close();
    canvas.drawPath(innerPath, flameInnerPaint);

    // 7. Ascending Embers
    for (final ember in _embers) {
      final progress = ember.life / ember.maxLife;
      final emberPaint = Paint()
        ..color = ember.color.withOpacity(progress.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(ember.pos.x, ember.pos.y), ember.radius * progress, emberPaint);
    }

    super.render(canvas);
  }
}
