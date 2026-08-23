import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flame/game.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/game_models.dart';
import '../../../core/network/websocket_client.dart';

// =========================================================================
// Game Events
// =========================================================================

abstract class GameEvent extends Equatable {
  const GameEvent();

  @override
  List<Object?> get props => [];
}

class JoinQueueEvent extends GameEvent {
  final String socketUrl;
  final String token;
  final String commune;
  final String timeSlot;
  final String mode;

  const JoinQueueEvent({
    required this.socketUrl,
    required this.token,
    required this.commune,
    required this.timeSlot,
    required this.mode,
  });

  @override
  List<Object?> get props => [socketUrl, token, commune, timeSlot, mode];
}

class ReconnectSessionEvent extends GameEvent {
  final String socketUrl;
  final String token;

  const ReconnectSessionEvent({
    required this.socketUrl,
    required this.token,
  });

  @override
  List<Object?> get props => [socketUrl, token];
}

class SendGameReadyEvent extends GameEvent {
  const SendGameReadyEvent();
}

class SendPlayerMoveEvent extends GameEvent {
  final DungeonStatePayload move;

  const SendPlayerMoveEvent(this.move);

  @override
  List<Object?> get props => [move];
}

class SendPingEvent extends GameEvent {
  final double x;
  final double y;

  const SendPingEvent(this.x, this.y);

  @override
  List<Object?> get props => [x, y];
}

class SendDisarmTrapsEvent extends GameEvent {
  const SendDisarmTrapsEvent();
}

class SendUnlockRuneGateEvent extends GameEvent {
  const SendUnlockRuneGateEvent();
}

class SendSanctuaryReachedEvent extends GameEvent {
  const SendSanctuaryReachedEvent();
}

class SendEmergencyDisconnectEvent extends GameEvent {
  final bool shouldBlock;

  const SendEmergencyDisconnectEvent({this.shouldBlock = false});

  @override
  List<Object?> get props => [shouldBlock];
}

class ResetGameEvent extends GameEvent {
  const ResetGameEvent();
}

class _OnSocketMessageEvent extends GameEvent {
  final Map<String, dynamic> message;

  const _OnSocketMessageEvent(this.message);

  @override
  List<Object?> get props => [message];
}

class _OnSocketStateChangedEvent extends GameEvent {
  final WebSocketConnectionState state;

  const _OnSocketStateChangedEvent(this.state);

  @override
  List<Object?> get props => [state];
}

// =========================================================================
// Game States
// =========================================================================

abstract class GameState extends Equatable {
  const GameState();

  @override
  List<Object?> get props => [];
}

class GameInitialState extends GameState {
  const GameInitialState();
}

class MatchmakingQueueState extends GameState {
  final String mode;

  const MatchmakingQueueState({required this.mode});

  @override
  List<Object?> get props => [mode];
}

class ActiveGameState extends GameState {
  final SessionInitPayload session;
  final bool partnerReady;
  final bool localReady;
  final DungeonStatePayload? latestDungeonState;
  final Vector2? latestPingPos;
  final int? trapsDisarmedTrigger;
  final int? runeGateUnlockedTrigger;

  const ActiveGameState({
    required this.session,
    this.partnerReady = false,
    this.localReady = false,
    this.latestDungeonState,
    this.latestPingPos,
    this.trapsDisarmedTrigger,
    this.runeGateUnlockedTrigger,
  });

  ActiveGameState copyWith({
    SessionInitPayload? session,
    bool? partnerReady,
    bool? localReady,
    DungeonStatePayload? latestDungeonState,
    Vector2? latestPingPos,
    int? trapsDisarmedTrigger,
    int? runeGateUnlockedTrigger,
  }) {
    return ActiveGameState(
      session: session ?? this.session,
      partnerReady: partnerReady ?? this.partnerReady,
      localReady: localReady ?? this.localReady,
      latestDungeonState: latestDungeonState ?? this.latestDungeonState,
      latestPingPos: latestPingPos ?? this.latestPingPos,
      trapsDisarmedTrigger: trapsDisarmedTrigger ?? this.trapsDisarmedTrigger,
      runeGateUnlockedTrigger: runeGateUnlockedTrigger ?? this.runeGateUnlockedTrigger,
    );
  }

