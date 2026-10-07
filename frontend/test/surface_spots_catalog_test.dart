import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/furniture_item.dart';
import 'package:frontend/core/services/furniture_catalog_service.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Surface Spots Catalog & Isometric Placement Tests', () {
    test('FurnitureRotationMeta and FurnitureCatalogItem parse surface_spots correctly', () {
      final jsonSample = {
        'id': 'test_table',
        'name': 'Test Table',
        'footprint': '1x1',
        'surface_height': 18,
        'supports_surface': true,
        'surface_offset': [-5, -13],
        'surface_spots': [
          {'spot': 0, 'sub_cell': [0, 0], 'offset': [-5, -13], 'item': 'table_lamp'},
          {'spot': 1, 'sub_cell': [1, 0], 'offset': [-4, -17], 'item': 'coffee_mug'},
          {'spot': 2, 'sub_cell': [0, 1], 'offset': [6, -5], 'item': 'coffee_mug'},
          {'spot': 3, 'sub_cell': [1, 1], 'offset': [8, -12], 'item': 'open_book'},
        ],
        'rotations': {
          '0': {
            'id': 'test_table_rot0',
            'name': 'Test Table Rot 0',
            'footprint': '1x1',
            'rot': 0,
            'surface_height': 18,
            'supports_surface': true,
            'surface_offset': [-5, -13],
            'surface_spots': [
              {'spot': 0, 'sub_cell': [0, 0], 'offset': [-5, -13], 'item': 'table_lamp'},
              {'spot': 1, 'sub_cell': [1, 0], 'offset': [-4, -17], 'item': 'coffee_mug'},
              {'spot': 2, 'sub_cell': [0, 1], 'offset': [6, -5], 'item': 'coffee_mug'},
              {'spot': 3, 'sub_cell': [1, 1], 'offset': [8, -12], 'item': 'open_book'},
            ],
          }
        }
      };

      final catalogItem = FurnitureCatalogItem.fromJson('test_table', jsonSample);
      expect(catalogItem.surfaceSpots.length, equals(4));
      expect(catalogItem.surfaceSpots[0].subU, equals(0));
      expect(catalogItem.surfaceSpots[0].subV, equals(0));
      expect(catalogItem.surfaceSpots[0].offsetX, equals(-5));
      expect(catalogItem.surfaceSpots[0].offsetY, equals(-13));

      expect(catalogItem.surfaceSpots[1].subU, equals(1));
      expect(catalogItem.surfaceSpots[1].subV, equals(0));
      expect(catalogItem.surfaceSpots[1].offsetX, equals(-4));
      expect(catalogItem.surfaceSpots[1].offsetY, equals(-17));

      expect(catalogItem.surfaceSpots[2].subU, equals(0));
      expect(catalogItem.surfaceSpots[2].subV, equals(1));
      expect(catalogItem.surfaceSpots[2].offsetX, equals(6));
      expect(catalogItem.surfaceSpots[2].offsetY, equals(-5));

      expect(catalogItem.surfaceSpots[3].subU, equals(1));
      expect(catalogItem.surfaceSpots[3].subV, equals(1));
      expect(catalogItem.surfaceSpots[3].offsetX, equals(8));
      expect(catalogItem.surfaceSpots[3].offsetY, equals(-12));

      final rot0 = catalogItem.rotations[0]!;
      expect(rot0.surfaceSpots.length, equals(4));
      expect(rot0.surfaceSpots[3].offsetX, equals(8));
      expect(rot0.surfaceSpots[3].offsetY, equals(-12));
    });

    test('IsometricFurnitureComponent applies spot-specific offsets based on relative subcell', () async {
      await FurnitureCatalogService.initialize();

      // Parent table placed at (2.0, 3.0)
      final world = World();
      final table = IsometricFurnitureComponent(
        id: 'table',
        typeName: 'table',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      );
      world.add(table);

      // Spot 0: subcell (0, 0) -> placed at (2.0, 3.0)
      final mugSpot0 = IsometricFurnitureComponent(
        id: 'mug_0',
        typeName: 'coffee_mug',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
        parentSurfaceHeight: 18.0,
      );
      world.add(mugSpot0);

      // Spot 1: subcell (1, 0) -> placed at (2.5, 3.0)
      final mugSpot1 = IsometricFurnitureComponent(
        id: 'mug_1',
        typeName: 'coffee_mug',
        gridX: 2.5,
        gridY: 3.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
        parentSurfaceHeight: 18.0,
      );
      world.add(mugSpot1);

      // Spot 2: subcell (0, 1) -> placed at (2.0, 3.5)
      final mugSpot2 = IsometricFurnitureComponent(
        id: 'mug_2',
        typeName: 'coffee_mug',
        gridX: 2.0,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
        parentSurfaceHeight: 18.0,
      );
      world.add(mugSpot2);

      // Spot 3: subcell (1, 1) -> placed at (2.5, 3.5)
      final mugSpot3 = IsometricFurnitureComponent(
        id: 'mug_3',
        typeName: 'coffee_mug',
        gridX: 2.5,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
        parentSurfaceHeight: 18.0,
      );
      world.add(mugSpot3);

      final off0 = mugSpot0.spriteOffset;
      final off1 = mugSpot1.spriteOffset;
      final off2 = mugSpot2.spriteOffset;
      final off3 = mugSpot3.spriteOffset;

      // Table offsets in furniture_catalog.json (hand-tuned to the art):
      // spot 0: [-6, -6]
      // spot 1: [-5, -15] -> diff in X: +1, diff in Y: -9
      // spot 2: [6, -5]   -> diff in X: +12, diff in Y: +1
      // spot 3: [8, -14]  -> diff in X: +14, diff in Y: -8
      expect(off1.x - off0.x, equals(1.0));
      expect(off1.y - off0.y, equals(-9.0));

      expect(off2.x - off0.x, equals(12.0));
      expect(off2.y - off0.y, equals(1.0));

      expect(off3.x - off0.x, equals(14.0));
      expect(off3.y - off0.y, equals(-8.0));
    });

    test('Dragged surface item previews the surface spot of the cell it hovers over', () async {
      await FurnitureCatalogService.initialize();

      final world = World();
      world.add(IsometricFurnitureComponent(
        id: 'table',
        typeName: 'table',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      ));

      final resting = IsometricFurnitureComponent(
        id: 'mug_rest',
        typeName: 'coffee_mug',
        gridX: 2.5,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
        parentSurfaceHeight: 18.0,
      );
      world.add(resting);

      // Still at spot (0,0) until dropped, but hovering over spot (1,1)
      final dragged = IsometricFurnitureComponent(
        id: 'mug_drag',
        typeName: 'coffee_mug',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
        parentSurfaceHeight: 18.0,
      );
      world.add(dragged);
      dragged.dragHoverGridX = 2.5;
      dragged.dragHoverGridY = 3.5;

      expect(dragged.spriteOffset, equals(resting.spriteOffset));
    });

    test('Surface items on the same table are ordered from back to front by priority', () async {
      await FurnitureCatalogService.initialize();

      // Parent table placed at (2.0, 3.0)
      final table = IsometricFurnitureComponent(
        id: 'table',
        typeName: 'table',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
      )..updateGridPosition(2.0, 3.0);

      // Spot 0: back (0, 0)
      final lampBack = IsometricFurnitureComponent(
        id: 'lamp_back',
        typeName: 'table_lamp',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
      )..updateGridPosition(
          2.0,
          3.0,
          parentId: 'table',
          parentFurthestX: 2.0,
          parentFurthestY: 3.0,
        );

      // Spot 1: right (1, 0)
      final lampRight = IsometricFurnitureComponent(
        id: 'lamp_right',
        typeName: 'table_lamp',
        gridX: 2.5,
        gridY: 3.0,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
      )..updateGridPosition(
          2.5,
          3.0,
          parentId: 'table',
          parentFurthestX: 2.0,
          parentFurthestY: 3.0,
        );

      // Spot 3: front (1, 1)
      final lampFront = IsometricFurnitureComponent(
        id: 'lamp_front',
        typeName: 'table_lamp',
        gridX: 2.5,
        gridY: 3.5,
        gridWidth: 0.5,
        gridHeight: 0.5,
        parentId: 'table',
      )..updateGridPosition(
          2.5,
          3.5,
          parentId: 'table',
          parentFurthestX: 2.0,
          parentFurthestY: 3.0,
        );

      // Back lamp MUST have lower priority than right lamp
      expect(lampBack.priority < lampRight.priority, isTrue,
          reason: 'Back lamp (priority ${lampBack.priority}) must be behind right lamp (priority ${lampRight.priority})');

      // Right lamp MUST have lower priority than front lamp
      expect(lampRight.priority < lampFront.priority, isTrue,
          reason: 'Right lamp (priority ${lampRight.priority}) must be behind front lamp (priority ${lampFront.priority})');

      // Front lamp MUST have higher priority than back lamp
      expect(lampFront.priority > lampBack.priority, isTrue,
          reason: 'Front lamp (priority ${lampFront.priority}) must be rendered on top of back lamp (priority ${lampBack.priority})');
    });
  });
}
