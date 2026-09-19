import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';

void main() {
  group('Connection Resilience and Lifecycle Tests', () {
    HttpServer? mockServer;
    WebSocketClient? client;
    GameBloc? gameBloc;
    final List<WebSocket> serverSockets = [];

    setUp(() async {
      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverSockets.clear();

      mockServer!.listen((HttpRequest request) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          WebSocketTransformer.upgrade(request).then((socket) {
            serverSockets.add(socket);
            socket.listen((message) {
              final data = jsonDecode(message as String) as Map<String, dynamic>;
              final type = data['type'];
              if (type == 'USER_ONLINE') {
                socket.add(jsonEncode({'type': 'PRESENCE_STATUS', 'isOnline': true}));
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
      for (final s in serverSockets) {
        try {
          await s.close();
        } catch (_) {}
      }
      await mockServer?.close(force: true);
    });

    test('Pausing app suspends reconnect timer, and resuming reconnects immediately', () async {
      final port = mockServer!.port;
      final wsUrl = 'ws://localhost:$port/ws';

      // 1. Connect initial session
      await client!.connect(wsUrl, 'jwt_token');
      expect(client!.isConnected, isTrue);

      // 2. Simulate app going to background
      client!.onAppPaused();
      expect(client!.isAppBackgrounded, isTrue);

      // 3. Drop socket while in background
      for (int i = 0; i < 50 && serverSockets.isEmpty; i++) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      expect(serverSockets.isNotEmpty, isTrue);
      await serverSockets.first.close();
      await Future.delayed(const Duration(milliseconds: 100));

      // In background, state should be disconnected and not reconnecting in a fast loop
      expect(client!.isConnected, isFalse);
      expect(client!.isAppBackgrounded, isTrue);

      // 4. Return app to foreground
      client!.onAppResumed();
      expect(client!.isAppBackgrounded, isFalse);

      // Wait for immediate reconnection
      await Future.delayed(const Duration(milliseconds: 300));
      expect(client!.isConnected, isTrue);
    });

    test('Max failed reconnect attempts do not emit fatal ERROR message packet', () async {
      // Point client to a port with nothing running
      final invalidUrl = 'ws://localhost:64532/invalid';

      var receivedFatalErrorPacket = false;
      client!.messageStream.listen((msg) {
        if (msg['type'] == 'ERROR') {
          receivedFatalErrorPacket = true;
        }
      });

      // Trigger reconnect attempts
      client!.connect(invalidUrl, 'token').catchError((_) {});
      await Future.delayed(const Duration(milliseconds: 500));

      // Verify no fatal ERROR packet is published that would blow up GameBloc
      expect(receivedFatalErrorPacket, isFalse);
    });

    test('GameBloc protects GameInitialState and ignores ERROR packets', () async {
      expect(gameBloc!.state, isA<GameInitialState>());

      // Connect to mock server
      await client!.connect('ws://localhost:${mockServer!.port}/ws', 'token');
      await Future.delayed(const Duration(milliseconds: 100));

      // Inject server error packet
      if (serverSockets.isNotEmpty) {
        serverSockets.first.add(jsonEncode({
          'type': 'ERROR',
          'message': 'Transient server warning'
        }));
      }

      await Future.delayed(const Duration(milliseconds: 200));

      // GameBloc must remain in GameInitialState (Lobby is preserved!)
      expect(gameBloc!.state, isA<GameInitialState>());
    });
  });
}
