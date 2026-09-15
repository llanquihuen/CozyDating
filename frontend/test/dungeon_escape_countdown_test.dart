import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/components/darkness_overlay_component.dart';
import 'package:frontend/features/game/components/rune_gate_component.dart';
import 'package:frontend/features/game/components/rune_tile_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';
import 'package:frontend/features/game/widgets/dungeon_escape_countdown_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dungeon Escape 7-Segment Countdown Banner Tests', () {
    testWidgets('Appears in large format and then smoothly shrinks to exactly 36px in height', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: DungeonEscapeCountdownBanner(secondsRemaining: 15),
            ),
          ),
        ),
      );

      // 1. Initial appearance (first 500ms): Large banner with escape warning title is rendered
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('¡HUYE! EL PORTAL SE CIERRA EN:'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);

      // Initial size is large (> 70px)
      final initialSize = tester.getSize(find.byType(DungeonEscapeCountdownBanner));
      expect(initialSize.height, greaterThan(70.0));

      // 2. Advance time past the 1.6s shrink animation:
      // It smoothly shrinks down to the compact top bar
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump();

      // Final resting height is strictly 36.0 px as requested by the user
      final compactSize = tester.getSize(find.byType(DungeonEscapeCountdownBanner));
      expect(compactSize.height, 36.0);

      // Compact banner shows the concise warning and the 7-segment clock
      expect(find.text('¡HUYE! PORTAL:'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Returns SizedBox.shrink when secondsRemaining is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DungeonEscapeCountdownBanner(secondsRemaining: 0),
          ),
        ),
      );

      expect(find.text('¡HUYE! EL PORTAL SE CIERRA EN:'), findsNothing);
      expect(find.text('¡HUYE! PORTAL:'), findsNothing);
    });
  });

  group('Dungeon Red Emergency Light & State Restoration Tests', () {
    test('DarknessOverlayComponent activates red lighting on portal unlock and restores on timeout', () async {
      final mapData = DungeonGenerator.generateMap(seed: 12345, act: 1);
      final game = DungeonGame(dungeonMapData: mapData);
      await game.onLoad();

      final overlay = game.world.children.whereType<DarknessOverlayComponent>().first;
      final gate = game.world.children.whereType<RuneGateComponent>().first;

      // 1. Initial State: Normal darkness, gate locked, portal timer at 0
      expect(game.portalRemainingSeconds.value, 0);
      expect(gate.isLocked, isTrue);

      // 2. Unlock portal: Escape countdown begins with red emergency lighting
      game.unlockRuneGate(seconds: 2);
      expect(game.portalRemainingSeconds.value, 2);
      expect(gate.isLocked, isFalse);

      // Simulate rendering while portal is open (red alarm light active)
      overlay.update(0.1);

      // 3. Let countdown expire (simulate timeout where player does not reach exit)
      await Future<void>.delayed(const Duration(milliseconds: 2200));

      // 4. Verification: Dungeon seamlessly returns to its previous state
      expect(game.portalRemainingSeconds.value, 0);
      expect(gate.isLocked, isTrue); // Relocked with exit-off.gif
      expect(game.currentSteppedSequence.isEmpty, isTrue); // Sequence reset

      // All rune tiles reset to unlit
      for (final rune in game.world.children.whereType<RuneTileComponent>()) {
        expect(rune.isLit, isFalse);
      }
    });
  });
}
