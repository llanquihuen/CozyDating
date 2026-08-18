import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../utils/isometric_coords.dart';

enum FurnitureType { wardrobe, portal, bed, plant, table, carpet }

class IsometricFurnitureComponent extends PositionComponent {
  int gridX;
  int gridY;
  int gridWidth;
  int gridHeight;
  int rotation;
  final FurnitureType type;
  final VoidCallback? onInteract;
  final String? baseAssetPath;
  final Map<int, Sprite> rotationSprites;
  Sprite? sprite;

  bool isSelected = false;
  bool isBeingDragged = false;
  Vector2 dragVisualOffset = Vector2.zero();

  double _portalAnimTimer = 0.0;
  double _dragFloatTimer = 0.0;

  // Programmatic Paints (Fallbacks if no sprite provided)
  final Paint _woodDarkPaint = Paint()..color = const Color(0xFF4E342E);
  final Paint _woodMidPaint = Paint()..color = const Color(0xFF6D4C41);
  final Paint _woodLightPaint = Paint()..color = const Color(0xFF8D6E63);
  final Paint _goldPaint = Paint()..color = const Color(0xFFFFD54F);
  final Paint _mirrorGlassPaint = Paint()..color = const Color(0xFFB3E5FC).withOpacity(0.85);

  final Paint _bedBlanketPaint = Paint()..color = const Color(0xFFE53935);
  final Paint _bedPillowPaint = Paint()..color = const Color(0xFFFFF9C4);

  final Paint _plantPotPaint = Paint()..color = const Color(0xFFD84315);
  final Paint _plantLeafPaint = Paint()..color = const Color(0xFF2E7D32);

  final Paint _candleFlamePaint = Paint()..color = const Color(0xFFFFAB00);

  IsometricFurnitureComponent({
    required this.gridX,
    required this.gridY,
    this.gridWidth = 1,
    this.gridHeight = 1,
    this.rotation = 0,
    required this.type,
    this.onInteract,
    this.baseAssetPath,
    this.sprite,
    Map<int, Sprite>? rotationSprites,
  }) : rotationSprites = rotationSprites ?? {} {
    if (sprite != null && !this.rotationSprites.containsKey(0)) {
      this.rotationSprites[0] = sprite!;
    }
    updateGridPosition(gridX, gridY);
  }

  /// Updates the component's position and Z-order based on grid coordinates
  void updateGridPosition(int gx, int gy) {
    gridX = gx;
    gridY = gy;
    position = IsometricCoords.gridToScreen(gx.toDouble(), gy.toDouble());
    // Z-order based on the "furthest" tile the furniture occupies
    priority = IsometricCoords.getZOrder(gx + gridWidth - 1, gy + gridHeight - 1, layer: (type == FurnitureType.carpet ? -1 : 1));
  }

  /// Rotates the furniture clockwise by 90 degrees (rotations 0, 1, 2, 3)
  void rotateClockwise() {
    rotation = (rotation + 1) % 4;

    // Swap footprint dimensions if non-square (e.g. 1x2 <-> 2x1)
    final tmp = gridWidth;
    gridWidth = gridHeight;
    gridHeight = tmp;

    // Switch to rotated sprite if loaded
    if (rotationSprites.containsKey(rotation)) {
      sprite = rotationSprites[rotation];
    }

    updateGridPosition(gridX, gridY);
  }

  /// Calculates the exact isometric sprite anchor offset based on the footprint (1x1, 1x2, 2x1, 2x2)
  Vector2 get spriteOffset {
    if (sprite == null) return Vector2.zero();
    return IsometricCoords.getFurnitureSpriteOffset(
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      spriteWidth: sprite!.srcSize.x,
      spriteHeight: sprite!.srcSize.y,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (type == FurnitureType.portal) {
      _portalAnimTimer += dt;
    }
    if (isBeingDragged) {
      _dragFloatTimer += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    if (isSelected) {
      _renderSelectionHighlights(canvas);
    }
    
    super.render(canvas);

    // The visual floor of the tile is at the bottom vertex (y = 16)
    final double groundY = IsometricCoords.tileHeight / 2;

    canvas.save();
    if (isBeingDragged) {
      // Elevate vertically when dragged + subtle gentle hover bobbing
      final floatY = -14.0 + sin(_dragFloatTimer * 6.0) * 2.0;
      canvas.translate(dragVisualOffset.x, dragVisualOffset.y + floatY);
    }

    if (sprite != null) {
      sprite!.render(
        canvas,
        position: spriteOffset,
        size: sprite!.srcSize,
      );
    } else {
      canvas.save();
      canvas.translate(0, groundY);
      switch (type) {
        case FurnitureType.wardrobe:
          _renderWardrobe(canvas);
          break;
        case FurnitureType.portal:
          _renderPortal(canvas);
          break;
        case FurnitureType.bed:
          _renderBed(canvas);
          break;
        case FurnitureType.plant:
          _renderPlant(canvas);
          break;
        case FurnitureType.table:
          _renderTable(canvas);
          break;
        case FurnitureType.carpet:
          break;
      }
      canvas.restore();
    }

    if (type == FurnitureType.wardrobe && !isBeingDragged) {
      _renderWardrobeLabel(canvas);
    }

    canvas.restore(); // Restore drag translation
  }

  void _renderWardrobeLabel(Canvas canvas) {
    const text = '🚪 Armario';
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFFFFD54F),
        fontSize: 10.0,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final labelY = (sprite != null) ? spriteOffset.y - 20.0 : -80.0;
    final labelX = -textPainter.width / 2.0;

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(labelX - 8, labelY - 3, textPainter.width + 16, textPainter.height + 6),
      const Radius.circular(8),
    );

    final bgPaint = Paint()..color = const Color(0xFF1E1C24).withOpacity(0.90);
    final borderPaint = Paint()
      ..color = const Color(0xFFFFD54F).withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawRRect(bgRect, bgPaint);
    canvas.drawRRect(bgRect, borderPaint);
    textPainter.paint(canvas, Offset(labelX, labelY));
  }

