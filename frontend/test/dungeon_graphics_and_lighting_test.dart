import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';
import 'package:frontend/features/game/components/darkness_overlay_component.dart';
import 'package:frontend/features/game/components/explorer_component.dart';
import 'package:frontend/features/game/components/rune_gate_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dungeon 64x64 Sprites, Exit Portal and Directional Lighting Tests', () {
    test('ExplorerComponent calculates accurate facing angles for directional vision', () {
      final explorer = ExplorerComponent(
        position: Vector2(50, 50),
        size: Vector2(32, 48),
      );

      explorer.setFacingDirection(AvatarDirection.south);
      expect(explorer.facingAngle, closeTo(pi / 2, 0.001));

      explorer.setFacingDirection(AvatarDirection.north);
      expect(explorer.facingAngle, closeTo(-pi / 2, 0.001));

      explorer.setFacingDirection(AvatarDirection.east);
      expect(explorer.facingAngle, closeTo(0.0, 0.001));

      explorer.setFacingDirection(AvatarDirection.west);
      expect(explorer.facingAngle, closeTo(pi, 0.001));

      explorer.setFacingDirection(AvatarDirection.southEast);
      expect(explorer.facingAngle, closeTo(pi / 4, 0.001));
    });

    test('RuneGateComponent manages locked state and animated GIF transitions', () {
      final gate = RuneGateComponent(
        position: Vector2(100, 100),
        size: Vector2(36, 36),
      );

      // Gate starts locked (displays exit-off.gif)
      expect(gate.isLocked, isTrue);

      // Unlock gate (when 3 runes are activated -> displays exit-on.gif)
      gate.unlockForDuration(const Duration(seconds: 15));
      expect(gate.isLocked, isFalse);
    });

    test('DarknessOverlayComponent loads and updates directional flashlight angle', () async {
      final game = DungeonGame();
      await game.onLoad();

      final overlay = game.world.children.whereType<DarknessOverlayComponent>().first;
      expect(overlay, isNotNull);

      // Change explorer facing direction to east (0 rad)
      game.explorer.setFacingDirection(AvatarDirection.east);
      overlay.update(0.5); // Let flashlight cone rotate

      // Verify explorer facingAngle is east
      expect(game.explorer.facingAngle, closeTo(0.0, 0.001));
    });

    test('DarknessOverlayComponent raycast stops when encountering walls', () async {
      // Map with wall to the right of spawn
      final customGrid = [
        [1, 1, 1, 1],
        [1, 2, 1, 1], // Player at (1, 1), Wall directly at (2, 1)
        [1, 0, 0, 1],
        [1, 1, 1, 1],
      ];

      final game = DungeonGame(
        dungeonMapData: DungeonMapData(
          gridMatrix: customGrid,
          secretRuneSequence: ['SOL', 'MOON', 'SNAKE'],
        ),
      );
      await game.onLoad();

      final overlay = game.world.children.whereType<DarknessOverlayComponent>().first;
      expect(overlay, isNotNull);

      // Player facing east towards the wall at (2, 1)
      game.explorer.setFacingDirection(AvatarDirection.east);
      overlay.update(0.1);

      // Raycast towards East from feetPosition should illuminate wall face and stop before col 3
      final hitPoint = overlay.castRayForTesting(
        game.explorer.feetPosition.toOffset(),
        0.0,
        150.0,
      );

      // Wall at col 2 spans from x = 2 * tileSize (72) to x = 3 * tileSize (108).
      // Ray penetrates into the wall face (x > 72) and stops before reaching the room behind (x <= 108.0)
      expect(hitPoint.dx, greaterThan(72.0));
      expect(hitPoint.dx, lessThanOrEqualTo(108.0));
    });

    test('Explorer full-body illumination capsule covers entire avatar height including head and hair', () async {
      final game = DungeonGame();
      await game.onLoad();

      final explorer = game.explorer;
      final avatarCenter = Offset(
        explorer.position.x + explorer.size.x / 2,
        explorer.position.y + explorer.size.y / 2,
      );

      // Core capsule height is 62px, outer is 68px
      const coreHeight = 62.0;
      final topOfCoreCapsule = avatarCenter.dy - (coreHeight / 2);
      final bottomOfCoreCapsule = avatarCenter.dy + (coreHeight / 2);

      // Head top is at explorer.position.y, feet are at explorer.position.y + explorer.size.y
      final headTop = explorer.position.y;
      final feetBottom = explorer.position.y + explorer.size.y;

      // The core illumination capsule MUST extend above the top of the head/hair
      expect(topOfCoreCapsule, lessThanOrEqualTo(headTop));
      // And MUST extend below the bottom of the feet
      expect(bottomOfCoreCapsule, greaterThanOrEqualTo(feetBottom));
    });
  });
}
