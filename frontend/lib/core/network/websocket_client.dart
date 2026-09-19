import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WebSocketConnectionState {
  disconnected,
  connected,
  reconnecting,
}

class WebSocketClient {
  static WebSocketClient? shared;
  static final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(false);

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;

  final _stateController = StreamController<WebSocketConnectionState>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();

  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  final int _maxReconnectAttempts = 10;
  final Duration _reconnectInterval = const Duration(seconds: 2);
  final Duration _heartbeatInterval = const Duration(seconds: 15);

  bool _isSessionActive = false;
  bool _manualDisconnect = false;
  bool _isAppBackgrounded = false;
  int _unansweredPings = 0;

  String? _cachedUrl;
  String? _cachedToken;
  Completer<void>? _connectingCompleter;

  WebSocketClient() {
    shared = this;
  }

  Stream<WebSocketConnectionState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  WebSocketConnectionState get connectionState => _connectionState;
  bool get isConnected => _connectionState == WebSocketConnectionState.connected;
  bool get isSessionActive => _isSessionActive;
  bool get isAppBackgrounded => _isAppBackgrounded;
  String? get currentUrl => _cachedUrl;

  void setSessionActive(bool active) {
    print('[NET FSM] setSessionActive = $active');
    _isSessionActive = active;
  }

  void onAppPaused() {
    print('[NET LIFECYCLE] App paused/backgrounded. Suspending auto-reconnect timer and heartbeat.');
    _isAppBackgrounded = true;
    _cancelReconnectTimer();
    _stopHeartbeat();
  }

  void onAppResumed() {
    print('[NET LIFECYCLE] App resumed. Re-enabling networking.');
    _isAppBackgrounded = false;
    _reconnectAttempts = 0;
    if (!isConnected && !_manualDisconnect && _cachedUrl != null) {
      reconnectNow();
    }
  }

  Future<bool> reconnectNow() async {
    print('[NET RECONNECT] Immediate reconnect requested.');
    _cancelReconnectTimer();
    _reconnectAttempts = 0;
    final success = await _trySingleReconnection();
    if (!success && !_manualDisconnect && !_isAppBackgrounded && _cachedUrl != null) {
      _scheduleNextReconnect();
    }
    return success;
  }

  Future<void> connect(String url, String token) async {
    if (isConnected && _cachedUrl == url && _channel != null) {
      print('[NET LOG] Already connected to $url. Re-using active WebSocket channel.');
      return;
    }

    // Deduplicate in-flight connection attempts
    if (_connectingCompleter != null) {
      print('[NET LOG] Connection already in-flight to $_cachedUrl. Awaiting existing attempt...');
      try {
        await _connectingCompleter!.future;
      } catch (_) {}
      if (isConnected && _cachedUrl == url && _channel != null) {
        return;
      }
    }

    print('[NET LOG] Connecting to $url with token: ${token.substring(0, token.length > 15 ? 15 : token.length)}...');
    _cachedUrl = url;
    _cachedToken = token;
    _manualDisconnect = false;
    _reconnectAttempts = 0;
    _cancelReconnectTimer();

    _connectingCompleter = Completer<void>();
    try {
      await _establishConnection();
      _connectingCompleter?.complete();
    } catch (e) {
      _connectingCompleter?.completeError(e);
      rethrow;
    } finally {
      _connectingCompleter = null;
    }
  }

  Future<void> disconnect() async {
    print('[NET LOG] Manual disconnect requested.');
    _manualDisconnect = true;
    _isSessionActive = false;
    _connectingCompleter?.complete();
    _connectingCompleter = null;
    _cancelReconnectTimer();
    _stopHeartbeat();
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

    await _closeChannel();

    try {
      print('[NET LOG] Attempting raw socket connection to $_cachedUrl...');
      final uri = Uri.parse(_cachedUrl!);
      final channel = WebSocketChannel.connect(uri);
      
      // Wait for socket connection readiness
      await channel.ready;

      _channel = channel;
      _reconnectAttempts = 0;
      print('[NET LOG] Socket connection ESTABLISHED successfully!');
      _transitionTo(WebSocketConnectionState.connected);
      _startHeartbeat();

      _channelSubscription = channel.stream.listen(
        _onMessageReceived,
        onDone: () => _onConnectionClosed(channel),
        onError: (err) => _handleError(err, channel),
        cancelOnError: true,
      );
    } catch (e) {
      print('[NET ERROR] Socket connection failed: $e');
      _handleError(e, null);
      rethrow;
    }
  }

