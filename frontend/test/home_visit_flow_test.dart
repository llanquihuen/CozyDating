import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/game_models.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/home_visit/screens/home_visit_view.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;

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
  group('Home Visit Date Mode Flow & Unit Tests', () {
    late _MockWebSocketClient mockWs;
    late GameBloc gameBloc;

    setUp(() {
      mockWs = _MockWebSocketClient();
      gameBloc = GameBloc(webSocketClient: mockWs);
    });

    tearDown(() {
      gameBloc.close();
      mockWs.dispose();
    });

    test('GameBloc processes SESSION_INIT with mode HOME and sets isHomeVisitActive', () async {
      mockWs.addMessage({
        "type": "SESSION_INIT",
        "roomId": "room_home_123",
        "role": "EXPLORER",
        "act": 1,
        "seed": 42,
        "mode": "HOME",
        "isHomeVisitActive": true,
        "hostUserId": "user_host_1",
        "partnerId": "user_guest_2",
        "partnerUsername": "Bob"
      });

      await expectLater(
        gameBloc.stream,
        emitsThrough(predicate<GameState>((state) {
          if (state is! ActiveGameState) return false;
          return state.session.mode == 'HOME' &&
              state.isHomeVisitActive &&
              state.hostUserId == 'user_host_1' &&
              state.session.roomId == 'room_home_123' &&
              state.session.partnerId == 'user_guest_2';
        })),
      );
    });

    test('GameBloc sends HOME date action events to WebSocket', () async {
      // 1. Move event
      gameBloc.add(const SendHomeAvatarMoveEvent(gridX: 10.0, gridY: 12.0));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockWs.sentMessages.any((m) => m['type'] == 'HOME_AVATAR_MOVE' && m['gridX'] == 10.0), isTrue);

      // 2. Sit event
      gameBloc.add(const SendHomeAvatarSitEvent(chairId: 'chair_wood_1', slotIndex: 1));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockWs.sentMessages.any((m) => m['type'] == 'HOME_AVATAR_SIT' && m['chairId'] == 'chair_wood_1'), isTrue);

      // 2b. Stand event
      gameBloc.add(const SendHomeAvatarStandEvent(gridX: 10.0, gridY: 13.0));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockWs.sentMessages.any((m) => m['type'] == 'HOME_AVATAR_STAND' && m['gridX'] == 10.0 && m['gridY'] == 13.0), isTrue);

      // 3. Emote event
      gameBloc.add(const SendHomeEmoteEvent(emote: '🍵'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockWs.sentMessages.any((m) => m['type'] == 'HOME_EMOTE' && m['emote'] == '🍵'), isTrue);

      // 4. Action event
      gameBloc.add(const SendHomeActionEvent(actionType: 'tea', message: 'sirvió té'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockWs.sentMessages.any((m) => m['type'] == 'HOME_ACTION' && m['actionType'] == 'tea'), isTrue);

      // 5. Chat event
      gameBloc.add(const SendHomeChatEvent(text: 'Hola en tu casa!'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockWs.sentMessages.any((m) => m['type'] == 'HOME_CHAT' && m['text'] == 'Hola en tu casa!'), isTrue);

      // 6. Completed date event
      gameBloc.add(const SendHomeCompletedEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(mockWs.sentMessages.any((m) => m['type'] == 'DATE_COMPLETED'), isTrue);
    });

    testWidgets('HomeVisitView renders host room title and cozy action buttons', (tester) async {
      final hostUser = const UserProfile(
        id: 'user_host_1',
        username: 'Alice',
        avatarConfig: AvatarConfig(),
        roomConfig: RoomConfig(),
      );
      final guestUser = const UserProfile(
        id: 'user_guest_2',
        username: 'Bob',
        avatarConfig: AvatarConfig(),
        roomConfig: RoomConfig(),
      );

      bool leaveTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<GameBloc>.value(
            value: gameBloc,
            child: HomeVisitView(
              localUser: guestUser,
              partnerUser: hostUser,
              isHost: false,
              hostName: 'Alice',
              hostRoomConfig: const RoomConfig(),
              onLeave: () {
                leaveTriggered = true;
              },
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Should show the host name badge
      expect(find.text('Hogar de Alice'), findsOneWidget);

      // Should show the action buttons
      expect(find.text('🍵'), findsOneWidget);
      expect(find.text('🎵'), findsOneWidget);
      expect(find.text('💖'), findsOneWidget);
      expect(find.text('✨'), findsOneWidget);
      expect(find.text('💬'), findsOneWidget);
      expect(find.text('Salir'), findsOneWidget);

      // Should show the walls cut button and toggle it
      expect(find.byKey(const Key('toggle_walls_cut_button')), findsOneWidget);
      expect(find.text('Muros'), findsOneWidget);
      await tester.tap(find.byKey(const Key('toggle_walls_cut_button')));
      await tester.pump();
      expect(find.text('Zócalo'), findsOneWidget);

      // Tap Salir button -> dialog opens
      await tester.tap(find.text('Salir'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('¿Terminar la visita?'), findsOneWidget);
      expect(find.text('¿Deseas despedirte de Alice y regresar a tu hogar?'), findsOneWidget);

      // Tap Despedirme
      await tester.tap(find.text('Despedirme'));
      await tester.pumpAndSettle();

      expect(leaveTriggered, isTrue);
      expect(mockWs.sentMessages.any((m) => m['type'] == 'DATE_COMPLETED'), isTrue);
    });

    test('GameBloc updates state on incoming HOME_AVATAR_SIT and HOME_AVATAR_STAND', () async {
      mockWs.addMessage({
        'type': 'SESSION_INIT',
        'roomId': 'room_home_123',
        'role': 'EXPLORER',
        'act': 1,
        'seed': 42,
        'mode': 'HOME',
        'isHomeVisitActive': true,
        'hostUserId': 'user_host_1',
        'partnerId': 'user_guest_2',
        'partnerUsername': 'Bob',
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Partner sits
      mockWs.addMessage({
        'type': 'HOME_AVATAR_SIT',
        'chairId': 'chair_cozy_1',
        'slotIndex': 0,
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sitState = gameBloc.state as ActiveGameState;
      expect(sitState.partnerHomeChairId, equals('chair_cozy_1'));
      expect(sitState.partnerHomeSlotIndex, equals(0));
      expect(sitState.partnerHomeSitTrigger, isNotNull);

      // Partner stands up
      mockWs.addMessage({
        'type': 'HOME_AVATAR_STAND',
        'gridX': 12.0,
        'gridY': 14.0,
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final standState = gameBloc.state as ActiveGameState;
      expect(standState.partnerHomeChairId, isNull);
      expect(standState.partnerHomeSlotIndex, isNull);
      expect(standState.partnerHomeStandTrigger, isNotNull);
      expect(standState.partnerHomeMovePos?.x, equals(12.0));
      expect(standState.partnerHomeMovePos?.y, equals(14.0));
    });
  });
}
