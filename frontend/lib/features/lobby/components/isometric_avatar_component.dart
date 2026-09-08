import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/components/modular_avatar_component.dart';
import '../data/chair_seat_config.dart';
import '../utils/isometric_coords.dart';
import '../utils/isometric_pathfinder.dart';
import 'isometric_furniture_component.dart';

class IsometricAvatarComponent extends PositionComponent {
  double gridX;
  double gridY;
  final AvatarConfig config;
  final void Function(Point<int> dest)? onReachedDestination;
  final VoidCallback? onSitStateChanged;

  late ModularAvatarComponent avatarRenderer;
  final List<Point<int>> _path = [];
  Point<int>? _finalGoal;
  bool isVisible = true;
  IsometricFurnitureComponent? sittingChair;
  SeatSpot? sittingSpot;
  AvatarBacklegComponent? backlegComponent;

  int get sittingSlotIndex => sittingSpot?.slotIndex ?? 0;
  bool get isSitting => avatarRenderer.isSitting;
  bool get isMoving => avatarRenderer.isMoving;

  static const double walkSpeed =
      5.6; // Sub-tiles per second (matching 2.8 full tiles/s)

  // Compact Chibi proportion (1:2 aspect ratio matching 64x128 sprites)
  static const double avatarWidth = 30.0;
  static const double avatarHeight = 60.0;
  // Offset in pixels from bottom of the sprite to where feet contact the ground
  static const double feetBottomPadding = 4.0;

  IsometricAvatarComponent({
    required this.gridX,
    required this.gridY,
    required this.config,
    this.onReachedDestination,
    this.onSitStateChanged,
  }) : super(size: Vector2(avatarWidth, avatarHeight)) {
    position = _calculateScreenPosition(gridX, gridY);
    priority =
        IsometricCoords.getSubZOrder(gridX.round(), gridY.round(), layer: 100);

    avatarRenderer = ModularAvatarComponent(
      config: config,
      direction: AvatarDirection.down,
      isMoving: false,
      renderBacklegSeparately: true,
      size: Vector2(avatarWidth, avatarHeight),
    );
    add(avatarRenderer);
    backlegComponent = AvatarBacklegComponent(this);
  }

  @override
  void onMount() {
    super.onMount();
    avatarRenderer.renderBacklegSeparately = true;
    backlegComponent ??= AvatarBacklegComponent(this);
    if (!backlegComponent!.isMounted && parent != null) {
      parent!.add(backlegComponent!);
    }
  }

  @override
  void onRemove() {
    backlegComponent?.removeFromParent();
    backlegComponent = null;
    super.onRemove();
  }

  /// Calculates the screen position that places the avatar's feet EXACTLY in the center of sub-cell (u, v)
  Vector2 _calculateScreenPosition(double u, double v) {
    // Center point of the isometric sub-grid diamond
    final centerTile = IsometricCoords.subGridToScreen(u, v);
    // Align bottom center of avatar feet with center of sub-grid tile diamond
    return Vector2(
      centerTile.x - (avatarWidth / 2.0),
      centerTile.y - (avatarHeight - feetBottomPadding),
    );
  }

