import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/lobby/components/isometric_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Switching chairs: sitting on chair 1 and clicking chair 2 stands up to empty space, walks to chair 2, and sits', () {
    final game = CozyRoomGame(avatarConfig: const AvatarConfig());

    final table = IsometricFurnitureComponent(
      id: 'table',
      typeName: 'table',
      gridX: 4.0,
      gridY: 4.0,
      gridWidth: 1.0,
      gridHeight: 1.0,
      footprint: '1x1',
    );

    // Chair 1: South of table (gx = 4.25, gy = 5.0, rot = 2)
    final chair1 = IsometricFurnitureComponent(
      id: 'chair_1',
      typeName: 'simple_chair_sm',
      gridX: 4.25,
      gridY: 5.0,
      gridWidth: 0.5,
      gridHeight: 0.5,
      rotation: 2,
      footprint: '0.5x0.5',
    );

    // Chair 2: North of table (gx = 4.25, gy = 3.5, rot = 0)
    final chair2 = IsometricFurnitureComponent(
      id: 'chair_2',
      typeName: 'simple_chair_sm',
      gridX: 4.25,
      gridY: 3.5,
      gridWidth: 0.5,
      gridHeight: 0.5,
      rotation: 0,
      footprint: '0.5x0.5',
    );

    game.world.add(table);
    game.world.add(chair1);
    game.world.add(chair2);

    final avatar = IsometricAvatarComponent(
      gridX: 4.0,
      gridY: 6.0,
      config: const AvatarConfig(),
      onReachedDestination: (dest) {
        // Same logic as CozyRoomGame._handleDestinationReached
        if (game.world.children.whereType<IsometricFurnitureComponent>().contains(chair2)) {
          game.avatar?.sitOnChair(chair2);
        }
      },
    );
    game.avatar = avatar;
    game.world.add(avatar);

    // Recalculate obstacles for room
    game.recalculateObstacles();

    // Step 1: Avatar sits on chair 1
    avatar.sitOnChair(chair1);
    expect(avatar.isSitting, isTrue);
    expect(avatar.sittingChair, equals(chair1));

    // Exit subcell for chair 1
    final chair1Exit = avatar.findExitSubCellForChair(chair1, obstacles: game.obstacles, blockedEdges: game.blockedEdges);
    expect(chair1Exit, isNotNull);

    // Step 2: Tap on chair2 directly while sitting on chair1
    final chair2TapPos = Vector2(
      chair2.worldVisualBoundingBox.center.dx,
      chair2.worldVisualBoundingBox.center.dy,
    );
    game.handleWorldTap(chair2TapPos);

    // Avatar must have stood up into chair 1's exit space!
    expect(avatar.isSitting, isFalse);
    expect(avatar.sittingChair, isNull);
    expect(avatar.gridX, equals(chair1Exit!.x.toDouble()));
    expect(avatar.gridY, equals(chair1Exit.y.toDouble()));

    // Avatar must now be moving along path towards chair 2
    expect(avatar.isMoving, isTrue);

    // Step 3: Simulate walk updates until avatar arrives at chair 2
    for (int i = 0; i < 30; i++) {
      avatar.update(0.1);
      if (!avatar.isMoving) break;
    }

    // Avatar reached chair 2 and sat down
    expect(avatar.isSitting, isTrue);
    expect(avatar.sittingChair, equals(chair2));

    // Step 4: Tap on chair 2 while sitting on it -> stands up into chair 2 exit space
    game.handleWorldTap(chair2TapPos);
    expect(avatar.isSitting, isFalse);
    expect(avatar.sittingChair, isNull);

    final chair2Exit = avatar.findExitSubCellForChair(chair2, obstacles: game.obstacles, blockedEdges: game.blockedEdges);
    expect(avatar.gridX, equals(chair2Exit!.x.toDouble()));
    expect(avatar.gridY, equals(chair2Exit.y.toDouble()));
  });
}
