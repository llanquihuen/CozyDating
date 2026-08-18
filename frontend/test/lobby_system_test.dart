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
      expect(AvatarStorageService.currentRoomConfig.wallpaper, equals('rustic_wood'));
      expect(AvatarStorageService.currentRoomConfig.floor, equals('oak_parquet'));

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
