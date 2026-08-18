import 'dart:math';
import 'package:flame/components.dart';

class IsometricCoords {
  static const double tileWidth = 64.0;
  static const double tileHeight = 32.0;

  /// Converts isometric grid coordinates (gx, gy) to 2D screen coordinates (sx, sy)
  static Vector2 gridToScreen(double gx, double gy, {double originX = 0, double originY = 0}) {
    final sx = (gx - gy) * (tileWidth / 2) + originX;
    final sy = (gx + gy) * (tileHeight / 2) + originY;
    return Vector2(sx, sy);
  }

  /// Converts 2D screen coordinates (sx, sy) to isometric grid coordinates (gx, gy)
  static Point<int> screenToGrid(double sx, double sy, {double originX = 0, double originY = 0}) {
    final relX = sx - originX;
    final relY = sy - originY;

    final gx = ((relX / (tileWidth / 2)) + (relY / (tileHeight / 2))) / 2;
    final gy = ((relY / (tileHeight / 2)) - (relX / (tileWidth / 2))) / 2;

    return Point(gx.round(), gy.round());
  }

  /// Calculates dynamic isometric depth priority for z-sorting
  static int getZOrder(int gx, int gy, {int layer = 0}) {
    return (gx + gy) * 10 + layer;
  }

  /// Calculates the exact isometric sprite anchor offset based on grid footprint (1x1, 1x2, 2x1, 2x2)
  static Vector2 getFurnitureSpriteOffset({
    required int gridWidth,
    required int gridHeight,
    required double spriteWidth,
    required double spriteHeight,
  }) {
    if (gridWidth == 1 && gridHeight == 2) {
      // 1x2 along Y-axis (extends Down-Left across 2 tiles)
      return Vector2(-64.0, -36.0);
    } else if (gridWidth == 2 && gridHeight == 1) {
      // 2x1 along X-axis (extends Down-Right across 2 tiles)
      return Vector2(-32.0, -36.0);
    } else if (gridWidth == 2 && gridHeight == 2) {
      // 2x2 across 4 tiles (King Bed / Large items)
      return Vector2(-64.0, -44.0);
    } else {
      // 1x1 standard single tile: centered horizontally, baseline at ground level (y = +16)
      return Vector2(-spriteWidth / 2.0, (tileHeight / 2.0) - spriteHeight);
    }
  }
}
