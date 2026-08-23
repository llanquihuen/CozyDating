import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../core/models/furniture_item.dart';
import '../../../core/services/furniture_catalog_service.dart';
import '../utils/isometric_coords.dart';
import '../utils/sprite_alpha_cache.dart';

enum FurnitureType { wardrobe, portal, bed, plant, table, carpet, custom }

class IsometricFurnitureComponent extends PositionComponent {
  String id;
  String typeName;
  int gridX;
  int gridY;
  int gridWidth;
  int gridHeight;
  int rotation;
  String footprint;
  String? parentId;
  double parentSurfaceHeight;
  String wallHeightLevel; // 'mid' or 'high'
  String resolution;
  final FurnitureType type;
  final VoidCallback? onInteract;
  final String? baseAssetPath;
  final Map<int, Sprite> rotationSprites;
  Sprite? sprite;

  bool isSelected = false;
  bool isBeingDragged = false;
  bool isDirectlyDragged = false;
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

  bool get isWardrobe => type == FurnitureType.wardrobe || id.contains('wardrobe') || typeName.contains('wardrobe');
  bool get isPortal => type == FurnitureType.portal || id.contains('portal') || typeName.contains('portal');
  bool get isSurfaceItem => footprint == 'surface' || id == 'table_lamp' || id == 'coffee_mug' || id == 'open_book' || id == 'cooking_pot' || id == 'cutting_board' || id == 'soap_bottles' || id == 'plush_teddy' || typeName == 'table_lamp' || typeName == 'coffee_mug' || typeName == 'open_book' || typeName == 'cooking_pot' || typeName == 'cutting_board' || typeName == 'soap_bottles' || typeName == 'plush_teddy';
  bool get isWallNorth => footprint == 'wall_n' || id.endsWith('_wall_n') || id.endsWith('_n') || typeName.endsWith('_wall_n') || typeName.endsWith('_n');
  bool get isWallWest => footprint == 'wall_w' || id.endsWith('_wall_w') || id.endsWith('_w') || typeName.endsWith('_wall_w') || typeName.endsWith('_w');
  bool get isWallItem => isWallNorth || isWallWest;
  bool get is32x64 => resolution == '32x64';

  IsometricFurnitureComponent({
    String? id,
    String? typeName,
    required this.gridX,
    required this.gridY,
    this.gridWidth = 1,
    this.gridHeight = 1,
    this.rotation = 0,
    this.footprint = '1x1',
    this.parentId,
    this.parentSurfaceHeight = 0.0,
    this.wallHeightLevel = 'high',
    this.resolution = '64x128',
    this.type = FurnitureType.custom,
    this.onInteract,
    this.baseAssetPath,
    this.sprite,
    Map<int, Sprite>? rotationSprites,
  })  : id = id ?? (type == FurnitureType.portal ? 'portal' : (type == FurnitureType.wardrobe ? 'closet' : 'furniture_${gridX}_$gridY')),
        typeName = typeName ?? id ?? (type == FurnitureType.portal ? 'portal' : (type == FurnitureType.wardrobe ? 'closet' : 'furniture_${gridX}_$gridY')),
        rotationSprites = rotationSprites ?? {} {
    if (sprite != null && !this.rotationSprites.containsKey(0)) {
      this.rotationSprites[0] = sprite!;
    }
    updateGridPosition(gridX, gridY, parentId: parentId, parentSurfaceHeight: parentSurfaceHeight, wallHeightLevel: wallHeightLevel);
  }

  /// Updates the component's position and Z-order based on grid coordinates and surface/wall placement
  void updateGridPosition(
    int gx,
    int gy, {
    String? parentId,
    double? parentSurfaceHeight,
    String? wallHeightLevel,
    int? parentFurthestX,
    int? parentFurthestY,
  }) {
    gridX = gx;
    gridY = gy;
    if (parentId != null) this.parentId = parentId;
    if (parentSurfaceHeight != null) this.parentSurfaceHeight = parentSurfaceHeight;
    if (wallHeightLevel != null) this.wallHeightLevel = wallHeightLevel;

    position = IsometricCoords.gridToScreen(gx.toDouble(), gy.toDouble());
    
    // Z-order based on footprint and furthest tile occupied (surface items get layer 2)
    final layer = (type == FurnitureType.carpet ? -1 : (isSurfaceItem ? 2 : 1));
    final targetX = (isSurfaceItem && parentFurthestX != null) ? parentFurthestX : (gx + gridWidth - 1);
    final targetY = (isSurfaceItem && parentFurthestY != null) ? parentFurthestY : (gy + gridHeight - 1);
    priority = IsometricCoords.getZOrder(
      targetX,
      targetY,
      layer: layer,
      footprint: footprint,
    );
  }

