import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import '../../../core/models/avatar_config.dart';
import '../../../core/models/room_config.dart';
import '../components/isometric_avatar_component.dart';
import '../components/isometric_furniture_component.dart';
import '../utils/isometric_coords.dart';
import '../utils/isometric_pathfinder.dart';

class CozyRoomGame extends FlameGame with DragCallbacks {
  AvatarConfig avatarConfig;
  RoomConfig roomConfig;
  final VoidCallback? onOpenWardrobe;
  final VoidCallback? onOpenMatchmaking;
  final ValueChanged<IsometricFurnitureComponent?>? onFurnitureSelected;

  late IsometricAvatarComponent avatar;
  late _IsometricRoomBackgroundComponent _backgroundComponent;
  final Set<Point<int>> obstacles = {};

  // Decorate Mode Flag
  bool isDecorateMode = false;
  IsometricFurnitureComponent? selectedFurniture;

  // Drag-and-Drop state for furniture
  IsometricFurnitureComponent? _draggedFurniture;
  Point<int>? _originalGridPos;
  Point<int>? _currentHoverGrid;
  bool _isValidDropLocation = true;
  Vector2? _dragStartWorldPos;

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
  });

  @override
  Color backgroundColor() => const Color(0xFF16141D);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 1. Add Isometric Room Floor & Walls inside world (priority: -100)
    _backgroundComponent = _IsometricRoomBackgroundComponent(
      gridSize: gridSize,
      roomConfig: roomConfig,
      game: this,
    );
    await _backgroundComponent.loadTextures();
    world.add(_backgroundComponent);

    // 2. Add Drag Highlighting Layer inside world (priority: 50)
    world.add(_DragHighlightLayer(game: this));

    // 3. Load Placed Furniture from roomConfig
    await _loadFurnitureFromConfig(roomConfig);

    // 4. Adventure Portal (Fixed interactive portal)
    world.add(IsometricFurnitureComponent(
      gridX: 6,
      gridY: 6,
      type: FurnitureType.portal,
      onInteract: onOpenMatchmaking,
    ));

    // 5. Register Initial Obstacles for all solid furniture
    _recalculateObstacles();

    // 6. Add Player Avatar inside world
    avatar = IsometricAvatarComponent(
      gridX: 4.0,
      gridY: 4.0,
      config: avatarConfig,
      onReachedDestination: _handleDestinationReached,
    );
    if (isDecorateMode) {
      avatar.isVisible = false;
    }
    world.add(avatar);
  }

  void setDecorateMode(bool enabled) {
    isDecorateMode = enabled;
    if (enabled) {
      // Hide avatar during decoration
      avatar.isVisible = false;
      selectFurniture(null);
    } else {
      // Find a safe free walkable tile to respawn avatar
      _recalculateObstacles();
      Point<int> spawnTile = const Point(4, 4);
      bool found = false;

      // Prefer center tiles
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

      avatar.teleportTo(spawnTile.x.toDouble(), spawnTile.y.toDouble());
      avatar.isVisible = true;
      selectFurniture(null);
    }
  }

  Future<void> _loadFurnitureFromConfig(RoomConfig config) async {
    final existing = world.children.whereType<IsometricFurnitureComponent>().where((f) => f.type != FurnitureType.portal).toList();
    for (final f in existing) {
      f.removeFromParent();
    }

    for (final item in config.furniture) {
      final rotSprites = await _loadRotationSprites(item.assetPath);

      FurnitureType type;
      switch (item.typeName) {
        case 'wardrobe':
          type = FurnitureType.wardrobe;
          break;
        case 'bed':
          type = FurnitureType.bed;
          break;
        case 'plant':
          type = FurnitureType.plant;
          break;
        case 'table':
          type = FurnitureType.table;
          break;
        default:
          type = FurnitureType.table;
          break;
      }

      final comp = IsometricFurnitureComponent(
        gridX: item.gridX,
        gridY: item.gridY,
        gridWidth: item.gridWidth,
        gridHeight: item.gridHeight,
        rotation: item.rotation,
        type: type,
        baseAssetPath: item.assetPath,
        sprite: rotSprites[item.rotation] ?? rotSprites[0],
        rotationSprites: rotSprites,
        onInteract: (type == FurnitureType.wardrobe) ? onOpenWardrobe : null,
      );
      world.add(comp);
    }
  }

  Future<Map<int, Sprite>> _loadRotationSprites(String? baseAssetPath) async {
    final Map<int, Sprite> map = {};
    if (baseAssetPath == null) return map;

    final cleanPath = baseAssetPath.replaceAll('.png', '');
    for (int rot = 0; rot < 4; rot++) {
      try {
        final spr = await loadSprite('${cleanPath}_$rot.png');
        map[rot] = spr;
      } catch (_) {
        try {
          final sprBase = await loadSprite('$cleanPath.png');
          map[rot] = sprBase;
        } catch (_) {}
      }
    }
    return map;
  }

  Future<void> addDynamicFurniture(FurnitureType type, int gw, int gh, String? assetPath) async {
    final rotSprites = await _loadRotationSprites(assetPath);

    Point<int> spawnPos = const Point(4, 4);
    for (int r = 0; r <= gridSize - gw; r++) {
      for (int c = 0; c <= gridSize - gh; c++) {
        final p = Point(r, c);
        final temp = IsometricFurnitureComponent(gridX: r, gridY: c, gridWidth: gw, gridHeight: gh, type: type);
        if (_checkIsValidLocation(temp, p)) {
          spawnPos = p;
          break;
        }
      }
    }

    final comp = IsometricFurnitureComponent(
      gridX: spawnPos.x,
      gridY: spawnPos.y,
      gridWidth: gw,
      gridHeight: gh,
      rotation: 0,
      type: type,
      baseAssetPath: assetPath,
      sprite: rotSprites[0],
      rotationSprites: rotSprites,
      onInteract: (type == FurnitureType.wardrobe) ? onOpenWardrobe : null,
    );
    world.add(comp);
    selectFurniture(comp);
    _recalculateObstacles();
  }

  void rotateSelectedFurniture() {
    if (selectedFurniture == null || selectedFurniture!.type == FurnitureType.portal) return;

    final comp = selectedFurniture!;
    final nextW = comp.gridHeight;
    final nextH = comp.gridWidth;

    // Check if new footprint fits inside grid
    int targetX = comp.gridX;
    int targetY = comp.gridY;

    if (targetX + nextW > gridSize) {
      targetX = gridSize - nextW;
    }
    if (targetY + nextH > gridSize) {
      targetY = gridSize - nextH;
    }

    // Check collision with other furniture
    bool fits = true;
    final others = world.children.whereType<IsometricFurnitureComponent>().where((f) => f != comp && f.type != FurnitureType.carpet);
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
    if (comp.type == FurnitureType.portal) return;
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
    }
    onFurnitureSelected?.call(comp);
  }

  void _recalculateObstacles() {
    obstacles.clear();
    final allFurniture = world.children.whereType<IsometricFurnitureComponent>();
    for (final f in allFurniture) {
      if (f.type == FurnitureType.carpet) continue;
      for (int x = 0; x < f.gridWidth; x++) {
        for (int y = 0; y < f.gridHeight; y++) {
          obstacles.add(Point(f.gridX + x, f.gridY + y));
        }
      }
    }
  }

  bool _checkIsValidLocation(IsometricFurnitureComponent item, Point<int> target) {
    if (target.x < 0 || target.x + item.gridWidth > gridSize || target.y < 0 || target.y + item.gridHeight > gridSize) {
      return false;
    }

    final allFurniture = world.children.whereType<IsometricFurnitureComponent>().where((f) => f != item);
    for (final f in allFurniture) {
      if (f.type == FurnitureType.carpet) continue;
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

    final wardrobe = world.children.whereType<IsometricFurnitureComponent>().where((f) => f.type == FurnitureType.wardrobe).firstOrNull;
    if (wardrobe != null) {
      if ((dest.x - wardrobe.gridX).abs() <= 1 && (dest.y - wardrobe.gridY).abs() <= 1) {
        onOpenWardrobe?.call();
      }
    }

    final portal = world.children.whereType<IsometricFurnitureComponent>().where((f) => f.type == FurnitureType.portal).firstOrNull;
    if (portal != null) {
      if ((dest.x - portal.gridX).abs() <= 1 && (dest.y - portal.gridY).abs() <= 1) {
        onOpenMatchmaking?.call();
      }
    }
  }

  void updateAvatarConfig(AvatarConfig newConfig) {
    avatarConfig = newConfig;
    avatar.updateConfig(newConfig);
  }

  void updateRoomConfig(RoomConfig newConfig) {
    roomConfig = newConfig;
    _backgroundComponent.roomConfig = newConfig;
  }

  RoomConfig exportCurrentRoomConfig() {
    final list = <PlacedFurnitureConfig>[];
    final allFurniture = world.children.whereType<IsometricFurnitureComponent>().where((f) => f.type != FurnitureType.portal);

    int idx = 0;
    for (final f in allFurniture) {
      String typeName = 'table';
      if (f.type == FurnitureType.wardrobe) typeName = 'wardrobe';
      if (f.type == FurnitureType.bed) typeName = 'bed';
      if (f.type == FurnitureType.plant) typeName = 'plant';
      if (f.type == FurnitureType.table) typeName = 'table';

      list.add(PlacedFurnitureConfig(
        id: 'item_${idx++}',
        typeName: typeName,
        gridX: f.gridX,
        gridY: f.gridY,
        gridWidth: f.gridWidth,
        gridHeight: f.gridHeight,
        rotation: f.rotation,
        assetPath: f.baseAssetPath,
      ));
    }

    return roomConfig.copyWith(furniture: list);
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

      // Higher initial zoom for an immersive, close-up lobby view
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
    const maxScrollSpeed = 280.0; // Screen pixels per second

    double panX = 0.0;
    double panY = 0.0;

    // Left Edge
    if (pos.x < edgeMargin) {
      final intensity = ((edgeMargin - pos.x) / edgeMargin).clamp(0.0, 1.0);
      panX = maxScrollSpeed * intensity * dt;
    }
    // Right Edge
    else if (pos.x > size.x - edgeMargin) {
      final intensity = ((pos.x - (size.x - edgeMargin)) / edgeMargin).clamp(0.0, 1.0);
      panX = -maxScrollSpeed * intensity * dt;
    }

    // Top Edge
    if (pos.y < topMargin) {
      final intensity = ((topMargin - pos.y) / topMargin).clamp(0.0, 1.0);
      panY = maxScrollSpeed * intensity * dt;
    }
    // Bottom Edge
    else if (pos.y > size.y - bottomMargin) {
      final intensity = ((pos.y - (size.y - bottomMargin)) / bottomMargin).clamp(0.0, 1.0);
      panY = -maxScrollSpeed * intensity * dt;
    }

    if (panX != 0.0 || panY != 0.0) {
      panCamera(Vector2(panX, panY));

      // Recalculate furniture hover location after camera moved
      final currentWorldPos = camera.viewfinder.transform.globalToLocal(pos);
      final rawGrid = IsometricCoords.screenToGrid(currentWorldPos.x, currentWorldPos.y);

      final clX = rawGrid.x.clamp(0, gridSize - _draggedFurniture!.gridWidth);
      final clY = rawGrid.y.clamp(0, gridSize - _draggedFurniture!.gridHeight);
      final clampedGrid = Point(clX, clY);

      _currentHoverGrid = clampedGrid;
      _isValidDropLocation = _checkIsValidLocation(_draggedFurniture!, clampedGrid);

      final targetScreenPos = IsometricCoords.gridToScreen(clampedGrid.x.toDouble(), clampedGrid.y.toDouble());
      final currentScreenPos = IsometricCoords.gridToScreen(_draggedFurniture!.gridX.toDouble(), _draggedFurniture!.gridY.toDouble());
      _draggedFurniture!.dragVisualOffset = targetScreenPos - currentScreenPos;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _lastDragScreenPos = event.localPosition;
    _currentDragScreenPos = event.localPosition;

    final worldPos = camera.viewfinder.transform.globalToLocal(event.localPosition);
    final gridPos = IsometricCoords.screenToGrid(worldPos.x, worldPos.y);

    if (isDecorateMode) {
      // Check if user grabbed a furniture item
      final allFurniture = world.children.whereType<IsometricFurnitureComponent>().toList();
      allFurniture.sort((a, b) => b.priority.compareTo(a.priority));

      bool grabbedFurniture = false;
      for (final f in allFurniture) {
        if (f.type == FurnitureType.portal) continue;
        final occupies = gridPos.x >= f.gridX &&
            gridPos.x < f.gridX + f.gridWidth &&
            gridPos.y >= f.gridY &&
            gridPos.y < f.gridY + f.gridHeight;

        if (occupies) {
          selectFurniture(f);
          _draggedFurniture = f;
          _originalGridPos = Point(f.gridX, f.gridY);
          _currentHoverGrid = Point(f.gridX, f.gridY);
          _dragStartWorldPos = worldPos;
          _isValidDropLocation = true;

          f.isBeingDragged = true;
          f.priority = 9999;
          grabbedFurniture = true;
          break;
        }
      }

      if (!grabbedFurniture) {
        // Dragging empty space in Decorate Mode pans the camera
        _isPanningCamera = true;
      }
    } else {
      // In Normal Mode: Dragging on screen pans the camera
      _isPanningCamera = true;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _currentDragScreenPos = event.localEndPosition;

    if (_isPanningCamera) {
      panCamera(event.localDelta);
      return;
    }

    if (isDecorateMode && _draggedFurniture != null && _dragStartWorldPos != null) {
      final currentWorldPos = camera.viewfinder.transform.globalToLocal(event.localEndPosition);
      final rawGrid = IsometricCoords.screenToGrid(currentWorldPos.x, currentWorldPos.y);

      final clX = rawGrid.x.clamp(0, gridSize - _draggedFurniture!.gridWidth);
      final clY = rawGrid.y.clamp(0, gridSize - _draggedFurniture!.gridHeight);
      final clampedGrid = Point(clX, clY);

      _currentHoverGrid = clampedGrid;
      _isValidDropLocation = _checkIsValidLocation(_draggedFurniture!, clampedGrid);

      final targetScreenPos = IsometricCoords.gridToScreen(clampedGrid.x.toDouble(), clampedGrid.y.toDouble());
      final currentScreenPos = IsometricCoords.gridToScreen(_draggedFurniture!.gridX.toDouble(), _draggedFurniture!.gridY.toDouble());
      _draggedFurniture!.dragVisualOffset = targetScreenPos - currentScreenPos;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
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
    _isPanningCamera = false;
    _lastDragScreenPos = null;
    _currentDragScreenPos = null;
    if (isDecorateMode) {
      _cancelDrag();
    }
  }

  void _finishDrag() {
    if (_draggedFurniture != null) {
      if (_isValidDropLocation && _currentHoverGrid != null) {
        _draggedFurniture!.updateGridPosition(_currentHoverGrid!.x, _currentHoverGrid!.y);
        _recalculateObstacles();
        world.add(_TapWaveComponent(grid: _currentHoverGrid!, isSnap: true));
      } else if (_originalGridPos != null) {
        _draggedFurniture!.updateGridPosition(_originalGridPos!.x, _originalGridPos!.y);
      }

      _draggedFurniture!.dragVisualOffset = Vector2.zero();
      _draggedFurniture!.isBeingDragged = false;
      _draggedFurniture = null;
      _originalGridPos = null;
      _currentHoverGrid = null;
    }
  }

  void _cancelDrag() {
    if (_draggedFurniture != null && _originalGridPos != null) {
      _draggedFurniture!.updateGridPosition(_originalGridPos!.x, _originalGridPos!.y);
      _draggedFurniture!.dragVisualOffset = Vector2.zero();
      _draggedFurniture!.isBeingDragged = false;
      _draggedFurniture = null;
      _originalGridPos = null;
      _currentHoverGrid = null;
    }
  }

  void handleScreenTap(Vector2 screenPosition) {
    final worldPos = camera.viewfinder.transform.globalToLocal(screenPosition);
    final gridPos = IsometricCoords.screenToGrid(worldPos.x, worldPos.y);

    if (isDecorateMode) {
      final allFurniture = world.children.whereType<IsometricFurnitureComponent>().toList();
      allFurniture.sort((a, b) => b.priority.compareTo(a.priority));

      IsometricFurnitureComponent? hit;
      for (final f in allFurniture) {
        if (f.type == FurnitureType.portal) continue;
        if (gridPos.x >= f.gridX &&
            gridPos.x < f.gridX + f.gridWidth &&
            gridPos.y >= f.gridY &&
            gridPos.y < f.gridY + f.gridHeight) {
          hit = f;
          break;
        }
      }
      selectFurniture(hit);
      return;
    }

    // In Normal Mode: Tap-to-move avatar
    if (_draggedFurniture != null) return;

    if (gridPos.x >= 0 && gridPos.x < gridSize && gridPos.y >= 0 && gridPos.y < gridSize) {
      world.add(_TapWaveComponent(grid: gridPos));

      final startPos = Point(avatar.gridX.round(), avatar.gridY.round());
      final path = IsometricPathfinder.findPath(
        start: startPos,
        goal: gridPos,
        obstacles: obstacles,
      );

      if (path.isNotEmpty) {
        avatar.setPath(path, gridPos);
      }
    }
  }
}

/// Renders glowing borders and ground shadow under the furniture currently being dragged
class _DragHighlightLayer extends Component {
  final CozyRoomGame game;

  _DragHighlightLayer({required this.game}) {
    priority = 50;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (game.isDecorateMode && game._draggedFurniture != null) {
      final item = game._draggedFurniture!;

      // 1. Render Previous / Original Position (Warm Golden Amber)
      if (game._originalGridPos != null) {
        final orig = game._originalGridPos!;
        final origStrokePaint = Paint()
          ..color = const Color(0xFFFFB300)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

        final origFillPaint = Paint()..color = const Color(0x35FFB300);

        for (int x = 0; x < item.gridWidth; x++) {
          for (int y = 0; y < item.gridHeight; y++) {
            final gx = orig.x + x;
            final gy = orig.y + y;
            final pos = IsometricCoords.gridToScreen(gx.toDouble(), gy.toDouble());

            final path = Path()
              ..moveTo(pos.x, pos.y - (IsometricCoords.tileHeight / 2))
              ..lineTo(pos.x + (IsometricCoords.tileWidth / 2), pos.y)
              ..lineTo(pos.x, pos.y + (IsometricCoords.tileHeight / 2))
              ..lineTo(pos.x - (IsometricCoords.tileWidth / 2), pos.y)
              ..close();

            canvas.drawPath(path, origFillPaint);
            canvas.drawPath(path, origStrokePaint);
          }
        }
      }

      // 2. Render Target / Hover Position (Neon Cyan if valid, Crimson Red if invalid)
      if (game._currentHoverGrid != null) {
        final target = game._currentHoverGrid!;
        final isValid = game._isValidDropLocation;

        final highlightColor = isValid ? const Color(0xFF00E5FF) : const Color(0xFFFF1744);
        final fillColor = isValid ? const Color(0x4000E5FF) : const Color(0x40FF1744);

        final strokePaint = Paint()
          ..color = highlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

        final fillPaint = Paint()..color = fillColor;

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

        final basePos = IsometricCoords.gridToScreen(
          target.x + (item.gridWidth - 1) / 2.0,
          target.y + (item.gridHeight - 1) / 2.0,
        );
        final shadowWidth = (item.gridWidth + item.gridHeight) * 32.0;
        final shadowHeight = (item.gridWidth + item.gridHeight) * 16.0;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(basePos.x, basePos.y), width: shadowWidth * 0.8, height: shadowHeight * 0.8),
          Paint()..color = Colors.black.withOpacity(0.35)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }
}

/// Renders the isometric floor tiles and wallpaper walls in world space using continuous projection
class _IsometricRoomBackgroundComponent extends Component {
  final int gridSize;
  final CozyRoomGame game;
  RoomConfig roomConfig;

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
    ];
    for (final key in floorKeys) {
      final filename = (key == 'terracotta_tiles') ? 'floor_terracotta.png' : ((key == 'tatami_mat') ? 'floor_tatami.png' : 'floor_$key.png');
      try {
        _floorSprites[key] = await game.loadSprite('floors/$filename');
      } catch (e) {
        print('Error loading floor sprite floors/$filename: $e');
      }
    }

    const wallpaperKeys = [
      'rustic_wood',
      'brick_stone',
      'cozy_stripes',
      'starry_night',
      'pastel_floral',
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
    final floorSprite = _floorSprites[roomConfig.floor];
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

    canvas.restore();
  }

  void _renderWalls(Canvas canvas) {
    final wallHeight = 70.0;
    final totalWallWidth = gridSize * 32.0;
    final wpSprite = _wallpaperSprites[roomConfig.wallpaper];

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
