import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/furniture_item.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/services/furniture_catalog_service.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
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

      final sideTable = FurnitureCatalogService.getItem('side_table');
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
        resolution: '32x64',
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

      expect(deserialized.resolution, equals('32x64'));
      expect(deserialized.wallpaper, equals('starry_night'));
      expect(deserialized.furniture.length, equals(3));
      expect(deserialized.furniture[1].parentId, equals('table_1'));
      expect(deserialized.furniture[2].wallHeightLevel, equals('high'));
      expect(deserialized, equals(room));
    });
  });
}
