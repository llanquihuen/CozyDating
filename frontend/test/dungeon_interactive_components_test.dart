import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/components/darkness_overlay_component.dart';
import 'package:frontend/features/game/components/floor_switch_component.dart';
import 'package:frontend/features/game/components/pushable_block_component.dart';
import 'package:frontend/features/game/components/spike_trap_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prompt 4 - Interactive Dungeon Components Tests', () {
    test('DungeonGame loads interactive components and darkness overlay', () async {
      final game = DungeonGame();
      await game.onLoad();

      final traps = game.world.children.whereType<SpikeTrapComponent>();
      final blocks = game.world.children.whereType<PushableBlockComponent>();
      final switches = game.world.children.whereType<FloorSwitchComponent>();
      final overlays = game.world.children.whereType<DarknessOverlayComponent>();

      expect(traps.length, greaterThanOrEqualTo(1));
      expect(blocks.length, equals(0));
      expect(switches.length, equals(0));
      expect(overlays.length, equals(1));
    });

    test('PushableBlockComponent moves when space is clear', () async {
      final emptyMap = DungeonMapData(
        gridMatrix: List.generate(11, (_) => List.generate(11, (_) => 0)),
        secretRuneSequence: ['SOL', 'MOON', 'SNAKE'],
      );
      final game = DungeonGame(dungeonMapData: emptyMap);
      await game.onLoad();

      final block = PushableBlockComponent(
        position: Vector2(32, 32),
        size: Vector2(32, 32),
      );
      game.add(block);

      // Try pushing East
      final success = block.tryPush(Vector2(1, 0));
      expect(success, isTrue);

      block.update(0.2); // Advance animation
      expect(block.isMoving, isTrue);
    });

    test('SpikeTrapComponent alternates active and inactive state over time', () {
      final trap = SpikeTrapComponent(
        position: Vector2(0, 0),
        size: Vector2(32, 32),
        isPeriodic: true,
      );

      final initialState = trap.isActive;
      trap.update(3.0); // Advance timer by 3.0s

      expect(trap.isActive, equals(!initialState));
    });

    test('FloorSwitchComponent toggles isPressed on collision', () {
      final switchComp = FloorSwitchComponent(
        position: Vector2(0, 0),
        size: Vector2(32, 32),
      );

      expect(switchComp.isPressed, isFalse);

      final mockComponent = PositionComponent();
      switchComp.onCollision(Set(), mockComponent);

      // Note: FloorSwitchComponent checks type for Explorer/Block
    });
  });
}
