import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import '../../../core/models/room_config.dart';
import '../utils/isometric_coords.dart';
import 'isometric_avatar_component.dart';

class IsometricInteriorWallComponent extends Component {
  final String id;
  int gridX;
  int gridY;
  String orientation; // 'north' (top edge) or 'west' (left edge)
  String style; // 'wood_slats', 'bathroom_glass', 'rustic_brick', 'modern_white', 'japanese_shoji', 'doorway_frame'
  bool hasDoorway;
  bool isSelected;
  // Shared plaster texture (wallpaper_solid_plaster.png), tinted per-style to
  // texture the flat-color wall styles the same way the room's own walls are textured.
  Sprite? plasterSprite;
  bool _isBeingDragged = false;
  bool get isBeingDragged => _isBeingDragged;
  set isBeingDragged(bool value) {
    _isBeingDragged = value;
    _updatePriority();
  }
  Vector2 dragVisualOffset = Vector2.zero();

  double currentOpacity = 1.0;
  double targetOpacity = 1.0;

  static const double wallHeight = 68.0;
  static const double halfTileW = IsometricCoords.tileWidth / 2.0; // 32
  static const double halfTileH = IsometricCoords.tileHeight / 2.0; // 16

  IsometricInteriorWallComponent({
    required this.id,
    required this.gridX,
    required this.gridY,
    this.orientation = 'north',
    this.style = 'wood_slats',
    this.hasDoorway = false,
    this.isSelected = false,
    this.plasterSprite,
    bool isBeingDragged = false,
  }) : _isBeingDragged = isBeingDragged {
    _updatePriority();
  }

  void _updatePriority() {
    priority = _isBeingDragged
        ? 9999
        : IsometricCoords.getInteriorWallZOrder(gridX, gridY, orientation);
  }

  void updateGridPosition(int newGx, int newGy, {String? newOrientation}) {
    gridX = newGx;
    gridY = newGy;
    if (newOrientation != null) {
      orientation = newOrientation;
    }
    _updatePriority();
  }

  void toggleOrientation() {
    orientation = (orientation == 'north') ? 'west' : 'north';
    _updatePriority();
  }

  void toggleDoorway() {
    hasDoorway = !hasDoorway;
  }

  /// World-space point at the middle of the wall's top edge — used to float the
  /// selection toolbar right above the wall instead of a fixed screen corner.
  Vector2 get topAnchorWorld {
    final basePos = IsometricCoords.gridToScreen(gridX.toDouble(), gridY.toDouble()) + dragVisualOffset;
    final isNorth = (orientation == 'north');

    double bX1, bY1, bX2, bY2;
    if (isNorth) {
      bX1 = basePos.x;
      bY1 = basePos.y - halfTileH;
      bX2 = basePos.x + halfTileW;
      bY2 = basePos.y;
    } else {
      bX1 = basePos.x - halfTileW;
      bY1 = basePos.y;
      bX2 = basePos.x;
      bY2 = basePos.y - halfTileH;
    }

    return Vector2((bX1 + bX2) / 2.0, (bY1 + bY2) / 2.0 - wallHeight);
  }

  InteriorWallConfig toConfig() {
    return InteriorWallConfig(
      id: id,
      gridX: gridX,
      gridY: gridY,
      orientation: orientation,
      style: style,
      hasDoorway: hasDoorway,
    );
  }

  bool hitTestWorld(Vector2 worldPos) {
    final basePos = IsometricCoords.gridToScreen(gridX.toDouble(), gridY.toDouble()) + dragVisualOffset;
    final isNorth = (orientation == 'north');

    // Same 4 corners used to paint the wall in render() — bottom-near, top-near,
    // top-far, bottom-far — so the hit area matches the actual slanted parallelogram
    // instead of the larger axis-aligned box that used to wrap loosely around it.
    double bX1, bY1, bX2, bY2;
    if (isNorth) {
      bX1 = basePos.x;
      bY1 = basePos.y - halfTileH;
      bX2 = basePos.x + halfTileW;
      bY2 = basePos.y;
    } else {
      bX1 = basePos.x - halfTileW;
      bY1 = basePos.y;
      bX2 = basePos.x;
      bY2 = basePos.y - halfTileH;
    }
    final tX1 = bX1, tY1 = bY1 - wallHeight;
    final tX2 = bX2, tY2 = bY2 - wallHeight;

    return _pointInQuad(
      worldPos,
      Vector2(bX1, bY1),
      Vector2(tX1, tY1),
      Vector2(tX2, tY2),
      Vector2(bX2, bY2),
    );
  }