  void sitOnChair(IsometricFurnitureComponent chair, {SeatSpot? spot}) {
    _path.clear();
    _finalGoal = null;
    sittingChair = chair;

    final chosenSpot = spot ?? ChairSeatConfig.getSpots(chair, chair.rotation).first;
    sittingSpot = chosenSpot;

    // Chair rotation to avatar diagonal direction:
    // 0: SW -> AvatarDirection.southWest (8)
    // 1: SE -> AvatarDirection.southEast (2)
    // 2: NE -> AvatarDirection.northEast (4)
    // 3: NW -> AvatarDirection.northWest (6)
    switch (chair.rotation) {
      case 0:
        avatarRenderer.direction = AvatarDirection.southWest;
        break;
      case 1:
        avatarRenderer.direction = AvatarDirection.southEast;
        break;
      case 2:
        avatarRenderer.direction = AvatarDirection.northEast;
        break;
      case 3:
        avatarRenderer.direction = AvatarDirection.northWest;
        break;
      default:
        avatarRenderer.direction = AvatarDirection.southWest;
    }

    gridX = chair.gridX * 2.0 + chosenSpot.subCell.x;
    gridY = chair.gridY * 2.0 + chosenSpot.subCell.y;

    // Sub-cell alignment + micro-ajuste visual configurable según ChairSeatConfig
    final basePos = _calculateScreenPosition(gridX, gridY);
    position = basePos + chosenSpot.visualOffset;

    // Sit above the chair base (chair.priority), but behind the chair backrest overlay (chair.priority + 20) for rot 2 & 3
    priority = chair.priority + 10;
    backlegComponent ??= AvatarBacklegComponent(this);
    backlegComponent!.priority = chair.priority - 2;
    avatarRenderer.sitDown();
    onSitStateChanged?.call();
  }

  Set<Point<int>>? lastObstacles;
  Set<String>? lastBlockedEdges;

  Point<int>? findExitSubCellForChair(
    IsometricFurnitureComponent chair, {
    SeatSpot? spot,
    Set<Point<int>>? obstacles,
    Set<String>? blockedEdges,
    int mapSize = 16,
  }) {
    final effectiveSpot = spot ?? sittingSpot;
    final baseU = (chair.gridX * 2).round() + (effectiveSpot?.subCell.x ?? 0);
    final baseV = (chair.gridY * 2).round() + (effectiveSpot?.subCell.y ?? 0);
    final startCell = Point(baseU, baseV);

    final obs = obstacles ?? lastObstacles ?? const <Point<int>>{};
    final edges = blockedEdges ?? lastBlockedEdges ?? const <String>{};
    final chairFootprint = chair.occupiedSubCells.toSet();

    // Priority of exit deltas based on chair facing rotation:
    // 0 (SW): facing (0, +1)
    // 1 (SE): facing (+1, 0)
    // 2 (NE): facing (0, -1)
    // 3 (NW): facing (-1, 0)
    final List<Point<int>> deltas;
    switch (chair.rotation) {
      case 0: // SW
        deltas = [
          const Point(0, 1),
          const Point(0, 2),
          const Point(0, 3),
          const Point(1, 0),
          const Point(-1, 0),
          const Point(1, 1),
          const Point(-1, 1),
          const Point(0, -1),
        ];
        break;
      case 1: // SE
        deltas = [
          const Point(1, 0),
          const Point(2, 0),
          const Point(3, 0),
          const Point(0, 1),
          const Point(0, -1),
          const Point(1, 1),
          const Point(1, -1),
          const Point(-1, 0),
        ];
        break;
      case 2: // NE
        deltas = [
          const Point(0, -1),
          const Point(0, -2),
          const Point(0, -3),
          const Point(1, 0),
          const Point(-1, 0),
          const Point(1, -1),
          const Point(-1, -1),
          const Point(0, 1),
        ];
        break;
      case 3: // NW
        deltas = [
          const Point(-1, 0),
          const Point(-2, 0),
          const Point(-3, 0),
          const Point(0, 1),
          const Point(0, -1),
          const Point(-1, 1),
          const Point(-1, -1),
          const Point(1, 0),
        ];
        break;
      default:
        deltas = [
          const Point(0, 1),
          const Point(1, 0),
          const Point(0, -1),
          const Point(-1, 0),
        ];
    }

    // BFS search outward from startCell:
    // Guarantees that any exit cell found has a continuous walkable path
    // that NEVER crosses blockedEdges (internal walls) or other furniture obstacles.
    final queue = <Point<int>>[startCell];
    final visited = <Point<int>>{startCell};
    final distance = <Point<int>, int>{startCell: 0};
    final reachableFreeCells = <Point<int>>[];
    final reachableFreeSet = <Point<int>>{};

    const maxSearchDistance = 4;

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      final dist = distance[current]!;
      if (dist >= maxSearchDistance) continue;

      final neighbors = [
        Point(current.x + 1, current.y),
        Point(current.x - 1, current.y),
        Point(current.x, current.y + 1),
        Point(current.x, current.y - 1),
      ];

      for (final next in neighbors) {
        if (next.x < 0 || next.x >= mapSize || next.y < 0 || next.y >= mapSize) {
          continue;
        }
        if (visited.contains(next)) continue;

        // Check internal wall boundary between current and next
        final edge = IsometricPathfinder.edgeKey(current.x, current.y, next.x, next.y);
        if (edges.contains(edge)) {
          continue; // Wall blocks movement!
        }

        visited.add(next);
        distance[next] = dist + 1;

        final isChairSubCell = chairFootprint.contains(next);
        final isObstacle = obs.contains(next);

        if (!isObstacle && !isChairSubCell) {
          // Found a completely free, wall-safe reachable subcell outside the chair
          reachableFreeCells.add(next);
          reachableFreeSet.add(next);
        } else if (isChairSubCell) {
          // Can walk across the chair's own subcells (e.g. from sofa seat to sofa edge)
          queue.add(next);
        }
        // If it is another obstacle not belonging to the chair, queue does not expand through it.
      }
    }

