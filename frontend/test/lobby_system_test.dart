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

      // 1. Avatar on South subcell behind North wall (tile 4, 3: South subcell is u=9, v=7)
      final avatarBehindNorthSouthQuadZ = IsometricCoords.getSubZOrder(9, 7, layer: 100);
      expect(avatarBehindNorthSouthQuadZ < northWallZ, isTrue, reason: 'Avatar in South quadrant behind north wall must be occluded');

      // 2. Avatar on North subcell in front of North wall (tile 4, 4: NW subcell is u=8, v=8)
      final avatarInFrontNorthZ = IsometricCoords.getSubZOrder(8, 8, layer: 100);
      expect(avatarInFrontNorthZ > northWallZ, isTrue, reason: 'Avatar on NW subcell in front of north wall must be on top');

      // 3. Avatar on South subcell behind West wall (tile 3, 4: South subcell is u=7, v=9)
      final avatarBehindWestSouthQuadZ = IsometricCoords.getSubZOrder(7, 9, layer: 100);
      expect(avatarBehindWestSouthQuadZ < westWallZ, isTrue, reason: 'Avatar in South quadrant behind west wall must be occluded');

      // 4. Avatar on South subcell in front of West wall (tile 4, 4: South subcell is u=9, v=9)
      final avatarInFrontWestZ = IsometricCoords.getSubZOrder(9, 9, layer: 100);
      expect(avatarInFrontWestZ > westWallZ, isTrue, reason: 'Avatar in South quadrant in front of west wall must be on top');

      // 5. Furniture on tile behind North wall (4, 3)
      final furnitureBehindZ = IsometricCoords.getZOrder(4, 3, layer: 1);
      expect(furnitureBehindZ < northWallZ, isTrue, reason: 'Furniture behind north wall must be occluded');

      // 6. Furniture on tile in front of North wall (4, 4)
      final furnitureInFrontZ = IsometricCoords.getZOrder(4, 4, layer: 1);
      expect(furnitureInFrontZ > northWallZ, isTrue, reason: 'Furniture in front of north wall must be on top');

      // 7. Corner L-junction: West wall draws over North wall
      expect(westWallZ > northWallZ, isTrue, reason: 'West wall must cap North wall cleanly at corner');
    });
  });

  group('Multi-user Avatar & Room Storage Tests', () {
    test('Independent avatar configs per user (userA, userB, userC, userD)', () {
      AvatarStorageService.setActiveUser('userA');
      expect(AvatarStorageService.currentConfig.topStyle, equals('jacket'));
      expect(AvatarStorageService.currentConfig.hairStyle, equals('long_flow'));

      AvatarStorageService.setActiveUser('userB');
      expect(AvatarStorageService.currentConfig.topStyle, equals('jacket'));
      expect(AvatarStorageService.currentConfig.hairStyle, equals('long_flow'));

      AvatarStorageService.setActiveUser('userC');
      expect(AvatarStorageService.currentConfig.topStyle, equals('jacket'));

      AvatarStorageService.setActiveUser('userD');
      expect(AvatarStorageService.currentConfig.hairStyle, equals('long_flow'));

      // Modifying userB does not change userA
      AvatarStorageService.saveUserConfig(
        'userB',
        AvatarStorageService.getUserConfig('userB').copyWith(topStyle: 'none'),
      );

      expect(AvatarStorageService.getUserConfig('userB').topStyle, equals('none'));
      expect(AvatarStorageService.getUserConfig('userA').topStyle, equals('jacket'));
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

      // Verify Paredes tab (active by default) has tools and texture selector
      expect(find.text('Todo el Salón'), findsOneWidget);
      expect(find.text('Pintar Zona'), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
      expect(find.text('🎨 Colores'), findsOneWidget);
      expect(find.text('Yeso/Liso'), findsOneWidget);
      expect(find.text('Azulejos'), findsOneWidget);

      // Tap Azulejos button in Paredes
      await tester.tap(find.text('Azulejos'));
      await tester.pumpAndSettle();

      // Tap Pisos tab
      await tester.tap(find.text('🪵 Pisos'));
      await tester.pumpAndSettle();

      // Verify floor tools and texture selectors are visible
      expect(find.text('Todo el Salón'), findsOneWidget);
      expect(find.text('Pintar Zona'), findsOneWidget);
      expect(find.text('Borrador'), findsOneWidget);
      expect(find.text('Baldosas'), findsOneWidget);
      expect(find.text('Alfombra'), findsOneWidget);

      // Tap Alfombra texture button
      await tester.tap(find.text('Alfombra'));
      await tester.pumpAndSettle();

      // Tap Muros Internos tab
      await tester.tap(find.text('🚪 Muros Internos'));
      await tester.pumpAndSettle();

      // Verify Muros Internos tools and textures are visible
      expect(find.text('Añadir Muro'), findsOneWidget);
      expect(find.text('Todos los Muros'), findsOneWidget);
      expect(find.text('Pintar Muro'), findsOneWidget);
      expect(find.text('Yeso/Liso'), findsOneWidget);
      expect(find.text('Azulejos'), findsOneWidget);
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
        roomConfig: const RoomConfig(floor: 'dark_walnut', floorOverrides: {}),
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

    test('RoomThemes resolves floor options and converts textures (tiles vs carpet) correctly', () {
      // 1. Resolve pattern
      final parquet = RoomThemes.getFloorOption('oak_parquet');
      expect(parquet.textureType, equals('pattern'));
      expect(parquet.color, isNull);

      // 2. Resolve legacy solid tiles
      final whiteTiles = RoomThemes.getFloorOption('solid_white_tiles');
      expect(whiteTiles.textureType, equals('tiles'));
      expect(whiteTiles.color, isNotNull);
      expect(whiteTiles.name, contains('Blanca'));

      // 3. Resolve solid carpet
      final mintCarpet = RoomThemes.getFloorOption('solid_carpet_mint_green');
      expect(mintCarpet.textureType, equals('carpet'));
      expect(mintCarpet.emoji, equals('🧶'));
      expect(mintCarpet.name, contains('Alfombra'));
      expect(mintCarpet.color, equals(const Color(0xFFA8D8B9)));

      // 4. changeTexture preserves color when switching from tiles to carpet
      final carpetFromTiles = RoomThemes.changeTexture('solid_mint_green', 'carpet');
      expect(carpetFromTiles, equals('solid_carpet_mint_green'));
      final optCarpet = RoomThemes.getFloorOption(carpetFromTiles);
      expect(optCarpet.textureType, equals('carpet'));
      expect(optCarpet.color, equals(const Color(0xFFA8D8B9)));

      // 5. changeTexture converts carpet back to tiles
      final tilesFromCarpet = RoomThemes.changeTexture('solid_carpet_blush_pink', 'tiles');
      expect(tilesFromCarpet, equals('solid_tiles_blush_pink'));
      final optTiles = RoomThemes.getFloorOption(tilesFromCarpet);
      expect(optTiles.textureType, equals('tiles'));
      expect(optTiles.color, equals(const Color(0xFFEBBFC2)));

      // 6. Paint with carpet texture in CozyRoomGame
      final game = CozyRoomGame(
        avatarConfig: AvatarStorageService.getUserConfig('alice'),
        roomConfig: const RoomConfig(floor: 'solid_carpet_warm_sand', floorOverrides: {}),
      );
      game.paintFloorTile(2, 2, 'solid_carpet_mint_green');
      expect(game.roomConfig.floorOverrides['2,2'], equals('solid_carpet_mint_green'));
    });

    test('Wall segment overrides serialize and deserialize properly in RoomConfig', () {
      const config = RoomConfig(
        wallpaper: 'rustic_wood',
        wallOverrides: {
          'n,0': 'solid_tiles_sage_green',
          'n,1': 'solid_tiles_sage_green',
          'w,3': 'solid_plaster_warm_beige',
        },
      );

      final jsonStr = config.toJson();
      final decoded = RoomConfig.fromJson(jsonStr);

      expect(decoded.wallpaper, equals('rustic_wood'));
      expect(decoded.wallOverrides.length, equals(3));
      expect(decoded.wallOverrides['n,0'], equals('solid_tiles_sage_green'));
      expect(decoded.wallOverrides['n,1'], equals('solid_tiles_sage_green'));
      expect(decoded.wallOverrides['w,3'], equals('solid_plaster_warm_beige'));
    });

    test('CozyRoomGame paints, erases and clears custom wall segment overrides', () {
      final game = CozyRoomGame(
        avatarConfig: AvatarStorageService.getUserConfig('alice'),
        roomConfig: const RoomConfig(wallpaper: 'rustic_wood', wallOverrides: {}),
      );

      // Paint wall segments
      game.paintWallSegment('n', 2, 'solid_tiles_mint_green');
      game.paintWallSegment('w', 4, 'solid_plaster_dusty_rose');
      expect(game.roomConfig.wallOverrides['n,2'], equals('solid_tiles_mint_green'));
      expect(game.roomConfig.wallOverrides['w,4'], equals('solid_plaster_dusty_rose'));
      expect(game.roomConfig.wallOverrides.length, equals(2));

      // Erase wall segment
      game.eraseWallSegment('n', 2);
      expect(game.roomConfig.wallOverrides.containsKey('n,2'), isFalse);
      expect(game.roomConfig.wallOverrides['w,4'], equals('solid_plaster_dusty_rose'));

      // Export preserves wall overrides
      final exported = game.exportCurrentRoomConfig();
      expect(exported.wallOverrides['w,4'], equals('solid_plaster_dusty_rose'));

      // Clear all wall overrides
      game.clearAllWallOverrides();
      expect(game.roomConfig.wallOverrides.isEmpty, isTrue);
    });

    test('RoomThemes resolves wallpaper options and converts textures (plaster vs tiles) correctly', () {
      // 1. Resolve pattern
      final rustic = RoomThemes.getWallpaperOption('rustic_wood');
      expect(rustic.textureType, equals('pattern'));
      expect(rustic.color, isNull);

      // 2. Resolve plaster color
      final whitePlaster = RoomThemes.getWallpaperOption('solid_white_plaster');
      expect(whitePlaster.textureType, equals('plaster'));
      expect(whitePlaster.color, isNotNull);
      expect(whitePlaster.name, contains('Blanco Lino'));

      // 3. Resolve tiles color
      final sageTiles = RoomThemes.getWallpaperOption('solid_tiles_sage_green');
      expect(sageTiles.textureType, equals('tiles'));
      expect(sageTiles.emoji, equals('🔲'));
      expect(sageTiles.name, contains('Azulejos'));
      expect(sageTiles.color, equals(const Color(0xFF8DA399)));

      // 4. changeWallpaperTexture preserves color when switching between plaster and tiles
      final tilesFromPlaster = RoomThemes.changeWallpaperTexture('solid_sage_green', 'tiles');
      expect(tilesFromPlaster, equals('solid_tiles_sage_green'));
      final optTiles = RoomThemes.getWallpaperOption(tilesFromPlaster);
      expect(optTiles.textureType, equals('tiles'));
      expect(optTiles.color, equals(const Color(0xFF8DA399)));

      final plasterFromTiles = RoomThemes.changeWallpaperTexture('solid_tiles_dusty_rose', 'plaster');
      expect(plasterFromTiles, equals('solid_plaster_dusty_rose'));
      final optPlaster = RoomThemes.getWallpaperOption(plasterFromTiles);
      expect(optPlaster.textureType, equals('plaster'));
      expect(optPlaster.color, equals(const Color(0xFFE5B2B7)));
    });

    test('addFurnitureFromCatalog and addInteriorWallFromStyle spawn near camera viewport center', () async {
      final game = CozyRoomGame(
        avatarConfig: AvatarStorageService.getUserConfig('alice'),
        roomConfig: const RoomConfig(),
      );

      // Pan camera to tile (5, 5)
      final pos55 = IsometricCoords.gridToScreen(5.0, 5.0);
      game.camera.viewfinder.position = pos55;

      final camCenter = game.getCameraCenterGrid();
      expect(camCenter.x, equals(5));
      expect(camCenter.y, equals(5));

      // 1. Add interior wall -> should spawn at (5, 5)
      final wallStyle = InteriorWallStyles.structural.first;
      game.addInteriorWallFromStyle(wallStyle);

      final addedWall = game.world.children.whereType<IsometricInteriorWallComponent>().first;
      expect(addedWall.gridX, equals(5));
      expect(addedWall.gridY, equals(5));

      // 2. Add second interior wall -> (5, 5, 'north') is taken, so it takes (5, 5, 'west') or closest empty slot
      game.addInteriorWallFromStyle(wallStyle);
      final walls = game.world.children.whereType<IsometricInteriorWallComponent>().toList();
      expect(walls.length, equals(2));
      expect(walls[1].gridX, equals(5));
      expect(walls[1].gridY, equals(5));
      expect(walls[1].orientation, equals('west'));
    });

    test('Multi-tile furniture (1x2, 2x1, 2x2) cannot be placed crossing interior dividing walls', () {
      final game = CozyRoomGame(
        avatarConfig: AvatarStorageService.getUserConfig('alice'),
        roomConfig: const RoomConfig(),
      );

      // Add a West wall at (3, 2)
      final wall = IsometricInteriorWallComponent(
        id: 'w1',
        gridX: 3,
        gridY: 2,
        orientation: 'west',
        style: 'wood_slats',
      );
      game.world.add(wall);

      // 1. A 2x1 item placed at (2, 2) would cross the West wall at (3, 2)
      final bed2x1 = IsometricFurnitureComponent(
        id: 'test_bed_2x1',
        gridX: 2,
        gridY: 2,
        gridWidth: 2,
        gridHeight: 1,
      );
      // Attempting to place bed at (2, 2) crossing the wall at (3, 2)
      expect(game.checkIsValidLocationForTesting(bed2x1, const Point(2, 2)), isFalse);

      // Placing the 2x1 item at (3, 2) does not cross the wall (wall is on its outer West edge)
      expect(game.checkIsValidLocationForTesting(bed2x1, const Point(3, 2)), isTrue);

      // 2. Add a North wall at (2, 3)
      final northWall = IsometricInteriorWallComponent(
        id: 'w2',
        gridX: 2,
        gridY: 3,
        orientation: 'north',
        style: 'wood_slats',
      );
      game.world.add(northWall);

      // A 1x2 item placed at (2, 2) would cross the North wall at (2, 3)
      final bed1x2 = IsometricFurnitureComponent(
        id: 'test_bed_1x2',
        gridX: 2,
        gridY: 2,
        gridWidth: 1,
        gridHeight: 2,
      );
      expect(game.checkIsValidLocationForTesting(bed1x2, const Point(2, 2)), isFalse);

      // 3. A 2x2 item at (2, 2) is also blocked
      final kingBed2x2 = IsometricFurnitureComponent(
        id: 'test_king_bed_2x2',
        gridX: 2,
        gridY: 2,
        gridWidth: 2,
        gridHeight: 2,
      );
      expect(game.checkIsValidLocationForTesting(kingBed2x2, const Point(2, 2)), isFalse);
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

      // Precision click tests: clicks slightly offset from center in all 4 directions still resolve to (8, 8)
      expect(IsometricCoords.screenToSubGrid(subScreen.x, subScreen.y - 3.0), equals(const Point(8, 8))); // Top
      expect(IsometricCoords.screenToSubGrid(subScreen.x, subScreen.y + 3.0), equals(const Point(8, 8))); // Bottom
      expect(IsometricCoords.screenToSubGrid(subScreen.x - 6.0, subScreen.y), equals(const Point(8, 8))); // Left
      expect(IsometricCoords.screenToSubGrid(subScreen.x + 6.0, subScreen.y), equals(const Point(8, 8))); // Right
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

  group('Initial 3-Room Layout (Bathroom, Bedroom, Kitchen) Tests', () {
    test('Default RoomConfig includes bathroom, bedroom, kitchen furniture and walls', () {
      const defaultRoom = RoomConfig();

      // Check furniture contains key items from all 3 rooms
      final furnitureIds = defaultRoom.furniture.map((f) => f.id).toSet();
      // Bathroom
      expect(furnitureIds.contains('bathtub_classic'), isTrue);
      expect(furnitureIds.contains('bathroom_toilet'), isTrue);
      expect(furnitureIds.contains('towel_rack_wall'), isTrue);
      // Bedroom
      expect(furnitureIds.contains('single_bed'), isTrue);
      expect(furnitureIds.contains('side_table'), isTrue);
      expect(furnitureIds.contains('table_lamp'), isTrue);
      expect(furnitureIds.contains('closet'), isTrue);
      // Kitchen
      expect(furnitureIds.contains('kitchen_fridge_sm'), isTrue);
      expect(furnitureIds.contains('kitchen_stove'), isTrue);
      expect(furnitureIds.contains('kitchen_sink'), isTrue);
      expect(furnitureIds.contains('pan_rack_wall'), isTrue);
      // Salón / Living
      expect(furnitureIds.contains('table'), isTrue);
      expect(furnitureIds.contains('coffee_mug'), isTrue);
      expect(furnitureIds.contains('wooden_chair') || furnitureIds.contains('simple_chair_sm'), isTrue);

      // Check interior walls include dividing partitions with doors for all 3 rooms
      final wallStyles = defaultRoom.interiorWalls.map((w) => w.style).toSet();
      expect(wallStyles.contains('bathroom_glass'), isTrue);
      expect(wallStyles.contains('wood_slats'), isTrue);

      // Doorways
      final doorways = defaultRoom.interiorWalls.where((w) => w.hasDoorway).toList();
      expect(doorways.length, greaterThanOrEqualTo(3)); // At least 1 door for bathroom, bedroom, kitchen

      // Floor overrides for zones
      expect(defaultRoom.floorOverrides.containsKey('0,0'), isTrue); // Bathroom tile
      expect(defaultRoom.floorOverrides['0,0'], equals('solid_white_tiles'));
      expect(defaultRoom.floorOverrides.containsKey('7,0'), isTrue); // Bedroom carpet
      expect(defaultRoom.floorOverrides['7,0'], equals('solid_carpet_warm_sand'));
      expect(defaultRoom.floorOverrides.containsKey('0,5'), isTrue); // Kitchen tile
      expect(defaultRoom.floorOverrides['0,5'], equals('solid_slate_gray'));
    });

    test('Avatar safe spawn location is never on an obstacle or furniture object', () {
      for (final uid in ['alice', 'bob', 'charlie', 'david']) {
        final cfg = AvatarStorageService.getUserRoomConfig(uid);
        final game = CozyRoomGame(
          avatarConfig: AvatarStorageService.getUserConfig(uid),
          roomConfig: cfg,
        );

        for (final item in cfg.furniture) {
          final comp = IsometricFurnitureComponent(
            id: item.id,
            typeName: item.typeName,
            gridX: item.gridX,
            gridY: item.gridY,
            gridWidth: item.gridWidth,
            gridHeight: item.gridHeight,
            rotation: item.rotation,
            footprint: item.gridWidth == 2 && item.gridHeight == 2
                ? '2x2'
                : (item.gridWidth == 1 && item.gridHeight == 2 ? '1x2' : '1x1'),
          );
          game.world.add(comp);
        }
        game.obstacles.clear();
        for (final f in game.world.children.whereType<IsometricFurnitureComponent>()) {
          game.obstacles.addAll(f.occupiedSubCells);
        }

        final spawnPos = game.findSafeSpawnSubGrid();
        expect(game.obstacles.contains(spawnPos), isFalse, reason: 'User $uid spawnPos $spawnPos should not be in obstacles');
      }
    });
  });

  group('Cutaway Low Walls / Modo Zócalo Tests', () {
    test('RoomConfig serializes and deserializes wallsCut property', () {
      const configWithFullWalls = RoomConfig(wallsCut: false);
      expect(configWithFullWalls.wallsCut, isFalse);
      final jsonFull = configWithFullWalls.toJson();
      final decodedFull = RoomConfig.fromJson(jsonFull);
      expect(decodedFull.wallsCut, isFalse);

      final configWithLowWalls = configWithFullWalls.copyWith(wallsCut: true);
      expect(configWithLowWalls.wallsCut, isTrue);
      final jsonLow = configWithLowWalls.toJson();
      final decodedLow = RoomConfig.fromJson(jsonLow);
      expect(decodedLow.wallsCut, isTrue);
    });

    test('CozyRoomGame toggleWallsCut and setWallsCut updates game and interior wall heights', () {
      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
        roomConfig: const RoomConfig(wallsCut: false),
      );

      final interiorWall = IsometricInteriorWallComponent(
        id: 'test_wall',
        gridX: 2,
        gridY: 2,
        orientation: 'north',
        wallsCut: false,
      );
      game.world.add(interiorWall);

      expect(game.wallsCut, isFalse);
      expect(interiorWall.wallsCut, isFalse);
      expect(interiorWall.effectiveWallHeight, equals(IsometricInteriorWallComponent.fullWallHeight));

      // Toggle to Low Walls (Zócalo)
      game.toggleWallsCut();
      expect(game.wallsCut, isTrue);
      expect(game.roomConfig.wallsCut, isTrue);
      expect(interiorWall.wallsCut, isTrue);
      expect(interiorWall.effectiveWallHeight, equals(IsometricInteriorWallComponent.lowWallHeight));

      // Toggle back to Full Walls
      game.toggleWallsCut();
      expect(game.wallsCut, isFalse);
      expect(game.roomConfig.wallsCut, isFalse);
      expect(interiorWall.wallsCut, isFalse);
      expect(interiorWall.effectiveWallHeight, equals(IsometricInteriorWallComponent.fullWallHeight));
    });
  });
}
