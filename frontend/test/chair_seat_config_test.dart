import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/lobby/components/isometric_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/data/chair_seat_config.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';
import 'package:frontend/features/lobby/utils/isometric_coords.dart';
import 'package:frontend/features/lobby/utils/isometric_pathfinder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChairSeatConfig & Multi-Seat System', () {
    test('ChairSeatConfig returns configured spots for simple_chair_sm and plush_armchair', () {
      final chair = IsometricFurnitureComponent(
        id: 'simple_chair_sm',
        typeName: 'simple_chair_sm',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 0,
        footprint: '0.5x0.5',
      );

      final chairSpots = ChairSeatConfig.getSpots(chair, 0);
      expect(chairSpots.length, equals(1));
      expect(chairSpots.first.slotIndex, equals(0));
      expect(chairSpots.first.subCell, equals(const Point(0, 0)));
      expect(chairSpots.first.visualOffset, equals(Vector2(-2.0, 0.0)));

      final armchair = IsometricFurnitureComponent(
        id: 'armchair',
        typeName: 'plush_armchair',
        gridX: 6.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
        rotation: 0,
        footprint: '1x1',
      );

      final armchairSpots = ChairSeatConfig.getSpots(armchair, 0);
      expect(armchairSpots.length, equals(1));
      expect(armchairSpots.first.slotIndex, equals(0));
      expect(armchairSpots.first.subCell, equals(const Point(0, 1)));
      expect(armchairSpots.first.visualOffset, equals(Vector2(11.0, 6.0)));
    });

    test('Multi-seat registration: custom 2-seater sofa supports 2 distinct seat spots and closest spot selection', () {
      ChairSeatConfig.registerFurnitureSpots('sofa_test_2x1', {
        0: [
          SeatSpot(slotIndex: 0, subCell: const Point(0, 1), visualOffset: Vector2(-14.0, -8.0)),
          SeatSpot(slotIndex: 1, subCell: const Point(2, 1), visualOffset: Vector2(14.0, -8.0)),
        ],
      });

      final sofa = IsometricFurnitureComponent(
        id: 'my_sofa',
        typeName: 'sofa_test_2x1',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 2.0,
        gridHeight: 1.0,
        rotation: 0,
        footprint: '2x1',
      );

      final spots = ChairSeatConfig.getSpots(sofa, 0);
      expect(spots.length, equals(2));
      expect(spots[0].slotIndex, equals(0));
      expect(spots[1].slotIndex, equals(1));

      // Calculate screen positions of both spots
      final baseSubU = sofa.gridX * 2.0;
      final baseSubV = sofa.gridY * 2.0;
      final pos0 = IsometricCoords.subGridToScreen(baseSubU + spots[0].subCell.x, baseSubV + spots[0].subCell.y) + spots[0].visualOffset;
      final pos1 = IsometricCoords.subGridToScreen(baseSubU + spots[1].subCell.x, baseSubV + spots[1].subCell.y) + spots[1].visualOffset;

      // Tapping near spot 0 selects spot 0
      final pickedNear0 = ChairSeatConfig.getClosestSpot(sofa, pos0);
      expect(pickedNear0.slotIndex, equals(0));

      // Tapping near spot 1 selects spot 1
      final pickedNear1 = ChairSeatConfig.getClosestSpot(sofa, pos1);
      expect(pickedNear1.slotIndex, equals(1));

      // If spot 0 is occupied, tapping near spot 0 picks available spot 1
      final pickedOccupied = ChairSeatConfig.getClosestSpot(sofa, pos0, occupiedSlots: {0});
      expect(pickedOccupied.slotIndex, equals(1));
    });

    test('Avatar sitting in plush_armchair applies correct subcell, visual offset and standing up finds free exit', () {
      final armchair = IsometricFurnitureComponent(
        id: 'armchair',
        typeName: 'plush_armchair',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
        rotation: 0,
        footprint: '1x1',
      );

      final avatar = IsometricAvatarComponent(
        gridX: 4.0,
        gridY: 7.0,
        config: const AvatarConfig(),
      );

      // Sit on armchair
      avatar.sitOnChair(armchair);
      expect(avatar.isSitting, isTrue);
      expect(avatar.sittingChair, equals(armchair));
      expect(avatar.sittingSpot, isNotNull);
      expect(avatar.sittingSlotIndex, equals(0));
      // subCell is (0, 1), so gridX = 4.0*2 + 0 = 8.0, gridY = 4.0*2 + 1 = 9.0
      expect(avatar.gridX, equals(8.0));
      expect(avatar.gridY, equals(9.0));

      // Armchair occupies subcells: (8,8), (9,8), (8,9), (9,9)
      final obstacles = armchair.occupiedSubCells.toSet();
      expect(obstacles.length, equals(4));

      // Stand up: should find an exit outside the 4 occupied subcells
      avatar.standUp(obstacles: obstacles);
      expect(avatar.isSitting, isFalse);
      expect(avatar.sittingChair, isNull);
      expect(avatar.sittingSpot, isNull);

      final standingPoint = Point(avatar.gridX.round(), avatar.gridY.round());
      expect(obstacles.contains(standingPoint), isFalse, reason: 'Avatar must stand outside the armchair footprint');
    });

    test('Avatar standing up from chair NEVER crosses internal walls', () {
      final chair = IsometricFurnitureComponent(
        id: 'chair_wall_test',
        typeName: 'simple_chair_sm',
        gridX: 2.0, // Subcell u = 4
        gridY: 2.0, // Subcell v = 4
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 0, // Facing SW: delta (0, 1) -> (4, 5)
        footprint: '0.5x0.5',
      );

      final avatar = IsometricAvatarComponent(
        gridX: 4.0,
        gridY: 4.0,
        config: const AvatarConfig(),
      );
      avatar.sitOnChair(chair);
      expect(avatar.isSitting, isTrue);

      // Blocked edge directly in front of chair facing direction (between (4, 4) and (4, 5))
      // Also block further down ray: (4, 5) to (4, 6)
      final blockedEdges = <String>{
        IsometricPathfinder.edgeKey(4, 4, 4, 5),
        IsometricPathfinder.edgeKey(4, 5, 4, 6),
      };

      final obstacles = chair.occupiedSubCells.toSet();

      avatar.standUp(obstacles: obstacles, blockedEdges: blockedEdges);
      expect(avatar.isSitting, isFalse);

      final standingPoint = Point(avatar.gridX.round(), avatar.gridY.round());
      expect(standingPoint.y <= 4, isTrue,
          reason: 'Avatar must NOT stand at or across v=5 (blocked by internal wall)');
      expect(standingPoint, isNot(equals(const Point(4, 4))),
          reason: 'Avatar must step outside chair footprint');
      // Should have stepped to side (e.g. (5, 4) or (3, 4)) or back (4, 3)
      expect(standingPoint == const Point(5, 4) || standingPoint == const Point(3, 4) || standingPoint == const Point(4, 3), isTrue);
    });

    test('Avatar standing up chooses only wall-free reachable exit when 3 sides are blocked by walls', () {
      final chair = IsometricFurnitureComponent(
        id: 'chair_corner_test',
        typeName: 'simple_chair_sm',
        gridX: 2.0, // Subcell (4, 4)
        gridY: 2.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 0,
        footprint: '0.5x0.5',
      );

      final avatar = IsometricAvatarComponent(
        gridX: 4.0,
        gridY: 4.0,
        config: const AvatarConfig(),
      );
      avatar.sitOnChair(chair);

      // Walls on South (front), North (back), and West (left):
      // Only East (4, 4) -> (5, 4) is open!
      final blockedEdges = <String>{
        IsometricPathfinder.edgeKey(4, 4, 4, 5), // South wall
        IsometricPathfinder.edgeKey(4, 4, 4, 3), // North wall
        IsometricPathfinder.edgeKey(4, 4, 3, 4), // West wall
      };

      final obstacles = chair.occupiedSubCells.toSet();

      avatar.standUp(obstacles: obstacles, blockedEdges: blockedEdges);
      expect(avatar.isSitting, isFalse);

      final standingPoint = Point(avatar.gridX.round(), avatar.gridY.round());
      expect(standingPoint, equals(const Point(5, 4)),
          reason: 'Avatar must exit solely to the open East side (5, 4) without crossing any of the 3 walls');
    });

    test('isDiningTableOrDesk classifies tables correctly and excludes beds, nightstands, and appliances', () {
      final diningTable = IsometricFurnitureComponent(id: 'dining_table', typeName: 'dining_table_2x2', gridX: 2, gridY: 2, gridWidth: 2, gridHeight: 2);
      final rusticTable = IsometricFurnitureComponent(id: 'table', typeName: 'table', gridX: 2, gridY: 2, gridWidth: 1, gridHeight: 1);
      final bed = IsometricFurnitureComponent(id: 'single_bed', typeName: 'single_high_bed', gridX: 6, gridY: 0, gridWidth: 1, gridHeight: 2);
      final nightstand = IsometricFurnitureComponent(id: 'side_table', typeName: 'side_table_sm', gridX: 5, gridY: 0, gridWidth: 0.5, gridHeight: 0.5);
      final lamp = IsometricFurnitureComponent(id: 'table_lamp', typeName: 'table_lamp', gridX: 5, gridY: 0, footprint: 'surface');
      final stove = IsometricFurnitureComponent(id: 'kitchen_stove', typeName: 'kitchen_stove', gridX: 0, gridY: 4, gridWidth: 1, gridHeight: 1);

      expect(CozyRoomGame.isDiningTableOrDesk(diningTable), isTrue);
      expect(CozyRoomGame.isDiningTableOrDesk(rusticTable), isTrue);
      expect(CozyRoomGame.isDiningTableOrDesk(bed), isFalse);
      expect(CozyRoomGame.isDiningTableOrDesk(nightstand), isFalse);
      expect(CozyRoomGame.isDiningTableOrDesk(lamp), isFalse);
      expect(CozyRoomGame.isDiningTableOrDesk(stove), isFalse);
    });

    test('Chair placed near a bed preserves its natural priority across all rotations (0, 1, 2, 3)', () {
      final game = CozyRoomGame(avatarConfig: const AvatarConfig());
      final bed = IsometricFurnitureComponent(
        id: 'single_bed',
        typeName: 'single_high_bed',
        gridX: 6.0,
        gridY: 0.0,
        gridWidth: 1.0,
        gridHeight: 2.0,
      );

      final chair = IsometricFurnitureComponent(
        id: 'simple_chair_sm',
        typeName: 'simple_chair_sm',
        gridX: 6.0,
        gridY: 2.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 0,
        footprint: '0.5x0.5',
      );

      game.world.add(bed);
      game.world.add(chair);

      final initialPriority = chair.priority;
      expect(chair.priority > bed.priority, isTrue, reason: 'Chair is South of bed (closer to camera) and must have higher priority');

      // Test across all rotations: 0 (SW), 1 (SE), 2 (NE), 3 (NW)
      for (int r = 0; r < 4; r++) {
        chair.setRotation(r);
        game.recalculateSurfacePriorities([bed, chair]);

        expect(chair.priority, equals(initialPriority),
            reason: 'Chair rotation $r near a bed must not drop priority below bed');
        expect(chair.priority > bed.priority, isTrue,
            reason: 'Chair in rotation $r must remain in front of bed');
      }
    });

    test('Chair adjacent to a real dining table orders behind on North/West and in front on South/East', () {
      final game = CozyRoomGame(avatarConfig: const AvatarConfig());
      final table = IsometricFurnitureComponent(
        id: 'dining_table',
        typeName: 'dining_table_2x2',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 2.0,
        gridHeight: 2.0,
      );

      // Chair to the North (gridY: 3.5 < table.gridY: 4.0) -> must be behind table
      final northChair = IsometricFurnitureComponent(
        id: 'chair_north',
        typeName: 'simple_chair_sm',
        gridX: 4.5,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 0,
        footprint: '0.5x0.5',
      );

      // Chair to the South (gridY: 6.0 >= table.gridY: 4.0) -> must be in front of table in ALL rotations
      final southChair = IsometricFurnitureComponent(
        id: 'chair_south',
        typeName: 'simple_chair_sm',
        gridX: 4.5,
        gridY: 6.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 2,
        footprint: '0.5x0.5',
      );

      game.world.add(table);
      game.world.add(northChair);
      game.world.add(southChair);

      game.recalculateSurfacePriorities([table, northChair, southChair]);

      expect(northChair.priority < table.priority, isTrue,
          reason: 'North chair must render behind the table');
      expect(southChair.priority > table.priority, isTrue,
          reason: 'South chair must render in front of the table');

      // If south chair is rotated to SE (rot 1) or SW (rot 0), it must STILL stay in front of the table!
      southChair.setRotation(0);
      game.recalculateSurfacePriorities([table, northChair, southChair]);
      expect(southChair.priority > table.priority, isTrue,
          reason: 'South chair in rotation 0 (SW) must still render in front of table');

      southChair.setRotation(1);
      game.recalculateSurfacePriorities([table, northChair, southChair]);
      expect(southChair.priority > table.priority, isTrue,
          reason: 'South chair in rotation 1 (SE) must still render in front of table');
    });

    test('Chair Front / Base dual-layer: chairFrontSprites renders overlay in any rotation and sandwiches avatar', () {
      final chair = IsometricFurnitureComponent(
        id: 'gamer_chair',
        typeName: 'gamer_chair',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
        rotation: 0, // SW
        footprint: '1x1',
      );

      final avatar = IsometricAvatarComponent(
        gridX: 4.0,
        gridY: 4.0,
        config: const AvatarConfig(),
      );

      final overlay = ChairBackrestOverlayComponent(chair);
      overlay.update(0.016);

      // 1. Priority sandwich: chair (base) < avatar < overlay (front)
      avatar.sitOnChair(chair);
      expect(chair.priority, lessThan(avatar.priority),
          reason: 'Chair base priority must be lower than sitting avatar priority');
      expect(avatar.priority, lessThan(overlay.priority),
          reason: 'Sitting avatar priority must be lower than chair front overlay priority');
      expect(overlay.priority, equals(chair.priority + 20));

      // 2. Front overlay responds to any rotation: SW (0), SE (1), NE (2), NW (3)
      for (int r = 0; r < 4; r++) {
        chair.setRotation(r);
        overlay.update(0.016);
        expect(overlay.priority, equals(chair.priority + 20));
      }
    });
  });
}