  /// Point-in-convex-quad test: true when [p] is on the same side of every edge of the
  /// quad a→b→c→d→a (checked via the cross product's sign), which holds for any point
  /// strictly inside a convex, non-self-intersecting polygon like this wall panel.
  bool _pointInQuad(Vector2 p, Vector2 a, Vector2 b, Vector2 c, Vector2 d) {
    final pts = [a, b, c, d];
    double? sign;
    for (int i = 0; i < 4; i++) {
      final edge = pts[(i + 1) % 4] - pts[i];
      final toPoint = p - pts[i];
      final cross = edge.x * toPoint.y - edge.y * toPoint.x;
      if (cross.abs() < 1e-6) continue;
      final s = cross.sign;
      if (sign == null) {
        sign = s;
      } else if (sign != s) {
        return false;
      }
    }
    return true;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (isBeingDragged) {
      targetOpacity = 1.0;
      currentOpacity = 1.0;
      return;
    }

    // Check if avatar is standing behind this wall in depth and visually occluded
    final avatars = (parent as World?)?.children.whereType<IsometricAvatarComponent>() ?? const [];
    bool isOccludingAvatar = false;

    if (avatars.isNotEmpty) {
      final basePos = IsometricCoords.gridToScreen(gridX.toDouble(), gridY.toDouble());
      final isNorth = (orientation == 'north');

      final double bX1 = isNorth ? basePos.x : basePos.x - halfTileW;
      final double bY1 = isNorth ? basePos.y - halfTileH : basePos.y;
      final double bX2 = isNorth ? basePos.x + halfTileW : basePos.x;
      final double bY2 = isNorth ? basePos.y : basePos.y - halfTileH;

      final minX = min(bX1, bX2) - 8.0;
      final maxX = max(bX1, bX2) + 8.0;
      final minY = min(bY1, bY2) - wallHeight - 6.0;
      final maxY = max(bY1, bY2) + 4.0;
      final wallRect = Rect.fromLTRB(minX, minY, maxX, maxY);

      for (final av in avatars) {
        if (!av.isVisible) continue;
        if (av.priority < priority) {
          final avBounds = Rect.fromLTWH(av.position.x, av.position.y, av.size.x, av.size.y);
          if (avBounds.overlaps(wallRect)) {
            isOccludingAvatar = true;
            break;
          }
        }
      }
    }

    // When avatar is behind the wall, fade to 50% opacity
    targetOpacity = isOccludingAvatar ? 0.50 : 1.0;

    // Smooth transition
    final speed = dt * 7.0;
    if (currentOpacity < targetOpacity) {
      currentOpacity = (currentOpacity + speed).clamp(0.50, 1.0);
    } else if (currentOpacity > targetOpacity) {
      currentOpacity = (currentOpacity - speed).clamp(0.50, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final basePos = IsometricCoords.gridToScreen(gridX.toDouble(), gridY.toDouble()) + dragVisualOffset;
    final isNorth = (orientation == 'north');

    // Bottom edge anchor points on the ground
    double bX1, bY1, bX2, bY2;
    if (isNorth) {
      // North Edge: connects Top vertex (pos.x, pos.y - 16) to Right vertex (pos.x + 32, pos.y)
      bX1 = basePos.x;
      bY1 = basePos.y - halfTileH;
      bX2 = basePos.x + halfTileW;
      bY2 = basePos.y;
    } else {
      // West Edge: connects Left vertex (pos.x - 32, pos.y) to Top vertex (pos.x, pos.y - 16)
      bX1 = basePos.x - halfTileW;
      bY1 = basePos.y;
      bX2 = basePos.x;
      bY2 = basePos.y - halfTileH;
    }

    // Top edge anchor points (elevated by wallHeight)
    final tX1 = bX1;
    final tY1 = bY1 - wallHeight;
    final tX2 = bX2;
    final tY2 = bY2 - wallHeight;

    final wallQuad = Path()
      ..moveTo(bX1, bY1)
      ..lineTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(bX2, bY2)
      ..close();

    final bool needsTransparency = currentOpacity < 0.99;
    if (needsTransparency) {
      canvas.saveLayer(
        null,
        Paint()..color = Color.fromRGBO(255, 255, 255, currentOpacity),
      );
    }

    _renderWallStyle(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, wallQuad, isNorth);

    if (needsTransparency) {
      canvas.restore();
    }

    // Selection or Drag Glow
    if (isSelected || isBeingDragged) {
      final glowColor = isBeingDragged ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F);
      final strokePaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);
      canvas.drawPath(wallQuad, strokePaint);

      // Base indicator
      final baseLine = Path()
        ..moveTo(bX1, bY1)
        ..lineTo(bX2, bY2);
      final basePaint = Paint()
        ..color = glowColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawPath(baseLine, basePaint);
    }
  }