  @override
  List<Object?> get props => [session, partnerReady, localReady, latestDungeonState, latestPingPos, trapsDisarmedTrigger, runeGateUnlockedTrigger];
}

class PausedGameState extends GameState {
  final SessionInitPayload session;
  final String reason;

  const PausedGameState({
    required this.session,
    required this.reason,
  });

  @override
  List<Object?> get props => [session, reason];
}

class TerminatedGameState extends GameState {
  final String reason;

  const TerminatedGameState({required this.reason});

  @override
  List<Object?> get props => [reason];
}

class ErrorGameState extends GameState {
  final String message;

  const ErrorGameState({required this.message});

  @override
  List<Object?> get props => [message];
}

// =========================================================================
// Game BLoC Implementation
// =========================================================================

class GameBloc extends Bloc<GameEvent, GameState> {
  final WebSocketClient webSocketClient;
  StreamSubscription<WebSocketConnectionState>? _stateSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;

  GameBloc({required this.webSocketClient}) : super(const GameInitialState()) {
    on<JoinQueueEvent>(_onJoinQueue);
    on<ReconnectSessionEvent>(_onReconnectSession);
    on<SendGameReadyEvent>(_onSendGameReady);
    on<SendPlayerMoveEvent>(_onSendPlayerMove);
    on<SendPingEvent>(_onSendPing);
    on<SendDisarmTrapsEvent>(_onSendDisarmTraps);
    on<SendUnlockRuneGateEvent>(_onSendUnlockRuneGate);
    on<SendSanctuaryReachedEvent>(_onSendSanctuaryReached);
    on<SendEmergencyDisconnectEvent>(_onSendEmergencyDisconnect);
    on<ResetGameEvent>(_onResetGame);
    on<_OnSocketMessageEvent>(_onSocketMessage);
    on<_OnSocketStateChangedEvent>(_onSocketStateChanged);

    _messageSubscription = webSocketClient.messageStream.listen((msg) {
      add(_OnSocketMessageEvent(msg));
    });

    _stateSubscription = webSocketClient.stateStream.listen((state) {
      add(_OnSocketStateChangedEvent(state));
    });
  }

  Future<void> _onJoinQueue(JoinQueueEvent event, Emitter<GameState> emit) async {
    print('[BLOC EVENT] JoinQueueEvent triggered [Commune: ${event.commune}, Mode: ${event.mode}]');
    emit(const GameInitialState());
    try {
      await webSocketClient.connect(event.socketUrl, event.token);
      
      print('[BLOC OUT] Submitting SESSION_INIT command over WebSocket...');
      webSocketClient.sendMessage({
        'type': 'SESSION_INIT',
        'token': event.token,
        'commune': event.commune,
        'timeSlot': event.timeSlot,
        'mode': event.mode,
      });

      print('[BLOC STATE] Emitting MatchmakingQueueState');
      emit(MatchmakingQueueState(mode: event.mode));
    } catch (e) {
      print('[BLOC ERROR] Exception during queue join: $e');
      emit(ErrorGameState(message: 'Failed to join matchmaking queue: $e'));
    }
  }

  Future<void> _onReconnectSession(ReconnectSessionEvent event, Emitter<GameState> emit) async {
    print('[BLOC EVENT] ReconnectSessionEvent triggered');
    try {
      await webSocketClient.connect(event.socketUrl, event.token);
      
      webSocketClient.sendMessage({
        'type': 'RECONNECT_SESSION',
        'token': event.token,
      });
    } catch (e) {
      print('[BLOC ERROR] Exception during manual reconnect: $e');
      emit(ErrorGameState(message: 'Manual reconnection attempt failed: $e'));
    }
  }

