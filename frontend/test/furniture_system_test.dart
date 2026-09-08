import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/furniture_item.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/services/furniture_catalog_service.dart';
import 'package:frontend/features/lobby/components/isometric_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';
import 'package:frontend/features/lobby/utils/isometric_coords.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FurnitureCatalogService & Metadata Tests', () {
    test('Catalog loads and identifies placement types correctly', () {
      final lamp = FurnitureCatalogService.getItem('table_lamp');
      expect(lamp, isNotNull);
      expect(lamp!.isSurfaceItem, isTrue);
      expect(lamp.placementType, equals(FurniturePlacementType.surface));

      final window = FurnitureCatalogService.getItem('window_yellow');
      expect(window, isNotNull);
      expect(window!.isWallItem, isTrue);

      final windowN = FurnitureCatalogService.getItem('window_yellow_n');
      expect(windowN, isNotNull);
      expect(windowN!.isWallItem, isTrue);

      final windowW = FurnitureCatalogService.getItem('window_yellow_w');
      expect(windowW, isNotNull);
      expect(windowW!.isWallItem, isTrue);

      final diningTable = FurnitureCatalogService.getItem('dining_table_2x2');
      expect(diningTable, isNotNull);
      expect(diningTable!.isSurfaceSupporting, isTrue);
      expect(diningTable.effectiveSurfaceHeight, equals(22));

      final sideTable = FurnitureCatalogService.getItem('side_table_sm') ?? FurnitureCatalogService.getItem('side_table');
      expect(sideTable, isNotNull);
      expect(sideTable!.isSurfaceSupporting, isTrue);
      expect(sideTable.effectiveSurfaceHeight, equals(18));
    });

    test('Paralelepipedos and cubes are active surface-supporting furniture', () {
      final cube1x1 = FurnitureCatalogService.getItem('cube_1x1');
      expect(cube1x1, isNotNull);
      expect(cube1x1!.isSurfaceSupporting, isTrue);
      expect(cube1x1.effectiveSurfaceHeight, greaterThan(0));

      final cube2x2 = FurnitureCatalogService.getItem('cube_2x2');
      expect(cube2x2, isNotNull);
      expect(cube2x2!.isSurfaceSupporting, isTrue);
      expect(cube2x2.effectiveSurfaceHeight, greaterThan(0));
    });

    test('Wall variant normalization between North and West', () {
      expect(FurnitureCatalogItem.getWallVariantFor('window_yellow', true), equals('window_yellow_n'));
      expect(FurnitureCatalogItem.getWallVariantFor('window_yellow', false), equals('window_yellow_w'));
      expect(FurnitureCatalogItem.getWallVariantFor('window_yellow_w', true), equals('window_yellow_n'));
      expect(FurnitureCatalogItem.getWallVariantFor('window_yellow_n', false), equals('window_yellow_w'));
      expect(FurnitureCatalogItem.getWallVariantFor('hanging_shelf_wall_w', true), equals('hanging_shelf_wall_n'));
      expect(FurnitureCatalogItem.getWallVariantFor('hanging_shelf_wall_n', false), equals('hanging_shelf_wall_w'));
      expect(FurnitureCatalogItem.getWallVariantFor('art_painting_w', true), equals('art_painting_n'));
      expect(FurnitureCatalogItem.getWallVariantFor('art_painting_n', false), equals('art_painting_w'));
    });
  });

  group('IsometricCoords Surface, Wall Calculations & Alturas', () {
    test('Surface item offset elevates visual Y snuggly on parent surface', () {
      final offsetWithTable = IsometricCoords.getFurnitureSpriteOffset(
        gridWidth: 1,
        gridHeight: 1,
        spriteWidth: 32,
        spriteHeight: 32,
        footprint: 'surface',
        surfaceHeight: 18.0,
      );

      // (32 / 4) - 32 - 18.0 = 8 - 32 - 18 = -42.0
      expect(offsetWithTable.y, equals(-42.0));
    });

    test('Wall X-axis offset is shifted +16 for North wall and -16 for West wall', () {
      final offsetN = IsometricCoords.getFurnitureSpriteOffset(
        gridWidth: 1,
        gridHeight: 1,
        spriteWidth: 64,
        spriteHeight: 64,
        footprint: 'wall_n',
      );

      final offsetW = IsometricCoords.getFurnitureSpriteOffset(
        gridWidth: 1,
        gridHeight: 1,
        spriteWidth: 64,
        spriteHeight: 64,
        footprint: 'wall_w',
      );

      expect(offsetN.x, equals(-32.0 + 16.0));
      expect(offsetW.x, equals(-32.0 - 16.0));
    });

    test('Wall height levels (mid = -32 vs high = -48) change vertical sprite offset at intermediate point', () {
      final offsetMid = IsometricCoords.getFurnitureSpriteOffset(
        gridWidth: 1,
        gridHeight: 1,
        spriteWidth: 64,
        spriteHeight: 64,
        footprint: 'wall_n',
        wallHeightLevel: 'mid',
      );

      final offsetHigh = IsometricCoords.getFurnitureSpriteOffset(
        gridWidth: 1,
        gridHeight: 1,
        spriteWidth: 64,
        spriteHeight: 64,
        footprint: 'wall_n',
        wallHeightLevel: 'high',
      );

      expect(offsetHigh.y, lessThan(offsetMid.y));
      expect(offsetMid.y - offsetHigh.y, equals(16.0));
    });

    test('Wall Z-order priority is positioned behind floor tiles', () {
      final floorPriority = IsometricCoords.getZOrder(2, 2, footprint: '1x1');
      final wallNPriority = IsometricCoords.getZOrder(2, 0, footprint: 'wall_n');
      final wallWPriority = IsometricCoords.getZOrder(0, 2, footprint: 'wall_w');

      expect(wallNPriority, isNegative);
      expect(wallWPriority, isNegative);
      expect(wallNPriority, lessThan(floorPriority));
      expect(wallWPriority, lessThan(floorPriority));
    });

    test('Wall screenToGrid maintains vertical stability without jumping to (0,0)', () {
      // Moving vertically UP/DOWN on North wall panel gx=2 (sx=80)
      for (double sy = 20; sy >= -120; sy -= 15) {
        final p = IsometricCoords.screenToGrid(80, sy);
        expect(p, equals(const Point(2, 0)), reason: 'At sx=80, sy=$sy point should stay at (2,0)');
      }

      // Moving vertically UP/DOWN on West wall panel gy=2 (sx=-80)
      for (double sy = 20; sy >= -120; sy -= 15) {
        final p = IsometricCoords.screenToGrid(-80, sy);
        expect(p, equals(const Point(0, 2)), reason: 'At sx=-80, sy=$sy point should stay at (0,2)');
      }
    });

    test('Wall screenToGrid advances diagonally 1:1 tile by tile along walls', () {
      // North wall: sx spans [32*gx, 32*(gx+1)), sy=-40 on wall
      expect(IsometricCoords.screenToGrid(16, -40), equals(const Point(0, 0))); // North 0
      expect(IsometricCoords.screenToGrid(48, -40), equals(const Point(1, 0))); // North 1
      expect(IsometricCoords.screenToGrid(80, -40), equals(const Point(2, 0))); // North 2
      expect(IsometricCoords.screenToGrid(112, -40), equals(const Point(3, 0))); // North 3

      // West wall: sx spans [-32*(gy+1), -32*gy), sy=-40 on wall
      expect(IsometricCoords.screenToGrid(-16, -40), equals(const Point(0, 0))); // West 0
      expect(IsometricCoords.screenToGrid(-48, -40), equals(const Point(0, 1))); // West 1
      expect(IsometricCoords.screenToGrid(-80, -40), equals(const Point(0, 2))); // West 2
      expect(IsometricCoords.screenToGrid(-112, -40), equals(const Point(0, 3))); // West 3
    });
  });

  group('Direct Hit-Testing & Surface Prioritization', () {
    test('Wall item hitTestWorld hits directly on wall sprite position', () {
      final wallComp = IsometricFurnitureComponent(
        id: 'window_yellow_n',
        gridX: 2,
        gridY: 0,
        footprint: 'wall_n',
        wallHeightLevel: 'mid',
      );

      final worldCenter = wallComp.position + wallComp.spriteOffset + Vector2(16, 16);
      expect(wallComp.hitTestWorld(worldCenter), isTrue);

      // Touching the floor baldosa underneath the wall item does NOT hit the wall item
      final floorBaldosaCenter = wallComp.position + Vector2(0, 0);
      expect(wallComp.hitTestWorld(floorBaldosaCenter), isFalse);

      // Far away point does not hit
      expect(wallComp.hitTestWorld(Vector2(500, 500)), isFalse);
    });

    test('Surface item hitTestWorld hits directly on elevated tabletop position with generous hitbox', () {
      final lampComp = IsometricFurnitureComponent(
        id: 'table_lamp',
        gridX: 3,
        gridY: 3,
        footprint: 'surface',
        parentSurfaceHeight: 18.0,
      );

      final worldCenter = lampComp.position + lampComp.spriteOffset + Vector2(16, 16);
      expect(lampComp.hitTestWorld(worldCenter), isTrue);
    });

    test('Moving a separate empty table only selects surface items that physically rest on its own tiles', () {
      final table1 = IsometricFurnitureComponent(
        id: 'table_1_unique',
        typeName: 'dining_table_2x2',
        gridX: 1,
        gridY: 1,
        gridWidth: 2,
        gridHeight: 2,
      );

      final lampOnTable1 = IsometricFurnitureComponent(
        id: 'lamp_1_unique',
        typeName: 'table_lamp',
        gridX: 1,
        gridY: 1,
        footprint: 'surface',
        parentId: 'table_1_unique',
      );

      final emptyTable2 = IsometricFurnitureComponent(
        id: 'table_2_unique',
        typeName: 'dining_table_2x2',
        gridX: 4,
        gridY: 4,
        gridWidth: 2,
        gridHeight: 2,
      );

      final allFurniture = [table1, lampOnTable1, emptyTable2];

      // Dragging emptyTable2:
      final attachedToTable2 = allFurniture.where((c) =>
          c.isSurfaceItem &&
          c.gridX >= emptyTable2.gridX &&
          c.gridX < emptyTable2.gridX + emptyTable2.gridWidth &&
          c.gridY >= emptyTable2.gridY &&
          c.gridY < emptyTable2.gridY + emptyTable2.gridHeight).toList();

      expect(attachedToTable2, isEmpty);

      // Dragging table1:
      final attachedToTable1 = allFurniture.where((c) =>
          c.isSurfaceItem &&
          c.gridX >= table1.gridX &&
          c.gridX < table1.gridX + table1.gridWidth &&
          c.gridY >= table1.gridY &&
          c.gridY < table1.gridY + table1.gridHeight).toList();

      expect(attachedToTable1.length, equals(1));
      expect(attachedToTable1.first.id, equals('lamp_1_unique'));
    });

    test('Surface item on multi-tile parent furniture renders in front (higher priority) than parent', () {
      final table2x2 = IsometricFurnitureComponent(
        id: 'table_dining',
        typeName: 'dining_table_2x2',
        gridX: 3,
        gridY: 3,
        gridWidth: 2,
        gridHeight: 2,
      );

      final coffeeMug = IsometricFurnitureComponent(
        id: 'mug',
        typeName: 'coffee_mug',
        gridX: 3,
        gridY: 3,
        footprint: 'surface',
      );

      // Mug links to table with parent furthest tile (4, 4)
      coffeeMug.updateGridPosition(
        coffeeMug.gridX,
        coffeeMug.gridY,
        parentId: table2x2.id,
        parentFurthestX: table2x2.gridX + table2x2.gridWidth - 1,
        parentFurthestY: table2x2.gridY + table2x2.gridHeight - 1,
      );

      expect(coffeeMug.priority, greaterThan(table2x2.priority));
    });
  });

  group('RoomConfig with Resolution & Surface Placed Items', () {
    test('JSON serialization preserves resolution, parentId, wallHeightLevel, and placement data', () {
      const room = RoomConfig(
        resolution: '64x128',
        wallpaper: 'starry_night',
        floor: 'checker_marble',
        furniture: [
          PlacedFurnitureConfig(
            id: 'table_1',
            typeName: 'dining_table_2x2',
            gridX: 2,
            gridY: 2,
            gridWidth: 2,
            gridHeight: 2,
          ),
          PlacedFurnitureConfig(
            id: 'lamp_1',
            typeName: 'table_lamp',
            gridX: 2,
            gridY: 2,
            parentId: 'table_1',
          ),
          PlacedFurnitureConfig(
            id: 'window_1',
            typeName: 'window_yellow_n',
            gridX: 4,
            gridY: 0,
            wallHeightLevel: 'high',
          ),
        ],
      );

      final jsonStr = room.toJson();
      final deserialized = RoomConfig.fromJson(jsonStr);

      expect(deserialized.resolution, equals('64x128'));
      expect(deserialized.wallpaper, equals('starry_night'));
      expect(deserialized.furniture.length, equals(3));
      expect(deserialized.furniture[1].parentId, equals('table_1'));
      expect(deserialized.furniture[2].wallHeightLevel, equals('high'));
      expect(deserialized, equals(room));
    });
  });

  group('0.5x0.5 Sub-Tile & Compact Furniture Tests', () {
    test('PlacedFurnitureConfig and PlacedFurniture support 0.5x0.5 coordinates and dimensions', () {
      const config = PlacedFurnitureConfig(
        id: 'plant_corner_1',
        typeName: 'potted_plant',
        gridX: 2.5,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
      );

      final map = config.toMap();
      final fromMap = PlacedFurnitureConfig.fromMap(map);

      expect(fromMap.gridX, equals(2.5));
      expect(fromMap.gridY, equals(3.5));
      expect(fromMap.gridWidth, equals(0.5));
      expect(fromMap.gridHeight, equals(0.5));

      const placed = PlacedFurniture(
        id: 'plant_1',
        gx: 1.5,
        gy: 4.5,
      );
      final json = placed.toJson();
      final fromJson = PlacedFurniture.fromJson(json);

      expect(fromJson.gx, equals(1.5));
      expect(fromJson.gy, equals(4.5));
    });

    test('IsometricCoords.getFurnitureSpriteOffset handles 0.5x0.5 sub-tile offset', () {
      final offset = IsometricCoords.getFurnitureSpriteOffset(
        gridWidth: 0.5,
        gridHeight: 0.5,
        spriteWidth: 32,
        spriteHeight: 48,
        footprint: '0.5x0.5',
      );

      expect(offset.x, equals(-16.0));
      expect(offset.y, equals(IsometricCoords.tileHeight / 4.0 - 48.0)); // 8.0 - 48.0 = -40.0
    });

    test('IsometricFurnitureComponent 0.5x0.5 occupies exactly 1 sub-cell at (gx*2, gy*2)', () {
      final plant1 = IsometricFurnitureComponent(
        id: 'plant_nw',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        footprint: '0.5x0.5',
      );
      expect(plant1.occupiedSubCells, equals([const Point(4, 6)]));

      final plant2 = IsometricFurnitureComponent(
        id: 'plant_se',
        gridX: 2.5,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        footprint: '0.5x0.5',
      );
      expect(plant2.occupiedSubCells, equals([const Point(5, 7)]));
    });

    test('CozyRoomGame permits multiple 0.5x0.5 items sharing the same standard tile without collision', () {
      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
      );

      final plant1 = IsometricFurnitureComponent(
        id: 'plant_nw',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        footprint: '0.5x0.5',
      );
      game.world.add(plant1);

      final plant2 = IsometricFurnitureComponent(
        id: 'plant_se',
        gridX: 2.5,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        footprint: '0.5x0.5',
      );

      // Placing plant2 at (2.5, 3.5) inside the same (2, 3) tile should be valid!
      final isValidDifferentSubcell = game.checkIsValidLocationForTesting(plant2, const Point<num>(2.5, 3.5));
      expect(isValidDifferentSubcell, isTrue);

      // Placing plant2 directly at the same subcell (2.0, 3.0) should collide and be invalid
      final isValidSameSubcell = game.checkIsValidLocationForTesting(plant2, const Point<num>(2.0, 3.0));
      expect(isValidSameSubcell, isFalse);

      // Placing a 1x1 table at (2.0, 3.0) should collide with plant1 at (2.0, 3.0)
      final table = IsometricFurnitureComponent(
        id: 'table_1x1',
        gridX: 0,
        gridY: 0,
        gridWidth: 1.0,
        gridHeight: 1.0,
        footprint: '1x1',
      );
      final isTableValid = game.checkIsValidLocationForTesting(table, const Point<num>(2.0, 3.0));
      expect(isTableValid, isFalse);

      // Placing table at a completely free tile (4.0, 4.0) should be valid
      final isTableValidFree = game.checkIsValidLocationForTesting(table, const Point<num>(4.0, 4.0));
      expect(isTableValidFree, isTrue);
    });

    test('FurnitureCatalogService includes kitchen_fridge_sm with 0.5x0.5 footprint in kitchen_bath category', () {
      final fridge = FurnitureCatalogService.getItem('kitchen_fridge_sm');
      expect(fridge, isNotNull);
      expect(fridge!.footprint, equals('0.5x0.5'));
      expect(fridge.gridWidth, equals(0.5));
      expect(fridge.gridHeight, equals(0.5));

      final kitchenItems = FurnitureCatalogService.getByCategory('kitchen_bath');
      expect(kitchenItems.any((i) => i.id == 'kitchen_fridge_sm'), isTrue);
    });

    test('All floor furniture (1x1, 1x2, 2x2) supports 0.5 fractional grid placement and accurate occupied sub-cells', () {
      final table1x1 = IsometricFurnitureComponent(
        id: 'table',
        gridX: 2.5,
        gridY: 3.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );
      expect(table1x1.occupiedSubCells, containsAll([
        const Point(5, 6),
        const Point(6, 6),
        const Point(5, 7),
        const Point(6, 7),
      ]));

      final bed1x2 = IsometricFurnitureComponent(
        id: 'bed',
        gridX: 1.5,
        gridY: 2.5,
        gridWidth: 1.0,
        gridHeight: 2.0,
        footprint: '1x2',
      );
      expect(bed1x2.occupiedSubCells.length, equals(8));
      expect(bed1x2.occupiedSubCells, contains(const Point(3, 5)));
      expect(bed1x2.occupiedSubCells, contains(const Point(4, 8)));
    });

    test('Depth sorting correctly orders items in-front vs behind other furniture and walls', () {
      // Chair placed at (2.0, 2.0) is behind Table placed at (2.5, 2.0)
      final chairBehind = IsometricCoords.getSubZOrder(4, 4, width: 2, depth: 2);
      final tableInFront = IsometricCoords.getSubZOrder(5, 4, width: 2, depth: 2);
      expect(tableInFront, greaterThan(chairBehind));

      // Table at (3.0, 3.0) is in front of North interior wall at (3, 3) AND West interior wall at (3, 3)
      final northWall = IsometricCoords.getInteriorWallZOrder(3, 3, 'north');
      final westWall = IsometricCoords.getInteriorWallZOrder(3, 3, 'west');
      final tableSouthOfWall = IsometricCoords.getSubZOrder(6, 6, width: 2, depth: 2);
      expect(tableSouthOfWall, greaterThan(northWall));
      expect(tableSouthOfWall, greaterThan(westWall));

      // Object at (3.0, 2.0) is on the north side of the wall at (3, 3), and renders behind it
      final tableNorthOfWall = IsometricCoords.getSubZOrder(6, 4, width: 2, depth: 2);
      expect(tableNorthOfWall, lessThan(northWall));

      // Object at (2.0, 3.0) is on the west side of the wall at (3, 3), and renders behind it
      final tableWestOfWall = IsometricCoords.getSubZOrder(4, 6, width: 2, depth: 2);
      expect(tableWestOfWall, lessThan(westWall));

      // Wardrobe at (3.5, 3.0) in front of Left North Wall (3, 3)
      final leftNorthWall = IsometricCoords.getInteriorWallZOrder(3, 3, 'north');
      final rightNorthWall = IsometricCoords.getInteriorWallZOrder(4, 3, 'north');
      final wardrobeInFront = IsometricCoords.getSubZOrder(7, 6, width: 2, depth: 2);
      expect(wardrobeInFront, greaterThan(leftNorthWall));

      // Compact Fridge 0.5x0.5 on NW subcell (u=6, v=6, width=1, depth=1) in front of North wall at (3, 3)
      final fridge05InFrontNorth = IsometricCoords.getSubZOrder(6, 6, width: 1, depth: 1);
      expect(fridge05InFrontNorth, greaterThan(leftNorthWall));

      // Compact Fridge 0.5x0.5 on SW subcell (u=6, v=7, width=1, depth=1) in front of West wall at (3, 3)
      final fridge05InFrontWest = IsometricCoords.getSubZOrder(6, 7, width: 1, depth: 1);
      expect(fridge05InFrontWest, greaterThan(IsometricCoords.getInteriorWallZOrder(3, 3, 'west')));

      // Avatar (u=6, v=6, layer=100) on NW subcell in front of North wall at (3, 3)
      final avatarInFrontNorth = IsometricCoords.getSubZOrder(6, 6, width: 1, depth: 1, layer: 100);
      expect(avatarInFrontNorth, greaterThan(leftNorthWall));

      // Avatar (u=6, v=7, layer=100) on SW subcell in front of West wall at (3, 3)
      final avatarInFrontWest = IsometricCoords.getSubZOrder(6, 7, width: 1, depth: 1, layer: 100);
      expect(avatarInFrontWest, greaterThan(IsometricCoords.getInteriorWallZOrder(3, 3, 'west')));

      // Avatar behind North Wall (3, 3) placed on subcell (6, 5)
      final avatarBehindNorth = IsometricCoords.getSubZOrder(6, 5, width: 1, depth: 1, layer: 100);
      expect(avatarBehindNorth, lessThan(leftNorthWall));

      // Furniture at (3.5, 2.0) behind Right North Wall (4, 3)
      final furnitureBehind = IsometricCoords.getSubZOrder(7, 4, width: 2, depth: 2);
      expect(furnitureBehind, lessThan(rightNorthWall));

      // 1x1 furniture at (gx=2, gy=2) -> subcell (4, 4)
      final table1x1Priority = IsometricCoords.getSubZOrder(4, 4, width: 2, depth: 2, layer: 1);
      // Avatar on East subcell (5, 4) within the same 1x1 tile should render IN FRONT of the table
      final avatarEastSubcell = IsometricCoords.getSubZOrder(5, 4, width: 1, depth: 1, layer: 100);
      expect(avatarEastSubcell, greaterThan(table1x1Priority));

      // Avatar on South-West subcell (4, 5) within the same 1x1 tile should render IN FRONT of the table
      final avatarSouthWestSubcell = IsometricCoords.getSubZOrder(4, 5, width: 1, depth: 1, layer: 100);
      expect(avatarSouthWestSubcell, greaterThan(table1x1Priority));

      // Avatar on South-East subcell (5, 5) within the same 1x1 tile should render IN FRONT of the table
      final avatarSouthEastSubcell = IsometricCoords.getSubZOrder(5, 5, width: 1, depth: 1, layer: 100);
      expect(avatarSouthEastSubcell, greaterThan(table1x1Priority));

      // 1x2 Bathtub at (gx=0, gy=0) with wall bump (10000)
      final bathtub1x2Priority = IsometricCoords.getSubZOrder(0, 0, width: 2, depth: 4, layer: 1) + 10000;
      // Avatar standing at East tile (gx=1, gy=0 -> subcell 2, 0)
      final avatarAtEastTile = IsometricCoords.getSubZOrder(2, 0, width: 1, depth: 1, layer: 100);
      expect(avatarAtEastTile, greaterThan(bathtub1x2Priority));
    });
  });

  group('Chair Layer Split & Magnetic Table Snapping Tests', () {
    test('Chair components identify as isChair and support setRotation', () {
      final chair = IsometricFurnitureComponent(
        id: 'simple_chair_sm',
        typeName: 'simple_chair_sm',
        gridX: 4.0,
        gridY: 5.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        footprint: '0.5x0.5',
      );
      expect(chair.isChair, isTrue);
      expect(chair.rotation, equals(0));

      chair.setRotation(2);
      expect(chair.rotation, equals(2));
    });

    test('Chair Backrest Overlay renders with priority above the table (Solución A)', () {
      final table = IsometricFurnitureComponent(
        id: 'table_1',
        typeName: 'table',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );

      final chairSouth = IsometricFurnitureComponent(
        id: 'chair_south',
        typeName: 'simple_chair_sm',
        gridX: 4.0,
        gridY: 5.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 2,
        footprint: '0.5x0.5',
      );
      final overlay = ChairBackrestOverlayComponent(chairSouth);
      overlay.update(0.016);

      // The chair base priority sits at its ground position
      expect(chairSouth.priority, isNotNull);
      // The chair backrest overlay has higher priority to render over the table's front edge
      expect(overlay.priority, greaterThan(table.priority));
    });

    test('canSnapToTable is true for simple_chair_sm and false for standard items', () {
      final chair = IsometricFurnitureComponent(
        id: 'simple_chair_sm',
        typeName: 'simple_chair_sm',
        gridX: 0,
        gridY: 0,
      );
      expect(chair.canSnapToTable, isTrue);

      final bookshelf = IsometricFurnitureComponent(
        id: 'bookshelf',
        typeName: 'bookshelf',
        gridX: 0,
        gridY: 0,
      );
      expect(bookshelf.canSnapToTable, isFalse);
    });

    test('canSnapToTable is true for gamer_chair_sm and gamer_chair', () {
      final gamerChairSm = IsometricFurnitureComponent(
        id: 'gamer_chair_sm',
        typeName: 'gamer_chair_sm',
        gridX: 0,
        gridY: 0,
      );
      expect(gamerChairSm.canSnapToTable, isTrue);

      final gamerChair = IsometricFurnitureComponent(
        id: 'gamer_chair',
        typeName: 'gamer_chair',
        gridX: 0,
        gridY: 0,
      );
      expect(gamerChair.canSnapToTable, isTrue);
    });

    test('gaming_pc_desk provides only 1 snap slot directly in front of the computer for each rotation', () {
      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
        roomConfig: const RoomConfig(),
      );

      final desk = IsometricFurnitureComponent(
        id: 'gaming_desk_1',
        typeName: 'gaming_pc_desk',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
        rotation: 0,
      );

      // Rot 0: Screen faces SW -> slot at South (gy: 5.0), chair faces North (autoRotation 2)
      desk.rotation = 0;
      var slots = game.getChairSnapSlotsForTable(desk);
      expect(slots.length, equals(1));
      expect(slots.first.gx, equals(4.25));
      expect(slots.first.gy, equals(5.0));
      expect(slots.first.autoRotation, equals(2));

      // Rot 1: Screen faces SE -> slot at East (gx: 5.0), chair faces West (autoRotation 3)
      desk.rotation = 1;
      slots = game.getChairSnapSlotsForTable(desk);
      expect(slots.length, equals(1));
      expect(slots.first.gx, equals(5.0));
      expect(slots.first.gy, equals(4.25));
      expect(slots.first.autoRotation, equals(3));

      // Rot 2: Screen faces NE -> slot at North (gy: 3.5), chair faces South (autoRotation 0)
      desk.rotation = 2;
      slots = game.getChairSnapSlotsForTable(desk);
      expect(slots.length, equals(1));
      expect(slots.first.gx, equals(4.25));
      expect(slots.first.gy, equals(3.5));
      expect(slots.first.autoRotation, equals(0));

      // Rot 3: Screen faces NW -> slot at West (gx: 3.5), chair faces East (autoRotation 1)
      desk.rotation = 3;
      slots = game.getChairSnapSlotsForTable(desk);
      expect(slots.length, equals(1));
      expect(slots.first.gx, equals(3.5));
      expect(slots.first.gy, equals(4.25));
      expect(slots.first.autoRotation, equals(1));
    });

    test('Table seat slots are centered between tiles to prevent clipping', () {
      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
        roomConfig: const RoomConfig(),
      );

      final table = IsometricFurnitureComponent(
        id: 'table_1',
        typeName: 'table',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );

      final slots = game.getChairSnapSlotsForTable(table);
      expect(slots.isNotEmpty, isTrue);

      // North slot centered at gx: 4.25, gy: 3.5
      final northSlot = slots.firstWhere((s) => s.autoRotation == 0);
      expect(northSlot.gx, equals(4.25));
      expect(northSlot.gy, equals(3.5));

      // South slot centered at gx: 4.25, gy: 5.0
      final southSlot = slots.firstWhere((s) => s.autoRotation == 2);
      expect(southSlot.gx, equals(4.25));
      expect(southSlot.gy, equals(5.0));

      // West slot centered at gx: 3.5, gy: 4.25
      final westSlot = slots.firstWhere((s) => s.autoRotation == 1);
      expect(westSlot.gx, equals(3.5));
      expect(westSlot.gy, equals(4.25));

      // East slot centered at gx: 5.0, gy: 4.25
      final eastSlot = slots.firstWhere((s) => s.autoRotation == 3);
      expect(eastSlot.gx, equals(5.0));
      expect(eastSlot.gy, equals(4.25));
    });

    test('Chair bases are tucked UNDER the table in ALL rotations (rot 0, 1, 2, 3)', () {
      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
        roomConfig: const RoomConfig(
          furniture: [
            PlacedFurnitureConfig(id: 'table_center', typeName: 'table', gridX: 4.0, gridY: 4.0, gridWidth: 1.0, gridHeight: 1.0),
            PlacedFurnitureConfig(id: 'chair_north', typeName: 'simple_chair_sm', gridX: 4.25, gridY: 3.5, rotation: 0),
            PlacedFurnitureConfig(id: 'chair_south', typeName: 'simple_chair_sm', gridX: 4.25, gridY: 5.0, rotation: 2),
            PlacedFurnitureConfig(id: 'chair_west', typeName: 'simple_chair_sm', gridX: 3.5, gridY: 4.25, rotation: 1),
            PlacedFurnitureConfig(id: 'chair_east', typeName: 'simple_chair_sm', gridX: 5.0, gridY: 4.25, rotation: 3),
          ],
        ),
      );

      final table = IsometricFurnitureComponent(
        id: 'table_center',
        typeName: 'table',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );

      // Verify findAdjacentTableForChair detects table for all 4 chair positions:
      expect(game.findAdjacentTableForChair(IsometricFurnitureComponent(gridX: 4.25, gridY: 3.5), 4.25, 3.5), isNull); // before added to world

      game.world.add(table);
      expect(game.findAdjacentTableForChair(IsometricFurnitureComponent(gridX: 4.25, gridY: 3.5), 4.25, 3.5), equals(table));
      expect(game.findAdjacentTableForChair(IsometricFurnitureComponent(gridX: 4.25, gridY: 5.0), 4.25, 5.0), equals(table));
      expect(game.findAdjacentTableForChair(IsometricFurnitureComponent(gridX: 3.5, gridY: 4.25), 3.5, 4.25), equals(table));
      expect(game.findAdjacentTableForChair(IsometricFurnitureComponent(gridX: 5.0, gridY: 4.25), 5.0, 4.25), equals(table));
    });

    test('Chairs snapped to table at fractional offsets block all covered subcells', () {
      final chairNE = IsometricFurnitureComponent(
        id: 'chair_ne',
        typeName: 'simple_chair_sm',
        gridX: 4.25,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        footprint: '0.5x0.5',
      );
      // gx = 4.25 * 2 = 8.5 -> floor is 8, max is 9. gy = 3.5 * 2 = 7
      expect(chairNE.occupiedSubCells, containsAll([
        const Point(8, 7),
        const Point(9, 7),
      ]));

      final chairNW = IsometricFurnitureComponent(
        id: 'chair_nw',
        typeName: 'simple_chair_sm',
        gridX: 3.5,
        gridY: 4.25,
        gridWidth: 0.5,
        gridHeight: 0.5,
        footprint: '0.5x0.5',
      );
      // gx = 3.5 * 2 = 7. gy = 4.25 * 2 = 8.5 -> floor is 8, max is 9
      expect(chairNW.occupiedSubCells, containsAll([
        const Point(7, 8),
        const Point(7, 9),
      ]));
    });

    test('Directional table-chair depth sorting does not occlude avatar 1 square before NW chair', () {
      final table = IsometricFurnitureComponent(
        id: 'table_center',
        typeName: 'table',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );

      final chairNW = IsometricFurnitureComponent(
        id: 'chair_nw',
        typeName: 'simple_chair_sm',
        gridX: 3.5,
        gridY: 4.25,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 1, // Facing table (East)
        footprint: '0.5x0.5',
      );

      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
      );
      game.world.add(table);
      game.world.add(chairNW);
      game.recalculateSurfacePriorities();

      // Chair is behind the table
      expect(chairNW.priority, lessThan(table.priority));

      // Avatar walking 1 tile before the chair on tile (3, 4) at subcell (6, 8)
      final avatarOneSquareAwayZ = IsometricCoords.getSubZOrder(6, 8, layer: 100);
      expect(avatarOneSquareAwayZ, lessThan(chairNW.priority));

      // Avatar on the walkway tile in front of the chair (e.g. tile 3, 5 at subcell 6, 10)
      final avatarInFrontZ = IsometricCoords.getSubZOrder(6, 10, layer: 100);
      expect(avatarInFrontZ, greaterThan(chairNW.priority));
    });

    test('Avatar walking behind South chair renders behind the chair', () {
      final table = IsometricFurnitureComponent(
        id: 'table_center',
        typeName: 'table',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );

      final chairSouth = IsometricFurnitureComponent(
        id: 'chair_south',
        typeName: 'simple_chair_sm',
        gridX: 4.25,
        gridY: 5.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        rotation: 2, // Facing table (North)
        footprint: '0.5x0.5',
      );

      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
      );
      game.world.add(table);
      game.world.add(chairSouth);
      game.recalculateSurfacePriorities();

      // South chair is in front of the table
      expect(chairSouth.priority, greaterThan(table.priority));

      // Avatar standing behind the South chair at (4, 4) (subcell 8, 8)
      final avatarBehindSouthChairZ = IsometricCoords.getSubZOrder(8, 8, layer: 100);
      expect(avatarBehindSouthChairZ, lessThan(chairSouth.priority));
    });

    test('Avatar standing South of table-attached chairs renders in front of chair and backrest overlay', () {
      final game = CozyRoomGame(avatarConfig: const AvatarConfig());

      for (final is2x2 in [false, true]) {
        final table = IsometricFurnitureComponent(
          id: is2x2 ? 'table_2x2' : 'table_1x1',
          typeName: is2x2 ? 'dining_table_2x2' : 'table',
          gridX: 4.0,
          gridY: 4.0,
          gridWidth: is2x2 ? 2.0 : 1.0,
          gridHeight: is2x2 ? 2.0 : 1.0,
          footprint: is2x2 ? '2x2' : '1x1',
        );

        final slots = game.getChairSnapSlotsForTable(table);
        for (final slot in slots) {
          final chair = IsometricFurnitureComponent(
            id: 'chair_${slot.gx}_${slot.gy}',
            typeName: 'simple_chair_sm',
            gridX: slot.gx,
            gridY: slot.gy,
            gridWidth: 0.5,
            gridHeight: 0.5,
            footprint: '0.5x0.5',
            rotation: slot.autoRotation,
          );

          final testGame = CozyRoomGame(avatarConfig: const AvatarConfig());
          testGame.world.add(table);
          testGame.world.add(chair);
          testGame.recalculateSurfacePriorities();

          final overlay = ChairBackrestOverlayComponent(chair);
          overlay.update(0.016);

          final occupied = chair.occupiedSubCells;
          final minU = (slot.gx * 2.0).floor();
          final minV = (slot.gy * 2.0).floor();

          // Check subcells to the south / southeast / southwest of the chair
          for (int du = 0; du <= 2; du++) {
            for (int dv = 0; dv <= 2; dv++) {
              if (du == 0 && dv == 0) continue;
              final testU = minU + du;
              final testV = minV + dv;
              if (occupied.contains(Point(testU, testV))) continue;

              final avZ = IsometricCoords.getSubZOrder(testU, testV, layer: 100);
              expect(
                avZ,
                greaterThan(chair.priority),
                reason: 'Avatar at ($testU, $testV) must render in front of chair at (${slot.gx}, ${slot.gy})',
              );
              expect(
                avZ,
                greaterThan(overlay.priority),
                reason: 'Avatar at ($testU, $testV) must render in front of backrest overlay at (${slot.gx}, ${slot.gy})',
              );
            }
          }
        }
      }
    });
  });

  group('Multi-tile 1x2 and 2x1 Furniture Depth Sorting & Avatar Occlusion Tests', () {
    test('2x1 furniture (e.g. cube_2x1) correctly sorts avatars behind and in front of all tiles', () {
      final cube2x1 = IsometricFurnitureComponent(
        id: 'cube_2x1',
        typeName: 'cube_2x1',
        gridX: 3.0,
        gridY: 2.0,
        gridWidth: 2.0,
        gridHeight: 1.0,
        footprint: '2x1',
      );
      // Furthest tile is (3+2-1, 2+1-1) = (4.0, 2.0) -> subcell (8, 4)
      final expectedPriority = IsometricCoords.getSubZOrder(8, 4, layer: 1);
      expect(cube2x1.priority, equals(expectedPriority));

      // 1. Avatar standing BEHIND the North tile (3, 1) -> subcell (6, 2)
      final avatarBehindNorth = IsometricCoords.getSubZOrder(6, 2, layer: 100);
      expect(avatarBehindNorth, lessThan(cube2x1.priority),
          reason: 'Avatar behind the north tile of 2x1 must render behind the furniture');

      // 2. Avatar standing BEHIND the South-East tile (4, 1) -> subcell (8, 2)
      // (This was previously broken because the 2x1 only sorted against tile (3,2))
      final avatarBehindSE = IsometricCoords.getSubZOrder(8, 2, layer: 100);
      expect(avatarBehindSE, lessThan(cube2x1.priority),
          reason: 'Avatar behind the south-east tile of 2x1 must render behind the furniture');

      // 3. Avatar standing IN FRONT OF the South-East tile (4, 3) -> subcell (8, 6)
      final avatarInFrontSE = IsometricCoords.getSubZOrder(8, 6, layer: 100);
      expect(avatarInFrontSE, greaterThan(cube2x1.priority),
          reason: 'Avatar in front of south-east tile of 2x1 must render in front of the furniture');

      // 4. Avatar standing IN FRONT OF the North tile (3, 3) -> subcell (6, 6)
      final avatarInFrontNorth = IsometricCoords.getSubZOrder(6, 6, layer: 100);
      expect(avatarInFrontNorth, greaterThan(cube2x1.priority),
          reason: 'Avatar in front of north tile of 2x1 must render in front of the furniture');
    });

    test('1x2 furniture (e.g. simple_sofa) correctly sorts avatars and adjacent furniture along South/West end', () {
      final sofa1x2 = IsometricFurnitureComponent(
        id: 'simple_sofa',
        typeName: 'simple_sofa',
        gridX: 3.0,
        gridY: 2.0,
        gridWidth: 1.0,
        gridHeight: 2.0,
        footprint: '1x2',
      );
      // Furthest tile is (3+1-1, 2+2-1) = (3.0, 3.0) -> subcell (6, 6)
      final expectedPriority = IsometricCoords.getSubZOrder(6, 6, layer: 1);
      expect(sofa1x2.priority, equals(expectedPriority));

      // 1. Avatar standing BEHIND North-East tile (3, 1) -> subcell (6, 2)
      final avatarBehindNE = IsometricCoords.getSubZOrder(6, 2, layer: 100);
      expect(avatarBehindNE, lessThan(sofa1x2.priority),
          reason: 'Avatar behind north-east tile of 1x2 must render behind the sofa');

      // 2. Avatar standing BEHIND South-West tile (2, 3) -> subcell (4, 6)
      // (This was previously broken because the 1x2 only sorted against tile (3,2))
      final avatarBehindSW = IsometricCoords.getSubZOrder(4, 6, layer: 100);
      expect(avatarBehindSW, lessThan(sofa1x2.priority),
          reason: 'Avatar behind south-west tile of 1x2 must render behind the sofa');

      // 3. Avatar standing IN FRONT OF South-West tile (3, 4) -> subcell (6, 8)
      final avatarInFrontSW = IsometricCoords.getSubZOrder(6, 8, layer: 100);
      expect(avatarInFrontSW, greaterThan(sofa1x2.priority),
          reason: 'Avatar in front of south-west tile of 1x2 must render in front of the sofa');

      // 4. Neighboring furniture placed at (2, 3) (North-West of the sofa southern armrest)
      final neighbor = IsometricFurnitureComponent(
        id: 'side_table',
        typeName: 'side_table',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );
      expect(neighbor.priority, lessThan(sofa1x2.priority),
          reason: 'Neighbor at (2, 3) must render behind the sofa southern armrest at (3, 3)');
    });
  });

  group('Animated Furniture & Gaming PC Desk Activation Tests', () {
    test('IsometricFurnitureComponent advances animation frames only when activated', () {
      final comp = IsometricFurnitureComponent(
        id: 'gaming_pc_desk',
        typeName: 'gaming_pc_desk',
        gridX: 4.0,
        gridY: 4.0,
        rotation: 0,
        animatedRotationSprites: {
          0: [
            // Frame 0 placeholder
            Sprite(ImageTestUtils.createDummyImage()),
            // Frame 1 placeholder
            Sprite(ImageTestUtils.createDummyImage()),
          ],
        },
        frameDuration: 0.1,
      );

      expect(comp.isActivated, isFalse);
      expect(comp.currentAnimFrame, equals(0));

      // Tick while inactive -> remains at frame 0
      comp.update(0.2);
      expect(comp.currentAnimFrame, equals(0));

      // Activate -> animates
      comp.setActivated(true);
      expect(comp.isActivated, isTrue);

      comp.update(0.05);
      expect(comp.currentAnimFrame, equals(0));

      comp.update(0.06); // total 0.11 > 0.10s
      expect(comp.currentAnimFrame, equals(1));

      comp.update(0.10); // loops back to frame 0
      expect(comp.currentAnimFrame, equals(0));

      // Deactivate -> resets
      comp.setActivated(false);
      expect(comp.isActivated, isFalse);
      expect(comp.currentAnimFrame, equals(0));
    });

    test('Sitting on the chair in front of gaming_pc_desk activates desk and standing up deactivates it', () {
      final desk = IsometricFurnitureComponent(
        id: 'gaming_pc_desk_1',
        typeName: 'gaming_pc_desk',
        gridX: 4.0,
        gridY: 4.0,
        rotation: 0, // Chair slot is at South (gx: 4.25, gy: 5.0, autoRotation: 2)
        animatedRotationSprites: {
          0: [
            Sprite(ImageTestUtils.createDummyImage()),
            Sprite(ImageTestUtils.createDummyImage()),
          ],
        },
      );

      final chairInFront = IsometricFurnitureComponent(
        id: 'gamer_chair_1',
        typeName: 'gamer_chair',
        gridX: 4.25,
        gridY: 5.0,
        rotation: 2,
      );

      final otherChair = IsometricFurnitureComponent(
        id: 'gamer_chair_2',
        typeName: 'gamer_chair',
        gridX: 1.0,
        gridY: 1.0,
        rotation: 0,
      );

      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
        roomConfig: const RoomConfig(),
      );

      game.world.add(desk);
      game.world.add(chairInFront);
      game.world.add(otherChair);

      // Create avatar connected to game's activation callback
      final avatar = IsometricAvatarComponent(
        gridX: 8.0,
        gridY: 8.0,
        config: const AvatarConfig(),
        onSitStateChanged: game.updateFurnitureActivationStatesForTesting,
      );
      game.world.add(avatar);
      game.avatar = avatar;

      expect(desk.isActivated, isFalse);

      // Sit on unrelated chair -> desk remains inactive
      avatar.sitOnChair(otherChair);
      expect(desk.isActivated, isFalse);

      // Sit on chair in front of desk -> desk activates!
      avatar.sitOnChair(chairInFront);
      expect(desk.isActivated, isTrue);

      // Stand up -> desk deactivates!
      avatar.standUp();
      expect(desk.isActivated, isFalse);
    });

    test('Sitting partnerAvatar in front of gaming_pc_desk activates desk and standing up deactivates it', () {
      final desk = IsometricFurnitureComponent(
        id: 'gaming_pc_desk_1',
        typeName: 'gaming_pc_desk',
        gridX: 4.0,
        gridY: 4.0,
        rotation: 0, // Chair slot is at South (gx: 4.25, gy: 5.0, autoRotation: 2)
        animatedRotationSprites: {
          0: [
            Sprite(ImageTestUtils.createDummyImage()),
            Sprite(ImageTestUtils.createDummyImage()),
          ],
        },
      );

      final chairInFront = IsometricFurnitureComponent(
        id: 'gamer_chair_1',
        typeName: 'gamer_chair',
        gridX: 4.25,
        gridY: 5.0,
        rotation: 2,
      );

      final game = CozyRoomGame(
        avatarConfig: const AvatarConfig(),
        roomConfig: const RoomConfig(),
      );

      game.world.add(desk);
      game.world.add(chairInFront);

      // Create partnerAvatar connected to game's activation callback
      final partner = IsometricAvatarComponent(
        gridX: 8.0,
        gridY: 8.0,
        config: const AvatarConfig(),
        onSitStateChanged: game.updateFurnitureActivationStatesForTesting,
      );
      game.world.add(partner);
      game.partnerAvatar = partner;

      expect(desk.isActivated, isFalse);

      // Sit partner on chair in front of desk -> desk activates!
      partner.sitOnChair(chairInFront);
      expect(desk.isActivated, isTrue);

      // Stand up -> desk deactivates!
      partner.standUp();
      expect(desk.isActivated, isFalse);
    });
  });
}

class ImageTestUtils {
  static dynamic createDummyImage() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint());
    final picture = recorder.endRecording();
    return picture.toImageSync(1, 1);
  }
}

