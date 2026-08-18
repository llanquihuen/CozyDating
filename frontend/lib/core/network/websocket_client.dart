import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WebSocketConnectionState {
  disconnected,
  connected,
  reconnecting,
}

class WebSocketClient {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;

  final _stateController = StreamController<WebSocketConnectionState>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final Duration _reconnectInterval = const Duration(seconds: 2);

  bool _isSessionActive = false;

  String? _cachedUrl;
  String? _cachedToken;

  WebSocketClient();

  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  WebSocketConnectionState get connectionState => _connectionState;
  bool get isSessionActive => _isSessionActive;

  void setSessionActive(bool active) {
    print('[NET FSM] setSessionActive = $active');
    _isSessionActive = active;
  }

  Future<void> connect(String url, String token) async {
    print('[NET LOG] Connecting to $url with token: ${token.substring(0, token.length > 15 ? 15 : token.length)}...');
    _cachedUrl = url;
    _cachedToken = token;
    _reconnectAttempts = 0;
    _cancelReconnectTimer();

    await _establishConnection();
  }

  Future<void> disconnect() async {
    print('[NET LOG] Manual disconnect requested.');
    _isSessionActive = false;
    _cancelReconnectTimer();
    await _closeChannel();
    _transitionTo(WebSocketConnectionState.disconnected);
  }

  void sendMessage(Map<String, dynamic> data) {
    final payloadStr = jsonEncode(data);
    print('[NET OUTGOING] Sending payload: $payloadStr');
    if (_channel != null && _connectionState == WebSocketConnectionState.connected) {
      try {
        _channel!.sink.add(payloadStr);
      } catch (e) {
        print('[NET ERROR] Failed to send text to socket: $e');
        _handleError(e);
      }
    } else {
      print('[NET WARN] Cannot send message, socket state is: $_connectionState');
    }
  }

  Future<void> _establishConnection() async {
    if (_cachedUrl == null) return;

    try {
      print('[NET LOG] Attempting raw socket connection to $_cachedUrl...');
      final uri = Uri.parse(_cachedUrl!);
      _channel = WebSocketChannel.connect(uri);
      
      // Wait for socket connection readiness
      await _channel!.ready;

      _reconnectAttempts = 0;
      print('[NET LOG] Socket connection ESTABLISHED successfully!');
      _transitionTo(WebSocketConnectionState.connected);

      _channelSubscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _onConnectionClosed,
        onError: _handleError,
        cancelOnError: true,
      );
    } catch (e) {
      print('[NET ERROR] Socket connection failed: $e');
      _handleError(e);
    }
  }

  void _onMessageReceived(dynamic data) {
    print('[NET INCOMING] Raw text received: $data');
    if (data is String) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(data) as Map<String, dynamic>;
        _messageController.add(parsed);
      } catch (e) {
        print('[NET ERROR] Failed to parse JSON message: $e');
      }
    }
  }

  void _onConnectionClosed() {
    print('[NET LOG] Socket connection closed by server or network loss. ActiveSession = $_isSessionActive');
    _channel = null;
    if (_isSessionActive) {
      _startReconnectionSchedule();
    } else {
      _transitionTo(WebSocketConnectionState.disconnected);
    }
  }

  void _handleError(dynamic error) {
    print('[NET ERROR] Socket error encountered: $error. ActiveSession = $_isSessionActive');
    _channel = null;
    if (_isSessionActive) {
      _startReconnectionSchedule();
    } else {
      _transitionTo(WebSocketConnectionState.disconnected);
    }
  }

  void _startReconnectionSchedule() {
    if (_connectionState == WebSocketConnectionState.reconnecting) return;

    print('[NET RECONNECT] Starting auto-reconnect timer (Interval: 2s, Max: $_maxReconnectAttempts)...');
    _transitionTo(WebSocketConnectionState.reconnecting);
    _reconnectAttempts = 0;

    _reconnectTimer = Timer.periodic(_reconnectInterval, (timer) async {
      _reconnectAttempts++;
      print('[NET RECONNECT] Reconnection attempt $_reconnectAttempts/$_maxReconnectAttempts to $_cachedUrl...');
      if (_reconnectAttempts > _maxReconnectAttempts) {
        print('[NET RECONNECT] Max attempts reached. Terminating auto-reconnect.');
        _cancelReconnectTimer();
        _isSessionActive = false;
        _transitionTo(WebSocketConnectionState.disconnected);
        _messageController.add({
          'type': 'ERROR',
          'message': 'Auto-reconnection failed after $_maxReconnectAttempts attempts.'
        });
        return;
      }

      try {
        final uri = Uri.parse(_cachedUrl!);
        final channel = WebSocketChannel.connect(uri);
        await channel.ready;

        print('[NET RECONNECT] Reconnection SUCCESSFUL!');
        _cancelReconnectTimer();
        _channel = channel;
        _reconnectAttempts = 0;
        _transitionTo(WebSocketConnectionState.connected);

        _channelSubscription = _channel!.stream.listen(
          _onMessageReceived,
          onDone: _onConnectionClosed,
          onError: _handleError,
          cancelOnError: true,
        );

        if (_cachedToken != null) {
          print('[NET RECONNECT] Automatically submitting RECONNECT_SESSION frame...');
          sendMessage({
            'type': 'RECONNECT_SESSION',
            'token': _cachedToken,
          });
        }
      } catch (e) {
        print('[NET RECONNECT] Attempt $_reconnectAttempts failed: $e');
      }
    });
  }

  void _transitionTo(WebSocketConnectionState newState) {
    if (_connectionState != newState) {
      print('[NET FSM] Transitioning state: $_connectionState -> $newState');
      _connectionState = newState;
      if (!_stateController.isClosed) {
        _stateController.add(newState);
      }
    }
  }

  void _cancelReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  Future<void> _closeChannel() async {
    try {
      await _channelSubscription?.cancel();
      await _channel?.sink.close();
    } catch (_) {}
    _channelSubscription = null;
    _channel = null;
  }

  void dispose() {
    _cancelReconnectTimer();
    _closeChannel();
    _stateController.close();
    _messageController.close();
  }
}