  void _renderWallStyle(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    Path quad,
    bool isNorth,
  ) {
    final styleOpt = InteriorWallStyles.all.firstWhere(
      (o) => o.id == style,
      orElse: () => InteriorWallStyles.all.first,
    );

    if (styleOpt.color != null && style != 'modern_white') {
      _renderPlasterColorWall(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, quad, isNorth, styleOpt.color!);
      return;
    }

    switch (style) {
      case 'bathroom_glass':
        _renderGlassScreen(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, quad, isNorth);
        break;
      case 'rustic_brick':
        _renderBrickWall(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, quad, isNorth);
        break;
      case 'modern_white':
        _renderModernWhite(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, quad, isNorth);
        break;
      case 'japanese_shoji':
        _renderShoji(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, quad, isNorth);
        break;
      case 'doorway_frame':
        _renderDoorwayFrame(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, isNorth);
        break;
      case 'wood_slats':
      default:
        if (hasDoorway) {
          _renderDoorwayFrame(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, isNorth);
        } else {
          _renderWoodSlats(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, quad, isNorth);
        }
        break;
    }
  }

  void _renderPlasterColorWall(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    Path quad,
    bool isNorth,
    Color color,
  ) {
    if (hasDoorway) {
      _renderDoorwayFrame(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, isNorth);
      return;
    }

    final capDx = isNorth ? -3.0 : 3.0;
    final capDy = -1.5;

    // Top Cap with soft highlight
    final topCap = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2 + capDx, tY2 + capDy)
      ..lineTo(tX1 + capDx, tY1 + capDy)
      ..close();

