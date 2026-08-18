import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';

void main() {
  group('E2E WebSockets and GameBloc Flow Tests', () {
    HttpServer? mockServer;
    WebSocketClient? client;
    GameBloc? gameBloc;
    final List<WebSocket> serverSockets = [];

    setUp(() async {
      // Bind a mock server to a dynamic local port
      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverSockets.clear();

      mockServer!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((socket) {
            serverSockets.add(socket);
            socket.listen((message) {
              final data =
                  jsonDecode(message as String) as Map<String, dynamic>;
              final type = data['type'];

              if (type == 'SESSION_INIT') {
                // Confirm queue
                socket.add(jsonEncode(
                    {'type': 'QUEUED', 'message': 'Placed in queue.'}));

                // Simulate match pairing after 50ms
                Timer(const Duration(milliseconds: 50), () {
                  socket.add(jsonEncode({
                    'type': 'SESSION_INIT',
                    'roomId': 'test_room',
                    'role': 'EXPLORER',
                    'mode': 'VOICE',
                    'livekitToken': 'livekit_jwt',
                    'partnerId': 'partnerBob',
                  }));
                });
              } else if (type == 'RECONNECT_SESSION') {
                // Confirm recovery
                socket.add(jsonEncode({'type': 'GAME_RESUMED'}));
              }
            });
          });
        }
      });

      client = WebSocketClient();
      gameBloc = GameBloc(webSocketClient: client!);
    });

    tearDown(() async {
      gameBloc?.close();
      client?.dispose();
      for (var s in serverSockets) {
        await s.close();
      }
      await mockServer?.close(force: true);
    });

    test('Full Happy Path: Matchmaking Queue -> Session Init -> Reconnect',
        () async {
      final port = mockServer!.port;
      final wsUrl = 'ws://localhost:$port/game';

      // 1. Join Queue
      gameBloc!.add(JoinQueueEvent(
        socketUrl: wsUrl,
        token: 'user_jwt',
        commune: 'Santiago',
        timeSlot: '20',
        mode: 'VOICE',
      ));

      // Wait for queue confirmation and matching init
      await expectLater(
        gameBloc!.stream,
        emitsThrough(isA<ActiveGameState>().having(
          (s) => s.session.roomId,
          'roomId',
          'test_room',
        )),
      );

      // Verify session is active and client connected
      expect(client!.connectionState, WebSocketConnectionState.connected);
      expect(client!.isSessionActive, isTrue);

      // 2. Simulate Connection Dropped by closing the server socket
      expect(serverSockets.isNotEmpty, isTrue);
      final pausedFuture = expectLater(
        gameBloc!.stream,
        emitsThrough(isA<PausedGameState>()),
      );
      final activeFuture = expectLater(
        gameBloc!.stream,
        emitsThrough(isA<ActiveGameState>()),
      );

      await serverSockets.first.close();

      // Wait for reconnect states to propagate
      await pausedFuture;
      expect(client!.connectionState, WebSocketConnectionState.reconnecting);

      // 3. Reconnect automatically
      await activeFuture;
      expect(client!.connectionState, WebSocketConnectionState.connected);
    });

    test('Emergency Disconnect immediately terminates room and blocks',
        () async {
      final port = mockServer!.port;
      final wsUrl = 'ws://localhost:$port/game';

      // Join and wait for game start
      gameBloc!.add(JoinQueueEvent(
        socketUrl: wsUrl,
        token: 'user_jwt',
        commune: 'Santiago',
        timeSlot: '20',
        mode: 'VOICE',
      ));

      await expectLater(
        gameBloc!.stream,
        emitsThrough(isA<ActiveGameState>()),
      );

      // Dispatch emergency disconnect
      gameBloc!.add(const SendEmergencyDisconnectEvent());

      // Verify immediate transition to terminated state and socket closed
      await expectLater(
        gameBloc!.stream,
        emits(isA<TerminatedGameState>().having(
          (s) => s.reason,
          'reason',
          contains('emergency disconnect'),
        )),
      );

      expect(client!.connectionState, WebSocketConnectionState.disconnected);
      expect(client!.isSessionActive, isFalse);
    });
  });
}