  void _onMessageReceived(dynamic data) {
    if (data is String) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(data) as Map<String, dynamic>;
        if (parsed['type'] == 'PONG') {
          // Keep-alive heartbeat pong received, reset unanswered counter
          _unansweredPings = 0;
          return;
        }
        print('[NET INCOMING] Raw text received: $data');
        _messageController.add(parsed);
      } catch (e) {
        print('[NET ERROR] Failed to parse JSON message: $e');
      }
    }
  }

  void _onConnectionClosed([WebSocketChannel? closedChannel]) {
    if (closedChannel != null && _channel != null && closedChannel != _channel) {
      print('[NET LOG] Ignored onDone from stale/superseded WebSocket channel.');
      return;
    }
    print('[NET LOG] Socket connection closed by server or network loss. ActiveSession = $_isSessionActive, ManualDisconnect = $_manualDisconnect, Backgrounded = $_isAppBackgrounded');
    _stopHeartbeat();
    _channel = null;
    if (_isAppBackgrounded) {
      print('[NET LOG] Socket closed while app is backgrounded. Waiting for resume.');
      _transitionTo(WebSocketConnectionState.disconnected);
    } else if (_isSessionActive || (!_manualDisconnect && _cachedUrl != null)) {
      _startReconnectionSchedule();
    } else {
      _transitionTo(WebSocketConnectionState.disconnected);
    }
  }

  void _handleError(dynamic error, [WebSocketChannel? failedChannel]) {
    if (failedChannel != null && _channel != null && failedChannel != _channel) {
      print('[NET LOG] Ignored error from stale/superseded WebSocket channel.');
      return;
    }
    print('[NET ERROR] Socket error encountered: $error. ActiveSession = $_isSessionActive, ManualDisconnect = $_manualDisconnect, Backgrounded = $_isAppBackgrounded');
    _stopHeartbeat();
    _channel = null;
    if (_isAppBackgrounded) {
      print('[NET ERROR] Socket error while app is backgrounded. Waiting for resume.');
      _transitionTo(WebSocketConnectionState.disconnected);
    } else if (_isSessionActive || (!_manualDisconnect && _cachedUrl != null)) {
      _startReconnectionSchedule();
    } else {
      _transitionTo(WebSocketConnectionState.disconnected);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _unansweredPings = 0;
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_connectionState == WebSocketConnectionState.connected && _channel != null) {
        _unansweredPings++;
        if (_unansweredPings >= 3) {
          print('[NET WARN] Heartbeat timeout: No PONG received in 45s (dead/half-open socket). Forcing reconnect...');
          _handleError('Heartbeat timeout (dead socket)');
          return;
        }
        sendMessage({'type': 'PING'});
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _unansweredPings = 0;
  }

  Future<bool> _trySingleReconnection() async {
    if (_cachedUrl == null || _manualDisconnect) return false;

    if (_connectingCompleter != null) {
      try {
        await _connectingCompleter!.future;
      } catch (_) {}
      if (isConnected) return true;
    }

    _transitionTo(WebSocketConnectionState.reconnecting);
    _connectingCompleter = Completer<void>();

    try {
      final uri = Uri.parse(_cachedUrl!);
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;

      print('[NET RECONNECT] Reconnection SUCCESSFUL to $_cachedUrl!');
      _cancelReconnectTimer();
      _channel = channel;
      _reconnectAttempts = 0;
      _transitionTo(WebSocketConnectionState.connected);
      _startHeartbeat();

      _channelSubscription = channel.stream.listen(
        _onMessageReceived,
        onDone: () => _onConnectionClosed(channel),
        onError: (err) => _handleError(err, channel),
        cancelOnError: true,
      );

      if (_cachedToken != null) {
        if (_isSessionActive) {
          print('[NET RECONNECT] Automatically submitting RECONNECT_SESSION frame...');
          sendMessage({
            'type': 'RECONNECT_SESSION',
            'token': _cachedToken,
          });
        } else {
          print('[NET RECONNECT] Automatically submitting USER_ONLINE frame...');
          sendMessage({
            'type': 'USER_ONLINE',
            'token': _cachedToken,
          });
        }
      }
      _connectingCompleter?.complete();
      return true;
    } catch (e) {
      print('[NET RECONNECT] Reconnection attempt failed: $e');
      _channel = null;
      _connectingCompleter?.completeError(e);
      return false;
    } finally {
      _connectingCompleter = null;
    }
  }

  void _startReconnectionSchedule() {
    if (_isAppBackgrounded || _manualDisconnect || _cachedUrl == null) return;
    if (_connectionState == WebSocketConnectionState.reconnecting && _reconnectTimer != null) return;

    _scheduleNextReconnect();
  }

  void _scheduleNextReconnect() {
    if (_isAppBackgrounded || _manualDisconnect || _cachedUrl == null) return;
    _cancelReconnectTimer();
    _transitionTo(WebSocketConnectionState.reconnecting);

    // Exponential backoff: 2s, 4s, 8s, 16s, capped at 30s
    int delaySeconds = 2;
    if (_reconnectAttempts > 0) {
      final factor = 1 << (_reconnectAttempts > 4 ? 4 : _reconnectAttempts);
      delaySeconds = (factor * 2).clamp(2, 30);
    }

    print('[NET RECONNECT] Scheduling reconnect attempt ${_reconnectAttempts + 1} in ${delaySeconds}s (max foreground attempts: $_maxReconnectAttempts)...');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      if (_isAppBackgrounded || _manualDisconnect) return;

      _reconnectAttempts++;
      if (_reconnectAttempts > _maxReconnectAttempts) {
        print('[NET RECONNECT] Max foreground reconnect attempts reached. Pausing fast retries (no fatal error packet sent).');
        _cancelReconnectTimer();
        _transitionTo(WebSocketConnectionState.disconnected);
        // Periodic gentle fallback check every 30 seconds
        _reconnectTimer = Timer(const Duration(seconds: 30), () {
          if (!_isAppBackgrounded && !_manualDisconnect && !isConnected) {
            _reconnectAttempts = _maxReconnectAttempts - 1;
            _scheduleNextReconnect();
          }
        });
        return;
      }

      final success = await _trySingleReconnection();
      if (!success && !_manualDisconnect && !_isAppBackgrounded && !isConnected) {
        _scheduleNextReconnect();
      }
    });
  }

  void _transitionTo(WebSocketConnectionState newState) {
    if (_connectionState != newState) {
      print('[NET FSM] Transitioning state: $_connectionState -> $newState');
      _connectionState = newState;
      isConnectedNotifier.value = (newState == WebSocketConnectionState.connected);
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
    _stopHeartbeat();
    try {
      await _channelSubscription?.cancel();
      await _channel?.sink.close();
    } catch (_) {}
    _channelSubscription = null;
    _channel = null;
  }

  void dispose() {
    _stopHeartbeat();
    _cancelReconnectTimer();
    _closeChannel();
    _stateController.close();
    _messageController.close();
  }
}