    final capColor = Color.lerp(color, Colors.white, 0.18) ?? color;
    canvas.drawPath(topCap, Paint()..color = capColor);
    canvas.drawPath(
      topCap,
      Paint()
        ..color = const Color(0xFF37474F).withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Wall Face (North side is brightly lit, West side has subtle ambient shading)
    final faceColor = isNorth ? color : (Color.lerp(color, Colors.black, 0.08) ?? color);
    final sprite = plasterSprite;
    if (sprite != null) {
      // Texture the face with the shared plaster sprite, tinted to the style's color —
      // same technique the room's own perimeter walls use for their solid-color wallpapers.
      canvas.save();
      canvas.clipPath(quad);
      final matrix = vmath.Matrix4.identity()
        ..translate(bX1, bY1 - wallHeight)
        ..setEntry(0, 0, (bX2 - bX1) / halfTileW)
        ..setEntry(1, 0, (bY2 - bY1) / halfTileW);
      canvas.transform(matrix.storage);
      sprite.render(
        canvas,
        position: Vector2.zero(),
        size: Vector2(halfTileW, wallHeight),
        overridePaint: Paint()..colorFilter = ColorFilter.mode(faceColor, BlendMode.modulate),
      );
      canvas.restore();
    } else {
      canvas.drawPath(quad, Paint()..color = faceColor);
    }

    // Bottom Baseboard Trim (matching the room's wooden baseboard)
    final baseTrim = Path()
      ..moveTo(bX1, bY1 - 4)
      ..lineTo(bX2, bY2 - 4)
      ..lineTo(bX2, bY2)
      ..lineTo(bX1, bY1)
      ..close();
    canvas.drawPath(baseTrim, Paint()..color = const Color(0xFF5D4037));
    canvas.drawPath(
      baseTrim,
      Paint()
        ..color = const Color(0xFF3E2723)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Outer border — a soft edge derived from the wall color itself, instead of a
    // fixed dark stroke, so it stays readable without standing out on light walls.
    canvas.drawPath(
      quad,
      Paint()
        ..color = (Color.lerp(color, Colors.black, 0.3) ?? color).withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _renderWoodSlats(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    Path quad,
    bool isNorth,
  ) {
    final capDx = isNorth ? -3.0 : 3.0;
    final capDy = -1.5;

    // 3D Top Cap
    final topCap = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2 + capDx, tY2 + capDy)
      ..lineTo(tX1 + capDx, tY1 + capDy)
      ..close();
    canvas.drawPath(topCap, Paint()..color = const Color(0xFF8D6E63));
    canvas.drawPath(topCap, Paint()..color = const Color(0xFF271711)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // Front Wall Face
    final baseColor = isNorth ? const Color(0xFF6D4C41) : const Color(0xFF5D4037);
    final fillPaint = Paint()..color = baseColor;
    canvas.drawPath(quad, fillPaint);

    // Vertical plank lines (5 planks across the 32px span)
    final linePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      final t = i / 5.0;
      final bx = bX1 + (bX2 - bX1) * t;
      final by = bY1 + (bY2 - bY1) * t;
      final tx = tX1 + (tX2 - tX1) * t;
      final ty = tY1 + (tY2 - tY1) * t;
      canvas.drawLine(Offset(bx, by), Offset(tx, ty), linePaint);
    }

    // Top beam / trim
    final topBeam = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2, tY2 + 5)
      ..lineTo(tX1, tY1 + 5)
      ..close();
    final topPaint = Paint()..color = isNorth ? const Color(0xFF8D6E63) : const Color(0xFF795548);
    canvas.drawPath(topBeam, topPaint);

    // Baseboard trim
    final baseTrim = Path()
      ..moveTo(bX1, bY1 - 4)
      ..lineTo(bX2, bY2 - 4)
      ..lineTo(bX2, bY2)
      ..lineTo(bX1, bY1)
      ..close();
    final baseTrimPaint = Paint()..color = const Color(0xFF3E2723);
    canvas.drawPath(baseTrim, baseTrimPaint);

    // Outer border
    final borderPaint = Paint()
      ..color = const Color(0xFF271711)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(quad, borderPaint);
  }

  void _renderGlassScreen(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    Path quad,
    bool isNorth,
  ) {
    if (hasDoorway) {
      _renderDoorwayFrame(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, isNorth);
      return;
    }

    final capDx = isNorth ? -2.0 : 2.0;
    final capDy = -1.0;

    // Top Chrome Cap
    final topCap = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2 + capDx, tY2 + capDy)
      ..lineTo(tX1 + capDx, tY1 + capDy)
      ..close();
    canvas.drawPath(topCap, Paint()..color = const Color(0xFFCFD8DC));

    // Translucent glass fill
    final glassFill = Paint()..color = const Color(0x6680DEEA);
    canvas.drawPath(quad, glassFill);

    // Glass sheen / reflection stripe
    final sheenPath = Path()
      ..moveTo(bX1 + (bX2 - bX1) * 0.25, bY1 + (bY2 - bY1) * 0.25)
      ..lineTo(tX1 + (tX2 - tX1) * 0.45, tY1 + (tY2 - tY1) * 0.45)
      ..lineTo(tX1 + (tX2 - tX1) * 0.55, tY1 + (tY2 - tY1) * 0.55)
      ..lineTo(bX1 + (bX2 - bX1) * 0.35, bY1 + (bY2 - bY1) * 0.35)
      ..close();
    final sheenPaint = Paint()..color = const Color(0x55FFFFFF);
    canvas.drawPath(sheenPath, sheenPaint);

    // Metallic chrome frame
    final framePaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(quad, framePaint);

    // Metal post bottom anchor
    final postPaint = Paint()
      ..color = const Color(0xFF78909C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(bX1, bY1), Offset(tX1, tY1), postPaint);
    canvas.drawLine(Offset(bX2, bY2), Offset(tX2, tY2), postPaint);
  }