  /// Changes the wall height level between 'mid' and 'high'
  void toggleWallHeightLevel() {
    wallHeightLevel = (wallHeightLevel == 'mid') ? 'high' : 'mid';
    updateGridPosition(gridX, gridY);
  }

  /// Rotates the furniture clockwise by 90 degrees (rotations 0, 1, 2, 3)
  void rotateClockwise() {
    rotation = (rotation + 1) % 4;

    // Swap footprint dimensions if non-square (e.g. 1x2 <-> 2x1)
    if (footprint == '1x2') {
      footprint = '2x1';
      final tmp = gridWidth;
      gridWidth = gridHeight;
      gridHeight = tmp;
    } else if (footprint == '2x1') {
      footprint = '1x2';
      final tmp = gridWidth;
      gridWidth = gridHeight;
      gridHeight = tmp;
    }

    // Switch to rotated sprite if loaded
    if (rotationSprites.containsKey(rotation)) {
      sprite = rotationSprites[rotation];
    }

    updateGridPosition(gridX, gridY);
  }

  /// Calculates the exact isometric sprite anchor offset based on footprint (1x1, 1x2, 2x1, 2x2, surface, wall_n, wall_w)
  Vector2 get spriteOffset {
    final rSize = renderSize;

    final catalogItem = FurnitureCatalogService.getItem(typeName) ?? FurnitureCatalogService.getItem(id);
    final rotMeta = catalogItem?.rotations[rotation];

    if (isSurfaceItem) {
      double effSurfaceH = parentSurfaceHeight;
      List<int> parentSurfOffset = const [0, 0];

      if (parentId != null) {
        final parentComp = (parent as World?)?.children.whereType<IsometricFurnitureComponent>().where((f) => f.id == parentId).firstOrNull;
        if (parentComp != null) {
          final pMeta = FurnitureCatalogService.getItem(parentComp.typeName) ?? FurnitureCatalogService.getItem(parentComp.id);
          if (pMeta != null) {
            final parentRotMeta = pMeta.rotations[parentComp.rotation];
            if (parentRotMeta != null) {
              if (parentRotMeta.surfaceHeight > 0) {
                effSurfaceH = parentRotMeta.surfaceHeight.toDouble();
              } else if (pMeta.effectiveSurfaceHeight > 0) {
                effSurfaceH = pMeta.effectiveSurfaceHeight.toDouble();
              }
              if (parentRotMeta.surfaceOffset.length >= 2) {
                parentSurfOffset = parentRotMeta.surfaceOffset;
              }
            } else {
              if (pMeta.effectiveSurfaceHeight > 0) {
                effSurfaceH = pMeta.effectiveSurfaceHeight.toDouble();
              }
              if (pMeta.surfaceOffset.length >= 2) {
                parentSurfOffset = pMeta.surfaceOffset;
              }
            }
          }
        }
      }
      if (effSurfaceH <= 0) effSurfaceH = 14.0;
      
      // Manual micro-adjustment per surface item from JSON:
      double manualAdjX = 0.0;
      double manualAdjY = 0.0;

      final effSurfaceHeight = rotMeta?.surfaceHeight ?? catalogItem?.surfaceHeight ?? 0;
      if (effSurfaceHeight != 0) {
        manualAdjY -= effSurfaceHeight.toDouble();
      }

      final offsetList = (rotMeta != null && rotMeta.spriteOffset.length >= 2)
          ? rotMeta.spriteOffset
          : (catalogItem?.spriteOffset ?? const [-32, -48]);

      if (offsetList.length >= 2) {
        manualAdjX += (offsetList[0] + 32.0);
        manualAdjY += (offsetList[1] + 48.0);
      }

      final parentDx = parentSurfOffset.isNotEmpty ? parentSurfOffset[0].toDouble() : 0.0;
      final parentDy = parentSurfOffset.length >= 2 ? parentSurfOffset[1].toDouble() : 0.0;

      return Vector2(
        (-rSize.x / 2.0) + manualAdjX + parentDx,
        (IsometricCoords.tileHeight / 4.0) - rSize.y - effSurfaceH + manualAdjY + parentDy,
      );
    } else if (isWallNorth) {
      final wallYOffset = (wallHeightLevel == 'high' ? -48.0 : -32.0);
      return Vector2((-rSize.x / 2.0) + 16.0, wallYOffset - rSize.y / 2.0);
    } else if (isWallWest) {
      final wallYOffset = (wallHeightLevel == 'high' ? -48.0 : -32.0);
      return Vector2((-rSize.x / 2.0) - 16.0, wallYOffset - rSize.y / 2.0);
    }

    // 1. Check catalog item / rotation metadata for floor items
    if (catalogItem != null) {
      if (rotMeta != null && rotMeta.spriteOffset.length >= 2) {
        double offX = rotMeta.spriteOffset[0].toDouble();
        double offY = rotMeta.spriteOffset[1].toDouble();
        return Vector2(offX, offY);
      }
    }

    // 2. Exact fallback calculation
    return IsometricCoords.getFurnitureSpriteOffset(
      gridWidth: gridWidth,
      gridHeight: gridHeight,
      spriteWidth: rSize.x,
      spriteHeight: rSize.y,
      footprint: footprint,
      surfaceHeight: parentSurfaceHeight,
      wallHeightLevel: wallHeightLevel,
      rotation: rotation,
    );
  }

