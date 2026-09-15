import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/game_models.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/game/components/explorer_component.dart';
import 'package:frontend/features/game/components/pitfall_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/game_view.dart';
import 'package:frontend/features/game/guide_game_view.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';

class _MockWebSocketClient extends WebSocketClient {
  final List<Map<String, dynamic>> sentMessages = [];

  @override
  Stream<WebSocketConnectionState> get stateStream => Stream.value(WebSocketConnectionState.connected);
  @override
  Stream<Map<String, dynamic>> get messageStream => const Stream.empty();
  @override
  Future<void> connect(String url, String token) async {}
  @override
  void sendMessage(Map<String, dynamic> data) {
    sentMessages.add(data);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dungeon Pitfall Trap Covering & Guide X Tests', () {
    test('Proximity detection and covering pitfall traps before falling in', () async {
      final mapData = DungeonGenerator.generateMap(seed: 12345, act: 1);
      String? feedbackMessage;
      final game = DungeonGame(
        dungeonMapData: mapData,
        onRuneFeedback: (msg) => feedbackMessage = msg,
      );
      await game.onLoad();

      // Find first pitfall in world
      final pitfall = game.world.children.whereType<PitfallComponent>().first;
      expect(pitfall.isRepaired, isFalse);
      expect(pitfall.isTriggered, isFalse);

      // Position explorer far away from the pitfall
      game.explorer.position = Vector2(0, 0);
      game.updateCoverTrapState();
      expect(game.canCoverTrap.value, isFalse);
      expect(game.getNearbyCoverablePitfall(), isNull);

      // Move explorer to adjacent tile right before the trap (1 tile south)
      final pitCol = (pitfall.position.x / game.tileSize).round();
      final pitRow = (pitfall.position.y / game.tileSize).round();
      game.explorer.position = ExplorerComponent.getCenteredTilePosition(
        pitCol,
        pitRow + 1,
        game.tileSize,
        game.explorer.size,
      );
      game.updateCoverTrapState();
      expect(game.getNearbyCoverablePitfall(), equals(pitfall));
      expect(game.canCoverTrap.value, isTrue);

      // Explorer taps the trap covering action
      final success = game.coverNearbyPitfall();
      expect(success, isTrue);
      expect(pitfall.isRepaired, isTrue);
      expect(pitfall.isTriggered, isFalse);
      expect(game.canCoverTrap.value, isFalse);
      expect(feedbackMessage, contains('tablones'));

      // Stepping on repaired pitfall does NOT trap explorer
      pitfall.onCollisionStart(
        {pitfall.position + Vector2(10, 10)},
        game.explorer,
      );
      expect(game.isExplorerTrapped, isFalse);
      expect(pitfall.isTriggered, isFalse);
    });

    testWidgets('Guide view displays bottom warning banner for traps marked with X', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = SessionInitPayload(
        roomId: 'test-room-1',
        role: 'GUIDE',
        mode: 'STANDARD',
        partnerId: 'explorer-1',
      );

      final state = ActiveGameState(
        session: session,
      );

      final mockWs = _MockWebSocketClient();
      final gameBloc = GameBloc(webSocketClient: mockWs);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<GameBloc>.value(
            value: gameBloc,
            child: GuideGameView(state: state),
          ),
        ),
      );

      // Verify that before map finishes loading, tutorial hand hint is NOT visible
      expect(find.byIcon(Icons.touch_app), findsNothing);

      // Advance time for map assets to load
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      // Verify the hand drawing hint is now visible after map load
      expect(find.byIcon(Icons.touch_app), findsOneWidget);

      // Verify the red trap warning banner text in the bottom sector
      expect(find.text('Avisa al explorador las trampas marcadas con X'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });

    testWidgets('Explorer view has TAPAR TRAMPA button which activates when near pitfall', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = SessionInitPayload(
        roomId: 'test-room-2',
        role: 'EXPLORER',
        mode: 'STANDARD',
        partnerId: 'guide-1',
      );

      final state = ActiveGameState(
        session: session,
      );

      final mockWs = _MockWebSocketClient();
      final gameBloc = GameBloc(webSocketClient: mockWs);

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<GameBloc>.value(
            value: gameBloc,
            child: GameView(state: state),
          ),
        ),
      );

      await tester.pump();

      // The button exists in the tree
      final buttonFinder = find.byKey(const ValueKey('cover_trap_button'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('TAPAR TRAMPA'), findsOneWidget);

      // Initially, when not right before a trap, button is disabled
      final initialButton = tester.widget<ElevatedButton>(buttonFinder);
      expect(initialButton.onPressed, isNull);
    });
  });
}
