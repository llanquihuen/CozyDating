import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/components/explorer_component.dart';
import 'package:frontend/features/game/components/pitfall_component.dart';
import 'package:frontend/features/game/components/spike_trap_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pitfall Soft Trap and Cooperative Rescue Tests', () {
    test('DungeonGame portal unlocks for 15 seconds by default', () async {
      final game = DungeonGame();
      await game.onLoad();

      expect(game.portalRemainingSeconds.value, equals(0));
      game.unlockRuneGate(); // Default 15 seconds
      expect(game.portalRemainingSeconds.value, equals(15));
      game.cancelPortalCountdown();
    });

    test('ExplorerComponent gets trapped in pitfall without resetting to start (1,1)', () async {
      final game = DungeonGame();
      await game.onLoad();

      final pitfallPos = Vector2(36 * 3, 36 * 3);
      final pitfall = PitfallComponent(position: pitfallPos, size: Vector2(36, 36));
      game.world.add(pitfall);

      expect(game.explorer.isTrappedInPitfall, isFalse);

      // Trigger pitfall trap
      game.explorer.triggerTrappedInPitfall(pitfallPos);

      expect(game.explorer.isTrappedInPitfall, isTrue);
      // Explorer is positioned at the pitfall, NOT reset to (1,1) (which would be at 36,36)
      expect(game.explorer.position.x, greaterThan(36 * 2));

      // Attempting to move while trapped is blocked
      final currentPos = game.explorer.position.clone();
      game.explorer.setMovementDirection(Vector2(1, 0));
      expect(game.explorer.isMoving, isFalse);
      expect(game.explorer.position, equals(currentPos));

      // Rescue explorer
      game.rescueExplorerFromPitfall(pitfallPos);
      expect(game.explorer.isTrappedInPitfall, isFalse);
      expect(pitfall.isRepaired, isTrue);
    });

    test('Explorer soft-stumbles backwards when hitting active spike trap', () async {
      final game = DungeonGame();
      await game.onLoad();

      final initialSafePos = game.explorer.lastSafePosition.clone();

      // Soft stumble
      game.explorer.softStumbleFromSpike();

      expect(game.explorer.position, equals(initialSafePos));
      expect(game.explorer.isMoving, isFalse);
    });
  });
}