    // 1. First priority: Check preferred directional deltas
    for (final d in deltas) {
      final target = Point(baseU + d.x, baseV + d.y);
      if (reachableFreeSet.contains(target)) {
        return target;
      }
    }

    // 2. Second priority: If no directional delta matched, pick the closest reachable free cell
    if (reachableFreeCells.isNotEmpty) {
      final Point<int> facingVec;
      switch (chair.rotation) {
        case 0:
          facingVec = const Point(0, 1);
          break;
        case 1:
          facingVec = const Point(1, 0);
          break;
        case 2:
          facingVec = const Point(0, -1);
          break;
        case 3:
          facingVec = const Point(-1, 0);
          break;
        default:
          facingVec = const Point(0, 1);
      }

      reachableFreeCells.sort((a, b) {
        final distA = distance[a] ?? 999;
        final distB = distance[b] ?? 999;
        if (distA != distB) {
          return distA.compareTo(distB);
        }
        final dotA = (a.x - baseU) * facingVec.x + (a.y - baseV) * facingVec.y;
        final dotB = (b.x - baseU) * facingVec.x + (b.y - baseV) * facingVec.y;
        return dotB.compareTo(dotA);
      });

      return reachableFreeCells.first;
    }

    return null;
  }

  void standUp({Set<Point<int>>? obstacles, Set<String>? blockedEdges}) {
    if (obstacles != null) lastObstacles = obstacles;
    if (blockedEdges != null) lastBlockedEdges = blockedEdges;
    final effectiveObs = obstacles ?? lastObstacles;
    final effectiveEdges = blockedEdges ?? lastBlockedEdges;

    if (avatarRenderer.isSitting) {
      if (sittingChair != null) {
        final exitSubCell = findExitSubCellForChair(
          sittingChair!,
          spot: sittingSpot,
          obstacles: effectiveObs,
          blockedEdges: effectiveEdges,
        );
        if (exitSubCell != null) {
          gridX = exitSubCell.x.toDouble();
          gridY = exitSubCell.y.toDouble();
          position = _calculateScreenPosition(gridX, gridY);
        }
      }
      avatarRenderer.standUp();
      sittingChair = null;
      sittingSpot = null;
      priority = IsometricCoords.getSubZOrder(gridX.round(), gridY.round(),
          layer: 100);
      onSitStateChanged?.call();
    }
  }

  void setPath(List<Point<int>> newPath, Point<int> goal) {
    if (avatarRenderer.isSitting) {
      standUp();
    }
    _path.clear();
    _path.addAll(newPath);
    _finalGoal = goal;
    if (_path.isNotEmpty) {
      avatarRenderer.isMoving = true;
    }
  }

  void teleportTo(double gx, double gy) {
    if (avatarRenderer.isSitting) {
      standUp();
    }
    _path.clear();
    _finalGoal = null;
    avatarRenderer.isMoving = false;
    gridX = gx;
    gridY = gy;
    position = _calculateScreenPosition(gridX, gridY);
    priority =
        IsometricCoords.getSubZOrder(gridX.round(), gridY.round(), layer: 100);
  }

  void updateConfig(AvatarConfig newConfig) {
    avatarRenderer.updateConfig(newConfig);
  }

  @override
  void renderTree(Canvas canvas) {
    if (!isVisible) return;
    super.renderTree(canvas);
  }

  @override
  void render(Canvas canvas) {
    if (!isVisible) return;
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!isVisible) return;

    if (_path.isNotEmpty) {
      final target = _path.first;
      final targetX = target.x.toDouble();
      final targetY = target.y.toDouble();

      final dx = targetX - gridX;
      final dy = targetY - gridY;
      final dist = sqrt(dx * dx + dy * dy);

      // Determine Facing Direction across all 8 directions based on screen-space velocity
      if (dist > 0.001) {
        final sx = (dx - dy) * IsometricCoords.subStepX;
        final sy = (dx + dy) * IsometricCoords.subStepY;
        final angle = atan2(sy, sx); // -pi to +pi radians
        final normAngle = (angle + 2 * pi) % (2 * pi);
        final sector = ((normAngle + pi / 8) / (pi / 4)).floor() % 8;

        switch (sector) {
          case 0:
            avatarRenderer.direction = AvatarDirection.east; // 3
            break;
          case 1:
            avatarRenderer.direction = AvatarDirection.southEast; // 2
            break;
          case 2:
            avatarRenderer.direction = AvatarDirection.south; // 1
            break;
          case 3:
            avatarRenderer.direction = AvatarDirection.southWest; // 8
            break;
          case 4:
            avatarRenderer.direction = AvatarDirection.west; // 7
            break;
          case 5:
            avatarRenderer.direction = AvatarDirection.northWest; // 6
            break;
          case 6:
            avatarRenderer.direction = AvatarDirection.north; // 5
            break;
          case 7:
            avatarRenderer.direction = AvatarDirection.northEast; // 4
            break;
        }
      }

      final step = walkSpeed * dt;
      if (step >= dist) {
        gridX = targetX;
        gridY = targetY;
        _path.removeAt(0);

        if (_path.isEmpty) {
          avatarRenderer.isMoving = false;
          if (_finalGoal != null) {
            final goal = _finalGoal!;
            _finalGoal = null;
            onReachedDestination?.call(goal);
          }
          if (avatarRenderer.isSitting) {
            return;
          }
        }
      } else {
        gridX += (dx / dist) * step;
        gridY += (dy / dist) * step;
      }

      // Update Screen Position and Z-sorting depth
      position = _calculateScreenPosition(gridX, gridY);
      priority = IsometricCoords.getSubZOrder(gridX.round(), gridY.round(),
          layer: 100);
    }
  }
}

/// Overlay component that renders the seated avatar's backleg (and backleg clothing)
/// behind the chair or sofa base (priority = chair.priority - 2).
class AvatarBacklegComponent extends PositionComponent {
  final IsometricAvatarComponent avatar;

  AvatarBacklegComponent(this.avatar)
      : super(size: Vector2(IsometricAvatarComponent.avatarWidth, IsometricAvatarComponent.avatarHeight));

  @override
  void update(double dt) {
    super.update(dt);
    position = avatar.position;
    size = avatar.size;

    if (avatar.isSitting && avatar.sittingChair != null) {
      // Sits directly BEHIND the chair / sofa base (chair.priority)
      priority = avatar.sittingChair!.priority - 2;
    }
  }

  @override
  void render(Canvas canvas) {
    if (!avatar.isVisible || !avatar.isSitting) return;
    avatar.avatarRenderer.renderBackleg(canvas, size);
  }
}

