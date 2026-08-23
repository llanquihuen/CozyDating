import 'dart:async' as async_lib;
import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import '../../../core/models/avatar_config.dart';
import '../../../core/models/furniture_item.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/furniture_catalog_service.dart';
import '../components/isometric_avatar_component.dart';
import '../components/isometric_furniture_component.dart';
import '../components/isometric_interior_wall_component.dart';
import '../utils/isometric_coords.dart';
import '../utils/isometric_pathfinder.dart';
import '../utils/sprite_alpha_cache.dart';

class CozyRoomGame extends FlameGame with DragCallbacks {
  AvatarConfig avatarConfig;
  RoomConfig roomConfig;
  final VoidCallback? onOpenWardrobe;
  final VoidCallback? onOpenMatchmaking;
  final ValueChanged<IsometricFurnitureComponent?>? onFurnitureSelected;
  final ValueChanged<IsometricInteriorWallComponent?>? onInteriorWallSelected;

  IsometricAvatarComponent? avatar;
  _IsometricRoomBackgroundComponent? _backgroundComponent;
  final Set<Point<int>> obstacles = {};
  final Set<String> blockedEdges = {};

  // Decorate Mode Flag
  bool isDecorateMode = false;
  IsometricFurnitureComponent? selectedFurniture;
  IsometricInteriorWallComponent? selectedInteriorWall;

  // Drag-and-Drop state for furniture
  IsometricFurnitureComponent? _draggedFurniture;
  List<IsometricFurnitureComponent> _attachedSurfaceItems = [];
  Point<int>? _originalGridPos;
  String? _originalParentId;
  double _originalSurfaceHeight = 0.0;
  String _originalWallId = '';
  Point<int>? _currentHoverGrid;
  bool _isValidDropLocation = true;
  Vector2? _dragStartWorldPos;

  // Drag-and-Drop state for interior walls
  IsometricInteriorWallComponent? _draggedInteriorWall;
  Point<int>? _originalWallGridPos;
  String? _originalWallOrientation;

  // A wall must be held (touched without much movement) for this long before it's
  // selected and armed for dragging — see onDragStart/onDragUpdate.
  static const Duration _wallGrabHoldDuration = Duration(milliseconds: 300);
  async_lib.Timer? _wallGrabTimer;
  IsometricInteriorWallComponent? _pendingWallGrab;

  // Same idea for furniture (floor, wall-mounted, and surface items alike), just a
  // shorter hold since these are grabbed/repositioned more often.
  static const Duration _furnitureGrabHoldDuration = Duration(milliseconds: 200);
  async_lib.Timer? _furnitureGrabTimer;
  IsometricFurnitureComponent? _pendingFurnitureGrab;

  // Floor Brush State (paint specific zones)
  String? activeFloorBrushId;
  bool _isFloorBrushDragging = false;

  // Camera Pan state
  bool _isPanningCamera = false;
  Vector2? _lastDragScreenPos;

  static const int gridSize = 8;

  CozyRoomGame({
    required this.avatarConfig,
    this.roomConfig = const RoomConfig(),
    this.onOpenWardrobe,
    this.onOpenMatchmaking,
    this.onFurnitureSelected,
    this.onInteriorWallSelected,
  });

  @override
  Color backgroundColor() => const Color(0xFF16141D);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await FurnitureCatalogService.initialize(forceReload: true);

    // 1. Add Isometric Room Floor & Walls inside world (priority: -100)
    final bg = _IsometricRoomBackgroundComponent(
      gridSize: gridSize,
      roomConfig: roomConfig,
      game: this,
    );
    _backgroundComponent = bg;
    await bg.loadTextures();
    world.add(bg);

    // 2. Add Drag Highlighting Layer inside world (priority: 50)
    world.add(_DragHighlightLayer(game: this));

    // 3. Load Placed Furniture from roomConfig
    await _loadFurnitureFromConfig(roomConfig);

    // 4. Adventure Portal (Fixed interactive portal)
    world.add(IsometricFurnitureComponent(
      id: 'portal',
      gridX: 6,
      gridY: 6,
      type: FurnitureType.portal,
      onInteract: onOpenMatchmaking,
      resolution: roomConfig.resolution,
    ));

    // 5. Register Initial Obstacles for all solid furniture
    _recalculateObstacles();

