import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/components/explorer_component.dart';
import 'package:frontend/features/game/components/wall_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prompt 3 - Flame Game Engine & Collision Tests', () {
    test('DungeonGame loads default grid matrix and instantiates walls and explorer', () async {
      final game = DungeonGame();
      await game.onLoad();

      final walls = game.world.children.whereType<WallComponent>();
      final explorers = game.world.children.whereType<ExplorerComponent>();

      expect(explorers.length, equals(1));
      expect(walls.length, greaterThan(0));
    });

    test('DungeonGame parses custom 2D grid matrix dynamically', () async {
      final customMatrix = [
        [1, 1, 1],
        [1, 2, 1],
        [1, 1, 1],
      ];

      final game = DungeonGame(
        dungeonMapData: DungeonMapData(
          gridMatrix: customMatrix,
          secretRuneSequence: const ['SOL', 'MOON', 'SNAKE'],
        ),
      );
      await game.onLoad();

      final walls = game.world.children.whereType<WallComponent>();
      expect(walls.length, equals(8)); // 8 walls surrounding center spawn (1,1)

      final explorer = game.world.children.whereType<ExplorerComponent>().first;
      final expectedPos = ExplorerComponent.getCenteredTilePosition(
        1,
        1,
        game.tileSize,
        explorer.size,
      );
      expect(explorer.position, equals(expectedPos));
    });

    test('ExplorerComponent updates position when direction vector is set', () async {
      final customMatrix = [
        [0, 0, 0],
        [0, 2, 0],
        [0, 0, 0],
      ];

      final game = DungeonGame(
        dungeonMapData: DungeonMapData(
          gridMatrix: customMatrix,
          secretRuneSequence: const ['SOL', 'MOON', 'SNAKE'],
        ),
      );
      await game.onLoad();

      final explorer = game.explorer;
      final startPos = explorer.position.clone();

      // Move East
      explorer.setMovementDirection(Vector2(1, 0));
      expect(explorer.isMoving, isTrue);

      explorer.update(0.1); // 0.1s delta time
      // Speed is 220px/s * 0.1s = 22px
      expect(explorer.position.x, closeTo(startPos.x + 22.0, 0.001));
      expect(explorer.position.y, closeTo(startPos.y, 0.001));
    });
  });
}
