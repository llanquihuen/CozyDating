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

      // 1. Avatar on tile behind North wall (4, 3)
      final avatarBehindNorthZ = ((4 + 3) * 1000) + 12;
      expect(avatarBehindNorthZ < northWallZ, isTrue, reason: 'Avatar behind north wall must be occluded');

      // 2. Avatar on tile in front of North wall (4, 4)
      final avatarInFrontNorthZ = ((4 + 4) * 1000) + 12;
      expect(avatarInFrontNorthZ > northWallZ, isTrue, reason: 'Avatar in front of north wall must be on top');

      // 3. Avatar on anti-diagonal adjacent tile (5, 3)
      final avatarDiagonalZ = ((5 + 3) * 1000) + 12;
      expect(avatarDiagonalZ > northWallZ, isTrue, reason: 'Avatar on adjacent right tile must not be occluded by left wall');

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
}
