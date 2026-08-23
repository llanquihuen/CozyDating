import 'dart:math';
import 'package:flame/components.dart';

class IsometricCoords {
  static const double tileWidth = 64.0;
  static const double tileHeight = 32.0;

  // Sub-grid (2x2 factor) constants
  static const double subTileWidth = 32.0;   // tileWidth / 2
  static const double subTileHeight = 16.0;  // tileHeight / 2
  static const double subStepX = 16.0;       // tileWidth / 4
  static const double subStepY = 8.0;        // tileHeight / 4

  /// Converts sub-grid coordinates (u, v) to 2D screen coordinates (sx, sy)
  static Vector2 subGridToScreen(double u, double v, {double originX = 0, double originY = 0}) {
    final sx = (u - v) * subStepX + originX;
    final sy = (u + v) * subStepY - subStepY + originY;
    return Vector2(sx, sy);
  }

  /// Converts 2D screen coordinates (sx, sy) to sub-grid coordinates (u, v)
  static Point<int> screenToSubGrid(double sx, double sy, {double originX = 0, double originY = 0}) {
    final relX = sx - originX;
    final relY = sy - originY + subStepY;

    // Floor isometric sub-grid projection
    final double rawU = ((relX / subStepX) + (relY / subStepY)) / 2;
    final double rawV = ((relY / subStepY) - (relX / subStepX)) / 2;

    return Point(rawU.floor(), rawV.floor());
  }

  /// Converts isometric grid coordinates (gx, gy) to 2D screen coordinates (sx, sy)
  static Vector2 gridToScreen(double gx, double gy, {double originX = 0, double originY = 0}) {
    final sx = (gx - gy) * (tileWidth / 2) + originX;
    final sy = (gx + gy) * (tileHeight / 2) + originY;
    return Vector2(sx, sy);
  }

  /// Converts 2D screen coordinates (sx, sy) to isometric grid coordinates (gx, gy).
  /// Accurately projects points in both the floor plane and vertical North/West wall zones.
  static Point<int> screenToGrid(double sx, double sy, {double originX = 0, double originY = 0}) {
    final relX = sx - originX;
    final relY = sy - originY;

    const halfW = tileWidth / 2;   // 32.0
    const halfH = tileHeight / 2;  // 16.0

    // Standard floor isometric projection (Z = 0)
    final double rawGx = ((relX / halfW) + (relY / halfH)) / 2;
    final double rawGy = ((relY / halfH) - (relX / halfW)) / 2;

    // Check if the point is above the back floor edges (in the vertical wall zone)
    if (relX >= 0 && rawGy < -0.5) {
      // North wall projection: vertical panels along X >= 0 (gy = 0)
      final gx = (relX / halfW).floor();
      return Point(gx, 0);
    } else if (relX < 0 && rawGx < -0.5) {
      // West wall projection: vertical panels along X < 0 (gx = 0)
      final gy = ((-relX) / halfW).floor();
      return Point(0, gy);
    }

    return Point(rawGx.round(), rawGy.round());
  }

  /// Calculates dynamic isometric depth priority for sub-grid z-sorting
  static int getSubZOrder(int u, int v, {int width = 1, int depth = 1, int layer = 0, String footprint = '1x1'}) {
    if (footprint == 'wall_n' || footprint.contains('wall_n')) {
      return -100 + (u ~/ 2) * 5 + layer;
    }
    if (footprint == 'wall_w' || footprint.contains('wall_w')) {
      return -100 + (v ~/ 2) * 5 + layer;
    }
    final int baseDepth = u + v + width + depth - 1;
    if (footprint == 'surface') {
      return baseDepth * 1000 + 50 + layer;
    }
    return baseDepth * 1000 + 10 + layer;
  }

  /// Calculates dynamic isometric depth priority for z-sorting
  static int getZOrder(int gx, int gy, {int layer = 0, String footprint = '1x1'}) {
    if (footprint == 'wall_n' || footprint.contains('wall_n')) {
      return -100 + gx * 5 + layer;
    }
    if (footprint == 'wall_w' || footprint.contains('wall_w')) {
      return -100 + gy * 5 + layer;
    }
    return getSubZOrder(gx * 2, gy * 2, width: 1, depth: 1, layer: layer, footprint: footprint);
  }

  /// Calculates depth priority for interior partition walls located on tile boundaries.
  static int getInteriorWallZOrder(int gx, int gy, String orientation) {
    final base = (gx + gy) * 2000;
    return (orientation == 'north') ? (base - 400) : (base - 300);
  }

  /// Calculates the exact isometric sprite anchor offset based on grid footprint (1x1, 1x2, 2x1, 2x2, surface, wall_n, wall_w)
  static Vector2 getFurnitureSpriteOffset({
    required int gridWidth,
    required int gridHeight,
    required double spriteWidth,
    required double spriteHeight,
    String footprint = '1x1',
    double surfaceHeight = 0.0,
    String wallHeightLevel = 'mid', // 'mid' or 'high'
    int rotation = 0,
  }) {
    if (footprint == 'surface') {
      final effSurfaceH = surfaceHeight > 0 ? surfaceHeight : 14.0;
      // Sits on top of the parent table/counter/bed/cube surface
      return Vector2(-spriteWidth / 2.0, (tileHeight / 4.0) - spriteHeight - effSurfaceH);
    } else if (footprint == 'wall_n') {
      // North Wall: +16.0 on X to center on right-sloping wall face
      // 'mid' = -32.0, 'high' = -48.0 (punto intermedio perfecto)
      final wallYOffset = (wallHeightLevel == 'high') ? -48.0 : -32.0;
      return Vector2((-spriteWidth / 2.0) + 16.0, wallYOffset - spriteHeight / 2.0);
    } else if (footprint == 'wall_w') {
      // West Wall: -16.0 on X to center on left-sloping wall face
      // 'mid' = -32.0, 'high' = -48.0
      final wallYOffset = (wallHeightLevel == 'high') ? -48.0 : -32.0;
      return Vector2((-spriteWidth / 2.0) - 16.0, wallYOffset - spriteHeight / 2.0);
    } else if (footprint == '1x2' || (gridWidth == 1 && gridHeight == 2)) {
      // 1x2 along Y-axis (extends Down-Left across 2 tiles)
      return Vector2(-64.0, -36.0);
    } else if (footprint == '2x1' || (gridWidth == 2 && gridHeight == 1)) {
      // 2x1 along X-axis (extends Down-Right across 2 tiles)
      return Vector2(-32.0, -36.0);
    } else if (footprint == '2x2' || (gridWidth == 2 && gridHeight == 2)) {
      // 2x2 across 4 tiles (King Bed / Dining Table / Large items)
      return Vector2(-64.0, -44.0);
    } else {
      // 1x1 standard single tile: centered horizontally, baseline at ground level (y = +16)
      return Vector2(-spriteWidth / 2.0, (tileHeight / 2.0) - spriteHeight);
    }
  }
}
