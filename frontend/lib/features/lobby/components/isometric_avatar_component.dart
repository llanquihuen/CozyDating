import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/components/modular_avatar_component.dart';
import '../utils/isometric_coords.dart';
import '../utils/isometric_pathfinder.dart';
import 'isometric_furniture_component.dart';

class IsometricAvatarComponent extends PositionComponent {
  double gridX;
  double gridY;
  final AvatarConfig config;
  final void Function(Point<int> dest)? onReachedDestination;

  late ModularAvatarComponent avatarRenderer;
  final List<Point<int>> _path = [];
  Point<int>? _finalGoal;
  bool isVisible = true;
  IsometricFurnitureComponent? sittingChair;

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
  }) : super(size: Vector2(avatarWidth, avatarHeight)) {
    position = _calculateScreenPosition(gridX, gridY);
    priority =
        IsometricCoords.getSubZOrder(gridX.round(), gridY.round(), layer: 100);

    avatarRenderer = ModularAvatarComponent(
      config: config,
      direction: AvatarDirection.down,
      isMoving: false,
      size: Vector2(avatarWidth, avatarHeight),
    );
    add(avatarRenderer);
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

  void sitOnChair(IsometricFurnitureComponent chair) {
    _path.clear();
    _finalGoal = null;
    sittingChair = chair;

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

    gridX = chair.gridX * 2.0;
    gridY = chair.gridY * 2.0;

    // Standard sub-cell alignment + micro-ajuste configurable según tipo de mueble y rotación
    final basePos = _calculateScreenPosition(gridX, gridY);
    final fineOffset = _getChairSeatOffset(chair);
    position = basePos + fineOffset;

    // Sit above the chair base (chair.priority), but behind the chair backrest overlay (chair.priority + 20) for rot 2 & 3
    priority = chair.priority + 10;
    avatarRenderer.sitDown();
  }

  /// Permite ajustar finamente la posición (en píxeles de pantalla) donde se sienta el avatar
  /// según el tipo de mueble (chair.typeName o chair.id) y su rotación (0: SW, 1: SE, 2: NE, 3: NW).
  ///
  /// Coordenadas de pantalla:
  /// - X positivo (+) mueve al personaje hacia la DERECHA.
  /// - X negativo (-) mueve al personaje hacia la IZQUIERDA.
  /// - Y positivo (+) mueve al personaje hacia ABAJO (más adelante/bajo en la pantalla).
  /// - Y negativo (-) mueve al personaje hacia ARRIBA (más alto en la pantalla).
  Vector2 _getChairSeatOffset(IsometricFurnitureComponent chair) {
    switch (chair.rotation) {
      case 3: // NW: 5 píxeles más a la izquierda (-5.0), 3 píxeles más arriba (-3.0)
        return Vector2(-5.0, 2.0);
      case 0: // SW
        return Vector2(-2.0, 0);
      case 1: // SE
      case 2: // NE
        return Vector2(5.0, 2.0);
      default:
        return Vector2.zero();
    }
  }

  Point<int>? findExitSubCellForChair(
    IsometricFurnitureComponent chair, {
    Set<Point<int>>? obstacles,
    Set<String>? blockedEdges,
    int mapSize = 16,
  }) {
    final baseU = (chair.gridX * 2).round();
    final baseV = (chair.gridY * 2).round();

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
          const Point(1, 0),
          const Point(-1, 0),
          const Point(0, -1),
        ];
        break;
      case 1: // SE
        deltas = [
          const Point(1, 0),
          const Point(2, 0),
          const Point(0, 1),
          const Point(0, -1),
          const Point(-1, 0),
        ];
        break;
      case 2: // NE
        deltas = [
          const Point(0, -1),
          const Point(0, -2),
          const Point(1, 0),
          const Point(-1, 0),
          const Point(0, 1),
        ];
        break;
      case 3: // NW
        deltas = [
          const Point(-1, 0),
          const Point(-2, 0),
          const Point(0, 1),
          const Point(0, -1),
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

    final obs = obstacles ?? const <Point<int>>{};
    final edges = blockedEdges ?? const <String>{};

    for (final d in deltas) {
      final target = Point(baseU + d.x, baseV + d.y);
      if (target.x >= 0 &&
          target.x < mapSize &&
          target.y >= 0 &&
          target.y < mapSize) {
        if (!obs.contains(target)) {
          final edge =
              IsometricPathfinder.edgeKey(baseU, baseV, target.x, target.y);
          if (!edges.contains(edge)) {
            return target;
          }
        }
      }
    }

    // Fallback search around 1-tile radius if preferred directions are blocked
    for (int du = -1; du <= 1; du++) {
      for (int dv = -1; dv <= 1; dv++) {
        if (du == 0 && dv == 0) continue;
        final target = Point(baseU + du, baseV + dv);
        if (target.x >= 0 &&
            target.x < mapSize &&
            target.y >= 0 &&
            target.y < mapSize) {
          if (!obs.contains(target)) {
            return target;
          }
        }
      }
    }

    return null;
  }

  void standUp({Set<Point<int>>? obstacles, Set<String>? blockedEdges}) {
    if (avatarRenderer.isSitting) {
      if (sittingChair != null) {
        final exitSubCell = findExitSubCellForChair(
          sittingChair!,
          obstacles: obstacles,
          blockedEdges: blockedEdges,
        );
        if (exitSubCell != null) {
          gridX = exitSubCell.x.toDouble();
          gridY = exitSubCell.y.toDouble();
          position = _calculateScreenPosition(gridX, gridY);
        }
      }
      avatarRenderer.standUp();
      sittingChair = null;
      priority = IsometricCoords.getSubZOrder(gridX.round(), gridY.round(),
          layer: 100);
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