  void _renderSelectionHighlights(Canvas canvas) {
    final borderPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (int i = 0; i < gridWidth; i++) {
      for (int j = 0; j < gridHeight; j++) {
        final relPos = IsometricCoords.gridToScreen(i.toDouble(), j.toDouble(), originX: 0, originY: 0);
        
        final path = Path()
          ..moveTo(relPos.x, relPos.y - IsometricCoords.tileHeight / 2)
          ..lineTo(relPos.x + IsometricCoords.tileWidth / 2, relPos.y)
          ..lineTo(relPos.x, relPos.y + IsometricCoords.tileHeight / 2)
          ..lineTo(relPos.x - IsometricCoords.tileWidth / 2, relPos.y)
          ..close();

        canvas.drawPath(path, borderPaint);
      }
    }
  }

  void _renderWardrobe(Canvas canvas) {
    final shadowPath = Path()
      ..moveTo(0, 0)
      ..lineTo(20, 10)
      ..lineTo(0, 20)
      ..lineTo(-20, 10)
      ..close();
    canvas.drawPath(shadowPath, Paint()..color = Colors.black.withOpacity(0.2));

    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -48, 32, 50), const Radius.circular(4)),
      _woodDarkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -46, 28, 46), const Radius.circular(3)),
      _woodMidPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-10, -42, 20, 36), const Radius.circular(2)),
      _mirrorGlassPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -51, 32, 5), const Radius.circular(2)),
      _goldPaint,
    );
    canvas.drawCircle(const Offset(6, -20), 2, _goldPaint);
  }

  void _renderPortal(Canvas canvas) {
    final double radiusX = 26.0;
    final double radiusY = 13.0;

    final glowPaint = Paint()
      ..color = const Color(0xFFFF6D00).withOpacity(0.35 + sin(_portalAnimTimer * 4) * 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radiusX * 2.4, height: radiusY * 2.4), glowPaint);

    final stoneRingPaint = Paint()
      ..color = const Color(0xFF37474F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radiusX * 2, height: radiusY * 2), stoneRingPaint);

    final voidPaint = Paint()..color = const Color(0xFF212121);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radiusX * 1.6, height: radiusY * 1.6), voidPaint);

    final double angle = _portalAnimTimer * 1.5;
    for (int i = 0; i < 4; i++) {
      final a = angle + (i * pi / 2);
      final rx = cos(a) * (radiusX * 0.75);
      final ry = sin(a) * (radiusY * 0.75);
      canvas.drawCircle(Offset(rx, ry), 2.5, Paint()..color = const Color(0xFFFFD54F));
    }
  }

  void _renderBed(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-18, -14, 36, 22), const Radius.circular(3)),
      _woodDarkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-16, -10, 32, 16), const Radius.circular(3)),
      _bedBlanketPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-14, -13, 14, 8), const Radius.circular(2)),
      _bedPillowPaint,
    );
  }

  void _renderPlant(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-6, -10, 12, 12), const Radius.circular(2)),
      _plantPotPaint,
    );
    canvas.drawCircle(const Offset(-4, -14), 6, _plantLeafPaint);
    canvas.drawCircle(const Offset(4, -15), 7, _plantLeafPaint);
    canvas.drawCircle(const Offset(0, -18), 8, _plantLeafPaint);
  }

  void _renderTable(Canvas canvas) {
    canvas.drawOval(const Rect.fromLTWH(-12, -14, 24, 14), _woodMidPaint);
    canvas.drawOval(const Rect.fromLTWH(-10, -13, 20, 12), _woodLightPaint);
    canvas.drawRect(const Rect.fromLTWH(-2, -18, 4, 6), Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(0, -21), 2.5, _candleFlamePaint);
  }
}
