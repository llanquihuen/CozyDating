import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/widgets/dungeon_mission_hud.dart';
import 'package:frontend/features/game/widgets/emote_wheel_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dungeon Mission HUD & Emote Wheel Widget Tests', () {
    testWidgets('DungeonMissionHud renders 3 rune sockets and countdown timer', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DungeonMissionHud(
              isGuide: false,
              targetRuneSequence: ['SOL', 'MOON', 'SNAKE'],
              currentActivatedCount: 1,
              portalSecondsRemaining: 15,
            ),
          ),
        ),
      );

      // Verify Explorer role tag
      expect(find.text('🔦 EXPLORADOR'), findsOneWidget);

      // Verify portal countdown display
      expect(find.text('15s'), findsOneWidget);

      // 1st rune is activated (shows ☀️), remaining 2 are unactivated (show ?)
      expect(find.text('☀️'), findsOneWidget);
      expect(find.text('?'), findsNWidgets(2));
    });

    testWidgets('DungeonAlertOverlay displays rescue button when partner is trapped in Guide view', (tester) async {
      bool rescueClicked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DungeonAlertOverlay(
              isGuide: true,
              isTrapped: true,
              onRescuePressed: () {
                rescueClicked = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('🪢 ¡Compañero atrapado! TOCA AQUÍ PARA RESCATAR'), findsOneWidget);

      await tester.tap(find.text('🪢 ¡Compañero atrapado! TOCA AQUÍ PARA RESCATAR'));
      expect(rescueClicked, isTrue);
    });

    testWidgets('EmoteWheelWidget expands on tap and selects emote', (tester) async {
      String? selectedEmote;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmoteWheelWidget(
              onEmoteSelected: (emote) {
                selectedEmote = emote;
              },
            ),
          ),
        ),
      );

      // Tap trigger button
      await tester.tap(find.byIcon(Icons.sentiment_satisfied_alt));
      await tester.pumpAndSettle();

      // Find heart emoji and tap it
      expect(find.text('❤️'), findsOneWidget);
      await tester.tap(find.text('❤️'));
      await tester.pumpAndSettle();

      expect(selectedEmote, equals('❤️'));
    });
  });
}
