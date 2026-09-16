import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/game_models.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/game/widgets/dungeon_defeat_dialog.dart';
import 'package:frontend/features/game/widgets/dungeon_victory_dialog.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyLocalConfig = const AvatarConfig(
    bodyType: 'female',
    hairStyle: 'braids',
    hairColor: Colors.black,
    skinColor: Color(0xFFF1C27D),
  );

  final dummyPartnerConfig = const AvatarConfig(
    bodyType: 'male',
    hairStyle: 'undercut',
    hairColor: Colors.brown,
    skinColor: Color(0xFFE0AC69),
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        return Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
          0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
          0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
          0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
        ]).buffer.asByteData();
      },
    );
  });

  group('Dungeon Timeout and Campfire Synchronization Tests', () {
    late _MockWebSocketClient mockWs;
    late GameBloc bloc;

    setUp(() {
      mockWs = _MockWebSocketClient();
      bloc = GameBloc(webSocketClient: mockWs);
    });

    tearDown(() {
      bloc.close();
      mockWs.dispose();
    });

    test('CAMPFIRE_START_RELAXATION sends websocket message and updates ActiveGameState', () async {
      final session = SessionInitPayload(
        roomId: 'test_room',
        role: 'EXPLORER',
        mode: 'MATCH',
        livekitToken: 'token',
        partnerId: 'partner1',
      );

      // Seed initial active game state
      bloc.emit(ActiveGameState(session: session, isCampfireActive: true));

      // Trigger relaxation event
      bloc.add(const SendCampfireStartRelaxationEvent());
      await pumpEventQueue();

      expect(mockWs.sentMessages.any((m) => m['type'] == 'CAMPFIRE_START_RELAXATION'), isTrue);
      expect((bloc.state as ActiveGameState).isCampfireRelaxationActive, isTrue);
    });

    test('Receiving CAMPFIRE_START_RELAXATION from partner sets isCampfireRelaxationActive', () async {
      final session = SessionInitPayload(
        roomId: 'test_room',
        role: 'EXPLORER',
        mode: 'MATCH',
        livekitToken: 'token',
        partnerId: 'partner1',
      );

      bloc.emit(ActiveGameState(session: session, isCampfireActive: true));

      mockWs.addMessage({'type': 'CAMPFIRE_START_RELAXATION'});
      await pumpEventQueue();

      expect((bloc.state as ActiveGameState).isCampfireRelaxationActive, isTrue);
      expect((bloc.state as ActiveGameState).campfireRelaxationTrigger, isNotNull);
    });

    test('DUNGEON_TIMEOUT sends websocket message and sets isDungeonFailed', () async {
      final session = SessionInitPayload(
        roomId: 'test_room',
        role: 'EXPLORER',
        mode: 'MATCH',
        livekitToken: 'token',
        partnerId: 'partner1',
      );

      bloc.emit(ActiveGameState(session: session));

      bloc.add(const SendDungeonTimeoutEvent());
      await pumpEventQueue();

      expect(mockWs.sentMessages.any((m) => m['type'] == 'DUNGEON_TIMEOUT'), isTrue);
      expect((bloc.state as ActiveGameState).isDungeonFailed, isTrue);
    });

    test('Receiving DUNGEON_TIMEOUT from partner sets isDungeonFailed', () async {
      final session = SessionInitPayload(
        roomId: 'test_room',
        role: 'GUIDE',
        mode: 'MATCH',
        livekitToken: 'token',
        partnerId: 'partner1',
      );

      bloc.emit(ActiveGameState(session: session));

      mockWs.addMessage({'type': 'DUNGEON_TIMEOUT'});
      await pumpEventQueue();

      expect((bloc.state as ActiveGameState).isDungeonFailed, isTrue);
    });

    test('SendDungeonLifeLostEvent deducts 1 life and sends DUNGEON_LIFE_LOST', () async {
      final session = SessionInitPayload(
        roomId: 'test_room',
        role: 'EXPLORER',
        mode: 'MATCH',
        livekitToken: 'token',
        partnerId: 'partner1',
      );

      bloc.emit(ActiveGameState(session: session, dungeonLives: 4));

      bloc.add(const SendDungeonLifeLostEvent(reason: 'PITFALL'));
      await pumpEventQueue();

      expect(mockWs.sentMessages.any((m) => m['type'] == 'DUNGEON_LIFE_LOST' && m['lives'] == 3), isTrue);
      expect((bloc.state as ActiveGameState).dungeonLives, 3);
      expect((bloc.state as ActiveGameState).isDungeonFailed, isFalse);
    });

    test('Losing all 4 lives triggers isDungeonFailed', () async {
      final session = SessionInitPayload(
        roomId: 'test_room',
        role: 'EXPLORER',
        mode: 'MATCH',
        livekitToken: 'token',
        partnerId: 'partner1',
      );

      bloc.emit(ActiveGameState(session: session, dungeonLives: 1));

      bloc.add(const SendDungeonLifeLostEvent(reason: 'SPIKE'));
      await pumpEventQueue();

      expect((bloc.state as ActiveGameState).dungeonLives, 0);
      expect((bloc.state as ActiveGameState).isDungeonFailed, isTrue);
    });

    test('Receiving DUNGEON_LIFE_LOST from partner updates lives and triggers defeat if 0', () async {
      final session = SessionInitPayload(
        roomId: 'test_room',
        role: 'GUIDE',
        mode: 'MATCH',
        livekitToken: 'token',
        partnerId: 'partner1',
      );

      bloc.emit(ActiveGameState(session: session, dungeonLives: 4));

      mockWs.addMessage({'type': 'DUNGEON_LIFE_LOST', 'lives': 2, 'reason': 'SPIKE'});
      await pumpEventQueue();

      expect((bloc.state as ActiveGameState).dungeonLives, 2);
      expect((bloc.state as ActiveGameState).isDungeonFailed, isFalse);

      mockWs.addMessage({'type': 'DUNGEON_LIFE_LOST', 'lives': 0, 'reason': 'PITFALL'});
      await pumpEventQueue();

      expect((bloc.state as ActiveGameState).dungeonLives, 0);
      expect((bloc.state as ActiveGameState).isDungeonFailed, isTrue);
    });

    testWidgets('DungeonDefeatDialog renders custom defeatTitle when lives run out', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DungeonDefeatDialog(
            localAvatar: dummyLocalConfig,
            partnerAvatar: dummyPartnerConfig,
            partnerName: 'Camila',
            defeatTitle: '¡SE AGOTARON LAS VIDAS!',
            defeatSubtitle: 'Las trampas y púas dañaron la expedición',
            onProceedToCampfire: () {},
          ),
        ),
      );

      expect(find.text('¡SE AGOTARON LAS VIDAS!'), findsOneWidget);
      expect(find.text('Las trampas y púas dañaron la expedición'), findsOneWidget);
    });

    testWidgets('DungeonDefeatDialog renders consolation details and auto-proceeds on countdown', (tester) async {
      bool proceedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DungeonDefeatDialog(
            localAvatar: dummyLocalConfig,
            partnerAvatar: dummyPartnerConfig,
            partnerName: 'Camila',
            autoProceedSeconds: 2,
            onProceedToCampfire: () {
              proceedCalled = true;
            },
          ),
        ),
      );

      expect(find.text('¡SE APAGÓ LA LINTERNA!'), findsOneWidget);
      expect(find.textContaining('El laberinto se cerró por hoy con Camila'), findsOneWidget);
      expect(find.textContaining('+50 monedas de consuelo'), findsOneWidget);
      expect(find.textContaining('Ir a la Fogata 🔥 (2s)'), findsOneWidget);
      expect(proceedCalled, isFalse);

      // Advance 1s
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Ir a la Fogata 🔥 (1s)'), findsOneWidget);
      expect(proceedCalled, isFalse);

      // Advance to completion
      await tester.pump(const Duration(seconds: 1));
      expect(proceedCalled, isTrue);
    });

    testWidgets('DungeonVictoryDialog renders and auto-proceeds on countdown', (tester) async {
      bool proceedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: DungeonVictoryDialog(
            localAvatar: dummyLocalConfig,
            partnerAvatar: dummyPartnerConfig,
            partnerName: 'Lucas',
            autoProceedSeconds: 2,
            onProceedToCampfire: () {
              proceedCalled = true;
            },
          ),
        ),
      );

      expect(find.text('¡MAZMORRA CONQUISTADA!'), findsOneWidget);
      expect(find.textContaining('Gran trabajo en equipo con Lucas'), findsOneWidget);
      expect(find.textContaining('+100 monedas de expedición'), findsOneWidget);
      expect(find.textContaining('Descansar en la Fogata 🔥 (2s)'), findsOneWidget);
      expect(proceedCalled, isFalse);

      // Advance 2s to completion
      await tester.pump(const Duration(seconds: 2));
      expect(proceedCalled, isTrue);
    });
  });
}
