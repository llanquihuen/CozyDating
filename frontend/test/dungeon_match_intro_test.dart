import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/models/game_models.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/game/screens/dungeon_match_intro_view.dart';

import 'dart:async';

class _MockWebSocketClient extends WebSocketClient {
  final List<Map<String, dynamic>> sentMessages = [];
  final StreamController<Map<String, dynamic>> _messageController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<WebSocketConnectionState> get stateStream => Stream.value(WebSocketConnectionState.connected);

  @override
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  void addMessage(Map<String, dynamic> msg) {
    _messageController.add(msg);
  }

  @override
  Future<void> connect(String url, String token) async {}

  @override
  void sendMessage(Map<String, dynamic> data) {
    sentMessages.add(data);
  }

  @override
  void dispose() {
    _messageController.close();
    super.dispose();
  }
}

void main() {
  group('DungeonMatchIntroView Widget Tests', () {
    testWidgets('Renders Match Intro Screen with both players and Explorer role guide', (tester) async {
      final mockClient = _MockWebSocketClient();
      final gameBloc = GameBloc(webSocketClient: mockClient);

      const session = SessionInitPayload(
        roomId: 'room_123',
        role: 'EXPLORER',
        mode: 'STANDARD',
        partnerId: 'bob',
        act: 1,
      );

      bool gameStarted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: gameBloc,
            child: BlocBuilder<GameBloc, GameState>(
              builder: (context, state) {
                if (state is ActiveGameState) {
                  return DungeonMatchIntroView(
                    state: state,
                    onStartGame: () {
                      gameStarted = true;
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      // Emit active game state in BLoC
      gameBloc.emit(const ActiveGameState(session: session));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('¡CITA ENCONTRADA!'), findsOneWidget);
      expect(find.text('Acto 1 • Mazmorra Cooperativa'), findsOneWidget);
      expect(find.text('TE VAN A GUIAR 🔦'), findsOneWidget);
      expect(find.text('¡Listo para la Cita!'), findsOneWidget);
      expect(find.text('Entrar directamente (Prueba)'), findsNothing);

      // Tap ready button
      await tester.tap(find.text('¡Listo para la Cita!'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(mockClient.sentMessages.any((m) => m['type'] == 'GAME_READY'), isTrue);

      // When partner also signals ready, countdown begins and starts the game
      gameBloc.emit(const ActiveGameState(
        session: session,
        localReady: true,
        partnerReady: true,
      ));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(seconds: 4));
      expect(gameStarted, isTrue);
    });

    testWidgets('Tapping Rechazar opens confirmation dialog and emits EMERGENCY_DISCONNECT', (tester) async {
      final mockClient = _MockWebSocketClient();
      final gameBloc = GameBloc(webSocketClient: mockClient);

      const session = SessionInitPayload(
        roomId: 'room_789',
        role: 'EXPLORER',
        mode: 'STANDARD',
        partnerId: 'bob',
        act: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: gameBloc,
            child: DungeonMatchIntroView(
              state: const ActiveGameState(session: session),
              onStartGame: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tap 'Rechazar'
      await tester.tap(find.text('Rechazar'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¿Rechazar esta cita?'), findsOneWidget);

      // Confirm rejection
      await tester.tap(find.text('Rechazar y Salir'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(mockClient.sentMessages.any((m) => m['type'] == 'EMERGENCY_DISCONNECT'), isTrue);
    });

    testWidgets('Tapping partner room sneakpeek opens isometric room preview modal and allows closing', (tester) async {
      final mockClient = _MockWebSocketClient();
      final gameBloc = GameBloc(webSocketClient: mockClient);

      const session = SessionInitPayload(
        roomId: 'room_room_modal_1',
        role: 'EXPLORER',
        mode: 'STANDARD',
        partnerId: 'bob',
        act: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: gameBloc,
            child: DungeonMatchIntroView(
              state: const ActiveGameState(session: session),
              onStartGame: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Find the partner sneakpeek card
      final roomPreviewTile = find.textContaining('Cuarto de Bob');
      expect(roomPreviewTile, findsOneWidget);

      // Ensure visible in SingleChildScrollView before tapping
      await tester.ensureVisible(roomPreviewTile);
      await tester.pump(const Duration(milliseconds: 100));

      // Tap room sneakpeek to open modal
      await tester.tap(roomPreviewTile);
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal is displayed with title and return button
      expect(find.textContaining('El Hogar de Bob'), findsOneWidget);
      expect(find.text('Volver a la Preparación ✨'), findsOneWidget);

      // Tap return button to dismiss dialog
      await tester.tap(find.text('Volver a la Preparación ✨'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('El Hogar de Bob'), findsNothing);
    });

    testWidgets('Displays local player face only (no own room) and partner with age, full bio, room and tastes', (tester) async {
      final mockClient = _MockWebSocketClient();
      final gameBloc = GameBloc(webSocketClient: mockClient);

      const session = SessionInitPayload(
        roomId: 'room_profile_check',
        role: 'EXPLORER',
        mode: 'STANDARD',
        partnerId: 'bob',
        partnerUsername: 'Bob Ross',
        partnerTastes: ['game_coop', 'cinema_ghibli', 'life_coffee_tea'],
        act: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: gameBloc,
            child: DungeonMatchIntroView(
              state: const ActiveGameState(session: session),
              onStartGame: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // 1. Local player does NOT have an own room preview
      expect(find.text('Tu Habitación'), findsNothing);
      expect(find.textContaining('Tú ('), findsOneWidget);

      // 2. Partner card displays:
      // - Name and Age (Bob in DB is 26 years old)
      expect(find.text('Bob Ross'), findsOneWidget);
      expect(find.textContaining('26 años'), findsOneWidget);
      expect(find.textContaining('Providencia'), findsOneWidget);

      // - Full Bio (entire description shown)
      expect(find.text('Acerca de mí'), findsOneWidget);
      expect(find.textContaining('Diseñador de día'), findsOneWidget);

      // - Partner Room sneakpeek
      expect(find.textContaining('Cuarto de Bob'), findsOneWidget);

      // - Tastes
      expect(find.text('Sus Gustos & Intereses'), findsOneWidget);
      expect(find.textContaining('Studio Ghibli'), findsOneWidget);
    });

    testWidgets('Displays real database partnerAge and partnerCommune when received via SessionInitPayload', (tester) async {
      final mockClient = _MockWebSocketClient();
      final gameBloc = GameBloc(webSocketClient: mockClient);

      const session = SessionInitPayload(
        roomId: 'room_custom_db_age',
        role: 'EXPLORER',
        mode: 'STANDARD',
        partnerId: 'user_random_db_id',
        partnerUsername: 'Carla',
        partnerAge: 29,
        partnerCommune: 'Viña del Mar',
        partnerTastes: ['game_coop'],
        act: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: gameBloc,
            child: DungeonMatchIntroView(
              state: const ActiveGameState(session: session),
              onStartGame: () {},
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Partner card must display Carla's exact database age and commune
      expect(find.text('Carla'), findsOneWidget);
      expect(find.textContaining('29 años'), findsOneWidget);
      expect(find.textContaining('Viña del Mar'), findsOneWidget);
    });
  });
}
