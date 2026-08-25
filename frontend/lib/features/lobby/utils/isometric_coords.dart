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

    return Point(rawU.round(), rawV.round());
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

    final int intraX = u % 2;
    final int intraY = v % 2;
    final int gx = u ~/ 2;
    final int gy = v ~/ 2;
    final int wSub = width;
    final int dSub = depth;

    final int subOffset = 1000 + (intraX + intraY + wSub - 1 + dSub - 1) * 1000 + intraY * 200 + intraX * 50;
    final int base = (gx + gy) * 10000 + subOffset;

    if (footprint == 'surface') {
      return base + 500 + layer;
    }
    return base + layer;
  }

  /// Extra whole-tile depth steps a floor item's RENDERED SPRITE needs added to its z-order so it
  /// clears a neighboring wall panel it visually overlaps ONLY WITHIN ITS OWN ROW (north) or
  /// OWN COLUMN (west) — never a panel in a different row/column.
  ///
  /// A floor item's drawn sprite can be wider than the 32px wall panel it's centered over — from
  /// a half-integer grid snap (see cozy_room_game.dart: all floor furniture snaps to 0.5 subgrid
  /// increments), OR simply from an off-center catalog `spriteOffset` even at an exact integer
  /// grid position (e.g. `kitchen_fridge_sm`'s `[-16, -56]`). When that spillover lands on another
  /// panel of the SAME continuous wall — i.e. still within the item's own row for a north wall, or
  /// own column for a west wall — that neighboring panel is geometrically flat with the item's own
  /// wall (no real depth difference) yet still draws with a full tile-step higher priority (see
  /// `getInteriorWallZOrder`), splitting the sprite in two. That's the only case this corrects.
  ///
  /// Crucially, a panel in a DIFFERENT row (north) or column (west) is not "the same wall" — it's
  /// the boundary into a genuinely different, farther room, and the unmodified `(gx + gy)` depth
  /// order in `getSubZOrder`/`getInteriorWallZOrder` already resolves that correctly: furniture
  /// that actually belongs behind such a wall (a different room's item) is SUPPOSED to be
  /// occluded by it. An earlier version of this function computed the bump using the sprite's
  /// nearest row/column (`gridY.round()`/`gridX.round()`) instead of its own home row/column
  /// (`gridY.floor()`/`gridX.floor()`), which let it reach across into an adjacent, legitimately
  /// occluding room's wall and incorrectly force the item in front of it — e.g. a fridge or bed
  /// that should stay tucked behind the north wall of an adjacent room started popping out in
  /// front of it. Anchoring both checks to the item's own floored row/column fixes that: see
  /// subcell-furniture-wall-zorder-fix memory.
  ///
  /// [spriteLeft]/[spriteRight] are the sprite's drawn screen-space X extent (world/room space,
  /// same origin as `gridToScreen`/`subGridToScreen`). Only forward (higher-priority, more
  /// "in front") overlap matters — overlapping a lower-priority neighbor is harmless since that
  /// neighbor already draws first — so the result is never negative.
  ///
  /// This returns the DESIRED bump for same-wall clearance only. It does NOT know which wall
  /// tiles actually exist in the room (a pure function over grid coordinates can't), so it cannot
  /// by itself tell "the panel one row over that I'd also need to clear" apart from "a panel one
  /// row over that doesn't even exist, so there's nothing to worry about." A real level can have a
  /// genuinely different, nearer room's wall there that this bump would incorrectly pop the item
  /// in front of. Callers that have access to the room's actual wall list — see
  /// `IsometricFurnitureComponent.updateGridPosition` and its `_capWallClearanceBump` — MUST cap
  /// this value against those real walls before using it; see subcell-furniture-wall-zorder-fix
  /// memory for why a blind, wall-list-agnostic ceiling (tried and reverted) was too conservative.
  static int getWallClearanceBump({
    required double gridX,
    required double gridY,
    required double spriteLeft,
    required double spriteRight,
  }) {
    if (spriteRight <= spriteLeft) return 0;

    // The bucket `getSubZOrder` actually uses for this item's OWN base priority — gx.floor()/
    // gy.floor(), matching `u ~/ 2` / `v ~/ 2` there exactly.
    final int homeGx = gridX.floor();
    final int homeGy = gridY.floor();

    // North-wall panels within the item's OWN row only: panel gx spans
    // sx ∈ [(gx-homeGy)*32, (gx-homeGy)*32+32]. The sprite reaches its highest-priority (max gx)
    // overlapping panel at its RIGHT edge.
    final int northMaxPanel = homeGy + ((spriteRight - 0.01) / subTileWidth).floor();
    final int northBump = (northMaxPanel - homeGx).clamp(0, 4);

    // West-wall panels within the item's OWN column only: panel gy spans
    // sx ∈ [(homeGx-gy)*32-32, (homeGx-gy)*32]. Screen X decreases as gy increases, so the sprite
    // reaches its highest-priority (max gy) overlapping panel at its LEFT edge.
    // `+ 0.01` mirrors the `- 0.01` above but in the opposite direction: for west panels the
    // forward (higher-priority) edge is the LEFT one, so pulling it back toward home means
    // nudging sx up slightly, not down. Without this, any sprite whose left edge lands exactly
    // on a 32px panel seam — the common case for ordinary integer-grid-positioned furniture with
    // a symmetric spriteOffset, since `position.x` is then itself an exact multiple of 32 — got
    // `ceil()`'d into the NEXT (higher-priority) panel it was only just touching, not actually
    // overlapping.
    final int westMaxPanel = homeGx - ((spriteLeft + 0.01) / subTileWidth).ceil();
    final int westBump = (westMaxPanel - homeGy).clamp(0, 4);

    return northBump > westBump ? northBump : westBump;
  }

  /// Screen-space X span of an interior wall panel at [gx]/[gy] — [isNorth] picks the orientation.
  /// Shared by `IsometricFurnitureComponent`'s real-wall-list clearance cap and (for reference)
  /// mirrors the panel math `getWallClearanceBump` uses internally; see
  /// isometric-wall-panel-geometry memory for the underlying geometry.
  static (double left, double right) getWallPanelScreenSpan(int gx, int gy, bool isNorth) {
    if (isNorth) {
      final left = (gx - gy) * subTileWidth;
      return (left, left + subTileWidth);
    }
    final right = (gx - gy) * subTileWidth;
    return (right - subTileWidth, right);
  }

  /// Calculates dynamic isometric depth priority for z-sorting (full tile)
  static int getZOrder(int gx, int gy, {int layer = 0, String footprint = '1x1'}) {
    if (footprint == 'wall_n' || footprint.contains('wall_n')) {
      return -100 + gx * 5 + layer;
    }
    if (footprint == 'wall_w' || footprint.contains('wall_w')) {
      return -100 + gy * 5 + layer;
    }
    return getSubZOrder(gx * 2, gy * 2, width: 2, depth: 2, layer: layer, footprint: footprint);
  }

  /// Calculates depth priority for interior partition walls located on tile boundaries.
  static int getInteriorWallZOrder(int gx, int gy, String orientation) {
    final int base = (gx + gy) * 10000;
    return (orientation == 'north')
        ? (base + 100)
        : (base + 200);
  }

  /// Calculates the exact isometric sprite anchor offset based on grid footprint (0.5x0.5, 1x1, 1x2, 2x1, 2x2, surface, wall_n, wall_w)
  static Vector2 getFurnitureSpriteOffset({
    required num gridWidth,
    required num gridHeight,
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
    } else if (footprint == '0.5x0.5' || (gridWidth <= 0.5 && gridHeight <= 0.5)) {
      // 0.5x0.5 compact quarter-tile: centered horizontally, baseline at sub-tile ground level (y = +8)
      return Vector2(-spriteWidth / 2.0, (tileHeight / 4.0) - spriteHeight);
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
