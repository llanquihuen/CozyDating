import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/services/furniture_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Retired furniture (docs/furniture-audit.md)', () {
    test('a saved room with a retired piece loads its replacement with the right footprint', () {
      final tub = PlacedFurnitureConfig.fromMap(const {
        'id': 'tub',
        'typeName': 'bathtub_2x2',
        'gridX': 2,
        'gridY': 3,
        'gridWidth': 2,
        'gridHeight': 2,
        'rotation': 1,
        'assetPath': 'furniture/established_furniture/bathtub_2x2_rot1.png',
      });
      expect(tub.typeName, 'bathtub_classic');
      expect((tub.gridWidth, tub.gridHeight), (2.0, 1.0)); // 1x2 turned once
      expect(tub.assetPath, isNull);
      expect((tub.gridX, tub.gridY, tub.rotation), (2.0, 3.0, 1));

      final bed = PlacedFurnitureConfig.fromMap(const {'id': 'b', 'typeName': 'single_bed', 'gridX': 7, 'gridY': 0});
      expect((bed.typeName, bed.gridWidth, bed.gridHeight), ('single_high_bed', 1.0, 2.0));

      final kept = PlacedFurnitureConfig.fromMap(const {'id': 'k', 'typeName': 'table', 'gridWidth': 1, 'gridHeight': 1});
      expect(kept.typeName, 'table');
    });

    test('the catalog no longer offers retired pieces but still resolves their ids', () async {
      await FurnitureCatalogService.initialize(forceReload: true);
      for (final entry in PlacedFurnitureConfig.retiredTypes.entries) {
        expect(FurnitureCatalogService.items.containsKey(entry.key), isFalse, reason: entry.key);
        expect(FurnitureCatalogService.getItem(entry.key)?.id, entry.value.$1);
      }
      final offered = {
        for (final c in ['living', 'bedroom', 'kitchen_bath', 'surface', 'walls', 'patio'])
          ...FurnitureCatalogService.getByCategory(c).map((i) => i.id),
      };
      expect(offered.intersection(PlacedFurnitureConfig.retiredTypes.keys.toSet()), isEmpty);
    });
  });
}
