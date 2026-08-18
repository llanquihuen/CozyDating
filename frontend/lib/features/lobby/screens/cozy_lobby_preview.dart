import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/network/websocket_client.dart';
import '../../game/bloc/game_bloc.dart';
import 'cozy_lobby_view.dart';

class _MockWebSocketClient extends WebSocketClient {
  @override
  Stream<WebSocketConnectionState> get stateStream => Stream.value(WebSocketConnectionState.connected);
  @override
  Stream<Map<String, dynamic>> get messageStream => const Stream.empty();
  @override
  Future<void> connect(String url, String token) async {}
  @override
  void sendMessage(Map<String, dynamic> data) {}
}

@Preview(name: 'Lobby: Alice (Initial)')
Widget previewLobbyAlice() {
  final mockClient = _MockWebSocketClient();
  
  return BlocProvider(
    create: (context) => GameBloc(webSocketClient: mockClient),
    child: CozyLobbyView(
      activeUserId: 'alice',
      onUserChanged: (newId) {
        print('User changed to $newId');
      },
    ),
  );
}

@Preview(name: 'Lobby: Charlie (In Queue)')
Widget previewLobbyCharlieQueued() {
  final mockClient = _MockWebSocketClient();
  final bloc = GameBloc(webSocketClient: mockClient);
  
  // We can manually emit a state if we want to show the queued UI
  // Note: This requires the Bloc to not be closed or immediately replaced.
  // For a simple preview, we just provide the provider.
  
  return BlocProvider.value(
    value: bloc,
    child: CozyLobbyView(
      activeUserId: 'charlie',
      onUserChanged: (newId) {},
    ),
  );
}

@Preview(name: 'Lobby: David')
Widget previewLobbyDavid() {
  final mockClient = _MockWebSocketClient();
  
  return BlocProvider(
    create: (context) => GameBloc(webSocketClient: mockClient),
    child: CozyLobbyView(
      activeUserId: 'david',
      onUserChanged: (newId) {},
    ),
  );
}
