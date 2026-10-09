import 'dart:convert';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../../core/models/room_config.dart';

/// Wall panels drawn at the furniture's pixel density: one 64x172 sprite per 32-unit wall column
/// (64x140 px of wall slanted like the isometric wall), drawn at 0.5x. Made by
/// `CreateSprites/room_tiles/make_walls.py`. Sprites are north-facing; west walls draw them mirrored.
class WallPanels {
  /// Panel count per key, written by make_walls.py next to the sprites.
  static const String manifestAsset = 'assets/images/wallpaper/panels/panels.json';

  /// World size of a panel sprite: 32 wide, 70 of wall plus the 16 the slant adds.
  static const double width = 32.0;
  static const double wallHeight = 70.0;
  static const double slant = 16.0;

  static String assetPath(String key, int n) => 'wallpaper/panels/${key}_p$n.png';

  static Map<String, int> parseManifest(String json) =>
      (jsonDecode(json) as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int));

  /// Panel set a perimeter wallpaper draws with: a pattern's own, or the gray base a colour tints.
  static String wallpaperKey(String wallpaperId) {
    final opt = RoomThemes.getWallpaperOption(wallpaperId);
    if (opt.color == null) return wallpaperId;
    final isTiles = opt.textureType == 'tiles' || wallpaperId.contains('tiles');
    return isTiles ? 'solid_tiles' : 'solid_plaster';
  }

  /// Panel set an interior wall style draws its face with, or null for styles without a face
  /// texture (glass, open doorway).
  static String? interiorKey(String style) {
    switch (style) {
      case 'wood_slats':
      case 'rustic_brick':
      case 'japanese_shoji':
      case 'modern_white':
        return style;
      case 'bathroom_glass':
      case 'doorway_frame':
        return null;
    }
    final opt = InteriorWallStyles.getOption(style);
    if (opt.color == null) return 'wood_slats';
    return style.contains('tiles') ? 'solid_tiles' : 'solid_plaster';
  }

  /// Draws a panel whose wall base runs from x = [left] to [left] + 32. [top] is the highest point
  /// of the panel's top edge (the wall base's highest end minus the wall height). North panels drop
  /// to the right; [mirrored] ones (west walls) drop to the left.
  static void draw(Canvas canvas, Sprite sprite,
      {required double left, required double top, required bool mirrored, Paint? paint}) {
    final size = Vector2(width, wallHeight + slant);
    if (!mirrored) {
      sprite.render(canvas, position: Vector2(left, top), size: size, overridePaint: paint);
      return;
    }
    canvas.save();
    canvas.translate(left + width, top);
    canvas.scale(-1, 1);
    sprite.render(canvas, size: size, overridePaint: paint);
    canvas.restore();
  }
}