    // 6. Add Player Avatar inside world
    final av = IsometricAvatarComponent(
      gridX: 4.0,
      gridY: 4.0,
      config: avatarConfig.copyWith(spriteResolution: roomConfig.resolution),
      onReachedDestination: _handleDestinationReached,
    );
    if (isDecorateMode) {
      av.isVisible = false;
    }
    avatar = av;
    world.add(av);
  }

  void setDecorateMode(bool enabled) {
    isDecorateMode = enabled;
    if (enabled) {
      avatar?.isVisible = false;
      selectFurniture(null);
      selectInteriorWall(null);
    } else {
      activeFloorBrushId = null;
      _isFloorBrushDragging = false;
      _recalculateObstacles();
      Point<int> spawnTile = const Point(4, 4);
      bool found = false;

      const searchOrder = [
        Point(4, 4), Point(3, 4), Point(4, 3), Point(3, 3),
        Point(5, 4), Point(4, 5), Point(2, 4), Point(4, 2),
        Point(2, 2), Point(5, 5), Point(1, 4), Point(4, 1),
      ];
      for (final p in searchOrder) {
        if (!obstacles.contains(p)) {
          spawnTile = p;
          found = true;
          break;
        }
      }
      if (!found) {
        for (int x = 0; x < gridSize; x++) {
          for (int y = 0; y < gridSize; y++) {
            final p = Point(x, y);
            if (!obstacles.contains(p)) {
              spawnTile = p;
              found = true;
              break;
            }
          }
          if (found) break;
        }
      }

      avatar?.teleportTo(spawnTile.x.toDouble(), spawnTile.y.toDouble());
      avatar?.isVisible = true;
      selectFurniture(null);
      selectInteriorWall(null);
    }
  }

  Future<void> _loadFurnitureFromConfig(RoomConfig config) async {
    final existing = world.children.whereType<IsometricFurnitureComponent>().where((f) => f.type != FurnitureType.portal).toList();
    for (final f in existing) {
      f.removeFromParent();
    }

    final existingWalls = world.children.whereType<IsometricInteriorWallComponent>().toList();
    for (final w in existingWalls) {
      w.removeFromParent();
    }

    // Load Interior Walls
    for (final w in config.interiorWalls) {
      world.add(IsometricInteriorWallComponent(
        id: w.id.isNotEmpty ? w.id : 'wall_${DateTime.now().microsecondsSinceEpoch}',
        gridX: w.gridX,
        gridY: w.gridY,
        orientation: w.orientation,
        style: w.style,
        hasDoorway: w.hasDoorway,
        plasterSprite: _backgroundComponent?._wallpaperSprites['solid_plaster'],
      ));
    }

    // First pass: instantiate all base floor and wall furniture
    final created = <PlacedFurnitureConfig, IsometricFurnitureComponent>{};
    for (final item in config.furniture) {
      final catalogItem = FurnitureCatalogService.getItem(item.typeName) ?? FurnitureCatalogService.getItem(item.id);
      final isWall = catalogItem?.isWallItem == true || item.typeName.contains('wall') || item.typeName.endsWith('_n') || item.typeName.endsWith('_w') || item.id.endsWith('_n') || item.id.endsWith('_w');

      String targetTypeName = item.typeName;
      String footprint = catalogItem?.footprint ?? (item.gridWidth == 2 && item.gridHeight == 2 ? '2x2' : (item.gridWidth == 1 && item.gridHeight == 2 ? '1x2' : '1x1'));

      if (isWall) {
        final bool isNorth = item.typeName.endsWith('_n') || item.id.endsWith('_n') || (item.gridY == 0 && item.gridX > 0) || (!item.typeName.endsWith('_w') && !item.id.endsWith('_w') && item.gridX >= item.gridY);
        targetTypeName = FurnitureCatalogItem.getWallVariantFor(item.typeName, isNorth);
        footprint = isNorth ? 'wall_n' : 'wall_w';
      }

      final rotSprites = await _loadRotationSprites(targetTypeName);

      final comp = IsometricFurnitureComponent(
        id: item.id.isNotEmpty ? item.id : '${targetTypeName}_${created.length}',
        typeName: targetTypeName,
        gridX: item.gridX,
        gridY: item.gridY,
        gridWidth: item.gridWidth,
        gridHeight: item.gridHeight,
        rotation: item.rotation,
        footprint: footprint,
        parentId: item.parentId,
        wallHeightLevel: item.wallHeightLevel.isNotEmpty ? item.wallHeightLevel : 'high',
        resolution: config.resolution,
        type: targetTypeName.contains('wardrobe') ? FurnitureType.wardrobe : (targetTypeName.contains('bed') ? FurnitureType.bed : FurnitureType.custom),
        sprite: rotSprites[item.rotation] ?? rotSprites[0],
        rotationSprites: rotSprites,
        onInteract: targetTypeName.contains('wardrobe') ? onOpenWardrobe : null,
      );
      created[item] = comp;
      world.add(comp);
    }

    // Second pass: Link parent surface heights and furthest depth priority for surface items
    _recalculateSurfacePriorities();
  }

  void _recalculateSurfacePriorities() {
    final allComps = world.children.whereType<IsometricFurnitureComponent>().toList();
    for (final comp in allComps) {
      if (comp.isSurfaceItem) {
        final parent = _findSurfaceParentAt(comp.gridX, comp.gridY, exclude: comp);
        if (parent != null) {
          final pMeta = FurnitureCatalogService.getItem(parent.typeName) ?? FurnitureCatalogService.getItem(parent.id);
          final sH = (pMeta?.effectiveSurfaceHeight ?? 18).toDouble();
          comp.updateGridPosition(
            comp.gridX,
            comp.gridY,
            parentId: parent.id,
            parentSurfaceHeight: sH,
            parentFurthestX: parent.gridX + parent.gridWidth - 1,
            parentFurthestY: parent.gridY + parent.gridHeight - 1,
          );
        } else {
          comp.updateGridPosition(comp.gridX, comp.gridY);
        }
      }
    }
  }

  IsometricFurnitureComponent? _findSurfaceParentAt(int gx, int gy, {IsometricFurnitureComponent? exclude}) {
    final candidates = world.children.whereType<IsometricFurnitureComponent>().where((f) => f != exclude && f.type != FurnitureType.portal && !f.isSurfaceItem && !f.isWallNorth && !f.isWallWest);
    for (final f in candidates) {
      if (gx >= f.gridX && gx < f.gridX + f.gridWidth && gy >= f.gridY && gy < f.gridY + f.gridHeight) {
        final meta = FurnitureCatalogService.getItem(f.typeName) ?? FurnitureCatalogService.getItem(f.id);
        if (meta != null && meta.isSurfaceSupporting) {
          return f;
        }
        // Fallback for known surface items
        if (f.id.contains('table') || f.id.contains('counter') || f.id.contains('stove') || f.id.contains('sink') || f.id.contains('bed') || f.id.contains('nightstand') || f.id.contains('drawer') || f.id.contains('cube') || f.typeName.contains('table') || f.typeName.contains('counter') || f.typeName.contains('bed') || f.typeName.contains('cube')) {
          return f;
        }
      }
    }
    return null;
  }

  Future<Map<int, Sprite>> _loadRotationSprites(String id) async {
    final Map<int, Sprite> map = {};
    final isHD = (roomConfig.resolution == '64x128');

    final candidateIds = [
      id,
      if (!id.endsWith('_n') && !id.endsWith('_w')) '${id}_n',
    ];

    for (int rot = 0; rot < 4; rot++) {
      for (final cid in candidateIds) {
        if (map.containsKey(rot)) break;
        if (isHD) {
          // HD Mode: Use 128x256 detailed furniture
          try {
            map[rot] = await loadSprite('furniture/128x256/${cid}_rot$rot.png');
            break;
          } catch (_) {}
          try {
            map[rot] = await loadSprite('furniture/128x256/$cid.png');
            break;
          } catch (_) {}
          try {
            map[rot] = await loadSprite('furniture/64x128/${cid}_rot$rot.png');
            break;
          } catch (_) {}
          try {
            map[rot] = await loadSprite('furniture/64x128/$cid.png');
            break;
          } catch (_) {}
        } else {
          // Retro Mode: Use 64x128 furniture (rendered with 2x scale)
          try {
            map[rot] = await loadSprite('furniture/64x128/${cid}_rot$rot.png');
            break;
          } catch (_) {}
          try {
            map[rot] = await loadSprite('furniture/64x128/$cid.png');
            break;
          } catch (_) {}
          try {
            map[rot] = await loadSprite('furniture/32x64/${cid}_rot$rot.png');
            break;
          } catch (_) {}
          try {
            map[rot] = await loadSprite('furniture/32x64/$cid.png');
            break;
          } catch (_) {}
        }

        // Root fallbacks
        try {
          map[rot] = await loadSprite('furniture/${cid}_rot$rot.png');
          break;
        } catch (_) {}
        try {
          map[rot] = await loadSprite('furniture/$cid.png');
          break;
        } catch (_) {}
      }
    }

    // Kick off alpha-channel decoding for these sprites now, well before any tap needs it,
    // so pixel-exact hit-testing (see IsometricFurnitureComponent.hitTestWorld) is ready by
    // the time the player actually interacts with the placed furniture.
    for (final sprite in map.values) {
      SpriteAlphaCache.warm(sprite.image);
    }

    return map;
  }

  Future<void> _switchWallVariant(IsometricFurnitureComponent comp, bool isNorth) async {
    final targetTypeName = FurnitureCatalogItem.getWallVariantFor(comp.typeName, isNorth);
    if (comp.typeName == targetTypeName && comp.footprint == (isNorth ? 'wall_n' : 'wall_w')) return;

    comp.typeName = targetTypeName;
    comp.footprint = isNorth ? 'wall_n' : 'wall_w';

    final rotSprites = await _loadRotationSprites(targetTypeName);
    comp.rotationSprites.clear();
    comp.rotationSprites.addAll(rotSprites);
    comp.sprite = rotSprites[0];
    comp.updateGridPosition(comp.gridX, comp.gridY);
  }

  Future<void> addFurnitureFromCatalog(FurnitureCatalogItem catalogItem) async {
    final isWall = catalogItem.isWallItem;
    final initialWallIsNorth = !catalogItem.isWallWest;
    final initialTypeName = isWall ? FurnitureCatalogItem.getWallVariantFor(catalogItem.id, initialWallIsNorth) : catalogItem.id;
    final rotSprites = await _loadRotationSprites(initialTypeName);
    final gw = catalogItem.gridWidth;
    final gh = catalogItem.gridHeight;

    Point<int> spawnPos = const Point(3, 3);
    String? parentId;
    double surfaceH = 0.0;

    final centerX = (gridSize - gw) / 2.0;
    final centerY = (gridSize - gh) / 2.0;

    if (catalogItem.isWallNorth || (catalogItem.isWallItem && !catalogItem.isWallWest)) {
      final candidates = <Point<int>>[];
      for (int x = 0; x <= gridSize - gw; x++) {
        final p = Point(x, 0);
        final temp = IsometricFurnitureComponent(
          id: catalogItem.id,
          gridX: x,
          gridY: 0,
          gridWidth: gw,
          gridHeight: gh,
          footprint: 'wall_n',
        );
        if (_checkIsValidLocation(temp, p)) {
          candidates.add(p);
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => ((a.x - centerX).abs()).compareTo((b.x - centerX).abs()));
        spawnPos = candidates.first;
      }
    } else if (catalogItem.isWallWest) {
      final candidates = <Point<int>>[];
      for (int y = 0; y <= gridSize - gh; y++) {
        final p = Point(0, y);
        final temp = IsometricFurnitureComponent(
          id: catalogItem.id,
          gridX: 0,
          gridY: y,
          gridWidth: gw,
          gridHeight: gh,
          footprint: 'wall_w',
        );
        if (_checkIsValidLocation(temp, p)) {
          candidates.add(p);
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) => ((a.y - centerY).abs()).compareTo((b.y - centerY).abs()));
        spawnPos = candidates.first;
      }
    } else if (catalogItem.isSurfaceItem) {
      // Find surface-supporting furniture closest to room center
      final parents = world.children.whereType<IsometricFurnitureComponent>().where((f) {
        final m = FurnitureCatalogService.getItem(f.id) ?? FurnitureCatalogService.getItem(f.typeName);
        return m != null && m.isSurfaceSupporting;
      }).toList();

      if (parents.isNotEmpty) {
        parents.sort((a, b) {
          final distA = (a.gridX - centerX) * (a.gridX - centerX) + (a.gridY - centerY) * (a.gridY - centerY);
          final distB = (b.gridX - centerX) * (b.gridX - centerX) + (b.gridY - centerY) * (b.gridY - centerY);
          return distA.compareTo(distB);
        });
        final parent = parents.first;
        spawnPos = Point(parent.gridX, parent.gridY);
        parentId = parent.id;
        final pMeta = FurnitureCatalogService.getItem(parent.id) ?? FurnitureCatalogService.getItem(parent.typeName);
        surfaceH = (pMeta?.effectiveSurfaceHeight ?? 18).toDouble();
      }
    } else {
      // Normal floor item: find free valid location closest to the center of the room
      final candidates = <Point<int>>[];
      for (int r = 0; r <= gridSize - gw; r++) {
        for (int c = 0; c <= gridSize - gh; c++) {
          final p = Point(r, c);
          final temp = IsometricFurnitureComponent(
            id: catalogItem.id,
            gridX: r,
            gridY: c,
            gridWidth: gw,
            gridHeight: gh,
            footprint: catalogItem.footprint,
          );
          if (_checkIsValidLocation(temp, p)) {
            candidates.add(p);
          }
        }
      }
      if (candidates.isNotEmpty) {
        candidates.sort((a, b) {
          final distA = (a.x - centerX) * (a.x - centerX) + (a.y - centerY) * (a.y - centerY);
          final distB = (b.x - centerX) * (b.x - centerX) + (b.y - centerY) * (b.y - centerY);
          return distA.compareTo(distB);
        });
        spawnPos = candidates.first;
      }
    }

    final uniqueId = '${catalogItem.id}_${DateTime.now().microsecondsSinceEpoch}';
    final comp = IsometricFurnitureComponent(
      id: uniqueId,
      typeName: initialTypeName,
      gridX: spawnPos.x,
      gridY: spawnPos.y,
      gridWidth: gw,
      gridHeight: gh,
      rotation: 0,
      footprint: isWall ? (initialWallIsNorth ? 'wall_n' : 'wall_w') : catalogItem.footprint,
      parentId: parentId,
      parentSurfaceHeight: surfaceH,
      wallHeightLevel: 'high',
      resolution: roomConfig.resolution,
      type: catalogItem.id.contains('wardrobe') ? FurnitureType.wardrobe : (catalogItem.id.contains('bed') ? FurnitureType.bed : FurnitureType.custom),
      sprite: rotSprites[0],
      rotationSprites: rotSprites,
      onInteract: catalogItem.id.contains('wardrobe') ? onOpenWardrobe : null,
    );
    world.add(comp);
    selectFurniture(comp);
    _recalculateObstacles();
  }

  void toggleSelectedWallHeight() {
    if (selectedFurniture != null && selectedFurniture!.isWallItem) {
      selectedFurniture!.toggleWallHeightLevel();
    }
  }

  void rotateSelectedFurniture() {
    if (selectedFurniture == null || selectedFurniture!.isPortal) return;

    final comp = selectedFurniture!;
    if (comp.isSurfaceItem || comp.isWallNorth || comp.isWallWest) {
      comp.rotateClockwise();
      return;
    }

    final nextW = comp.gridHeight;
    final nextH = comp.gridWidth;

    int targetX = comp.gridX;
    int targetY = comp.gridY;

    if (targetX + nextW > gridSize) targetX = gridSize - nextW;
    if (targetY + nextH > gridSize) targetY = gridSize - nextH;

    bool fits = true;
    final others = world.children.whereType<IsometricFurnitureComponent>().where((f) => f != comp && f.type != FurnitureType.carpet && !f.isSurfaceItem && !f.isWallNorth && !f.isWallWest);
    for (final f in others) {
      for (int fx = 0; fx < f.gridWidth; fx++) {
        for (int fy = 0; fy < f.gridHeight; fy++) {
          final fPoint = Point(f.gridX + fx, f.gridY + fy);
          for (int nx = 0; nx < nextW; nx++) {
            for (int ny = 0; ny < nextH; ny++) {
              if (Point(targetX + nx, targetY + ny) == fPoint) {
                fits = false;
                break;
              }
            }
          }
        }
      }
    }

    if (fits) {
      comp.gridX = targetX;
      comp.gridY = targetY;
      comp.rotateClockwise();
      _recalculateObstacles();
    }
  }

  void deleteFurniture(IsometricFurnitureComponent comp) {
    if (comp.isPortal) return;
    comp.removeFromParent();
    if (selectedFurniture == comp) {
      selectFurniture(null);
    }
    _recalculateObstacles();
  }

  void deleteSelectedFurniture() {
    if (selectedFurniture != null) {
      deleteFurniture(selectedFurniture!);
    }
  }

  void selectFurniture(IsometricFurnitureComponent? comp) {
    if (selectedFurniture != null) {
      selectedFurniture!.isSelected = false;
    }
    selectedFurniture = comp;
    if (selectedFurniture != null) {
      selectedFurniture!.isSelected = true;
      if (selectedInteriorWall != null) {
        selectedInteriorWall!.isSelected = false;
        selectedInteriorWall = null;
        onInteriorWallSelected?.call(null);
      }
    }
    onFurnitureSelected?.call(comp);
  }

  void addInteriorWallFromStyle(InteriorWallStyleOption styleOption) {
    final uniqueId = 'interior_wall_${DateTime.now().microsecondsSinceEpoch}';
    final comp = IsometricInteriorWallComponent(
      id: uniqueId,
      gridX: 3,
      gridY: 3,
      orientation: 'north',
      style: styleOption.id,
      hasDoorway: styleOption.isDoorway,
      plasterSprite: _backgroundComponent?._wallpaperSprites['solid_plaster'],
    );
    world.add(comp);
    selectInteriorWall(comp);
    _recalculateObstacles();
  }

  void selectInteriorWall(IsometricInteriorWallComponent? comp) {
    if (selectedInteriorWall != null) {
      selectedInteriorWall!.isSelected = false;
    }
    selectedInteriorWall = comp;
    if (selectedInteriorWall != null) {
      selectedInteriorWall!.isSelected = true;
      if (selectedFurniture != null) {
        selectedFurniture!.isSelected = false;
        selectedFurniture = null;
        onFurnitureSelected?.call(null);
      }
    }
    onInteriorWallSelected?.call(comp);
  }

  void rotateSelectedInteriorWall() {
    if (selectedInteriorWall != null) {
      selectedInteriorWall!.toggleOrientation();
      _recalculateObstacles();
    }
  }

  void toggleSelectedInteriorWallDoorway() {
    if (selectedInteriorWall != null) {
      selectedInteriorWall!.toggleDoorway();
      _recalculateObstacles();
    }
  }

  void deleteSelectedInteriorWall() {
    if (selectedInteriorWall != null) {
      selectedInteriorWall!.removeFromParent();
      selectInteriorWall(null);
      _recalculateObstacles();
    }
  }

  int applyStyleToAllInteriorWalls(InteriorWallStyleOption styleOption) {
    if (styleOption.isDoorway) return 0;
    final walls = world.children
        .whereType<IsometricInteriorWallComponent>()
        .where((w) => !w.hasDoorway)
        .toList();
    for (final w in walls) {
      w.style = styleOption.id;
      w.plasterSprite = _backgroundComponent?._wallpaperSprites['solid_plaster'];
    }
    return walls.length;
  }

  int applySelectedInteriorWallStyleToAll() {
    if (selectedInteriorWall == null) return 0;
    final targetStyle = selectedInteriorWall!.style;
    final walls = world.children.whereType<IsometricInteriorWallComponent>().toList();
    for (final w in walls) {
      w.style = targetStyle;
      w.plasterSprite = _backgroundComponent?._wallpaperSprites['solid_plaster'];
    }
    return walls.length;
  }

  /// Screen-space point (in the GameWidget's own coordinate space, which lines up
  /// 1:1 with the Flutter Stack above it) hovering just above the selected furniture's
  /// sprite. Used to float its action toolbar right over the object instead of a fixed
  /// screen corner. Returns null when nothing is selected.
  Vector2? getSelectedFurnitureAnchor() {
    final f = selectedFurniture;
    if (f == null || !f.isMounted) return null;
    try {
      final worldTop = f.position + f.spriteOffset + Vector2(f.renderSize.x / 2.0, 0);
      final anchor = camera.viewfinder.transform.localToGlobal(worldTop);
      if (!anchor.x.isFinite || !anchor.y.isFinite) return null;
      return anchor;
    } catch (_) {
      // Called every frame from a UI ticker while the camera may be mid-transform — never
      // let a transient failure here (e.g. a degenerate matrix for one frame) escape as an
      // uncaught exception during a build.
      return null;
    }
  }

  /// Same idea as [getSelectedFurnitureAnchor] but for the selected interior wall.
  Vector2? getSelectedInteriorWallAnchor() {
    final w = selectedInteriorWall;
    if (w == null || !w.isMounted) return null;
    try {
      final anchor = camera.viewfinder.transform.localToGlobal(w.topAnchorWorld);
      if (!anchor.x.isFinite || !anchor.y.isFinite) return null;
      return anchor;
    } catch (_) {
      return null;
    }
  }

  void _recalculateObstacles() {
    obstacles.clear();
    blockedEdges.clear();

    final allFurniture = world.children.whereType<IsometricFurnitureComponent>();
    for (final f in allFurniture) {
      if (f.type == FurnitureType.carpet || f.isSurfaceItem || f.isWallNorth || f.isWallWest) continue;
      for (int x = 0; x < f.gridWidth; x++) {
        for (int y = 0; y < f.gridHeight; y++) {
          obstacles.add(Point(f.gridX + x, f.gridY + y));
        }
      }
    }

    final allWalls = world.children.whereType<IsometricInteriorWallComponent>();
    for (final w in allWalls) {
      if (w.hasDoorway || w.style == 'doorway_frame') continue;
      if (w.orientation == 'north') {
        if (w.gridY > 0) {
          blockedEdges.add(IsometricPathfinder.edgeKey(w.gridX, w.gridY, w.gridX, w.gridY - 1));
        }
      } else {
        if (w.gridX > 0) {
          blockedEdges.add(IsometricPathfinder.edgeKey(w.gridX, w.gridY, w.gridX - 1, w.gridY));
        }
      }
    }

    _recalculateSurfacePriorities();
  }

  bool _checkIsValidLocation(IsometricFurnitureComponent item, Point<int> target) {
    // 1. Surface Item: Must be placed on a furniture with surface_height > 0
    if (item.isSurfaceItem) {
      if (target.x < 0 || target.x >= gridSize || target.y < 0 || target.y >= gridSize) {
        return false;
      }
      final parent = _findSurfaceParentAt(target.x, target.y, exclude: item);
      return parent != null;
    }

    // 2. Wall North Item: Must be at North Wall (gy == 0)
    if (item.isWallNorth) {
      if (target.y != 0 || target.x < 0 || target.x >= gridSize) return false;
      final existingWalls = world.children.whereType<IsometricFurnitureComponent>().where((f) => f != item && f.isWallNorth);
      return !existingWalls.any((f) => f.gridX == target.x && f.gridY == 0);
    }

    // 3. Wall West Item: Must be at West Wall (gx == 0)
    if (item.isWallWest) {
      if (target.x != 0 || target.y < 0 || target.y >= gridSize) return false;
      final existingWalls = world.children.whereType<IsometricFurnitureComponent>().where((f) => f != item && f.isWallWest);
      return !existingWalls.any((f) => f.gridX == 0 && f.gridY == target.y);
    }

    // 4. Standard Floor Item: Bounds check
    if (target.x < 0 || target.x + item.gridWidth > gridSize || target.y < 0 || target.y + item.gridHeight > gridSize) {
      return false;
    }

    // Collision check against other solid floor items
    final allFurniture = world.children.whereType<IsometricFurnitureComponent>().where((f) => f != item && f.type != FurnitureType.carpet && !f.isSurfaceItem && !f.isWallNorth && !f.isWallWest);
    for (final f in allFurniture) {
      for (int fx = 0; fx < f.gridWidth; fx++) {
        for (int fy = 0; fy < f.gridHeight; fy++) {
          final fPoint = Point(f.gridX + fx, f.gridY + fy);
          for (int ix = 0; ix < item.gridWidth; ix++) {
            for (int iy = 0; iy < item.gridHeight; iy++) {
              if (Point(target.x + ix, target.y + iy) == fPoint) {
                return false;
              }
            }
          }
        }
      }
    }

    return true;
  }

  void _handleDestinationReached(Point<int> dest) {
    if (isDecorateMode) return;

    final wardrobe = world.children.whereType<IsometricFurnitureComponent>().where((f) => f.isWardrobe).firstOrNull;
    if (wardrobe != null) {
      if ((dest.x - wardrobe.gridX).abs() <= 1 && (dest.y - wardrobe.gridY).abs() <= 1) {
        onOpenWardrobe?.call();
      }
    }

    final portal = world.children.whereType<IsometricFurnitureComponent>().where((f) => f.isPortal).firstOrNull;
    if (portal != null) {
      if ((dest.x - portal.gridX).abs() <= 1 && (dest.y - portal.gridY).abs() <= 1) {
        onOpenMatchmaking?.call();
      }
    }
  }

  void updateAvatarConfig(AvatarConfig newConfig) {
    avatarConfig = newConfig;
    avatar?.updateConfig(newConfig);
  }

  Future<void> updateResolution(String newResolution) async {
    roomConfig = roomConfig.copyWith(resolution: newResolution);
    avatarConfig = avatarConfig.copyWith(spriteResolution: newResolution);
    avatar?.updateConfig(avatarConfig);

    // Reload all furniture sprites
    final allFurniture = world.children.whereType<IsometricFurnitureComponent>().where((f) => !f.isPortal).toList();
    for (final f in allFurniture) {
      f.resolution = newResolution;
      final rotSprites = await _loadRotationSprites(f.typeName);
      f.rotationSprites.clear();
      f.rotationSprites.addAll(rotSprites);
      f.sprite = rotSprites[f.rotation] ?? rotSprites[0];
    }
  }

  void updateWallpaper(String wallpaperId) {
    roomConfig = roomConfig.copyWith(wallpaper: wallpaperId);
    _backgroundComponent?.roomConfig = roomConfig;
  }

  void updateFloor(String floorId) {
    roomConfig = roomConfig.copyWith(floor: floorId);
    _backgroundComponent?.roomConfig = roomConfig;
  }

  void setFloorBrush(String? floorBrushId) {
    activeFloorBrushId = floorBrushId;
    if (floorBrushId != null) {
      selectFurniture(null);
      selectInteriorWall(null);
    }
  }

  void paintFloorTile(int gx, int gy, String floorId) {
    if (gx < 0 || gx >= gridSize || gy < 0 || gy >= gridSize) return;
    final key = '$gx,$gy';
    if (roomConfig.floorOverrides[key] == floorId) return;

    final newOverrides = Map<String, String>.from(roomConfig.floorOverrides);
    newOverrides[key] = floorId;
    roomConfig = roomConfig.copyWith(floorOverrides: newOverrides);
    _backgroundComponent?.roomConfig = roomConfig;
  }

  void eraseFloorTile(int gx, int gy) {
    if (gx < 0 || gx >= gridSize || gy < 0 || gy >= gridSize) return;
    final key = '$gx,$gy';
    if (!roomConfig.floorOverrides.containsKey(key)) return;

    final newOverrides = Map<String, String>.from(roomConfig.floorOverrides);
    newOverrides.remove(key);
    roomConfig = roomConfig.copyWith(floorOverrides: newOverrides);
    _backgroundComponent?.roomConfig = roomConfig;
  }

  void clearAllFloorOverrides() {
    if (roomConfig.floorOverrides.isEmpty) return;
    roomConfig = roomConfig.copyWith(floorOverrides: const {});
    _backgroundComponent?.roomConfig = roomConfig;
  }

  void updateRoomConfig(RoomConfig newConfig, {bool reloadFurniture = true}) {
    roomConfig = newConfig;
    _backgroundComponent?.roomConfig = newConfig;
    if (reloadFurniture) {
      _loadFurnitureFromConfig(newConfig);
    }
  }

  RoomConfig exportCurrentRoomConfig() {
    final list = <PlacedFurnitureConfig>[];
    final allFurniture = world.children.whereType<IsometricFurnitureComponent>().where((f) => !f.isPortal);

    for (final f in allFurniture) {
      list.add(PlacedFurnitureConfig(
        // typeName must stay the catalog id so the reload can resolve footprint + sprites;
        // id must stay the runtime id so parentId links from surface items survive the round-trip.
        id: f.id,
        typeName: f.typeName,
        gridX: f.gridX,
        gridY: f.gridY,
        gridWidth: f.gridWidth,
        gridHeight: f.gridHeight,
        rotation: f.rotation,
        parentId: f.parentId,
        wallHeightLevel: f.wallHeightLevel,
        assetPath: f.baseAssetPath,
      ));
    }

    final wallList = <InteriorWallConfig>[];
    final allInteriorWalls = world.children.whereType<IsometricInteriorWallComponent>();
    for (final w in allInteriorWalls) {
      wallList.add(w.toConfig());
    }

    return roomConfig.copyWith(
      furniture: list,
      interiorWalls: wallList,
      floorOverrides: roomConfig.floorOverrides,
    );
  }

  void adjustZoom(double zoomMultiplier) {
    final newZoom = (camera.viewfinder.zoom * zoomMultiplier).clamp(0.55, 2.8);
    camera.viewfinder.zoom = newZoom;
  }

  void setZoom(double targetZoom) {
    camera.viewfinder.zoom = targetZoom.clamp(0.55, 2.8);
  }

  void panCamera(Vector2 screenDelta) {
    final currentPos = camera.viewfinder.position;
    final zoom = camera.viewfinder.zoom;
    final newX = (currentPos.x - (screenDelta.x / zoom)).clamp(-450.0, 450.0);
    final newY = (currentPos.y - (screenDelta.y / zoom)).clamp(-250.0, 500.0);
    camera.viewfinder.position = Vector2(newX, newY);
  }

  void resetCamera() {
    final roomCenterScreen = IsometricCoords.gridToScreen(3.5, 3.5);
    camera.viewfinder.position = roomCenterScreen;
    camera.viewfinder.zoom = 1.35;
  }

  bool _hasInitializedCamera = false;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_hasInitializedCamera) {
      final roomCenterScreen = IsometricCoords.gridToScreen(3.5, 3.5);
      camera.viewfinder.position = roomCenterScreen;
      camera.viewfinder.anchor = Anchor.center;

      final zoomFit = min(size.x / 450.0, size.y / 380.0);
      camera.viewfinder.zoom = zoomFit.clamp(1.20, 1.85);
      _hasInitializedCamera = true;
    }
  }

  Vector2? _currentDragScreenPos;

  @override
  void update(double dt) {
    super.update(dt);
    if (isDecorateMode && _draggedFurniture != null && _currentDragScreenPos != null) {
      _handleEdgeAutoScroll(dt);
    }
  }

  void _handleEdgeAutoScroll(double dt) {
    if (_currentDragScreenPos == null || _draggedFurniture == null) return;

    final pos = _currentDragScreenPos!;
    const edgeMargin = 70.0;
    const topMargin = 90.0;
    const bottomMargin = 160.0;
    const maxScrollSpeed = 280.0;

    double panX = 0.0;
    double panY = 0.0;

    if (pos.x < edgeMargin) {
      final intensity = ((edgeMargin - pos.x) / edgeMargin).clamp(0.0, 1.0);
      panX = maxScrollSpeed * intensity * dt;
    } else if (pos.x > size.x - edgeMargin) {
      final intensity = ((pos.x - (size.x - edgeMargin)) / edgeMargin).clamp(0.0, 1.0);
      panX = -maxScrollSpeed * intensity * dt;
    }

    if (pos.y < topMargin) {
      final intensity = ((topMargin - pos.y) / topMargin).clamp(0.0, 1.0);
      panY = maxScrollSpeed * intensity * dt;
    } else if (pos.y > size.y - bottomMargin) {
      final intensity = ((pos.y - (size.y - bottomMargin)) / bottomMargin).clamp(0.0, 1.0);
      panY = -maxScrollSpeed * intensity * dt;
    }

    if (panX != 0.0 || panY != 0.0) {
      panCamera(Vector2(panX, panY));
      _updateDragHoverPosition(_currentDragScreenPos!);
    }
  }

  void _updateDragHoverPosition(Vector2 screenPos) {
    if (_draggedFurniture == null) return;

    final currentWorldPos = camera.viewfinder.transform.globalToLocal(screenPos);

    Point<int> clampedGrid;
    if (_draggedFurniture!.isWallItem) {
      // Wall items exist along the vertical planes of North Wall (sx >= 0) or West Wall (sx < 0).
      // Each isometric wall panel occupies exactly (tileWidth / 2 = 32px) horizontally:
      // North tile gx spans sx [32*gx, 32*gx+32); West tile gy spans sx (-32*gy-32, -32*gy].
      // Moving vertically UP/DOWN (delta sx = 0) stays rock-solid on the same panel.
      // Moving diagonally along the wall advances exactly one panel per 32px, 1:1.
      final panelWidth = IsometricCoords.tileWidth / 2.0;
      final anchorSx = currentWorldPos.x;
      final bool isNorth = (anchorSx >= 0);

      if (isNorth) {
        final rawX = (anchorSx / panelWidth).floor();
        final gx = rawX.clamp(0, gridSize - _draggedFurniture!.gridWidth);
        clampedGrid = Point(gx, 0);
        _switchWallVariant(_draggedFurniture!, true);
      } else {
        final rawY = ((-anchorSx) / panelWidth).floor();
        final gy = rawY.clamp(0, gridSize - _draggedFurniture!.gridHeight);
        clampedGrid = Point(0, gy);
        _switchWallVariant(_draggedFurniture!, false);
      }
    } else {
      final rawGrid = IsometricCoords.screenToGrid(currentWorldPos.x, currentWorldPos.y);
      final clX = rawGrid.x.clamp(0, gridSize - _draggedFurniture!.gridWidth);
      final clY = rawGrid.y.clamp(0, gridSize - _draggedFurniture!.gridHeight);
      clampedGrid = Point(clX, clY);
    }

    _currentHoverGrid = clampedGrid;
    _isValidDropLocation = _checkIsValidLocation(_draggedFurniture!, clampedGrid);

    // If surface item, update dynamic elevation and parent linkage for magnetic preview
    if (_draggedFurniture!.isSurfaceItem) {
      final parent = _findSurfaceParentAt(clampedGrid.x, clampedGrid.y, exclude: _draggedFurniture);
      if (parent != null) {
        _draggedFurniture!.parentId = parent.id;
        final pMeta = FurnitureCatalogService.getItem(parent.typeName) ?? FurnitureCatalogService.getItem(parent.id);
        final parentRotMeta = pMeta?.rotations[parent.rotation];
        if (parentRotMeta != null && parentRotMeta.surfaceHeight > 0) {
          _draggedFurniture!.parentSurfaceHeight = parentRotMeta.surfaceHeight.toDouble();
        } else {
          _draggedFurniture!.parentSurfaceHeight = (pMeta?.effectiveSurfaceHeight ?? 18).toDouble();
        }
      } else {
        _draggedFurniture!.parentId = null;
        _draggedFurniture!.parentSurfaceHeight = 0.0;
      }
    }

    final targetScreenPos = IsometricCoords.gridToScreen(clampedGrid.x.toDouble(), clampedGrid.y.toDouble());
    final currentScreenPos = IsometricCoords.gridToScreen(_draggedFurniture!.gridX.toDouble(), _draggedFurniture!.gridY.toDouble());
    final delta = targetScreenPos - currentScreenPos;
    _draggedFurniture!.dragVisualOffset = delta;

    // Also update visual offset for attached surface items
    for (final child in _attachedSurfaceItems) {
      child.dragVisualOffset = delta;
      child.isBeingDragged = true;
    }
  }

  void _updateWallDragHoverPosition(Vector2 screenPos) {
    if (_draggedInteriorWall == null || _dragStartWorldPos == null || _originalWallGridPos == null) return;
    final currentWorldPos = camera.viewfinder.transform.globalToLocal(screenPos);

    // Move the wall by how far the finger has actually travelled since touch-down, instead
    // of snapping it to whatever tile sits directly under the finger. A tall wall panel is
    // grabbed anywhere along its height (e.g. near the top), and re-projecting that exact
    // point onto the floor plane lands on a different tile than the wall's own — which used
    // to make it jump the instant you touched it, before the finger moved at all.
    final worldDelta = currentWorldPos - _dragStartWorldPos!;
    final originalScreenPos = IsometricCoords.gridToScreen(
      _originalWallGridPos!.x.toDouble(),
      _originalWallGridPos!.y.toDouble(),
    );
    final adjustedWorldPos = originalScreenPos + worldDelta;

    final rawGrid = IsometricCoords.screenToGrid(adjustedWorldPos.x, adjustedWorldPos.y);
    final clX = rawGrid.x.clamp(0, gridSize - 1);
    final clY = rawGrid.y.clamp(0, gridSize - 1);
    final targetGrid = Point(clX, clY);

    _currentHoverGrid = targetGrid;
    _isValidDropLocation = true;

    final targetScreenPos = IsometricCoords.gridToScreen(clX.toDouble(), clY.toDouble());
    final currentScreenPos = IsometricCoords.gridToScreen(_draggedInteriorWall!.gridX.toDouble(), _draggedInteriorWall!.gridY.toDouble());
    _draggedInteriorWall!.dragVisualOffset = targetScreenPos - currentScreenPos;
  }

  /// Arms [hit] for dragging: records its original placement (for cancel/restore) and
  /// marks it — and any surface items sitting on it — as being dragged. Shared by the
  /// "already selected, grab instantly" and "hold-timer just fired" paths in onDragStart.
  void _armFurnitureDrag(IsometricFurnitureComponent hit, Vector2 worldPos) {
    _draggedFurniture = hit;
    _originalGridPos = Point(hit.gridX, hit.gridY);
    _originalParentId = hit.parentId;
    _originalSurfaceHeight = hit.parentSurfaceHeight;
    _originalWallId = hit.typeName;
    _currentHoverGrid = Point(hit.gridX, hit.gridY);
    _dragStartWorldPos = worldPos;
    _isValidDropLocation = true;

    hit.isBeingDragged = true;
    hit.isDirectlyDragged = true;
    hit.priority = 9999;

    // If dragging a surface-supporting furniture, find all attached surface children strictly on top of THIS table's tiles
    _attachedSurfaceItems.clear();
    if (!hit.isSurfaceItem && !hit.isWallItem) {
      _attachedSurfaceItems = world.children
          .whereType<IsometricFurnitureComponent>()
          .where((c) =>
              c.isSurfaceItem &&
              c.gridX >= hit.gridX &&
              c.gridX < hit.gridX + hit.gridWidth &&
              c.gridY >= hit.gridY &&
              c.gridY < hit.gridY + hit.gridHeight)
          .toList();
      for (final child in _attachedSurfaceItems) {
        child.isBeingDragged = true;
        child.isDirectlyDragged = false;
        child.priority = 10001; // Render strictly on top of parent table during drag
      }
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _lastDragScreenPos = event.localPosition;
    _currentDragScreenPos = event.localPosition;

    final worldPos = camera.viewfinder.transform.globalToLocal(event.localPosition);

    if (isDecorateMode) {
      // Pass -1: Floor Brush Mode (Paints/Erases tiles by touch & dragging)
      if (activeFloorBrushId != null) {
        final gridPos = IsometricCoords.screenToGrid(worldPos.x, worldPos.y);
        if (gridPos.x >= 0 && gridPos.x < gridSize && gridPos.y >= 0 && gridPos.y < gridSize) {
          _isFloorBrushDragging = true;
          if (activeFloorBrushId == '__eraser__') {
            eraseFloorTile(gridPos.x, gridPos.y);
            world.add(_TapWaveComponent(grid: gridPos, isSnap: true));
          } else {
            paintFloorTile(gridPos.x, gridPos.y, activeFloorBrushId!);
            world.add(_TapWaveComponent(grid: gridPos));
          }
          return;
        }
      }

      // Pass 0: Check Interior Walls
      final allInteriorWalls = world.children.whereType<IsometricInteriorWallComponent>().toList();
      allInteriorWalls.sort((a, b) => b.priority.compareTo(a.priority));

      for (final w in allInteriorWalls) {
        if (w.hitTestWorld(worldPos)) {
          if (w == selectedInteriorWall) {
            // Already selected — grab it immediately, no hold delay, so it tracks the
            // finger from the very first movement instead of waiting on the timer below.
            _dragStartWorldPos = worldPos;
            _draggedInteriorWall = w;
            _originalWallGridPos = Point(w.gridX, w.gridY);
            _originalWallOrientation = w.orientation;
            _currentHoverGrid = Point(w.gridX, w.gridY);
            _isValidDropLocation = true;
            w.isBeingDragged = true;
            w.priority = 9999;
            return;
          }

          // Not selected yet — this could be a deliberate grab-and-hold, or just a finger
          // passing over the wall on its way to pan the camera. Wait for a short hold before
          // committing to a grab; if the finger moves first, hand off to camera panning
          // instead (see onDragUpdate). A plain tap still selects it via handleScreenTap on
          // pointer-up, independent of this timer.
          _pendingWallGrab = w;
          _dragStartWorldPos = worldPos;
          _wallGrabTimer?.cancel();
          _wallGrabTimer = async_lib.Timer(_wallGrabHoldDuration, () {
            if (_pendingWallGrab != w || !w.isMounted) return;
            _pendingWallGrab = null;

            selectInteriorWall(w);
            _draggedInteriorWall = w;
            _originalWallGridPos = Point(w.gridX, w.gridY);
            _originalWallOrientation = w.orientation;
            _currentHoverGrid = Point(w.gridX, w.gridY);
            _isValidDropLocation = true;

            w.isBeingDragged = true;
            w.priority = 9999;
          });
          return;
        }
      }

      final allFurniture = world.children.whereType<IsometricFurnitureComponent>().toList();
      allFurniture.sort((a, b) => b.priority.compareTo(a.priority));

      IsometricFurnitureComponent? hit;

      // Pass 1: Surface items strictly prioritized (e.g. coffee mug, lamp on top of dining table)
      for (final f in allFurniture) {
        if (f.isPortal || !f.isSurfaceItem) continue;
        if (f.hitTestWorld(worldPos)) {
          hit = f;
          break;
        }
      }

      // Pass 2: Wall items
      if (hit == null) {
        for (final f in allFurniture) {
          if (f.isPortal || !f.isWallItem) continue;
          if (f.hitTestWorld(worldPos)) {
            hit = f;
            break;
          }
        }
      }

      // Pass 3: Floor items
      if (hit == null) {
        for (final f in allFurniture) {
          if (f.isPortal || f.isSurfaceItem || f.isWallItem) continue;
          if (f.hitTestWorld(worldPos)) {
            hit = f;
            break;
          }
        }
      }

      if (hit != null) {
        if (hit == selectedFurniture) {
          // Already selected — grab it immediately, no hold delay, so it tracks the
          // finger from the very first movement.
          _armFurnitureDrag(hit, worldPos);
        } else {
          // Not selected yet — wait for a short hold before committing to a grab; if the
          // finger moves first, hand off to camera panning instead (see onDragUpdate). A
          // plain tap still selects it via handleScreenTap on pointer-up, independent of
          // this timer.
          final targetHit = hit;
          _pendingFurnitureGrab = targetHit;
          _dragStartWorldPos = worldPos;
          _furnitureGrabTimer?.cancel();
          _furnitureGrabTimer = async_lib.Timer(_furnitureGrabHoldDuration, () {
            if (_pendingFurnitureGrab != targetHit || !targetHit.isMounted) return;
            _pendingFurnitureGrab = null;
            selectFurniture(targetHit);
            _armFurnitureDrag(targetHit, worldPos);
          });
        }
      } else {
        _isPanningCamera = true;
      }
    } else {
      _isPanningCamera = true;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _currentDragScreenPos = event.localEndPosition;

    if (_isFloorBrushDragging && activeFloorBrushId != null) {
      final worldPos = camera.viewfinder.transform.globalToLocal(event.localEndPosition);
      final gridPos = IsometricCoords.screenToGrid(worldPos.x, worldPos.y);
      if (gridPos.x >= 0 && gridPos.x < gridSize && gridPos.y >= 0 && gridPos.y < gridSize) {
        final key = '${gridPos.x},${gridPos.y}';
        if (activeFloorBrushId == '__eraser__') {
          if (roomConfig.floorOverrides.containsKey(key)) {
            eraseFloorTile(gridPos.x, gridPos.y);
            world.add(_TapWaveComponent(grid: gridPos, isSnap: true));
          }
        } else {
          if (roomConfig.floorOverrides[key] != activeFloorBrushId) {
            paintFloorTile(gridPos.x, gridPos.y, activeFloorBrushId!);
            world.add(_TapWaveComponent(grid: gridPos));
          }
        }
      }
      return;
    }

    if (_isPanningCamera) {
      panCamera(event.localDelta);
      return;
    }

    // A wall grab is still pending its hold timer — if the finger has actually moved by
    // now, this wasn't a deliberate hold-still-to-grab. Treat it like it started on empty
    // space instead and pan the camera with it.
    if (_pendingWallGrab != null && _dragStartWorldPos != null) {
      final worldPos = camera.viewfinder.transform.globalToLocal(event.localEndPosition);
      if ((worldPos - _dragStartWorldPos!).length > 8.0) {
        _wallGrabTimer?.cancel();
        _wallGrabTimer = null;
        _pendingWallGrab = null;
        _dragStartWorldPos = null;
        _isPanningCamera = true;
        panCamera(event.localDelta);
      }
      return;
    }

    // Same idea for a furniture grab that's still pending its hold timer.
    if (_pendingFurnitureGrab != null && _dragStartWorldPos != null) {
      final worldPos = camera.viewfinder.transform.globalToLocal(event.localEndPosition);
      if ((worldPos - _dragStartWorldPos!).length > 8.0) {
        _furnitureGrabTimer?.cancel();
        _furnitureGrabTimer = null;
        _pendingFurnitureGrab = null;
        _dragStartWorldPos = null;
        _isPanningCamera = true;
        panCamera(event.localDelta);
      }
      return;
    }

    if (isDecorateMode && _draggedInteriorWall != null && _dragStartWorldPos != null) {
      _updateWallDragHoverPosition(event.localEndPosition);
      return;
    }

    if (isDecorateMode && _draggedFurniture != null && _dragStartWorldPos != null) {
      _updateDragHoverPosition(event.localEndPosition);
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _isFloorBrushDragging = false;
    _wallGrabTimer?.cancel();
    _wallGrabTimer = null;
    _pendingWallGrab = null;
    _furnitureGrabTimer?.cancel();
    _furnitureGrabTimer = null;
    _pendingFurnitureGrab = null;
    _isPanningCamera = false;
    _lastDragScreenPos = null;
    _currentDragScreenPos = null;
    if (isDecorateMode) {
      _finishDrag();
    }
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    _isFloorBrushDragging = false;
    _wallGrabTimer?.cancel();
    _wallGrabTimer = null;
    _pendingWallGrab = null;
    _furnitureGrabTimer?.cancel();
    _furnitureGrabTimer = null;
    _pendingFurnitureGrab = null;
    _isPanningCamera = false;
    _lastDragScreenPos = null;
    _currentDragScreenPos = null;
    if (isDecorateMode) {
      _cancelDrag();
    }
  }

  void _finishDrag() {
    if (_draggedInteriorWall != null) {
      _draggedInteriorWall!.isBeingDragged = false;
      if (_currentHoverGrid != null) {
        _draggedInteriorWall!.updateGridPosition(
          _currentHoverGrid!.x,
          _currentHoverGrid!.y,
        );
        world.add(_TapWaveComponent(grid: _currentHoverGrid!, isSnap: true));
      } else if (_originalWallGridPos != null) {
        _draggedInteriorWall!.updateGridPosition(
          _originalWallGridPos!.x,
          _originalWallGridPos!.y,
          newOrientation: _originalWallOrientation,
        );
      }

      _draggedInteriorWall!.dragVisualOffset = Vector2.zero();
      _draggedInteriorWall = null;
      _originalWallGridPos = null;
      _originalWallOrientation = null;
      _currentHoverGrid = null;
      _recalculateObstacles();
    }

    if (_draggedFurniture != null) {
      if (_isValidDropLocation && _currentHoverGrid != null) {
        final deltaX = _currentHoverGrid!.x - _originalGridPos!.x;
        final deltaY = _currentHoverGrid!.y - _originalGridPos!.y;

        String? newParentId;
        double newSurfaceH = 0.0;
        if (_draggedFurniture!.isSurfaceItem) {
          final parent = _findSurfaceParentAt(_currentHoverGrid!.x, _currentHoverGrid!.y, exclude: _draggedFurniture);
          if (parent != null) {
            newParentId = parent.id;
            final pMeta = FurnitureCatalogService.getItem(parent.typeName) ?? FurnitureCatalogService.getItem(parent.id);
            final parentRotMeta = pMeta?.rotations[parent.rotation];
            if (parentRotMeta != null && parentRotMeta.surfaceHeight > 0) {
              newSurfaceH = parentRotMeta.surfaceHeight.toDouble();
            } else {
              newSurfaceH = (pMeta?.effectiveSurfaceHeight ?? 18).toDouble();
            }
          }
        }

        _draggedFurniture!.updateGridPosition(
          _currentHoverGrid!.x,
          _currentHoverGrid!.y,
          parentId: newParentId,
          parentSurfaceHeight: newSurfaceH,
        );

        // Move all attached surface items together with parent furniture
        for (final child in _attachedSurfaceItems) {
          child.updateGridPosition(
            child.gridX + deltaX,
            child.gridY + deltaY,
            parentId: _draggedFurniture!.id,
          );
          child.dragVisualOffset = Vector2.zero();
          child.isBeingDragged = false;
          child.isDirectlyDragged = false;
        }

        _recalculateObstacles();
        _recalculateSurfacePriorities();
        world.add(_TapWaveComponent(grid: _currentHoverGrid!, isSnap: true));
      } else if (_originalGridPos != null) {
        if (_draggedFurniture!.isWallItem && _draggedFurniture!.typeName != _originalWallId) {
          _switchWallVariant(_draggedFurniture!, _originalWallId.endsWith('_n'));
        }
        _draggedFurniture!.updateGridPosition(
          _originalGridPos!.x,
          _originalGridPos!.y,
          parentId: _originalParentId,
          parentSurfaceHeight: _originalSurfaceHeight,
        );

        for (final child in _attachedSurfaceItems) {
          child.dragVisualOffset = Vector2.zero();
          child.isBeingDragged = false;
          child.isDirectlyDragged = false;
        }
        _recalculateSurfacePriorities();
      }

      _draggedFurniture!.dragVisualOffset = Vector2.zero();
      _draggedFurniture!.isBeingDragged = false;
      _draggedFurniture!.isDirectlyDragged = false;
      _draggedFurniture = null;
      _attachedSurfaceItems.clear();
      _originalGridPos = null;
      _originalParentId = null;
      _originalSurfaceHeight = 0.0;
      _originalWallId = '';
      _currentHoverGrid = null;
    }
  }

  void _cancelDrag() {
    if (_draggedInteriorWall != null && _originalWallGridPos != null) {
      _draggedInteriorWall!.isBeingDragged = false;
      _draggedInteriorWall!.updateGridPosition(
        _originalWallGridPos!.x,
        _originalWallGridPos!.y,
        newOrientation: _originalWallOrientation,
      );
      _draggedInteriorWall!.dragVisualOffset = Vector2.zero();
      _draggedInteriorWall = null;
      _originalWallGridPos = null;
      _originalWallOrientation = null;
      _currentHoverGrid = null;
      _recalculateObstacles();
    }

    if (_draggedFurniture != null && _originalGridPos != null) {
      if (_draggedFurniture!.isWallItem && _draggedFurniture!.typeName != _originalWallId) {
        _switchWallVariant(_draggedFurniture!, _originalWallId.endsWith('_n'));
      }
      _draggedFurniture!.updateGridPosition(
        _originalGridPos!.x,
        _originalGridPos!.y,
        parentId: _originalParentId,
        parentSurfaceHeight: _originalSurfaceHeight,
      );
      _draggedFurniture!.dragVisualOffset = Vector2.zero();
      _draggedFurniture!.isBeingDragged = false;
      _draggedFurniture!.isDirectlyDragged = false;

      for (final child in _attachedSurfaceItems) {
        child.dragVisualOffset = Vector2.zero();
        child.isBeingDragged = false;
        child.isDirectlyDragged = false;
      }
      _recalculateSurfacePriorities();

      _draggedFurniture = null;
      _attachedSurfaceItems.clear();
      _originalGridPos = null;
      _originalParentId = null;
      _originalSurfaceHeight = 0.0;
      _originalWallId = '';
      _currentHoverGrid = null;
    }
  }

  void handleScreenTap(Vector2 screenPosition) {
    final worldPos = camera.viewfinder.transform.globalToLocal(screenPosition);
    final gridPos = IsometricCoords.screenToGrid(worldPos.x, worldPos.y);

    if (isDecorateMode) {
      // Pass -1: Floor Brush Mode (Paints/Erases tiles on tap)
      if (activeFloorBrushId != null) {
        if (gridPos.x >= 0 && gridPos.x < gridSize && gridPos.y >= 0 && gridPos.y < gridSize) {
          if (activeFloorBrushId == '__eraser__') {
            eraseFloorTile(gridPos.x, gridPos.y);
            world.add(_TapWaveComponent(grid: gridPos, isSnap: true));
          } else {
            paintFloorTile(gridPos.x, gridPos.y, activeFloorBrushId!);
            world.add(_TapWaveComponent(grid: gridPos));
          }
          return;
        }
      }

      // Pass 0: Check Interior Walls
      final allInteriorWalls = world.children.whereType<IsometricInteriorWallComponent>().toList();
      allInteriorWalls.sort((a, b) => b.priority.compareTo(a.priority));
      for (final w in allInteriorWalls) {
        if (w.hitTestWorld(worldPos)) {
          selectInteriorWall(w);
          return;
        }
      }

      final allFurniture = world.children.whereType<IsometricFurnitureComponent>().toList();
      allFurniture.sort((a, b) => b.priority.compareTo(a.priority));

      IsometricFurnitureComponent? hit;

      // Pass 1: Surface items strictly prioritized
      for (final f in allFurniture) {
        if (f.isPortal || !f.isSurfaceItem) continue;
        if (f.hitTestWorld(worldPos)) {
          hit = f;
          break;
        }
      }

      // Pass 2: Wall items
      if (hit == null) {
        for (final f in allFurniture) {
          if (f.isPortal || !f.isWallItem) continue;
          if (f.hitTestWorld(worldPos)) {
            hit = f;
            break;
          }
        }
      }

      // Pass 3: Floor items
      if (hit == null) {
        for (final f in allFurniture) {
          if (f.isPortal || f.isSurfaceItem || f.isWallItem) continue;
          if (f.hitTestWorld(worldPos)) {
            hit = f;
            break;
          }
        }
      }

      selectFurniture(hit);
      if (hit == null) {
        selectInteriorWall(null);
      }
      return;
    }

    // In Normal Mode: Tap-to-move avatar
    if (_draggedFurniture != null || _draggedInteriorWall != null) return;

    if (gridPos.x >= 0 && gridPos.x < gridSize && gridPos.y >= 0 && gridPos.y < gridSize) {
      world.add(_TapWaveComponent(grid: gridPos));

      if (avatar != null) {
        final startPos = Point(avatar!.gridX.round(), avatar!.gridY.round());
        final path = IsometricPathfinder.findPath(
          start: startPos,
          goal: gridPos,
          obstacles: obstacles,
          blockedEdges: blockedEdges,
        );

        if (path.isNotEmpty) {
          avatar!.setPath(path, gridPos);
        }
      }
    }
  }
}

/// Renders glowing borders and ground shadow under the furniture currently being dragged
class _DragHighlightLayer extends Component {
  final CozyRoomGame game;

  _DragHighlightLayer({required this.game}) {
    priority = 10000;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (game.isDecorateMode && game._draggedFurniture != null) {
      final item = game._draggedFurniture!;

      // 1. Render Origin Marker (Showing where the item originated from)
      if (game._originalGridPos != null) {
        final orig = game._originalGridPos!;
        final origScreen = IsometricCoords.gridToScreen(orig.x.toDouble(), orig.y.toDouble());

        if (item.isSurfaceItem) {
          final origH = game._originalSurfaceHeight > 0 ? game._originalSurfaceHeight : 14.0;
          double pDx = 0.0;
          double pDy = 0.0;
          if (game._originalParentId != null) {
            final origParent = game.world.children.whereType<IsometricFurnitureComponent>().where((f) => f.id == game._originalParentId).firstOrNull;
            if (origParent != null) {
              final pMeta = FurnitureCatalogService.getItem(origParent.typeName) ?? FurnitureCatalogService.getItem(origParent.id);
              final pRot = pMeta?.rotations[origParent.rotation];
              if (pRot != null && pRot.surfaceOffset.length >= 2) {
                pDx = pRot.surfaceOffset[0].toDouble();
                pDy = pRot.surfaceOffset[1].toDouble();
              }
            }
          }

          // Item micro-adjustments
          double itemDx = 0.0;
          double itemDy = 0.0;
          final itemMeta = FurnitureCatalogService.getItem(item.typeName) ?? FurnitureCatalogService.getItem(item.id);
          final itemRot = itemMeta?.rotations[item.rotation];
          final offList = itemRot?.spriteOffset ?? itemMeta?.spriteOffset ?? const [-32, -48];
          if (offList.length >= 2) {
            itemDx = (offList[0] + 32.0);
            itemDy = (offList[1] + 48.0);
          }
          if (itemRot != null && itemRot.surfaceHeight != 0) {
            itemDy -= itemRot.surfaceHeight.toDouble();
          } else if (itemMeta != null && itemMeta.surfaceHeight != 0) {
            itemDy -= itemMeta.surfaceHeight.toDouble();
          }

          final originRect = Rect.fromCenter(
            center: Offset(origScreen.x + pDx + itemDx, origScreen.y - origH + pDy + itemDy),
            width: 22,
            height: 12,
          );
          final origFill = Paint()..color = const Color(0x25FFD54F);
          final origStroke = Paint()
            ..color = const Color(0x80FFD54F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawOval(originRect, origFill);
          canvas.drawOval(originRect, origStroke);
        } else if (item.isWallItem) {
          final wallYOffset = (item.wallHeightLevel == 'high') ? -48.0 : -32.0;
          // The item's footprint may already have flipped to the wall it is being dragged onto,
          // so the origin marker's orientation comes from the variant captured at drag start.
          // orig.y == 0 cannot be used: the corner tile (0,0) belongs to both walls.
          final isOrigNorth = !game._originalWallId.endsWith('_w');
          final cx = origScreen.x + (isOrigNorth ? 16.0 : -16.0);
          final cy = origScreen.y + wallYOffset;
          const w = 30.0;
          const h = 28.0;
          final slope = isOrigNorth ? 0.5 : -0.5;

          final wallPath = Path()
            ..moveTo(cx - w / 2.0, cy - h / 2.0 - (w / 2.0) * slope)
            ..lineTo(cx + w / 2.0, cy - h / 2.0 + (w / 2.0) * slope)
            ..lineTo(cx + w / 2.0, cy + h / 2.0 + (w / 2.0) * slope)
            ..lineTo(cx - w / 2.0, cy + h / 2.0 - (w / 2.0) * slope)
            ..close();

          final origStroke = Paint()
            ..color = const Color(0x80A78BFA)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5;
          canvas.drawPath(wallPath, origStroke);
        } else {
          for (int x = 0; x < item.gridWidth; x++) {
            for (int y = 0; y < item.gridHeight; y++) {
              final pos = IsometricCoords.gridToScreen((orig.x + x).toDouble(), (orig.y + y).toDouble());
              final path = Path()
                ..moveTo(pos.x, pos.y - (IsometricCoords.tileHeight / 2))
                ..lineTo(pos.x + (IsometricCoords.tileWidth / 2), pos.y)
                ..lineTo(pos.x, pos.y + (IsometricCoords.tileHeight / 2))
                ..lineTo(pos.x - (IsometricCoords.tileWidth / 2), pos.y)
                ..close();
              final origStroke = Paint()
                ..color = const Color(0x8000E5FF)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.5;
              canvas.drawPath(path, origStroke);
            }
          }
        }
      }

      // 2. Render Target / Destination Magnet Preview Marker
      if (game._currentHoverGrid != null) {
        final target = game._currentHoverGrid!;
        final isValid = game._isValidDropLocation;

        final highlightColor = isValid
            ? (item.isSurfaceItem ? const Color(0xFFFFD54F) : (item.isWallItem ? const Color(0xFFA78BFA) : const Color(0xFF00E5FF)))
            : const Color(0xFFFF1744);
        final fillColor = isValid
            ? (item.isSurfaceItem ? const Color(0x35FFD54F) : (item.isWallItem ? const Color(0x40A78BFA) : const Color(0x4000E5FF)))
            : const Color(0x35FF1744);

        final strokePaint = Paint()
          ..color = highlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8);

        final fillPaint = Paint()..color = fillColor;

        if (item.isWallItem && isValid) {
          final isNorth = item.isWallNorth;
          final pos = IsometricCoords.gridToScreen(target.x.toDouble(), target.y.toDouble());
          final wallYOffset = (item.wallHeightLevel == 'high') ? -48.0 : -32.0;
          final cx = pos.x + (isNorth ? 16.0 : -16.0);
          final cy = pos.y + wallYOffset;
          const w = 34.0;
          const h = 32.0;
          final slope = isNorth ? 0.5 : -0.5;

          final wallPath = Path()
            ..moveTo(cx - w / 2.0, cy - h / 2.0 - (w / 2.0) * slope)
            ..lineTo(cx + w / 2.0, cy - h / 2.0 + (w / 2.0) * slope)
            ..lineTo(cx + w / 2.0, cy + h / 2.0 + (w / 2.0) * slope)
            ..lineTo(cx - w / 2.0, cy + h / 2.0 - (w / 2.0) * slope)
            ..close();

          canvas.drawPath(wallPath, fillPaint);
          canvas.drawPath(wallPath, strokePaint);

          // Subtle base outline on corresponding floor tile
          final floorPath = Path()
            ..moveTo(pos.x, pos.y - (IsometricCoords.tileHeight / 2))
            ..lineTo(pos.x + (IsometricCoords.tileWidth / 2), pos.y)
            ..lineTo(pos.x, pos.y + (IsometricCoords.tileHeight / 2))
            ..lineTo(pos.x - (IsometricCoords.tileWidth / 2), pos.y)
            ..close();
          final floorStroke = Paint()
            ..color = const Color(0x60A78BFA)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2;
          canvas.drawPath(floorPath, floorStroke);
        } else if (item.isSurfaceItem) {
          final pos = IsometricCoords.gridToScreen(target.x.toDouble(), target.y.toDouble());

          if (isValid) {
            // Magnetic landing pad firmly resting on the tabletop surface
            final targetParent = game._findSurfaceParentAt(target.x, target.y, exclude: item);
            double pDx = 0.0;
            double pDy = 0.0;
            double targetSurfaceH = item.parentSurfaceHeight > 0 ? item.parentSurfaceHeight : 18.0;

            if (targetParent != null) {
              final pMeta = FurnitureCatalogService.getItem(targetParent.typeName) ?? FurnitureCatalogService.getItem(targetParent.id);
              final pRot = pMeta?.rotations[targetParent.rotation];
              if (pRot != null) {
                if (pRot.surfaceHeight > 0) targetSurfaceH = pRot.surfaceHeight.toDouble();
                if (pRot.surfaceOffset.length >= 2) {
                  pDx = pRot.surfaceOffset[0].toDouble();
                  pDy = pRot.surfaceOffset[1].toDouble();
                }
              } else if (pMeta != null) {
                if (pMeta.effectiveSurfaceHeight > 0) targetSurfaceH = pMeta.effectiveSurfaceHeight.toDouble();
                if (pMeta.surfaceOffset.length >= 2) {
                  pDx = pMeta.surfaceOffset[0].toDouble();
                  pDy = pMeta.surfaceOffset[1].toDouble();
                }
              }
            }

            // Item micro-adjustments
            double itemDx = 0.0;
            double itemDy = 0.0;
            final itemMeta = FurnitureCatalogService.getItem(item.typeName) ?? FurnitureCatalogService.getItem(item.id);
            final itemRot = itemMeta?.rotations[item.rotation];
            final offList = itemRot?.spriteOffset ?? itemMeta?.spriteOffset ?? const [-32, -48];
            if (offList.length >= 2) {
              itemDx = (offList[0] + 32.0);
              itemDy = (offList[1] + 48.0);
            }
            if (itemRot != null && itemRot.surfaceHeight != 0) {
              itemDy -= itemRot.surfaceHeight.toDouble();
            } else if (itemMeta != null && itemMeta.surfaceHeight != 0) {
              itemDy -= itemMeta.surfaceHeight.toDouble();
            }

            final landingCenter = Offset(pos.x + pDx + itemDx, pos.y - targetSurfaceH + pDy + itemDy);
            final targetOval = Rect.fromCenter(
              center: landingCenter,
              width: 22,
              height: 12,
            );
            canvas.drawOval(targetOval, fillPaint);
            canvas.drawOval(targetOval, strokePaint);
          } else {
            // Invalid drop (bare ground): draw red ground tile warning
            final path = Path()
              ..moveTo(pos.x, pos.y - (IsometricCoords.tileHeight / 2))
              ..lineTo(pos.x + (IsometricCoords.tileWidth / 2), pos.y)
              ..lineTo(pos.x, pos.y + (IsometricCoords.tileHeight / 2))
              ..lineTo(pos.x - (IsometricCoords.tileWidth / 2), pos.y)
              ..close();
            canvas.drawPath(path, fillPaint);
            canvas.drawPath(path, strokePaint);
          }
        } else {
          for (int x = 0; x < item.gridWidth; x++) {
            for (int y = 0; y < item.gridHeight; y++) {
              final gx = target.x + x;
              final gy = target.y + y;
              final pos = IsometricCoords.gridToScreen(gx.toDouble(), gy.toDouble());

              final path = Path()
                ..moveTo(pos.x, pos.y - (IsometricCoords.tileHeight / 2))
                ..lineTo(pos.x + (IsometricCoords.tileWidth / 2), pos.y)
                ..lineTo(pos.x, pos.y + (IsometricCoords.tileHeight / 2))
                ..lineTo(pos.x - (IsometricCoords.tileWidth / 2), pos.y)
                ..close();

              canvas.drawPath(path, fillPaint);
              canvas.drawPath(path, strokePaint);
            }
          }
        }
      }
    }
  }
}

class _IsometricRoomBackgroundComponent extends Component {
  final int gridSize;
  RoomConfig roomConfig;
  final CozyRoomGame game;

  final Map<String, Sprite> _floorSprites = {};
  final Map<String, Sprite> _wallpaperSprites = {};

  _IsometricRoomBackgroundComponent({
    required this.gridSize,
    required this.roomConfig,
    required this.game,
  }) {
    priority = -100;
  }

  Future<void> loadTextures() async {
    const floorKeys = [
      'oak_parquet',
      'dark_walnut',
      'checker_marble',
      'terracotta_tiles',
      'tatami_mat',
      'solid_tiles',
    ];
    for (final key in floorKeys) {
      try {
        _floorSprites[key] = await game.loadSprite('floors/floor_$key.png');
      } catch (e) {
        print('Error loading floor sprite floors/floor_$key.png: $e');
      }
    }

    const wallpaperKeys = [
      'rustic_wood',
      'brick_stone',
      'cozy_stripes',
      'starry_night',
      'pastel_floral',
      'solid_plaster',
    ];
    for (final key in wallpaperKeys) {
      try {
        _wallpaperSprites[key] = await game.loadSprite('wallpaper/wallpaper_$key.png');
      } catch (e) {
        print('Error loading wallpaper sprite wallpaper/wallpaper_$key.png: $e');
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _renderWalls(canvas);
    _renderFloor(canvas);
  }

  void _renderFloor(Canvas canvas) {
    final floorOpt = RoomThemes.floors.firstWhere(
      (o) => o.id == roomConfig.floor,
      orElse: () => RoomThemes.floors.first,
    );

    final totalGridSize = gridSize * 32.0;

    final pTop = IsometricCoords.gridToScreen(0.0, 0.0);
    final pRight = IsometricCoords.gridToScreen(gridSize.toDouble(), 0.0);
    final pBottom = IsometricCoords.gridToScreen(gridSize.toDouble(), gridSize.toDouble());
    final pLeft = IsometricCoords.gridToScreen(0.0, gridSize.toDouble());

    final floorPath = Path()
      ..moveTo(pTop.x, pTop.y - (IsometricCoords.tileHeight / 2))
      ..lineTo(pRight.x, pRight.y - (IsometricCoords.tileHeight / 2))
      ..lineTo(pBottom.x, pBottom.y - (IsometricCoords.tileHeight / 2))
      ..lineTo(pLeft.x, pLeft.y - (IsometricCoords.tileHeight / 2))
      ..close();

    canvas.save();
    canvas.clipPath(floorPath);

    final matrixFloor = vmath.Matrix4.identity()
      ..translate(0.0, -IsometricCoords.tileHeight / 2)
      ..setEntry(0, 0, 1.0)
      ..setEntry(0, 1, -1.0)
      ..setEntry(1, 0, 0.5)
      ..setEntry(1, 1, 0.5);

    canvas.transform(matrixFloor.storage);

    if (floorOpt.color != null) {
      // Solid color with subtle ceramic tile texture
      final baseTileSprite = _floorSprites['solid_tiles'];
      if (baseTileSprite != null) {
        final tintPaint = Paint()
          ..colorFilter = ColorFilter.mode(floorOpt.color!, BlendMode.modulate);
        baseTileSprite.render(
          canvas,
          position: Vector2.zero(),
          size: Vector2(totalGridSize, totalGridSize),
          overridePaint: tintPaint,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, totalGridSize, totalGridSize),
          Paint()..color = floorOpt.color!,
        );
      }
    } else {
      final floorSprite = _floorSprites[roomConfig.floor];
      if (floorSprite != null) {
        floorSprite.render(
          canvas,
          position: Vector2.zero(),
          size: Vector2(totalGridSize, totalGridSize),
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, totalGridSize, totalGridSize),
          Paint()..color = const Color(0xFF8D6E63),
        );
      }
    }

    // 2. Render Custom Floor Tile Overrides (each tile displays 1/8th slice of the general texture)
    if (roomConfig.floorOverrides.isNotEmpty) {
      final Map<String, List<Point<int>>> floorGroups = {};
      for (final entry in roomConfig.floorOverrides.entries) {
        final parts = entry.key.split(',');
        if (parts.length != 2) continue;
        final gx = int.tryParse(parts[0]);
        final gy = int.tryParse(parts[1]);
        if (gx == null || gy == null || gx < 0 || gx >= gridSize || gy < 0 || gy >= gridSize) continue;
        floorGroups.putIfAbsent(entry.value, () => []).add(Point(gx, gy));
      }

      for (final group in floorGroups.entries) {
        final tileFloorId = group.key;
        final tiles = group.value;
        final tileFloorOpt = RoomThemes.floors.firstWhere(
          (o) => o.id == tileFloorId,
          orElse: () => RoomThemes.floors.first,
        );

        final groupPath = Path();
        for (final p in tiles) {
          groupPath.addRect(Rect.fromLTWH(p.x * 32.0, p.y * 32.0, 32.0, 32.0));
        }

        canvas.save();
        canvas.clipPath(groupPath);

        if (tileFloorOpt.color != null) {
          final baseTileSprite = _floorSprites['solid_tiles'];
          if (baseTileSprite != null) {
            final tintPaint = Paint()
              ..colorFilter = ColorFilter.mode(tileFloorOpt.color!, BlendMode.modulate);
            baseTileSprite.render(
              canvas,
              position: Vector2.zero(),
              size: Vector2(totalGridSize, totalGridSize),
              overridePaint: tintPaint,
            );
          } else {
            canvas.drawPath(groupPath, Paint()..color = tileFloorOpt.color!);
          }
        } else {
          final tileSprite = _floorSprites[tileFloorId];
          if (tileSprite != null) {
            tileSprite.render(
              canvas,
              position: Vector2.zero(),
              size: Vector2(totalGridSize, totalGridSize),
            );
          } else {
            canvas.drawPath(groupPath, Paint()..color = const Color(0xFF8D6E63));
          }
        }

        canvas.restore();
      }
    }

    canvas.restore();
  }

  void _renderWalls(Canvas canvas) {
    final wallHeight = 70.0;
    final totalWallWidth = gridSize * 32.0;

    final wpOpt = RoomThemes.wallpapers.firstWhere(
      (o) => o.id == roomConfig.wallpaper,
      orElse: () => RoomThemes.wallpapers.first,
    );

    final isSolidColor = wpOpt.color != null;
    final Sprite? wpSprite = isSolidColor
        ? _wallpaperSprites['solid_plaster']
        : _wallpaperSprites[roomConfig.wallpaper];
    final Paint? wpPaint = isSolidColor
        ? (Paint()..colorFilter = ColorFilter.mode(wpOpt.color!, BlendMode.modulate))
        : null;

    // NW Wall
    final pNW_start = IsometricCoords.gridToScreen(0.0, 0.0);

    canvas.save();
    final matrixNW = vmath.Matrix4.identity()
      ..translate(pNW_start.x, pNW_start.y - (IsometricCoords.tileHeight / 2) - wallHeight)
      ..setEntry(1, 0, 0.5);

    canvas.transform(matrixNW.storage);

    if (wpSprite != null) {
      wpSprite.render(
        canvas,
        position: Vector2.zero(),
        size: Vector2(totalWallWidth, wallHeight),
        overridePaint: wpPaint,
      );
    }
    canvas.restore();

    // NE Wall
    final pNE_start = IsometricCoords.gridToScreen(0.0, 0.0);

    canvas.save();
    final matrixNE = vmath.Matrix4.identity()
      ..translate(pNE_start.x, pNE_start.y - (IsometricCoords.tileHeight / 2) - wallHeight)
      ..setEntry(0, 0, -1.0)
      ..setEntry(1, 0, 0.5);

    canvas.transform(matrixNE.storage);

    if (wpSprite != null) {
      wpSprite.render(
        canvas,
        position: Vector2.zero(),
        size: Vector2(totalWallWidth, wallHeight),
        overridePaint: wpPaint,
      );
    }
    canvas.restore();
  }
}

class _TapWaveComponent extends Component {
  final Point<int> grid;
  final bool isSnap;
  double progress = 0.0;

  _TapWaveComponent({required this.grid, this.isSnap = false}) {
    priority = 500;
  }

  @override
  void update(double dt) {
    super.update(dt);
    progress += dt * (isSnap ? 4.0 : 3.0);
    if (progress >= 1.0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final pos = IsometricCoords.gridToScreen(grid.x.toDouble(), grid.y.toDouble());
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final waveColor = isSnap ? const Color(0xFF00E5FF) : const Color(0xFFFFD54F);

    final paint = Paint()
      ..color = waveColor.withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSnap ? 3.5 : 2.5;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.x, pos.y),
        width: IsometricCoords.tileWidth * progress,
        height: IsometricCoords.tileHeight * progress,
      ),
      paint,
    );
  }
}
