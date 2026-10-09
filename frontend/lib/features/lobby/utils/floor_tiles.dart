import 'dart:convert';

import '../../../core/models/room_config.dart';

/// Isometric floor tiles drawn at the furniture's pixel density: one 128x64 sprite per 64x32 tile,
/// drawn at 0.5x. Made by `CreateSprites/room_tiles/make_floors.py`, several variants per material.
class FloorTiles {
  /// Variant count per tile key, written by make_floors.py next to the sprites.
  static const String manifestAsset = 'assets/images/floors/tiles/tiles.json';

  static String assetPath(String tileKey, int n) => 'floors/tiles/${tileKey}_v$n.png';

  /// Variant for tile (gx, gy); same hash as `variant()` in make_floors.py.
  static int variant(int gx, int gy, int count) =>
      (((gx * 73856093) ^ (gy * 19349663)) & 0x7FFFFFFF) % count;

  static Map<String, int> parseManifest(String json) =>
      (jsonDecode(json) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));

  /// Tile set a floor id draws with: a pattern's own tiles, or the gray base a solid colour tints.
  static String tileKey(String floorId) {
    final opt = RoomThemes.getFloorOption(floorId);
    if (opt.color == null) return floorId;
    final isCarpet = opt.textureType == 'carpet' || floorId.contains('carpet');
    return isCarpet ? 'solid_carpet' : 'solid_tiles';
  }
}
