import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../dungeon_game.dart';
import 'rune_gate_component.dart';
import 'rune_tile_component.dart';

class DarknessOverlayComponent extends PositionComponent with HasGameRef<DungeonGame> {
  final double baseLanternRadius = 36.0; // Base lantern around player (exactly 1 tile radius)
  double _currentFacingAngle = pi / 2; // Default facing south (down)
  double _pulseTimer = 0.0;

  DarknessOverlayComponent() {
    priority = 100; // Render below Ping Beacons (priority 101)
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    size = Vector2(11 * gameRef.tileSize, 11 * gameRef.tileSize);
    _currentFacingAngle = gameRef.explorer.facingAngle;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _pulseTimer += dt;

    // Smoothly rotate the flashlight beam towards targeted aim angle or explorer's facing angle
    final targetAngle = gameRef.customFlashlightAngle ?? gameRef.explorer.facingAngle;
    final angleDiff = atan2(sin(targetAngle - _currentFacingAngle), cos(targetAngle - _currentFacingAngle));
    _currentFacingAngle += angleDiff * min(1.0, dt * 18.0);
  }

  /// Exposed for unit testing raycasting against walls
  Offset castRayForTesting(Offset origin, double angle, double maxDistance, {double wallPenetration = 14.0}) {
    return _castRay(origin, angle, maxDistance, gameRef.dungeonMapData?.gridMatrix, gameRef.tileSize, wallPenetration: wallPenetration);
  }

