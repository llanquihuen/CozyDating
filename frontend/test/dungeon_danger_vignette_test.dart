import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/widgets/dungeon_danger_vignette_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DungeonDangerVignetteOverlay Tests', () {
    testWidgets('Renders nothing when secondsRemaining > 15', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DungeonDangerVignetteOverlay(secondsRemaining: 180),
          ),
        ),
      );

      // Should render SizedBox.shrink, not a Container with BoxDecoration
      expect(find.byType(Container), findsNothing);
      expect(find.byType(DungeonDangerVignetteOverlay), findsOneWidget);
    });

    testWidgets('Renders pulsing red vignette when secondsRemaining <= 15', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DungeonDangerVignetteOverlay(secondsRemaining: 15),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Container with red vignette and IgnorePointer should be present
      expect(find.byType(IgnorePointer), findsWidgets);
      final containerFinder = find.descendant(
        of: find.byType(DungeonDangerVignetteOverlay),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(containerFinder);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      expect(boxDecoration.gradient, isA<RadialGradient>());
    });

    testWidgets('Does not block touches on widgets underneath (IgnorePointer works)', (tester) async {
      bool buttonClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: ElevatedButton(
                    onPressed: () {
                      buttonClicked = true;
                    },
                    child: const Text('BOTON JUEGO'),
                  ),
                ),
                const Positioned.fill(
                  child: DungeonDangerVignetteOverlay(secondsRemaining: 5),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tap through the overlay
      await tester.tap(find.text('BOTON JUEGO'));
      expect(buttonClicked, isTrue);
    });

    testWidgets('Intensifies as time decreases from 15 to 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DungeonDangerVignetteOverlay(secondsRemaining: 1),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      final containerFinder = find.descendant(
        of: find.byType(DungeonDangerVignetteOverlay),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);

      final containerWidget = tester.widget<Container>(containerFinder);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      final border = boxDecoration.border as Border;
      // Border at 1s remaining should be thick (> 4.0)
      expect(border.top.width, greaterThan(4.0));
    });
  });
}