  void _renderBrickWall(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    Path quad,
    bool isNorth,
  ) {
    if (hasDoorway) {
      _renderDoorwayFrame(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, isNorth);
      return;
    }

    final capDx = isNorth ? -3.0 : 3.0;
    final capDy = -1.5;

    // Top Stone Cap
    final topCap = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2 + capDx, tY2 + capDy)
      ..lineTo(tX1 + capDx, tY1 + capDy)
      ..close();
    canvas.drawPath(topCap, Paint()..color = const Color(0xFFECEFF1));
    canvas.drawPath(topCap, Paint()..color = const Color(0xFF37474F)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    final baseColor = isNorth ? const Color(0xFFB74B38) : const Color(0xFFA03F2E);
    canvas.drawPath(quad, Paint()..color = baseColor);

    // Mortar horizontal lines (6 rows)
    final mortarPaint = Paint()
      ..color = const Color(0xFFD7CCC8).withOpacity(0.7)
      ..strokeWidth = 1.0;

    for (int r = 1; r <= 5; r++) {
      final t = r / 6.0;
      final dy = -wallHeight * t;
      canvas.drawLine(Offset(bX1, bY1 + dy), Offset(bX2, bY2 + dy), mortarPaint);
    }

    // Outer border
    canvas.drawPath(
      quad,
      Paint()
        ..color = const Color(0xFF3E1B15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _renderModernWhite(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    Path quad,
    bool isNorth,
  ) {
    if (hasDoorway) {
      _renderDoorwayFrame(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, isNorth);
      return;
    }

    final capDx = isNorth ? -3.0 : 3.0;
    final capDy = -1.5;

    // Top White Cap
    final topCap = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2 + capDx, tY2 + capDy)
      ..lineTo(tX1 + capDx, tY1 + capDy)
      ..close();
    canvas.drawPath(topCap, Paint()..color = Colors.white);
    canvas.drawPath(topCap, Paint()..color = const Color(0xFF90A4AE)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    final baseColor = isNorth ? const Color(0xFFECEFF1) : const Color(0xFFCFD8DC);
    canvas.drawPath(quad, Paint()..color = baseColor);

    // Subtle vertical seam
    final midBX = (bX1 + bX2) / 2.0;
    final midBY = (bY1 + bY2) / 2.0;
    final midTX = (tX1 + tX2) / 2.0;
    final midTY = (tY1 + tY2) / 2.0;
    canvas.drawLine(
      Offset(midBX, midBY),
      Offset(midTX, midTY),
      Paint()
        ..color = const Color(0xFF90A4AE)
        ..strokeWidth = 1.0,
    );

    // Black metal base trim
    final baseTrim = Path()
      ..moveTo(bX1, bY1 - 3)
      ..lineTo(bX2, bY2 - 3)
      ..lineTo(bX2, bY2)
      ..lineTo(bX1, bY1)
      ..close();
    canvas.drawPath(baseTrim, Paint()..color = const Color(0xFF263238));

    // Outer border
    canvas.drawPath(
      quad,
      Paint()
        ..color = const Color(0xFF37474F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _renderShoji(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    Path quad,
    bool isNorth,
  ) {
    if (hasDoorway) {
      _renderDoorwayFrame(canvas, bX1, bY1, bX2, bY2, tX1, tY1, tX2, tY2, isNorth);
      return;
    }

    final capDx = isNorth ? -3.0 : 3.0;
    final capDy = -1.5;

    // Dark Wood Top Cap
    final topCap = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2 + capDx, tY2 + capDy)
      ..lineTo(tX1 + capDx, tY1 + capDy)
      ..close();
    canvas.drawPath(topCap, Paint()..color = const Color(0xFF4E342E));

    // Rice paper fill
    canvas.drawPath(quad, Paint()..color = const Color(0xFFFFF9E6));

    final latticePaint = Paint()
      ..color = const Color(0xFF3E2723)
      ..strokeWidth = 1.0;

    // Horizontal bars
    for (int r = 1; r <= 4; r++) {
      final t = r / 5.0;
      final dy = -wallHeight * t;
      canvas.drawLine(Offset(bX1, bY1 + dy), Offset(bX2, bY2 + dy), latticePaint);
    }

    // Vertical bars
    for (int c = 1; c <= 2; c++) {
      final t = c / 3.0;
      final bx = bX1 + (bX2 - bX1) * t;
      final by = bY1 + (bY2 - bY1) * t;
      final tx = tX1 + (tX2 - tX1) * t;
      final ty = tY1 + (tY2 - tY1) * t;
      canvas.drawLine(Offset(bx, by), Offset(tx, ty), latticePaint);
    }

    // Frame border
    canvas.drawPath(
      quad,
      Paint()
        ..color = const Color(0xFF271711)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  void _renderDoorwayFrame(
    Canvas canvas,
    double bX1,
    double bY1,
    double bX2,
    double bY2,
    double tX1,
    double tY1,
    double tX2,
    double tY2,
    bool isNorth,
  ) {
    final capDx = isNorth ? -3.0 : 3.0;
    final capDy = -1.5;

    // Top Beam 3D Cap
    final topCap = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2 + capDx, tY2 + capDy)
      ..lineTo(tX1 + capDx, tY1 + capDy)
      ..close();
    canvas.drawPath(topCap, Paint()..color = const Color(0xFF795548));

    // Left post
    const postWidthFraction = 0.18;
    final post1BX = bX1 + (bX2 - bX1) * postWidthFraction;
    final post1BY = bY1 + (bY2 - bY1) * postWidthFraction;
    final post1TX = tX1 + (tX2 - tX1) * postWidthFraction;
    final post1TY = tY1 + (tY2 - tY1) * postWidthFraction;

    final leftPost = Path()
      ..moveTo(bX1, bY1)
      ..lineTo(tX1, tY1)
      ..lineTo(post1TX, post1TY)
      ..lineTo(post1BX, post1BY)
      ..close();

    // Right post
    final post2BX = bX2 - (bX2 - bX1) * postWidthFraction;
    final post2BY = bY2 - (bY2 - bY1) * postWidthFraction;
    final post2TX = tX2 - (tX2 - tX1) * postWidthFraction;
    final post2TY = tY2 - (tY2 - tY1) * postWidthFraction;

    final rightPost = Path()
      ..moveTo(post2BX, post2BY)
      ..lineTo(post2TX, post2TY)
      ..lineTo(tX2, tY2)
      ..lineTo(bX2, bY2)
      ..close();

    // Top header beam
    const headerHeight = 12.0;
    final topBeam = Path()
      ..moveTo(tX1, tY1)
      ..lineTo(tX2, tY2)
      ..lineTo(tX2, tY2 + headerHeight)
      ..lineTo(tX1, tY1 + headerHeight)
      ..close();

    final woodPaint = Paint()..color = const Color(0xFF5D4037);
    final borderPaint = Paint()
      ..color = const Color(0xFF271711)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(leftPost, woodPaint);
    canvas.drawPath(leftPost, borderPaint);

    canvas.drawPath(rightPost, woodPaint);
    canvas.drawPath(rightPost, borderPaint);

    canvas.drawPath(topBeam, woodPaint);
    canvas.drawPath(topBeam, borderPaint);
  }
}