  /// DDA 2D grid raycasting to find the exact collision point of light against dungeon walls
  Offset _castRay(
    Offset origin,
    double angle,
    double maxDistance,
    List<List<int>>? grid,
    double tileSize, {
    double wallPenetration = 14.0,
  }) {
    final dx = cos(angle);
    final dy = sin(angle);

    if (grid == null || grid.isEmpty) {
      return origin + Offset(dx * maxDistance, dy * maxDistance);
    }

    final rows = grid.length;
    final cols = grid[0].length;

    int mapX = (origin.dx / tileSize).floor();
    int mapY = (origin.dy / tileSize).floor();

    if (mapX < 0 || mapX >= cols || mapY < 0 || mapY >= rows) {
      return origin + Offset(dx * maxDistance, dy * maxDistance);
    }

    if (grid[mapY][mapX] == 1) {
      return origin;
    }

    final stepX = dx >= 0 ? 1 : -1;
    final stepY = dy >= 0 ? 1 : -1;

    final deltaDistX = (dx == 0) ? 1e30 : (tileSize / dx.abs());
    final deltaDistY = (dy == 0) ? 1e30 : (tileSize / dy.abs());

    double sideDistX;
    if (dx > 0) {
      sideDistX = ((mapX + 1) * tileSize - origin.dx) / dx;
    } else if (dx < 0) {
      sideDistX = (origin.dx - mapX * tileSize) / (-dx);
    } else {
      sideDistX = 1e30;
    }

    double sideDistY;
    if (dy > 0) {
      sideDistY = ((mapY + 1) * tileSize - origin.dy) / dy;
    } else if (dy < 0) {
      sideDistY = (origin.dy - mapY * tileSize) / (-dy);
    } else {
      sideDistY = 1e30;
    }

    double distance = 0.0;
    int hitSide = 0;

    while (distance < maxDistance) {
      if (sideDistX < sideDistY) {
        distance = sideDistX;
        sideDistX += deltaDistX;
        mapX += stepX;
        hitSide = 0;
      } else {
        distance = sideDistY;
        sideDistY += deltaDistY;
        mapY += stepY;
        hitSide = 1;
      }

      // Check bounds
      if (mapX < 0 || mapX >= cols || mapY < 0 || mapY >= rows) {
        final hitDist = min(distance, maxDistance);
        return origin + Offset(dx * hitDist, dy * hitDist);
      }

      // Wall collision (cell == 1)
      if (grid[mapY][mapX] == 1) {
        final entryDist = min(distance, maxDistance);
        final entryX = origin.dx + dx * entryDist;
        final entryY = origin.dy + dy * entryDist;
        final surfaceDepth = min(wallPenetration, tileSize * 0.2); // ~6-7px on wall surface

        // Penetrate perpendicularly into the wall surface so straight corridor walls produce flat, straight light edges
        if (hitSide == 0) {
          // Vertical wall (left/right): advance along X only
          return Offset(entryX + stepX * surfaceDepth, entryY);
        } else {
          // Horizontal wall (top/bottom): advance along Y only
          return Offset(entryX, entryY + stepY * surfaceDepth);
        }
      }
    }

    return origin + Offset(dx * maxDistance, dy * maxDistance);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = size.toRect();
    final lightOrigin = gameRef.explorer.feetPosition.toOffset();
    final grid = gameRef.dungeonMapData?.gridMatrix;
    final tileSize = gameRef.tileSize;

    final isPortalOpen = gameRef.portalRemainingSeconds.value > 0;

    // 1. Save canvas layer for alpha blending cut-outs
    canvas.saveLayer(rect, Paint());

    // 2. Ambient Overlay:
    // When the runes are united and portal is open, the entire dungeon is illuminated by a red emergency alarm light!
    // If time expires before reaching the exit, it seamlessly returns to the 99% pitch-black darkness.
    if (isPortalOpen) {
      final alarmPulse = sin(_pulseTimer * 5.0) * 0.08 + 0.42;
      canvas.drawRect(
        rect,
        Paint()..color = Color.fromRGBO(140, 15, 15, alarmPulse),
      );
    } else {
      // 99% pitch black ambient darkness overlay
      canvas.drawRect(rect, Paint()..color = const Color.fromRGBO(0, 0, 0, 0.99));
    }

    // 3. Cut out Exit Portal light (expands to 64px beacon during escape, 48px in normal state)
    final pulse = sin(_pulseTimer * 3.0) * 0.06 + 0.94;
    for (final gate in gameRef.world.children.whereType<RuneGateComponent>()) {
      final gateCenter = (gate.position + Vector2(gate.size.x / 2, gate.size.y / 2)).toOffset();
      final exitRadius = (isPortalOpen ? 64.0 : 48.0) * pulse;

      final exitLightPaint = Paint()
        ..blendMode = BlendMode.dstOut
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..shader = RadialGradient(
          colors: const [
            Colors.black,
            Colors.black87,
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(
          Rect.fromCircle(center: gateCenter, radius: exitRadius),
        );

      canvas.drawCircle(gateCenter, exitRadius, exitLightPaint);
    }

    // 4. Cut out glowing light around correctly activated/lit Rune Tiles
    for (final rune in gameRef.world.children.whereType<RuneTileComponent>()) {
      if (rune.isLit) {
        final runeCenter = (rune.position + Vector2(rune.size.x / 2, rune.size.y / 2)).toOffset();
        final runeRadius = 36.0 * pulse;

        final runeLightPaint = Paint()
          ..blendMode = BlendMode.dstOut
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..shader = RadialGradient(
            colors: const [
              Colors.black,
              Colors.black87,
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(center: runeCenter, radius: runeRadius),
          );

        canvas.drawCircle(runeCenter, runeRadius, runeLightPaint);
      }
    }

    // 5. Cut out Explorer Full-Body Illumination (Capsule covering head, hair, face and body)
    // Ensures the character avatar is 100% visible (head, hair, face, clothes, feet) with zero dark clipping
    final avatarCenter = Offset(
      gameRef.explorer.position.x + gameRef.explorer.size.x / 2,
      gameRef.explorer.position.y + gameRef.explorer.size.y / 2,
    );

    // Outer soft aura layer to smoothly transition into darkness without hard seams
    final outerBodyRect = Rect.fromCenter(
      center: avatarCenter,
      width: 34.0,
      height: 68.0,
    );
    final outerBodyPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.black54
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerBodyRect, const Radius.circular(17)),
      outerBodyPaint,
    );

    // Core bright body layer: 100% solid cutout so head, long hair, face and body are completely illuminated
    final coreBodyRect = Rect.fromCenter(
      center: avatarCenter,
      width: 30.0,
      height: 62.0,
    );
    final coreBodyPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..color = Colors.black
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(coreBodyRect, const Radius.circular(15)),
      coreBodyPaint,
    );

    // 6. Cut out Explorer Base ground lantern light (360 degrees bounded by walls so it never leaks into adjacent rooms)
    const numBaseRays = 36;
    final baseRadius = baseLanternRadius; // Exactly 36px (1 tile) as specified
    final baseLanternPath = Path()..moveTo(lightOrigin.dx, lightOrigin.dy);

    for (int i = 0; i <= numBaseRays; i++) {
      final angle = i * (2 * pi / numBaseRays);
      final hitPoint = _castRay(
        lightOrigin,
        angle,
        baseRadius,
        grid,
        tileSize,
        wallPenetration: 4.0, // Slight 4px contact with walls, 100% blocked from adjacent rooms
      );
      baseLanternPath.lineTo(hitPoint.dx, hitPoint.dy);
    }
    baseLanternPath.close();

    final baseLightPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = RadialGradient(
        colors: const [
          Colors.black,
          Colors.black87,
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(
        Rect.fromCircle(center: lightOrigin, radius: baseRadius),
      );

    canvas.drawPath(baseLanternPath, baseLightPaint);

    // 7. Cut out Explorer Forward-Looking Flashlight with Wall Collision and Soft Organic Edges
    final beamDistance = gameRef.tileSize * 3.8;
    final gridMatrix = gameRef.dungeonMapData?.gridMatrix;

    // Helper to generate a cone path with raycasting
    Path buildConePath(double halfConeAngle) {
      final path = Path()..moveTo(lightOrigin.dx, lightOrigin.dy);
      final startAngle = _currentFacingAngle - halfConeAngle;
      final endAngle = _currentFacingAngle + halfConeAngle;
      const numRays = 64;
      final angleStep = (endAngle - startAngle) / numRays;

      for (int i = 0; i <= numRays; i++) {
        final rayAngle = startAngle + (i * angleStep);
        final hitPoint = _castRay(
          lightOrigin,
          rayAngle,
          beamDistance,
          gridMatrix,
          tileSize,
          wallPenetration: 6.0, // Perpendicular depth into wall face
        );
        path.lineTo(hitPoint.dx, hitPoint.dy);
      }
      path.close();
      return path;
    }

    // Outer soft fringe layer: wide cone (~76° total) with blur to soften diagonal edges and eliminate harsh cuts
    const outerHalfAngle = 38 * (pi / 180);
    final outerPath = buildConePath(outerHalfAngle);
    final outerPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
      ..shader = RadialGradient(
        colors: const [
          Colors.black54,
          Colors.black38,
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCircle(center: lightOrigin, radius: beamDistance),
      );
    canvas.drawPath(outerPath, outerPaint);

    // Core bright beam layer: focused cone (~56° total)
    const coreHalfAngle = 28 * (pi / 180);
    final corePath = buildConePath(coreHalfAngle);
    final corePaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
      ..shader = RadialGradient(
        colors: const [
          Colors.black,
          Colors.black87,
          Colors.black38,
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.75, 1.0],
      ).createShader(
        Rect.fromCircle(center: lightOrigin, radius: beamDistance),
      );
    canvas.drawPath(corePath, corePaint);

    // 7. Restore canvas layer
    canvas.restore();

    // 8. If portal is open, overlay a pulsating red emergency alarm wash across the entire dungeon
    if (isPortalOpen) {
      final emergencyAlarmWash = Paint()
        ..color = Color.fromRGBO(255, 30, 30, 0.18 + 0.08 * sin(_pulseTimer * 5.0))
        ..blendMode = BlendMode.screen;
      canvas.drawRect(rect, emergencyAlarmWash);
    }
  }
}