  Vector2 get renderSize {
    if (sprite == null) return Vector2(32, 32);
    if (is32x64) {
      // Retro Mode: 64x128 assets at 1.0x scale (fits 64x32 tile with pixel art)
      return sprite!.srcSize * 1.0;
    }
    // HD Mode: 128x256 assets rendered at 0.5x scale (half size, crisp double-density pixels fitting 64x32 tiles)
    return sprite!.srcSize * 0.5;
  }

  /// World bounding rectangle of the drawn sprite (useful for direct hit-testing in walls and surface)
  Rect get worldVisualBoundingBox {
    final off = spriteOffset;
    final size = renderSize;
    return Rect.fromLTWH(
      position.x + off.x + dragVisualOffset.x,
      position.y + off.y + dragVisualOffset.y,
      size.x,
      size.y,
    );
  }

  /// World rectangle of the single wall panel this item occupies.
  ///
  /// The sprite canvas is a full tile wide (64px) but an isometric wall panel is only
  /// (tileWidth / 2 = 32px) wide horizontally, and the artwork is drawn inside that column.
  /// Hit-testing the whole canvas would let a tap grab an item almost two panels away.
  Rect get wallPanelBoundingBox {
    final panelWidth = IsometricCoords.tileWidth / 2.0;
    final off = spriteOffset;
    final left = isWallNorth ? position.x : position.x - panelWidth;
    return Rect.fromLTWH(
      left + dragVisualOffset.x,
      position.y + off.y + dragVisualOffset.y,
      panelWidth,
      renderSize.y,
    );
  }

