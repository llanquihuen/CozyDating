import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../dungeon_game.dart';

class DarknessOverlayComponent extends PositionComponent with HasGameRef<DungeonGame> {
  final double lanternRadius = 88.0; // Focused 2.5-3 tile lantern light radius

  DarknessOverlayComponent() {
    priority = 100; // Render below Ping Beacons (priority 101)
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Size it to cover the entire 11x11 grid
    size = Vector2(11 * gameRef.tileSize, 11 * gameRef.tileSize);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = size.toRect();
    final explorerCenter = gameRef.explorer.center.toOffset();

    // 1. Save canvas layer for alpha blending cut-out
    canvas.saveLayer(rect, Paint());

    // 2. Draw solid 100% pitch black ambient darkness overlay
    canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));

    // 3. Cut out circular lantern light hole centered at Explorer with sharp focus
    final lightPaint = Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = RadialGradient(
        colors: const [
          Colors.black,
          Colors.black87,
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.85],
      ).createShader(
        Rect.fromCircle(center: explorerCenter, radius: lanternRadius),
      );

    canvas.drawCircle(explorerCenter, lanternRadius, lightPaint);

    // 4. Restore canvas layer
    canvas.restore();
  }
}
