import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/features/lobby/utils/wall_panels.dart';

final _manifest = WallPanels.parseManifest(File(WallPanels.manifestAsset).readAsStringSync());

(int, int) _pngSize(File f) {
  final b = ByteData.sublistView(f.readAsBytesSync());
  return (b.getUint32(16), b.getUint32(20));
}

void main() {
  group('Wall panels at the furniture pixel density', () {
    final keys = {
      for (final w in RoomThemes.wallpapers) WallPanels.wallpaperKey(w.id),
      WallPanels.wallpaperKey(RoomThemes.getWallpaperId('sage_green', 'tiles')),
      for (final s in InteriorWallStyles.all)
        if (WallPanels.interiorKey(s.id) != null) WallPanels.interiorKey(s.id)!,
    };

    test('every wallpaper and interior wall face has 64x172 panels, as many as the manifest says', () {
      expect(keys, containsAll(['solid_plaster', 'solid_tiles', 'brick_stone', 'wood_slats', 'japanese_shoji']));
      for (final key in keys) {
        final count = _manifest[key] ?? 0;
        expect(count, greaterThan(0), reason: 'no panels for $key');
        for (var n = 0; n < count; n++) {
          final f = File('assets/images/${WallPanels.assetPath(key, n)}');
          expect(f.existsSync(), isTrue, reason: f.path);
          expect(_pngSize(f), (64, 172), reason: f.path);
        }
        expect(File('assets/images/${WallPanels.assetPath(key, count)}').existsSync(), isFalse,
            reason: '$key has more files than the manifest lists');
      }
    });

    test('solid colours use the gray base of their texture; glass and doorways have no face', () {
      expect(WallPanels.wallpaperKey('solid_sage_green'), 'solid_plaster');
      expect(WallPanels.wallpaperKey('solid_tiles_lavender'), 'solid_tiles');
      expect(WallPanels.wallpaperKey('starry_night'), 'starry_night');
      expect(WallPanels.interiorKey('solid_dusty_rose'), 'solid_plaster');
      expect(WallPanels.interiorKey('rustic_brick'), 'rustic_brick');
      expect(WallPanels.interiorKey('bathroom_glass'), isNull);
      expect(WallPanels.interiorKey('doorway_frame'), isNull);
    });
  });
}
