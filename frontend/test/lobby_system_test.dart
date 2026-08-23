import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/core/services/avatar_storage_service.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/lobby/screens/cozy_lobby_view.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/components/isometric_interior_wall_component.dart';
import 'package:frontend/features/lobby/utils/isometric_coords.dart';
import 'package:frontend/features/lobby/utils/isometric_pathfinder.dart';

void main() {
  group('Isometric Coords & A* Pathfinder Tests', () {
    test('Isometric screen to grid and grid to screen conversion', () {
      final screen = IsometricCoords.gridToScreen(4.0, 4.0);
      final grid = IsometricCoords.screenToGrid(screen.x, screen.y);

      expect(grid.x, equals(4));
      expect(grid.y, equals(4));
    });

    test('A* Pathfinder finds optimal walkable path', () {
      final obstacles = {const Point(2, 2), const Point(2, 3)};
      final path = IsometricPathfinder.findPath(
        start: const Point(1, 1),
        goal: const Point(3, 3),
        obstacles: obstacles,
      );

      expect(path.isNotEmpty, isTrue);
      expect(path.last, equals(const Point(3, 3)));
      expect(path.contains(const Point(2, 2)), isFalse);
    });

    test('A* redirects to nearest neighbor when goal is inside obstacle', () {
      final obstacles = {const Point(5, 5)};
      final path = IsometricPathfinder.findPath(
        start: const Point(4, 4),
        goal: const Point(5, 5),
        obstacles: obstacles,
      );

      expect(path.isNotEmpty, isTrue);
      expect(path.last, isNot(equals(const Point(5, 5))));
      expect(obstacles.contains(path.last), isFalse);
    });

    test('A* Pathfinder routes around blocked edges (interior dividing walls)', () {
      // Direct path from (2, 2) to (2, 1) is blocked by a North wall on (2, 2)
      final blockedEdge = IsometricPathfinder.edgeKey(2, 2, 2, 1);
      final blockedEdges = {blockedEdge};

      final path = IsometricPathfinder.findPath(
        start: const Point(2, 2),
        goal: const Point(2, 1),
        obstacles: {},
        blockedEdges: blockedEdges,
      );

      expect(path.isNotEmpty, isTrue);
      expect(path.last, equals(const Point(2, 1)));
      // The first step cannot be directly to (2, 1) because the edge is blocked
      expect(path.first, isNot(equals(const Point(2, 1))));
    });
  });

  group('Interior Walls and RoomConfig Tests', () {
    test('InteriorWallConfig serializes and deserializes correctly in RoomConfig', () {
      const wall1 = InteriorWallConfig(
        id: 'wall_1',
        gridX: 2,
        gridY: 3,
        orientation: 'north',
        style: 'bathroom_glass',
        hasDoorway: false,
      );
      const wall2 = InteriorWallConfig(
        id: 'wall_2',
        gridX: 4,
        gridY: 4,
        orientation: 'west',
        style: 'wood_slats',
        hasDoorway: true,
      );

      const config = RoomConfig(
        interiorWalls: [wall1, wall2],
      );

      final jsonStr = config.toJson();
      final decoded = RoomConfig.fromJson(jsonStr);

      expect(decoded.interiorWalls.length, equals(2));
      expect(decoded.interiorWalls[0].style, equals('bathroom_glass'));
      expect(decoded.interiorWalls[0].orientation, equals('north'));
      expect(decoded.interiorWalls[1].style, equals('wood_slats'));
      expect(decoded.interiorWalls[1].hasDoorway, isTrue);
    });

    test('Isometric Z-order consistently handles avatar and furniture behind and in front of walls', () {
      const gx = 4;
      const gy = 4;

      final northWallZ = IsometricCoords.getInteriorWallZOrder(gx, gy, 'north');
      final westWallZ = IsometricCoords.getInteriorWallZOrder(gx, gy, 'west');

      // 1. Avatar on subcell behind North wall (tile 4, 3: u=8, v=7)
      final avatarBehindNorthZ = ((8 + 7) * 1000) + 20;
      expect(avatarBehindNorthZ < northWallZ, isTrue, reason: 'Avatar behind north wall must be occluded');

      // 2. Avatar on subcell in front of North wall (tile 4, 4: u=8, v=8)
      final avatarInFrontNorthZ = ((8 + 8) * 1000) + 20;
      expect(avatarInFrontNorthZ > northWallZ, isTrue, reason: 'Avatar in front of north wall must be on top');

      // 3. Avatar on tile behind North wall (tile 4, 3: u=8, v=6)
      final avatarBehindZ = ((8 + 6) * 1000) + 20;
      expect(avatarBehindZ < northWallZ, isTrue);

      // 4. Furniture on tile behind North wall (4, 3)
      final furnitureBehindZ = IsometricCoords.getZOrder(4, 3, layer: 1);
      expect(furnitureBehindZ < northWallZ, isTrue, reason: 'Furniture behind north wall must be occluded');

      // 5. Furniture on tile in front of North wall (4, 4)
      final furnitureInFrontZ = IsometricCoords.getZOrder(4, 4, layer: 1);
      expect(furnitureInFrontZ > northWallZ, isTrue, reason: 'Furniture in front of north wall must be on top');

      // 6. Corner L-junction: West wall draws over North wall
      expect(westWallZ > northWallZ, isTrue, reason: 'West wall must cap North wall cleanly at corner');
    });
  });

  group('Multi-user Avatar & Room Storage Tests', () {
    test('Independent avatar configs per user (userA, userB, userC, userD)', () {
      AvatarStorageService.setActiveUser('userA');
      expect(AvatarStorageService.currentConfig.topStyle, equals('flannel_shirt'));
      expect(AvatarStorageService.currentConfig.hairStyle, equals('farm_braids'));

      AvatarStorageService.setActiveUser('userB');
      expect(AvatarStorageService.currentConfig.topStyle, equals('hoodie'));
      expect(AvatarStorageService.currentConfig.hairStyle, equals('long_flowing'));

      AvatarStorageService.setActiveUser('userC');
      expect(AvatarStorageService.currentConfig.topStyle, equals('traveler_tunic'));

      AvatarStorageService.setActiveUser('userD');
      expect(AvatarStorageService.currentConfig.hairStyle, equals('messy_wanderer'));

      // Modifying userB does not change userA
      AvatarStorageService.saveUserConfig(
        'userB',
        AvatarStorageService.getUserConfig('userB').copyWith(topStyle: 'tshirt'),
      );

      expect(AvatarStorageService.getUserConfig('userB').topStyle, equals('tshirt'));
      expect(AvatarStorageService.getUserConfig('userA').topStyle, equals('flannel_shirt'));
    });

    test('Independent RoomConfig wallpaper and floors per user', () {
      AvatarStorageService.setActiveUser('alice');
      expect(AvatarStorageService.currentRoomConfig.wallpaper, equals('solid_white_plaster'));
      expect(AvatarStorageService.currentRoomConfig.floor, equals('solid_blush_pink'));

      AvatarStorageService.setActiveUser('bob');
      expect(AvatarStorageService.currentRoomConfig.wallpaper, equals('cozy_stripes'));
      expect(AvatarStorageService.currentRoomConfig.floor, equals('dark_walnut'));

      // Save custom theme for alice
      AvatarStorageService.saveUserRoomConfig(
        'alice',
        const RoomConfig(wallpaper: 'starry_night', floor: 'checker_marble'),
      );

      expect(AvatarStorageService.getUserRoomConfig('alice').wallpaper, equals('starry_night'));
      expect(AvatarStorageService.getUserRoomConfig('alice').floor, equals('checker_marble'));
      // bob remains unchanged
      expect(AvatarStorageService.getUserRoomConfig('bob').wallpaper, equals('cozy_stripes'));
    });
  });

  group('CozyLobbyView Widget Tests', () {
    testWidgets('Renders CozyLobbyView with user selector and buttons', (tester) async {
      final webSocketClient = WebSocketClient();
      final gameBloc = GameBloc(webSocketClient: webSocketClient);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<GameBloc>.value(
            value: gameBloc,
            child: CozyLobbyView(
              activeUserId: 'alice',
              onUserChanged: (_) {},
            ),
          ),
        ),
      );

      // Verify UI elements
      expect(find.text('Decorar'), findsOneWidget);
      expect(find.text('Constructor'), findsOneWidget);
      expect(find.text('Armario'), findsOneWidget);
      expect(find.text('Iniciar Cita'), findsOneWidget);
      expect(find.text('Habitación Cozy (Lobby)'), findsOneWidget);
      expect(find.text('🧑‍🦰 Alice (Explorador)'), findsOneWidget);
    });

    testWidgets('Tapping Decorar button enters decorate mode with Muebles & Decoracion bottom bar', (tester) async {
      final webSocketClient = WebSocketClient();
      final gameBloc = GameBloc(webSocketClient: webSocketClient);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<GameBloc>.value(
            value: gameBloc,
            child: CozyLobbyView(
              activeUserId: 'alice',
              onUserChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap Decorar button
      await tester.tap(find.text('Decorar'));
      await tester.pumpAndSettle();

      // Should show Decorate mode UI with Muebles & Decoración section
      expect(find.text('DECORAR'), findsOneWidget);
      expect(find.text('🛋️ Muebles & Decoración'), findsOneWidget);
      expect(find.text('Abrir Catálogo'), findsOneWidget);
      expect(find.text('Salón y Mesas'), findsOneWidget);
      expect(find.text('Dormitorio'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // Open catalog and check dividers/tabiques is not in catalog categories
      await tester.tap(find.text('Abrir Catálogo'));
      await tester.pumpAndSettle();

      expect(find.text('Catálogo de Muebles'), findsOneWidget);
      expect(find.text('🧱 Tabiques y Muros'), findsNothing);
    });

    testWidgets('Tapping Constructor button switches to constructor mode with tabs', (tester) async {
      final webSocketClient = WebSocketClient();
      final gameBloc = GameBloc(webSocketClient: webSocketClient);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<GameBloc>.value(
            value: gameBloc,
            child: CozyLobbyView(
              activeUserId: 'alice',
              onUserChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap Constructor button
      await tester.tap(find.text('Constructor'));
      await tester.pumpAndSettle();

      // Should show Constructor mode UI elements
      expect(find.text('CONSTRUCTOR'), findsOneWidget);
      expect(find.text('🧱 Paredes'), findsOneWidget);
      expect(find.text('🪵 Pisos'), findsOneWidget);
      expect(find.text('🚪 Muros Internos'), findsOneWidget);
      expect(find.text('Listo'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    test('updateWallpaper and updateFloor update background config without reloading furniture', () {
      final initialConfig = RoomConfig(
        wallpaper: 'rustic_wood',
        floor: 'oak_parquet',
        furniture: [
          PlacedFurnitureConfig(id: 'bed_1', typeName: 'bed_single', gridX: 2, gridY: 2),
          PlacedFurnitureConfig(id: 'table_1', typeName: 'table', gridX: 4, gridY: 4),
        ],
      );

      final game = CozyRoomGame(
        avatarConfig: AvatarStorageService.getUserConfig('alice'),
        roomConfig: initialConfig,
      );

      expect(game.roomConfig.wallpaper, equals('rustic_wood'));
      expect(game.roomConfig.floor, equals('oak_parquet'));
      expect(game.roomConfig.furniture.length, equals(2));

      // Paint wallpaper
      game.updateWallpaper('starry_night');
      expect(game.roomConfig.wallpaper, equals('starry_night'));
      expect(game.roomConfig.furniture.length, equals(2));

      // Paint floor
      game.updateFloor('checker_marble');
      expect(game.roomConfig.floor, equals('checker_marble'));
      expect(game.roomConfig.wallpaper, equals('starry_night'));
      expect(game.roomConfig.furniture.length, equals(2));
    });

    test('applyStyleToAllInteriorWalls updates all interior walls in the room', () {
      final initialConfig = RoomConfig(
        interiorWalls: [
          InteriorWallConfig(id: 'w1', gridX: 2, gridY: 2, orientation: 'north', style: 'wood_slats'),
          InteriorWallConfig(id: 'w2', gridX: 4, gridY: 4, orientation: 'west', style: 'wood_slats'),
        ],
      );

      final game = CozyRoomGame(
        avatarConfig: AvatarStorageService.getUserConfig('alice'),
        roomConfig: initialConfig,
      );

      final styleOption = InteriorWallStyles.all.firstWhere((s) => s.id == 'solid_sage_green');
      final count = game.applyStyleToAllInteriorWalls(styleOption);

      expect(count, equals(0)); // World components not yet added since onLoad wasn't called in pure unit test

      // Directly add components to world (two solid walls and one doorway)
      final w1 = IsometricInteriorWallComponent(id: 'w1', gridX: 2, gridY: 2, style: 'wood_slats');
      final w2 = IsometricInteriorWallComponent(id: 'w2', gridX: 4, gridY: 4, style: 'wood_slats');
      final wDoor = IsometricInteriorWallComponent(id: 'wDoor', gridX: 3, gridY: 3, style: 'doorway_frame', hasDoorway: true);
      game.world.add(w1);
      game.world.add(w2);
      game.world.add(wDoor);

      final count2 = game.applyStyleToAllInteriorWalls(styleOption);
      expect(count2, equals(2)); // Only solid walls updated
      expect(w1.style, equals('solid_sage_green'));
      expect(w2.style, equals('solid_sage_green'));
      expect(wDoor.style, equals('doorway_frame')); // Doorway preserved!
      expect(wDoor.hasDoorway, isTrue);

      // Attempting to paint using a doorway style option returns 0
      final doorwayStyle = InteriorWallStyles.all.firstWhere((s) => s.isDoorway);
      expect(game.applyStyleToAllInteriorWalls(doorwayStyle), equals(0));

      // Apply selected wall style to all
      w1.style = 'rustic_brick';
      game.selectedInteriorWall = w1;
      final count3 = game.applySelectedInteriorWallStyleToAll();
      expect(count3, equals(3));
      expect(w1.style, equals('rustic_brick'));
      expect(w2.style, equals('rustic_brick'));
    });

    test('Floor tile overrides serialize and deserialize properly in RoomConfig', () {
      const config = RoomConfig(
        floor: 'oak_parquet',
        floorOverrides: {
          '0,0': 'solid_white_tiles',
          '0,1': 'solid_white_tiles',
          '1,0': 'checker_marble',
        },
      );

      final jsonStr = config.toJson();
      final decoded = RoomConfig.fromJson(jsonStr);

      expect(decoded.floor, equals('oak_parquet'));
      expect(decoded.floorOverrides.length, equals(3));
      expect(decoded.floorOverrides['0,0'], equals('solid_white_tiles'));
      expect(decoded.floorOverrides['0,1'], equals('solid_white_tiles'));
      expect(decoded.floorOverrides['1,0'], equals('checker_marble'));
    });

    test('CozyRoomGame paints, erases and clears custom floor tile zones', () {
      final game = CozyRoomGame(
        avatarConfig: AvatarStorageService.getUserConfig('alice'),
        roomConfig: const RoomConfig(floor: 'dark_walnut'),
      );

      // Paint tiles
      game.paintFloorTile(1, 1, 'solid_white_tiles');
      game.paintFloorTile(1, 2, 'solid_white_tiles');
      expect(game.roomConfig.floorOverrides['1,1'], equals('solid_white_tiles'));
      expect(game.roomConfig.floorOverrides['1,2'], equals('solid_white_tiles'));
      expect(game.roomConfig.floorOverrides.length, equals(2));

      // Erase tile
      game.eraseFloorTile(1, 1);
      expect(game.roomConfig.floorOverrides.containsKey('1,1'), isFalse);
      expect(game.roomConfig.floorOverrides['1,2'], equals('solid_white_tiles'));

      // Export preserves overrides
      final exported = game.exportCurrentRoomConfig();
      expect(exported.floorOverrides['1,2'], equals('solid_white_tiles'));

      // Clear all overrides
      game.clearAllFloorOverrides();
      expect(game.roomConfig.floorOverrides.isEmpty, isTrue);
    });
  });

  group('Sub-Grid (2x2 Factor) System Tests', () {
    test('Isometric sub-grid coordinate conversions (subGridToScreen & screenToSubGrid)', () {
      // (8.5, 8.5) in sub-grid is the exact center of tile (4, 4)
      final subCenter = IsometricCoords.subGridToScreen(8.5, 8.5);
      final tileCenter = IsometricCoords.gridToScreen(4.0, 4.0);

      expect(subCenter.x, equals(tileCenter.x));
      expect(subCenter.y, equals(tileCenter.y));

      // Inverse projection of tile (4, 4) North subcell (8, 8)
      final subScreen = IsometricCoords.subGridToScreen(8.0, 8.0);
      final subPoint = IsometricCoords.screenToSubGrid(subScreen.x, subScreen.y);
      expect(subPoint.x, equals(8));
      expect(subPoint.y, equals(8));

      // Half-tile step (e.g. u=9, v=8 vs u=8, v=8)
      final halfStepScreen = IsometricCoords.subGridToScreen(9.0, 8.0);
      expect(halfStepScreen.x - subScreen.x, equals(16.0));
      expect(halfStepScreen.y - subScreen.y, equals(8.0));
    });

    test('Pathfinder operates smoothly on 16x16 sub-grid', () {
      final obstacles = {const Point(4, 4), const Point(4, 5)};
      final path = IsometricPathfinder.findPath(
        start: const Point(2, 2),
        goal: const Point(6, 6),
        obstacles: obstacles,
        mapSize: IsometricPathfinder.subGridSize,
      );

      expect(path.isNotEmpty, isTrue);
      expect(path.last, equals(const Point(6, 6)));
      expect(path.contains(const Point(4, 4)), isFalse);
      expect(path.contains(const Point(4, 5)), isFalse);
    });

    test('Bookshelf and tall wardrobe occupy 2 sub-cells on North wall (leaving South sub-cells free)', () {
      final bookshelf = IsometricFurnitureComponent(
        id: 'bookshelf_1',
        typeName: 'bookshelf',
        gridX: 2,
        gridY: 2,
        rotation: 0,
      );

      // Tile (2, 2) has sub-grid origin (4, 4).
      // On rot 0 (North-facing), it occupies (4, 4) and (5, 4).
      // South sub-cells (4, 5) and (5, 5) remain FREE for avatar walking.
      final occupied = bookshelf.occupiedSubCells;
      expect(occupied.length, equals(2));
      expect(occupied, contains(const Point(4, 4)));
      expect(occupied, contains(const Point(5, 4)));
      expect(occupied.contains(const Point(4, 5)), isFalse);
      expect(occupied.contains(const Point(5, 5)), isFalse);
    });

    test('Bookshelf rotation to West wall swaps occupied sub-cells to (4, 4) and (4, 5)', () {
      final bookshelf = IsometricFurnitureComponent(
        id: 'bookshelf_1',
        typeName: 'bookshelf',
        gridX: 2,
        gridY: 2,
        rotation: 1, // West-facing
      );

      final occupied = bookshelf.occupiedSubCells;
      expect(occupied.length, equals(2));
      expect(occupied, contains(const Point(4, 4)));
      expect(occupied, contains(const Point(4, 5)));
      expect(occupied.contains(const Point(5, 4)), isFalse);
      expect(occupied.contains(const Point(5, 5)), isFalse);
    });

    test('Refrigerator occupies exactly 1 sub-cell depending on rotation corner', () {
      final fridgeRot0 = IsometricFurnitureComponent(
        id: 'refrigerator_inox',
        typeName: 'refrigerator',
        gridX: 3,
        gridY: 3,
        rotation: 0, // NW
      );
      expect(fridgeRot0.occupiedSubCells, equals([const Point(6, 6)]));

      final fridgeRot1 = IsometricFurnitureComponent(
        id: 'refrigerator_inox',
        typeName: 'refrigerator',
        gridX: 3,
        gridY: 3,
        rotation: 1, // NE
      );
      expect(fridgeRot1.occupiedSubCells, equals([const Point(7, 6)]));

      final fridgeRot2 = IsometricFurnitureComponent(
        id: 'refrigerator_inox',
        typeName: 'refrigerator',
        gridX: 3,
        gridY: 3,
        rotation: 2, // SE
      );
      expect(fridgeRot2.occupiedSubCells, equals([const Point(7, 7)]));

      final fridgeRot3 = IsometricFurnitureComponent(
        id: 'refrigerator_inox',
        typeName: 'refrigerator',
        gridX: 3,
        gridY: 3,
        rotation: 3, // SW
      );
      expect(fridgeRot3.occupiedSubCells, equals([const Point(6, 7)]));
    });

    test('Coffee table (1x1 standard) occupies all 4 sub-cells in its quadrant (2x2)', () {
      final table = IsometricFurnitureComponent(
        id: 'coffee_table',
        typeName: 'table',
        gridX: 1,
        gridY: 1,
        gridWidth: 1,
        gridHeight: 1,
      );

      // Tile (1, 1) has sub-grid origin (2, 2). Occupies all 4: (2,2), (3,2), (2,3), (3,3)
      final occupied = table.occupiedSubCells;
      expect(occupied.length, equals(4));
      expect(occupied, contains(const Point(2, 2)));
      expect(occupied, contains(const Point(3, 2)));
      expect(occupied, contains(const Point(2, 3)));
      expect(occupied, contains(const Point(3, 3)));
    });
  });
}
