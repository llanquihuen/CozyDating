import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/components/modular_avatar_component.dart';
import '../components/floating_emote_component.dart';
import 'components/floating_item_arc_component.dart';

enum CinematicPhase {
  walkingIn,
  itemExchange,
  celebrating,
  walkingOut,
  finished,
}

class RoleSwapCinematicGame extends FlameGame {
  final AvatarConfig localAvatarConfig;
  final AvatarConfig? partnerAvatarConfig;
  final bool localWasExplorer;
  final VoidCallback? onCinematicFinished;

  late final ModularAvatarComponent leftAvatar;
  late final ModularAvatarComponent rightAvatar;

  double _elapsedTime = 0.0;
  CinematicPhase currentPhase = CinematicPhase.walkingIn;

  Vector2 _leftStartPos = Vector2(-200, 200);
  Vector2 _leftCenterPos = Vector2(160, 200);
  Vector2 _rightStartPos = Vector2(600, 200);
  Vector2 _rightCenterPos = Vector2(240, 200);

  bool _itemsSpawned = false;
  bool _emotesSpawned = false;

  RoleSwapCinematicGame({
    required this.localAvatarConfig,
    this.partnerAvatarConfig,
    required this.localWasExplorer,
    this.onCinematicFinished,
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

    final leftConfig = localWasExplorer ? localAvatarConfig : partnerConfig;
    final rightConfig = localWasExplorer ? partnerConfig : localAvatarConfig;

    leftAvatar = ModularAvatarComponent(
      config: leftConfig,
      direction: AvatarDirection.east,
      isMoving: true,
      size: Vector2(64, 128),
      position: _leftStartPos.clone(),
    );

    rightAvatar = ModularAvatarComponent(
      config: rightConfig,
      direction: AvatarDirection.west,
      isMoving: true,
      size: Vector2(64, 128),
      position: _rightStartPos.clone(),
    );
  }

  @override
  Color backgroundColor() => const Color(0xFF0B0C10);

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
    final groundY = size.y * 0.48;

    _leftStartPos = Vector2(centerX - min(size.x * 0.45, 200), groundY);
    _leftCenterPos = Vector2(centerX - 42, groundY);

    _rightStartPos = Vector2(centerX + min(size.x * 0.45, 200) - 64, groundY);
    _rightCenterPos = Vector2(centerX - 22, groundY);

    // Position viewfinder camera
    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();

    if (_elapsedTime == 0.0) {
      leftAvatar.position = _leftStartPos.clone();
      rightAvatar.position = _rightStartPos.clone();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsedTime += dt;

    // Phase 1: Walking In (0.0s -> 2.2s)
    if (_elapsedTime < 2.2) {
      currentPhase = CinematicPhase.walkingIn;
      final progress = (_elapsedTime / 2.2).clamp(0.0, 1.0);
      // Smooth ease-out movement
      final curved = 1 - pow(1 - progress, 2);

      leftAvatar.isMoving = true;
      leftAvatar.direction = AvatarDirection.east;
      leftAvatar.position = _leftStartPos + (_leftCenterPos - _leftStartPos) * curved.toDouble();

      rightAvatar.isMoving = true;
      rightAvatar.direction = AvatarDirection.west;
      rightAvatar.position = _rightStartPos + (_rightCenterPos - _rightStartPos) * curved.toDouble();
    }
    // Phase 2: Stop & Item Exchange (2.2s -> 4.6s)
    else if (_elapsedTime < 4.6) {
      currentPhase = CinematicPhase.itemExchange;
      leftAvatar.isMoving = false;
      leftAvatar.position = _leftCenterPos.clone();

      rightAvatar.isMoving = false;
      rightAvatar.position = _rightCenterPos.clone();

      if (!_itemsSpawned) {
        _itemsSpawned = true;
        // Torch flies from Left (Ex-Explorer) to Right (New Explorer)
        final torchStart = leftAvatar.position + Vector2(32, 40);
        final torchEnd = rightAvatar.position + Vector2(32, 40);
        world.add(FloatingItemArcComponent(
          iconText: '🔦',
          startPos: torchStart,
          endPos: torchEnd,
          arcHeight: 48,
          duration: 1.5,
        ));

        // Compass flies from Right (Ex-Guide) to Left (New Guide)
        final compassStart = rightAvatar.position + Vector2(32, 50);
        final compassEnd = leftAvatar.position + Vector2(32, 50);
        world.add(FloatingItemArcComponent(
          iconText: '🧭',
          startPos: compassStart,
          endPos: compassEnd,
          arcHeight: 52,
          duration: 1.5,
        ));
      }

      // At 3.4s, spawn shared connection emotes
      if (_elapsedTime >= 3.4 && !_emotesSpawned) {
        _emotesSpawned = true;
        currentPhase = CinematicPhase.celebrating;
        world.add(FloatingEmoteComponent(
          emote: '❤️',
          position: leftAvatar.position + Vector2(32, -10),
        ));
        world.add(FloatingEmoteComponent(
          emote: '👏',
          position: rightAvatar.position + Vector2(32, -10),
        ));
      }
    }
    // Phase 3: Turn Around and Walk Out (4.6s -> 7.5s)
    else if (_elapsedTime < 7.5) {
      currentPhase = CinematicPhase.walkingOut;
      final outProgress = ((_elapsedTime - 4.6) / 2.9).clamp(0.0, 1.0);
      final curvedOut = pow(outProgress, 1.8);

      // Turn around: Left avatar goes west, right avatar goes east
      leftAvatar.direction = AvatarDirection.west;
      leftAvatar.isMoving = true;
      leftAvatar.position = _leftCenterPos + (_leftStartPos - _leftCenterPos) * curvedOut.toDouble();

      rightAvatar.direction = AvatarDirection.east;
      rightAvatar.isMoving = true;
      rightAvatar.position = _rightCenterPos + (_rightStartPos - _rightCenterPos) * curvedOut.toDouble();
    }
    // Phase 4: Finished
    else {
      if (currentPhase != CinematicPhase.finished) {
        currentPhase = CinematicPhase.finished;
        leftAvatar.isMoving = false;
        rightAvatar.isMoving = false;
        onCinematicFinished?.call();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    // Draw bridge floor and starry night ambiance
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF080811), Color(0xFF161A29), Color(0xFF0C0E17)],
      ).createShader(Rect.fromLTWH(0, 0, size.x, size.y));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), bgPaint);

    // Draw Stone Bridge Pathway
    final bridgeY = size.y * 0.48 + 108;
    final bridgePaint = Paint()..color = const Color(0xFF282C37);
    final bridgeEdgePaint = Paint()
      ..color = const Color(0xFF4A5164)
      ..strokeWidth = 3;

    // Bridge platform
    canvas.drawRect(Rect.fromLTWH(0, bridgeY, size.x, 32), bridgePaint);
    canvas.drawLine(Offset(0, bridgeY), Offset(size.x, bridgeY), bridgeEdgePaint);
    canvas.drawLine(Offset(0, bridgeY + 32), Offset(size.x, bridgeY + 32), bridgeEdgePaint);

    // Subtle stone flag markings
    final flagPaint = Paint()..color = const Color(0xFF353B4A);
    for (double x = 12; x < size.x; x += 36) {
      canvas.drawLine(Offset(x, bridgeY), Offset(x, bridgeY + 32), flagPaint);
    }

    super.render(canvas);
  }
}
