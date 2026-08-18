import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../dungeon_game.dart';

class FloorComponent extends Component with HasGameRef<DungeonGame> {
  final Sprite sprite;

  FloorComponent({required this.sprite}) {
    priority = -1; // Render behind everything in the world
  }

  @override
  void render(Canvas canvas) {
    final grid = gameRef.dungeonMapData?.gridMatrix;
    if (grid == null) return;

    final rows = grid.length;
    final cols = grid[0].length;
    final tileSize = gameRef.tileSize;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        sprite.render(
          canvas,
          position: Vector2(c * tileSize, r * tileSize),
          size: Vector2(tileSize, tileSize),
        );
      }
    }
  }
}
