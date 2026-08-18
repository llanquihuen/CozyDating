import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/components/rune_gate_component.dart';
import 'package:frontend/features/game/components/rune_tile_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Procedural Dungeon Generator & Rune Puzzle Tests', () {
    test('DungeonGenerator produces valid map data and 3-rune secret sequence', () {
      final mapData = DungeonGenerator.generateMap(seed: 12345);

      expect(mapData.gridMatrix.length, equals(11));
      expect(mapData.gridMatrix[0].length, equals(11));
      expect(mapData.secretRuneSequence.length, equals(3));
    });

    test('RuneGateComponent starts locked and unlocks on command', () {
      final gate = RuneGateComponent(
        position: Vector2(32, 32),
        size: Vector2(32, 32),
      );

      expect(gate.isLocked, isTrue);

      gate.unlock();

      expect(gate.isLocked, isFalse);
    });

    test('DungeonGame loads procedural map with Rune Gates and Rune Tiles', () async {
      final game = DungeonGame();
      await game.onLoad();

      final gates = game.world.children.whereType<RuneGateComponent>();
      final runeTiles = game.world.children.whereType<RuneTileComponent>();

      expect(gates.length, greaterThanOrEqualTo(1));
      expect(runeTiles.length, greaterThanOrEqualTo(3));
    });
  });
}
