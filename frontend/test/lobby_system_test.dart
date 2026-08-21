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
      expect(find.text('Armario'), findsOneWidget);
      expect(find.text('Iniciar Cita'), findsOneWidget);
      expect(find.text('Habitación Cozy (Lobby)'), findsOneWidget);
      expect(find.text('🧑‍🦰 Alice (Explorador)'), findsOneWidget);
    });
  });
}
