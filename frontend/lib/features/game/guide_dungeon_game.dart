import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../avatar/components/modular_avatar_component.dart';
import 'components/explorer_component.dart';
import 'components/ping_beacon_component.dart';
import 'components/spike_trap_component.dart';
import 'dungeon_game.dart';
import 'services/dungeon_generator.dart';

class GuideDungeonGame extends DungeonGame with TapCallbacks, DragCallbacks {
  final void Function(Vector2 pingPos)? onPingTap;
  Vector2? _lastSentPoint;
  final double _minDistBetweenPoints = 8.0;

  GuideDungeonGame({
    super.dungeonMapData,
    super.explorerAvatarConfig,
    this.onPingTap,
  }) : super(isGuideMode: true);

  @override
  void onTapUp(TapUpEvent event) {
    super.onTapUp(event);
    _processInputPoint(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);
    _processInputPoint(event.canvasEndPosition);
  }

  void _processInputPoint(Vector2 canvasPos) {
    final worldPos = camera.viewfinder.globalToLocal(canvasPos);
    
    // Throttle networking and local spam
    if (_lastSentPoint != null && (worldPos - _lastSentPoint!).length < _minDistBetweenPoints) {
      return;
    }
    _lastSentPoint = worldPos.clone();

    // Add local visual trail point
    addTrailPoint(worldPos);

    // Notify UI / WebSocket
    onPingTap?.call(worldPos);
  }

  @override
  void disarmAllTraps() {
    print('[GUIDE ENGINE] Disarming all spike traps in dungeon...');
    for (final trap in world.children.whereType<SpikeTrapComponent>()) {
      trap.disarmTemporarily(const Duration(seconds: 5));
    }
  }

  /// Updates the remote Explorer avatar position, direction and animation in the Guide screen
  void updateExplorerRemotePosition(Vector2 remotePos, {String? direction, bool isMoving = false}) {
    final marginX = (tileSize - explorer.size.x) / 2;
    final marginY = (tileSize - explorer.size.x) / 2 - (explorer.size.y - explorer.size.x);
    final col = ((remotePos.x - marginX) / tileSize).round();
    final row = ((remotePos.y - marginY) / tileSize).round();
    final centeredPos = ExplorerComponent.getCenteredTilePosition(col, row, tileSize, explorer.size);

    if (direction != null) {
      switch (direction.toLowerCase()) {
        case 'up':
        case 'north':
          explorer.avatarRenderer.direction = AvatarDirection.north;
          break;
        case 'down':
        case 'south':
          explorer.avatarRenderer.direction = AvatarDirection.south;
          break;
        case 'left':
        case 'west':
          explorer.avatarRenderer.direction = AvatarDirection.west;
          break;
        case 'right':
        case 'east':
          explorer.avatarRenderer.direction = AvatarDirection.east;
          break;
        case 'southeast':
          explorer.avatarRenderer.direction = AvatarDirection.southEast;
          break;
        case 'northeast':
          explorer.avatarRenderer.direction = AvatarDirection.northEast;
          break;
        case 'northwest':
          explorer.avatarRenderer.direction = AvatarDirection.northWest;
          break;
        case 'southwest':
          explorer.avatarRenderer.direction = AvatarDirection.southWest;
          break;
      }
    }

    explorer.avatarRenderer.isMoving = isMoving;

    // If far away (like respawn at start), snap immediately
    if ((explorer.position - centeredPos).length > tileSize * 2) {
      explorer.position = centeredPos.clone();
      explorer.targetPosition = centeredPos.clone();
      explorer.isMoving = false;
    } else {
      explorer.targetPosition = centeredPos.clone();
      if ((explorer.position - centeredPos).length > 1.0) {
        explorer.direction = (centeredPos - explorer.position).normalized();
        explorer.isMoving = true;
      } else {
        explorer.position = centeredPos.clone();
        explorer.isMoving = isMoving;
      }
    }
  }
}
