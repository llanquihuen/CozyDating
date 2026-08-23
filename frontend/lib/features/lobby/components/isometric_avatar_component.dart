import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/components/modular_avatar_component.dart';
import '../utils/isometric_coords.dart';

class IsometricAvatarComponent extends PositionComponent {
  double gridX;
  double gridY;
  final AvatarConfig config;
  final void Function(Point<int> dest)? onReachedDestination;

  late ModularAvatarComponent avatarRenderer;
  final List<Point<int>> _path = [];
  Point<int>? _finalGoal;
  bool isVisible = true;

  static const double walkSpeed = 5.6; // Sub-tiles per second (matching 2.8 full tiles/s)

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
    priority = ((gridX + gridY) * 1000).round() + 20;

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

  void setPath(List<Point<int>> newPath, Point<int> goal) {
    _path.clear();
    _path.addAll(newPath);
    _finalGoal = goal;
    if (_path.isNotEmpty) {
      avatarRenderer.isMoving = true;
    }
  }

  void teleportTo(double gx, double gy) {
    _path.clear();
    _finalGoal = null;
    avatarRenderer.isMoving = false;
    gridX = gx;
    gridY = gy;
    position = _calculateScreenPosition(gridX, gridY);
    priority = ((gridX + gridY) * 1000).round() + 20;
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

      // Determine Facing Direction based on dominant movement axis in isometric space
      if (dx.abs() >= dy.abs()) {
        if (dx > 0.05) {
          avatarRenderer.direction = AvatarDirection.right; // Moving Down-Right
        } else if (dx < -0.05) {
          avatarRenderer.direction = AvatarDirection.left;  // Moving Up-Left
        }
      } else {
        if (dy > 0.05) {
          avatarRenderer.direction = AvatarDirection.down;  // Moving Down-Left (towards screen)
        } else if (dy < -0.05) {
          avatarRenderer.direction = AvatarDirection.up;    // Moving Up-Right (away from screen)
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
            onReachedDestination?.call(_finalGoal!);
            _finalGoal = null;
          }
        }
      } else {
        gridX += (dx / dist) * step;
        gridY += (dy / dist) * step;
      }

      // Update Screen Position and Z-sorting depth
      position = _calculateScreenPosition(gridX, gridY);
      priority = ((gridX + gridY) * 1000).round() + 20;
    }
  }
}
