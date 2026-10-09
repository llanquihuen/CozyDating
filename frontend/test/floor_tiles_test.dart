import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/features/lobby/utils/floor_tiles.dart';

final _manifest = FloorTiles.parseManifest(File(FloorTiles.manifestAsset).readAsStringSync());

(int, int) _pngSize(File f) {
  final b = ByteData.sublistView(f.readAsBytesSync());
  return (b.getUint32(16), b.getUint32(20));
}

void main() {
  group('Floor tiles at the furniture pixel density', () {
    // The catalog lists the patterns and tiled colours; carpets are built from a colour key.
    final keys = {
      for (final f in RoomThemes.floors) FloorTiles.tileKey(f.id),
      FloorTiles.tileKey(RoomThemes.getFloorId('warm_sand', 'carpet')),
    };

    test('every floor in the catalog has tiles of 128x64, as many as the manifest says', () {
      expect(keys, containsAll(['solid_tiles', 'solid_carpet', 'oak_parquet', 'tatami_mat']));
      for (final key in keys) {
        final count = _manifest[key] ?? 0;
        expect(count, greaterThan(0), reason: 'no tiles for $key');
        for (var n = 0; n < count; n++) {
          final f = File('assets/images/${FloorTiles.assetPath(key, n)}');
          expect(f.existsSync(), isTrue, reason: f.path);
          expect(_pngSize(f), (128, 64), reason: f.path);
        }
        expect(File('assets/images/${FloorTiles.assetPath(key, count)}').existsSync(), isFalse,
            reason: '$key has more files than the manifest lists');
      }
    });

    test('solid colours draw with the gray base of their texture', () {
      expect(FloorTiles.tileKey('solid_carpet_blush_pink'), 'solid_carpet');
      expect(FloorTiles.tileKey('solid_slate_gray'), 'solid_tiles');
      expect(FloorTiles.tileKey('oak_parquet'), 'oak_parquet');
    });

    test('the variant hash is stable, in range and mixes variants', () {
      final seen = <int>{};
      for (var gy = 0; gy < 8; gy++) {
        for (var gx = 0; gx < 8; gx++) {
          final v = FloorTiles.variant(gx, gy, 4);
          expect(v, inInclusiveRange(0, 3));
          expect(FloorTiles.variant(gx, gy, 4), v);
          seen.add(v);
        }
      }
      expect(seen.length, 4);
    });
  });
}