  void _onSendGameReady(SendGameReadyEvent event, Emitter<GameState> emit) {
    print('[BLOC EVENT] SendGameReadyEvent triggered');
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      webSocketClient.sendMessage({'type': 'GAME_READY'});
      emit(active.copyWith(localReady: true));
    }
  }

  void _onSendPlayerMove(SendPlayerMoveEvent event, Emitter<GameState> emit) {
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      webSocketClient.sendMessage({
        'type': 'PLAYER_MOVE',
        'playerX': event.move.playerX,
        'playerY': event.move.playerY,
        'chaserX': event.move.chaserX,
        'chaserY': event.move.chaserY,
        'role': event.move.role,
        'direction': event.move.direction,
        'isMoving': event.move.isMoving,
        'activeTraps': event.move.activeTraps,
        'blockPositions': event.move.blockPositions,
      });
      emit(active.copyWith(latestDungeonState: event.move));
    }
  }

  void _onSendPing(SendPingEvent event, Emitter<GameState> emit) {
    print('[BLOC EVENT] SendPingEvent triggered: (${event.x}, ${event.y})');
    webSocketClient.sendMessage({
      'type': 'PING_SENT',
      'pingX': event.x,
      'pingY': event.y,
    });
  }

  void _onSendDisarmTraps(SendDisarmTrapsEvent event, Emitter<GameState> emit) {
    print('[BLOC EVENT] SendDisarmTrapsEvent triggered');
    webSocketClient.sendMessage({'type': 'TRAP_TOGGLED'});
  }

  void _onSendUnlockRuneGate(SendUnlockRuneGateEvent event, Emitter<GameState> emit) {
    print('[BLOC EVENT] SendUnlockRuneGateEvent triggered');
    webSocketClient.sendMessage({'type': 'RUNE_GATE_UNLOCKED'});
  }

  void _onSendSanctuaryReached(SendSanctuaryReachedEvent event, Emitter<GameState> emit) {
    print('[BLOC EVENT] SendSanctuaryReachedEvent triggered - sending ROLE_SWAP packet to server');
    webSocketClient.sendMessage({'type': 'ROLE_SWAP'});
  }

  Future<void> _onSendEmergencyDisconnect(SendEmergencyDisconnectEvent event, Emitter<GameState> emit) async {
    print('[BLOC EVENT] SendEmergencyDisconnectEvent triggered (ShouldBlock: ${event.shouldBlock})');
    webSocketClient.setSessionActive(false);
    webSocketClient.sendMessage({
      'type': 'EMERGENCY_DISCONNECT',
      'block': event.shouldBlock,
    });
    await webSocketClient.disconnect();

    final reasonText = event.shouldBlock
        ? 'You exited the game and permanently blocked your partner (emergency disconnect).'
        : 'You exited the game session (emergency disconnect - Friendly Exit - No Block).';

    emit(TerminatedGameState(reason: reasonText));
  }

  void _onResetGame(ResetGameEvent event, Emitter<GameState> emit) {
    print('[BLOC EVENT] ResetGameEvent triggered. Disconnecting socket and resetting BLoC state to GameInitialState...');
    webSocketClient.disconnect();
    emit(const GameInitialState());
  }

  void _onSocketMessage(_OnSocketMessageEvent event, Emitter<GameState> emit) {
    final msg = event.message;
    final type = msg['type'] as String?;

    print('[BLOC IN] Processing socket message of type: $type');

    if (type == 'ERROR') {
      print('[BLOC IN] Received error packet: ${msg['message']}');
      emit(ErrorGameState(message: msg['message'] as String? ?? 'Unknown error'));
      return;
    }

    if (type == 'SESSION_INIT') {
      final payload = SessionInitPayload.fromJson(msg);
      print('[BLOC IN] Received SESSION_INIT match! RoomId: ${payload.roomId}, Role: ${payload.role}, Partner: ${payload.partnerId}');
      webSocketClient.setSessionActive(true);
      emit(ActiveGameState(session: payload));
      return;
    }

    if (type == 'PING_SENT') {
      final px = (msg['pingX'] as num?)?.toDouble() ?? 0.0;
      final py = (msg['pingY'] as num?)?.toDouble() ?? 0.0;
      print('[BLOC IN] Received PING_SENT at ($px, $py)');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(latestPingPos: Vector2(px, py)));
      }
      return;
    }

    if (type == 'TRAP_TOGGLED') {
      print('[BLOC IN] Received TRAP_TOGGLED from server!');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(trapsDisarmedTrigger: DateTime.now().millisecondsSinceEpoch));
      }
      return;
    }

    if (type == 'RUNE_GATE_UNLOCKED') {
      print('[BLOC IN] Received RUNE_GATE_UNLOCKED from server!');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(runeGateUnlockedTrigger: DateTime.now().millisecondsSinceEpoch));
      }
      return;
    }

    if (type == 'ROLE_SWAP') {
      print('[BLOC IN] Received authoritative ROLE_SWAP from server: $msg');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        final currentRole = active.session.role;
        final newSeed = (msg['seed'] as num?)?.toInt() ?? active.session.seed;
        final newAct = (msg['act'] as num?)?.toInt() ?? 2;

        String newRole;
        final serverExplorerId = msg['explorerId'] as String?;
        final serverGuideId = msg['guideId'] as String?;

        if (serverExplorerId != null && serverGuideId != null) {
          if (active.session.partnerId == serverGuideId) {
            newRole = 'EXPLORER';
          } else if (active.session.partnerId == serverExplorerId) {
            newRole = 'GUIDE';
          } else {
            newRole = currentRole == 'EXPLORER' ? 'GUIDE' : 'EXPLORER';
          }
        } else {
          newRole = currentRole == 'EXPLORER' ? 'GUIDE' : 'EXPLORER';
        }

        final updatedSession = SessionInitPayload(
          roomId: active.session.roomId,
          role: newRole,
          mode: active.session.mode,
          livekitToken: active.session.livekitToken,
          partnerId: active.session.partnerId,
          act: newAct,
          seed: newSeed,
        );
        print('[BLOC IN] Roles swapped for Act $newAct: $currentRole -> $newRole (Seed: $newSeed, Partner: ${active.session.partnerId})');
        emit(ActiveGameState(session: updatedSession));
      }
      return;
    }

    if (type == 'GAME_READY') {
      print('[BLOC IN] Partner confirmed GAME_READY');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(partnerReady: true));
      }
      return;
    }

    if (type == 'GAME_PAUSED') {
      print('[BLOC IN] Received GAME_PAUSED from server');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(PausedGameState(session: active.session, reason: 'Partner disconnected. Game paused.'));
      }
      return;
    }

    if (type == 'GAME_RESUMED') {
      print('[BLOC IN] Received GAME_RESUMED from server');
      if (state is PausedGameState) {
        final paused = state as PausedGameState;
        emit(ActiveGameState(
          session: paused.session,
          partnerReady: true,
        ));
      }
      return;
    }

    if (type == 'PLAYER_MOVE') {
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        final payload = DungeonStatePayload.fromJson(msg);
        emit(active.copyWith(
          partnerReady: true,
          latestDungeonState: payload,
        ));
      }
      return;
    }

    if (type == 'EMERGENCY_DISCONNECT') {
      print('[BLOC IN] Received EMERGENCY_DISCONNECT from server');
      webSocketClient.setSessionActive(false);
      final reason = msg['reason'] as String?;
      final isBlocked = reason == 'PARTNER_ABORTED_AND_BLOCKED';
      
      final reasonText = isBlocked
          ? 'Partner aborted the match and blocked you permanently.'
          : 'Partner exited the game session (Friendly Exit).';

      emit(TerminatedGameState(reason: reasonText));
      return;
    }

    if (type == 'GAME_OVER') {
      print('[BLOC IN] Received GAME_OVER from server');
      webSocketClient.setSessionActive(false);
      emit(TerminatedGameState(reason: msg['reason'] as String? ?? 'Session ended.'));
      return;
    }
  }

  void _onSocketStateChanged(_OnSocketStateChangedEvent event, Emitter<GameState> emit) {
    final netState = event.state;
    print('[BLOC IN] Socket state notification: $netState');

    if (netState == WebSocketConnectionState.reconnecting) {
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(PausedGameState(session: active.session, reason: 'Connection lost. Reconnecting...'));
      }
    } else if (netState == WebSocketConnectionState.disconnected) {
      if (state is MatchmakingQueueState) {
        print('[BLOC IN] Disconnected while in queue. Returning to GameInitialState (Main Menu).');
        emit(const GameInitialState());
      } else if (state is ActiveGameState || state is PausedGameState) {
        emit(const TerminatedGameState(reason: 'Connection disconnected permanently.'));
      }
    }
  }

  @override
  Future<void> close() {
    _stateSubscription?.cancel();
    _messageSubscription?.cancel();
    webSocketClient.disconnect();
    return super.close();
  }
}