  /// Checks if a world touch/click point directly hits this component's actual drawn
  /// pixels — same precision the interior walls get from testing their real parallelogram
  /// shape, just done here by sampling the sprite's own alpha channel instead of a polygon,
  /// since furniture silhouettes (a chair, a lamp, a bookshelf) aren't a single clean shape.
  bool hitTestWorld(Vector2 worldPos) {
    if (isWallItem) {
      // Wall items must strictly be selected on the wall (above the floor baseline), NOT on
      // their floor baldosa — unrelated to pixel precision, just where "on the wall" ends.
      final floorBaseY = isWallNorth
          ? position.y - (IsometricCoords.tileHeight / 2) + 0.5 * (worldPos.x - position.x)
          : position.y - (IsometricCoords.tileHeight / 2) - 0.5 * (worldPos.x - position.x);
      if (worldPos.y > floorBaseY) {
        return false; // Touch is on the floor baldosa below the wall
      }
    }

    final off = spriteOffset;
    final size = renderSize;
    // Point within the sprite's own locally-drawn rect: (0,0) at its top-left corner,
    // `size` at its bottom-right — exactly what render() passes as position:/size: to
    // sprite.render(), so this is the exact inverse of that mapping.
    final local = Vector2(
      worldPos.x - position.x - dragVisualOffset.x - off.x,
      worldPos.y - position.y - dragVisualOffset.y - off.y,
    );

    final s = sprite;
    if (s != null) {
      final opaque = SpriteAlphaCache.isOpaqueAt(s, local, size);
      if (opaque != null) return opaque;
    }

    // Fallback for the brief window before this sprite's pixel data finishes decoding (or
    // if there's no sprite at all, e.g. a programmatically-drawn placeholder): a loosely
    // inflated box around the drawn area, so nothing is untappable while warming up.
    final fallbackBox = Rect.fromLTWH(0, 0, size.x, size.y).inflate(4.0);
    return fallbackBox.contains(Offset(local.x, local.y));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (isPortal) {
      _portalAnimTimer += dt;
    }
    if (isBeingDragged) {
      _dragFloatTimer += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final double groundY = IsometricCoords.tileHeight / 2;

    canvas.save();
    if (isBeingDragged) {
      if (isSurfaceItem && parentId != null && isDirectlyDragged) {
        // Directly dragging the surface item: magnetically snap directly onto destination furniture surface (no floating in the air)
        canvas.translate(dragVisualOffset.x, dragVisualOffset.y);
      } else {
        // Elevate vertically when dragged (parent furniture OR attached surface child moving along with parent)
        final floatY = -14.0 + sin(_dragFloatTimer * 6.0) * 2.0;
        canvas.translate(dragVisualOffset.x, dragVisualOffset.y + floatY);
      }
    }

    if (sprite != null) {
      sprite!.render(
        canvas,
        position: spriteOffset,
        size: renderSize,
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
        case FurnitureType.custom:
          break;
      }
      canvas.restore();
    }

    if (isWardrobe && !isBeingDragged) {
      _renderWardrobeLabel(canvas);
    }

    // Render selection highlights in front of sprite/furniture
    if (isSelected && !isBeingDragged) {
      _renderSelectionHighlights(canvas);
    }

    canvas.restore(); // Restore drag translation
  }

  void _renderWardrobeLabel(Canvas canvas) {
    const text = '🚪 Armario';
    final textSpan = const TextSpan(
      text: text,
      style: TextStyle(
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
    if (isBeingDragged) return; // Origin highlight is rendered by _DragHighlightLayer while dragging

    final highlightColor = isSurfaceItem
        ? const Color(0xFFFFD54F)
        : (isWallItem ? const Color(0xFFA78BFA) : const Color(0xFF00E5FF));

    final borderPaint = Paint()
      ..color = highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    if (isWallItem) {
      // Orientation comes from the footprint, not from gridY == 0: the corner tile (0,0) sits on
      // both walls, so the coordinate alone cannot tell a north panel from a west one.
      final isOriginalNorth = isWallNorth;
      final off = IsometricCoords.getFurnitureSpriteOffset(
        gridWidth: gridWidth,
        gridHeight: gridHeight,
        spriteWidth: renderSize.x,
        spriteHeight: renderSize.y,
        footprint: isOriginalNorth ? 'wall_n' : 'wall_w',
        wallHeightLevel: wallHeightLevel,
      );
      final size = renderSize;
      final cx = off.x + size.x / 2.0;
      final cy = off.y + size.y / 2.0;
      const w = 34.0;
      const h = 32.0;
      final slope = isOriginalNorth ? 0.5 : -0.5;

      final path = Path()
        ..moveTo(cx - w / 2.0, cy - h / 2.0 - (w / 2.0) * slope)
        ..lineTo(cx + w / 2.0, cy - h / 2.0 + (w / 2.0) * slope)
        ..lineTo(cx + w / 2.0, cy + h / 2.0 + (w / 2.0) * slope)
        ..lineTo(cx - w / 2.0, cy + h / 2.0 - (w / 2.0) * slope)
        ..close();

      canvas.drawPath(path, borderPaint);
      return;
    }

    if (isSurfaceItem) {
      // Draw compact, elegant glowing base ring beneath tabletop item
      final off = spriteOffset;
      final size = renderSize;
      final cx = off.x + size.x / 2.0;
      final cy = off.y + (size.y * 0.78);

      final glowRect = Rect.fromCenter(center: Offset(cx, cy), width: 22, height: 12);
      final fillGlow = Paint()
        ..color = const Color(0x35FFD54F)
        ..style = PaintingStyle.fill;
      final borderGlow = Paint()
        ..color = const Color(0xFFFFD54F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

      canvas.drawOval(glowRect, fillGlow);
      canvas.drawOval(glowRect, borderGlow);
      return;
    }

    for (int i = 0; i < gridWidth; i++) {
      for (int j = 0; j < gridHeight; j++) {
        final relPos = IsometricCoords.gridToScreen(i.toDouble(), j.toDouble(), originX: 0, originY: 0);
        
        final path = Path()
          ..moveTo(relPos.x, relPos.y - (IsometricCoords.tileHeight / 2))
          ..lineTo(relPos.x + (IsometricCoords.tileWidth / 2), relPos.y)
          ..lineTo(relPos.x, relPos.y + (IsometricCoords.tileHeight / 2))
          ..lineTo(relPos.x - (IsometricCoords.tileWidth / 2), relPos.y)
          ..close();

        canvas.drawPath(path, borderPaint);
      }
    }
  }

  // --- Fallback Vector Renderers ---
  void _renderWardrobe(Canvas canvas) {
    const w = 24.0;
    const h = 58.0;
    final r = Rect.fromLTWH(-w / 2, -h, w, h);
    canvas.drawRect(r, _woodDarkPaint);
    canvas.drawRect(Rect.fromLTWH(-w / 2 + 2, -h + 2, w - 4, h - 4), _woodMidPaint);
    final mirrorR = Rect.fromLTWH(-w / 2 + 4, -h + 8, w - 8, h - 16);
    canvas.drawRect(mirrorR, _mirrorGlassPaint);
    canvas.drawCircle(Offset(w / 2 - 5, -h / 2), 1.5, _goldPaint);
  }

  void _renderPortal(Canvas canvas) {
    final t = _portalAnimTimer * 3.0;
    final radius = 22.0 + sin(t) * 2.0;
    final glowPaint = Paint()
      ..color = const Color(0xFF673AB7).withOpacity(0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(const Offset(0, -16), radius + 4, glowPaint);

    final portalPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFE040FB),
          const Color(0xFF7C4DFF),
          const Color(0xFF180E29).withOpacity(0.8),
        ],
      ).createShader(Rect.fromCircle(center: const Offset(0, -16), radius: radius));
    canvas.drawCircle(const Offset(0, -16), radius, portalPaint);
  }

  void _renderBed(Canvas canvas) {
    const w = 32.0;
    const h = 48.0;
    final r = Rect.fromLTWH(-w / 2, -h, w, h);
    canvas.drawRect(r, _woodDarkPaint);
    canvas.drawRect(Rect.fromLTWH(-w / 2 + 2, -h + 12, w - 4, h - 14), _bedBlanketPaint);
    canvas.drawRect(Rect.fromLTWH(-w / 2 + 4, -h + 4, w - 8, 8), _bedPillowPaint);
  }

  void _renderPlant(Canvas canvas) {
    const potW = 16.0;
    const potH = 14.0;
    final potR = Rect.fromLTWH(-potW / 2, -potH, potW, potH);
    canvas.drawRect(potR, _plantPotPaint);
    canvas.drawCircle(const Offset(0, -potH - 8), 10, _plantLeafPaint);
    canvas.drawCircle(const Offset(-6, -potH - 12), 7, _plantLeafPaint);
    canvas.drawCircle(const Offset(6, -potH - 12), 7, _plantLeafPaint);
  }

  void _renderTable(Canvas canvas) {
    const w = 26.0;
    const h = 18.0;
    final topR = Rect.fromLTWH(-w / 2, -h - 4, w, 6);
    canvas.drawRect(topR, _woodLightPaint);
    canvas.drawRect(Rect.fromLTWH(-w / 2 + 2, -h + 2, 3, h - 2), _woodDarkPaint);
    canvas.drawRect(Rect.fromLTWH(w / 2 - 5, -h + 2, 3, h - 2), _woodDarkPaint);
    canvas.drawCircle(const Offset(0, -h - 6), 2, _candleFlamePaint);
  }
}
