import 'dart:async';
import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:flame/game.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/game_models.dart';
import '../../../core/models/room_config.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../chat/services/chat_service.dart';

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

class SendBlockPushedEvent extends GameEvent {
  final String blockId;
  final double x;
  final double y;

  const SendBlockPushedEvent({
    required this.blockId,
    required this.x,
    required this.y,
  });

  @override
  List<Object?> get props => [blockId, x, y];
}

class SendRoleSwapRequestEvent extends GameEvent {
  const SendRoleSwapRequestEvent();
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

class SendEmoteEvent extends GameEvent {
  final String emote;

  const SendEmoteEvent(this.emote);

  @override
  List<Object?> get props => [emote];
}

class SendPitfallTrappedEvent extends GameEvent {
  final double tileX;
  final double tileY;

  const SendPitfallTrappedEvent(this.tileX, this.tileY);

  @override
  List<Object?> get props => [tileX, tileY];
}

class SendPitfallRescueEvent extends GameEvent {
  final double tileX;
  final double tileY;

  const SendPitfallRescueEvent(this.tileX, this.tileY);

  @override
  List<Object?> get props => [tileX, tileY];
}

class SendSpikeAlertEvent extends GameEvent {
  const SendSpikeAlertEvent();
}

class SendRuneProgressEvent extends GameEvent {
  final int correctCount;
  final int totalCount;
  final String? rune;
  final bool isCorrect;

  const SendRuneProgressEvent({
    required this.correctCount,
    required this.totalCount,
    this.rune,
    required this.isCorrect,
  });

  @override
  List<Object?> get props => [correctCount, totalCount, rune, isCorrect];
}

class ApplyRoleSwapEvent extends GameEvent {
  const ApplyRoleSwapEvent();
}

class SendCampfireAnswerEvent extends GameEvent {
  final int round;
  final String optionId;

  const SendCampfireAnswerEvent({required this.round, required this.optionId});

  @override
  List<Object?> get props => [round, optionId];
}

class SendCampfireNextRoundEvent extends GameEvent {
  final int round;

  const SendCampfireNextRoundEvent({required this.round});

  @override
  List<Object?> get props => [round];
}

class SendCampfireCompletedEvent extends GameEvent {
  const SendCampfireCompletedEvent();

  @override
  List<Object?> get props => [];
}

class SendHomeAvatarMoveEvent extends GameEvent {
  final double gridX;
  final double gridY;

  const SendHomeAvatarMoveEvent({required this.gridX, required this.gridY});

  @override
  List<Object?> get props => [gridX, gridY];
}

class SendHomeAvatarStandEvent extends GameEvent {
  final double gridX;
  final double gridY;

  const SendHomeAvatarStandEvent({required this.gridX, required this.gridY});

  @override
  List<Object?> get props => [gridX, gridY];
}

class SendHomeAvatarSitEvent extends GameEvent {
  final String chairId;
  final int slotIndex;

  const SendHomeAvatarSitEvent({required this.chairId, required this.slotIndex});

  @override
  List<Object?> get props => [chairId, slotIndex];
}

class SendHomeActionEvent extends GameEvent {
  final String actionType;
  final String message;

  const SendHomeActionEvent({required this.actionType, required this.message});

  @override
  List<Object?> get props => [actionType, message];
}

class SendHomeEmoteEvent extends GameEvent {
  final String emote;

  const SendHomeEmoteEvent({required this.emote});

  @override
  List<Object?> get props => [emote];
}

class SendHomeChatEvent extends GameEvent {
  final String text;

  const SendHomeChatEvent({required this.text});

  @override
  List<Object?> get props => [text];
}

class SendHomeCompletedEvent extends GameEvent {
  const SendHomeCompletedEvent();

  @override
  List<Object?> get props => [];
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
  final String? commune;
  final String? timeSlot;

  const MatchmakingQueueState({
    required this.mode,
    this.commune,
    this.timeSlot,
  });

  @override
  List<Object?> get props => [mode, commune, timeSlot];
}

class ActiveGameState extends GameState {
  final SessionInitPayload session;
  final bool partnerReady;
  final bool localReady;
  final DungeonStatePayload? latestDungeonState;
  final Vector2? latestPingPos;
  final int? trapsDisarmedTrigger;
  final int? runeGateUnlockedTrigger;
  final AvatarConfig? partnerAvatarConfig;
  final RoomConfig? partnerRoomConfig;
  final String? partnerUsername;
  final List<String>? partnerTastes;
  final String? latestEmote;
  final int? emoteTrigger;
  final Vector2? trappedPitfallPos;
  final Vector2? rescuedPitfallPos;
  final int? pitfallRescueTrigger;
  final int? spikeAlertTrigger;
  final int runeActivatedCount;
  final SessionInitPayload? pendingRoleSwapSession;
  final bool isCampfireActive;
  final String? partnerCampfireOptionId;
  final int? partnerCampfireRound;
  final int? partnerCampfireAnswerTrigger;
  final int? campfireNextRoundTrigger;
  final bool isHomeVisitActive;
  final String? hostUserId;
  final Vector2? partnerHomeMovePos;
  final int? partnerHomeMoveTrigger;
  final String? partnerHomeChairId;
  final int? partnerHomeSlotIndex;
  final int? partnerHomeSitTrigger;
  final int? partnerHomeStandTrigger;
  final String? homeActionType;
  final String? homeActionMessage;
  final int? homeActionTrigger;
  final String? homeChatText;
  final int? homeChatTrigger;

  const ActiveGameState({
    required this.session,
    this.partnerReady = false,
    this.localReady = false,
    this.latestDungeonState,
    this.latestPingPos,
    this.trapsDisarmedTrigger,
    this.runeGateUnlockedTrigger,
    this.partnerAvatarConfig,
    this.partnerRoomConfig,
    this.partnerUsername,
    this.partnerTastes,
    this.latestEmote,
    this.emoteTrigger,
    this.trappedPitfallPos,
    this.rescuedPitfallPos,
    this.pitfallRescueTrigger,
    this.spikeAlertTrigger,
    this.runeActivatedCount = 0,
    this.pendingRoleSwapSession,
    this.isCampfireActive = false,
    this.partnerCampfireOptionId,
    this.partnerCampfireRound,
    this.partnerCampfireAnswerTrigger,
    this.campfireNextRoundTrigger,
    this.isHomeVisitActive = false,
    this.hostUserId,
    this.partnerHomeMovePos,
    this.partnerHomeMoveTrigger,
    this.partnerHomeChairId,
    this.partnerHomeSlotIndex,
    this.partnerHomeSitTrigger,
    this.partnerHomeStandTrigger,
    this.homeActionType,
    this.homeActionMessage,
    this.homeActionTrigger,
    this.homeChatText,
    this.homeChatTrigger,
  });

  ActiveGameState copyWith({
    SessionInitPayload? session,
    bool? partnerReady,
    bool? localReady,
    DungeonStatePayload? latestDungeonState,
    Vector2? latestPingPos,
    int? trapsDisarmedTrigger,
    int? runeGateUnlockedTrigger,
    AvatarConfig? partnerAvatarConfig,
    RoomConfig? partnerRoomConfig,
    String? partnerUsername,
    List<String>? partnerTastes,
    String? latestEmote,
    int? emoteTrigger,
    Vector2? trappedPitfallPos,
    Vector2? rescuedPitfallPos,
    int? pitfallRescueTrigger,
    int? spikeAlertTrigger,
    int? runeActivatedCount,
    SessionInitPayload? pendingRoleSwapSession,
    bool? isCampfireActive,
    String? partnerCampfireOptionId,
    int? partnerCampfireRound,
    int? partnerCampfireAnswerTrigger,
    int? campfireNextRoundTrigger,
    bool? isHomeVisitActive,
    String? hostUserId,
    Vector2? partnerHomeMovePos,
    int? partnerHomeMoveTrigger,
    String? partnerHomeChairId,
    int? partnerHomeSlotIndex,
    int? partnerHomeSitTrigger,
    int? partnerHomeStandTrigger,
    String? homeActionType,
    String? homeActionMessage,
    int? homeActionTrigger,
    String? homeChatText,
    int? homeChatTrigger,
    bool clearTrappedPitfall = false,
    bool clearPendingRoleSwap = false,
    bool clearPartnerHomeChair = false,
  }) {
    return ActiveGameState(
      session: session ?? this.session,
      partnerReady: partnerReady ?? this.partnerReady,
      localReady: localReady ?? this.localReady,
      latestDungeonState: latestDungeonState ?? this.latestDungeonState,
      latestPingPos: latestPingPos ?? this.latestPingPos,
      trapsDisarmedTrigger: trapsDisarmedTrigger ?? this.trapsDisarmedTrigger,
      runeGateUnlockedTrigger: runeGateUnlockedTrigger ?? this.runeGateUnlockedTrigger,
      partnerAvatarConfig: partnerAvatarConfig ?? this.partnerAvatarConfig,
      partnerRoomConfig: partnerRoomConfig ?? this.partnerRoomConfig,
      partnerUsername: partnerUsername ?? this.partnerUsername,
      partnerTastes: partnerTastes ?? this.partnerTastes,
      latestEmote: latestEmote ?? this.latestEmote,
      emoteTrigger: emoteTrigger ?? this.emoteTrigger,
      trappedPitfallPos: clearTrappedPitfall ? null : (trappedPitfallPos ?? this.trappedPitfallPos),
      rescuedPitfallPos: rescuedPitfallPos ?? this.rescuedPitfallPos,
      pitfallRescueTrigger: pitfallRescueTrigger ?? this.pitfallRescueTrigger,
      spikeAlertTrigger: spikeAlertTrigger ?? this.spikeAlertTrigger,
      runeActivatedCount: runeActivatedCount ?? this.runeActivatedCount,
      pendingRoleSwapSession: clearPendingRoleSwap ? null : (pendingRoleSwapSession ?? this.pendingRoleSwapSession),
      isCampfireActive: isCampfireActive ?? this.isCampfireActive,
      partnerCampfireOptionId: partnerCampfireOptionId ?? this.partnerCampfireOptionId,
      partnerCampfireRound: partnerCampfireRound ?? this.partnerCampfireRound,
      partnerCampfireAnswerTrigger: partnerCampfireAnswerTrigger ?? this.partnerCampfireAnswerTrigger,
      campfireNextRoundTrigger: campfireNextRoundTrigger ?? this.campfireNextRoundTrigger,
      isHomeVisitActive: isHomeVisitActive ?? this.isHomeVisitActive,
      hostUserId: hostUserId ?? this.hostUserId,
      partnerHomeMovePos: partnerHomeMovePos ?? this.partnerHomeMovePos,
      partnerHomeMoveTrigger: partnerHomeMoveTrigger ?? this.partnerHomeMoveTrigger,
      partnerHomeChairId: clearPartnerHomeChair ? null : (partnerHomeChairId ?? this.partnerHomeChairId),
      partnerHomeSlotIndex: clearPartnerHomeChair ? null : (partnerHomeSlotIndex ?? this.partnerHomeSlotIndex),
      partnerHomeSitTrigger: partnerHomeSitTrigger ?? this.partnerHomeSitTrigger,
      partnerHomeStandTrigger: partnerHomeStandTrigger ?? this.partnerHomeStandTrigger,
      homeActionType: homeActionType ?? this.homeActionType,
      homeActionMessage: homeActionMessage ?? this.homeActionMessage,
      homeActionTrigger: homeActionTrigger ?? this.homeActionTrigger,
      homeChatText: homeChatText ?? this.homeChatText,
      homeChatTrigger: homeChatTrigger ?? this.homeChatTrigger,
    );
  }

  @override
  List<Object?> get props => [
    session,
    partnerReady,
    localReady,
    latestDungeonState,
    latestPingPos,
    trapsDisarmedTrigger,
    runeGateUnlockedTrigger,
    partnerAvatarConfig,
    partnerRoomConfig,
    partnerUsername,
    partnerTastes,
    latestEmote,
    emoteTrigger,
    trappedPitfallPos,
    rescuedPitfallPos,
    pitfallRescueTrigger,
    spikeAlertTrigger,
    runeActivatedCount,
    pendingRoleSwapSession,
    isCampfireActive,
    partnerCampfireOptionId,
    partnerCampfireRound,
    partnerCampfireAnswerTrigger,
    campfireNextRoundTrigger,
    isHomeVisitActive,
    hostUserId,
    partnerHomeMovePos,
    partnerHomeMoveTrigger,
    partnerHomeChairId,
    partnerHomeSlotIndex,
    partnerHomeSitTrigger,
    partnerHomeStandTrigger,
    homeActionType,
    homeActionMessage,
    homeActionTrigger,
    homeChatText,
    homeChatTrigger,
  ];
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
    on<SendEmoteEvent>(_onSendEmote);
    on<SendPitfallTrappedEvent>(_onSendPitfallTrapped);
    on<SendPitfallRescueEvent>(_onSendPitfallRescue);
    on<SendSpikeAlertEvent>(_onSendSpikeAlert);
    on<SendRuneProgressEvent>(_onSendRuneProgress);
    on<ApplyRoleSwapEvent>(_onApplyRoleSwap);
    on<SendCampfireAnswerEvent>(_onSendCampfireAnswer);
    on<SendCampfireNextRoundEvent>(_onSendCampfireNextRound);
    on<SendCampfireCompletedEvent>(_onSendCampfireCompleted);
    on<SendHomeAvatarMoveEvent>(_onSendHomeAvatarMove);
    on<SendHomeAvatarStandEvent>(_onSendHomeAvatarStand);
    on<SendHomeAvatarSitEvent>(_onSendHomeAvatarSit);
    on<SendHomeActionEvent>(_onSendHomeAction);
    on<SendHomeEmoteEvent>(_onSendHomeEmote);
    on<SendHomeChatEvent>(_onSendHomeChat);
    on<SendHomeCompletedEvent>(_onSendHomeCompleted);
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
    webSocketClient.setSessionActive(true);
    emit(MatchmakingQueueState(
      mode: event.mode,
      commune: event.commune,
      timeSlot: event.timeSlot,
    ));

    try {
      if (!webSocketClient.isConnected) {
        await webSocketClient.connect(event.socketUrl, event.token);
      }
      
      final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
      final myUsername = AuthService.currentUser?.username ?? myId;
      final myAvatar = AvatarStorageService.getUserConfig(myId);
      final myRoom = AvatarStorageService.getUserRoomConfig(myId);
      final myTastes = (AuthService.currentUser?.tastes != null && AuthService.currentUser!.tastes.isNotEmpty)
          ? AuthService.currentUser!.tastes
          : AvatarStorageService.getUserTastes(myId);

      print('[BLOC OUT] Submitting SESSION_INIT command with profile over WebSocket (Tastes: $myTastes)...');
      webSocketClient.sendMessage({
        'type': 'SESSION_INIT',
        'token': event.token,
        'commune': event.commune,
        'timeSlot': event.timeSlot,
        'mode': event.mode,
        'username': myUsername,
        'avatarConfig': myAvatar.toJson(),
        'roomConfig': myRoom.toMap(),
        'tastes': myTastes,
      });
    } catch (e) {
      print('[BLOC ERROR] Exception during queue join: $e');
      webSocketClient.setSessionActive(false);
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

  void _onSendEmote(SendEmoteEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending EMOTE_TRIGGERED: ${event.emote}');
    webSocketClient.sendMessage({
      'type': 'EMOTE_TRIGGERED',
      'emote': event.emote,
    });
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      emit(active.copyWith(
        latestEmote: event.emote,
        emoteTrigger: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _onSendPitfallTrapped(SendPitfallTrappedEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending PITFALL_TRAPPED at (${event.tileX}, ${event.tileY})');
    webSocketClient.sendMessage({
      'type': 'PITFALL_TRAPPED',
      'tileX': event.tileX,
      'tileY': event.tileY,
    });
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      emit(active.copyWith(trappedPitfallPos: Vector2(event.tileX, event.tileY)));
    }
  }

  void _onSendPitfallRescue(SendPitfallRescueEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending PITFALL_RESCUED at (${event.tileX}, ${event.tileY})');
    webSocketClient.sendMessage({
      'type': 'PITFALL_RESCUED',
      'tileX': event.tileX,
      'tileY': event.tileY,
    });
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      emit(active.copyWith(
        clearTrappedPitfall: true,
        rescuedPitfallPos: Vector2(event.tileX, event.tileY),
        pitfallRescueTrigger: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _onSendSpikeAlert(SendSpikeAlertEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending TRAP_TRIGGERED (SPIKE)');
    webSocketClient.sendMessage({
      'type': 'TRAP_TRIGGERED',
      'trapType': 'SPIKE',
    });
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      emit(active.copyWith(spikeAlertTrigger: DateTime.now().millisecondsSinceEpoch));
    }
  }

  void _onSendRuneProgress(SendRuneProgressEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending RUNE_STEPPED: ${event.correctCount}/${event.totalCount}');
    webSocketClient.sendMessage({
      'type': 'RUNE_STEPPED',
      'correctCount': event.correctCount,
      'totalCount': event.totalCount,
      'rune': event.rune,
      'isCorrect': event.isCorrect,
    });
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      emit(active.copyWith(runeActivatedCount: event.correctCount));
    }
  }

  void _onApplyRoleSwap(ApplyRoleSwapEvent event, Emitter<GameState> emit) {
    if (state is ActiveGameState) {
      final active = state as ActiveGameState;
      if (active.pendingRoleSwapSession != null) {
        print('[BLOC] Applying pending role swap session: ${active.pendingRoleSwapSession!.role}');
        emit(ActiveGameState(
          session: active.pendingRoleSwapSession!,
          partnerAvatarConfig: active.partnerAvatarConfig,
          partnerRoomConfig: active.partnerRoomConfig,
          partnerUsername: active.partnerUsername,
          partnerTastes: active.partnerTastes,
        ));
      }
    }
  }

  void _onSendCampfireAnswer(SendCampfireAnswerEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending CAMPFIRE_ANSWER for round ${event.round}: ${event.optionId}');
    webSocketClient.sendMessage({
      'type': 'CAMPFIRE_ANSWER',
      'round': event.round,
      'optionId': event.optionId,
    });
  }

  void _onSendCampfireNextRound(SendCampfireNextRoundEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending CAMPFIRE_NEXT_ROUND for round ${event.round}');
    webSocketClient.sendMessage({
      'type': 'CAMPFIRE_NEXT_ROUND',
      'round': event.round,
    });
  }

  void _onSendCampfireCompleted(SendCampfireCompletedEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending CAMPFIRE_COMPLETED to server');
    webSocketClient.sendMessage({
      'type': 'CAMPFIRE_COMPLETED',
    });
  }

  void _onSendHomeAvatarMove(SendHomeAvatarMoveEvent event, Emitter<GameState> emit) {
    webSocketClient.sendMessage({
      'type': 'HOME_AVATAR_MOVE',
      'gridX': event.gridX,
      'gridY': event.gridY,
    });
  }

  void _onSendHomeAvatarStand(SendHomeAvatarStandEvent event, Emitter<GameState> emit) {
    webSocketClient.sendMessage({
      'type': 'HOME_AVATAR_STAND',
      'gridX': event.gridX,
      'gridY': event.gridY,
    });
  }

  void _onSendHomeAvatarSit(SendHomeAvatarSitEvent event, Emitter<GameState> emit) {
    webSocketClient.sendMessage({
      'type': 'HOME_AVATAR_SIT',
      'chairId': event.chairId,
      'slotIndex': event.slotIndex,
    });
  }

  void _onSendHomeAction(SendHomeActionEvent event, Emitter<GameState> emit) {
    webSocketClient.sendMessage({
      'type': 'HOME_ACTION',
      'actionType': event.actionType,
      'message': event.message,
    });
  }

  void _onSendHomeEmote(SendHomeEmoteEvent event, Emitter<GameState> emit) {
    webSocketClient.sendMessage({
      'type': 'HOME_EMOTE',
      'emote': event.emote,
    });
  }

  void _onSendHomeChat(SendHomeChatEvent event, Emitter<GameState> emit) {
    webSocketClient.sendMessage({
      'type': 'HOME_CHAT',
      'text': event.text,
    });
  }

  void _onSendHomeCompleted(SendHomeCompletedEvent event, Emitter<GameState> emit) {
    print('[BLOC OUT] Sending HOME_COMPLETED (DATE_COMPLETED) to server');
    webSocketClient.sendMessage({
      'type': 'DATE_COMPLETED',
    });
  }

  Future<void> _onSendEmergencyDisconnect(SendEmergencyDisconnectEvent event, Emitter<GameState> emit) async {
    print('[BLOC EVENT] SendEmergencyDisconnectEvent triggered (ShouldBlock: ${event.shouldBlock})');
    if (state is MatchmakingQueueState) {
      print('[BLOC OUT] Leaving matchmaking queue via emergency disconnect...');
      webSocketClient.sendMessage({'type': 'LEAVE_QUEUE'});
    }
    webSocketClient.setSessionActive(false);
    webSocketClient.sendMessage({
      'type': 'EMERGENCY_DISCONNECT',
      'block': event.shouldBlock,
    });
    // Maintain lobby connection and presence for chat and invites
    ChatService.ensureConnected();

    final reasonText = event.shouldBlock
        ? 'You exited the game and permanently blocked your partner (emergency disconnect).'
        : 'You exited the game session (emergency disconnect - Friendly Exit - No Block).';

    emit(TerminatedGameState(reason: reasonText));
  }

  void _onResetGame(ResetGameEvent event, Emitter<GameState> emit) {
    print('[BLOC EVENT] ResetGameEvent triggered. Resetting BLoC state to GameInitialState and maintaining socket connection...');
    // If we were waiting in matchmaking queue, notify backend to leave the queue
    if (state is MatchmakingQueueState) {
      print('[BLOC OUT] Leaving matchmaking queue...');
      webSocketClient.sendMessage({'type': 'LEAVE_QUEUE'});
    }
    webSocketClient.setSessionActive(false);
    emit(const GameInitialState());
    ChatService.ensureConnected();
  }

  void _onSocketMessage(_OnSocketMessageEvent event, Emitter<GameState> emit) {
    final msg = event.message;
    final type = msg['type'] as String?;

    print('[BLOC IN] Processing socket message of type: $type');

    if (type == 'ERROR') {
      print('[BLOC IN] Received error packet: ${msg['message']}');
      webSocketClient.setSessionActive(false);
      emit(ErrorGameState(message: msg['message'] as String? ?? 'Unknown error'));
      return;
    }

    if (type == 'QUEUED') {
      print('[BLOC IN] Confirmed in matchmaking queue by server');
      if (state is! MatchmakingQueueState && state is! ActiveGameState) {
        emit(const MatchmakingQueueState(mode: 'STANDARD'));
      }
      return;
    }

    if (type == 'SESSION_INIT') {
      final payload = SessionInitPayload.fromJson(msg);
      print('[BLOC IN] Received SESSION_INIT match! RoomId: ${payload.roomId}, Role: ${payload.role}, Partner: ${payload.partnerId} (${payload.partnerUsername}), PartnerTastes: ${payload.partnerTastes}');
      webSocketClient.setSessionActive(true);

      // Si el backend envió el avatar/cuarto/gustos reales del partner, guardarlos en AvatarStorageService
      if (payload.partnerAvatarConfig != null && payload.partnerId.isNotEmpty) {
        AvatarStorageService.saveUserConfig(payload.partnerId, payload.partnerAvatarConfig!);
      }
      if (payload.partnerRoomConfig != null && payload.partnerId.isNotEmpty) {
        AvatarStorageService.saveUserRoomConfig(payload.partnerId, payload.partnerRoomConfig!);
      }
      if (payload.partnerTastes.isNotEmpty && payload.partnerId.isNotEmpty) {
        AvatarStorageService.saveUserTastes(payload.partnerId, payload.partnerTastes);
      }

      final resolvedAvatar = payload.partnerAvatarConfig ?? AvatarStorageService.getUserConfig(payload.partnerId);
      final resolvedRoom = payload.partnerRoomConfig ?? AvatarStorageService.getUserRoomConfig(payload.partnerId);
      final resolvedTastes = payload.partnerTastes.isNotEmpty
          ? payload.partnerTastes
          : AvatarStorageService.getUserTastes(payload.partnerId);

      // Re-enviar inmediatamente nuestro perfil completo (incluyendo gustos) para sincronización simétrica
      final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
      final myUsername = AuthService.currentUser?.username ?? myId;
      final myAvatar = AvatarStorageService.getUserConfig(myId);
      final myRoom = AvatarStorageService.getUserRoomConfig(myId);
      final myTastes = (AuthService.currentUser?.tastes != null && AuthService.currentUser!.tastes.isNotEmpty)
          ? AuthService.currentUser!.tastes
          : AvatarStorageService.getUserTastes(myId);

      webSocketClient.sendMessage({
        'type': 'PROFILE_SYNC',
        'userId': myId,
        'username': myUsername,
        'avatarConfig': myAvatar.toJson(),
        'roomConfig': myRoom.toMap(),
        'tastes': myTastes,
      });

      final isHomeVisit = payload.isHomeVisitActive || payload.mode == 'HOME' || msg['isHomeVisitActive'] == true;
      final hostUserId = (msg['hostUserId'] as String?) ?? payload.hostUserId;

      emit(ActiveGameState(
        session: payload,
        partnerAvatarConfig: resolvedAvatar,
        partnerRoomConfig: resolvedRoom,
        partnerUsername: payload.partnerUsername ?? payload.partnerId,
        partnerTastes: resolvedTastes,
        isCampfireActive: payload.mode == 'CAMPFIRE' || msg['isCampfireActive'] == true,
        isHomeVisitActive: isHomeVisit,
        hostUserId: hostUserId,
      ));
      return;
    }

    if (type == 'PROFILE_SYNC') {
      final senderUserId = msg['userId'] as String? ?? '';
      final senderUsername = msg['username'] as String?;
      final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;

      // Ignore echoes of our own profile sync so we never overwrite partner info with our own
      if (senderUserId.isNotEmpty && senderUserId == myId) {
        print('[BLOC IN] Ignoring self PROFILE_SYNC packet from $senderUserId');
        return;
      }

      final avatarData = msg['avatarConfig'] as Map<String, dynamic>?;
      final roomData = msg['roomConfig'] as Map<String, dynamic>?;
      final rawTastes = msg['tastes'];

      AvatarConfig? partnerAvatar;
      RoomConfig? partnerRoom;
      List<String>? partnerTastes;

      if (avatarData != null) {
        partnerAvatar = AvatarConfig.fromJson(avatarData);
        if (senderUserId.isNotEmpty) {
          AvatarStorageService.saveUserConfig(senderUserId, partnerAvatar);
        }
      }

      if (roomData != null) {
        partnerRoom = RoomConfig.fromMap(roomData);
        if (senderUserId.isNotEmpty) {
          AvatarStorageService.saveUserRoomConfig(senderUserId, partnerRoom);
        }
      }

      if (rawTastes is List) {
        partnerTastes = rawTastes.map((e) => e.toString()).toList();
      } else if (rawTastes is String && rawTastes.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawTastes);
          if (decoded is List) {
            partnerTastes = decoded.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }

      if (partnerTastes != null && partnerTastes.isNotEmpty && senderUserId.isNotEmpty) {
        AvatarStorageService.saveUserTastes(senderUserId, partnerTastes);
      }

      print('[BLOC IN] Received PROFILE_SYNC from partner $senderUserId (${senderUsername ?? "unknown"}), Tastes: $partnerTastes');

      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          partnerAvatarConfig: partnerAvatar ?? active.partnerAvatarConfig,
          partnerRoomConfig: partnerRoom ?? active.partnerRoomConfig,
          partnerUsername: senderUsername ?? active.partnerUsername,
          partnerTastes: (partnerTastes != null && partnerTastes.isNotEmpty) ? partnerTastes : active.partnerTastes,
        ));
      }
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

    if (type == 'EMOTE_TRIGGERED') {
      final emote = msg['emote'] as String? ?? '❤️';
      print('[BLOC IN] Received EMOTE_TRIGGERED from partner: $emote');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          latestEmote: emote,
          emoteTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      return;
    }

    if (type == 'PITFALL_TRAPPED') {
      final tx = (msg['tileX'] as num?)?.toDouble() ?? 0.0;
      final ty = (msg['tileY'] as num?)?.toDouble() ?? 0.0;
      print('[BLOC IN] Received PITFALL_TRAPPED at ($tx, $ty)');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(trappedPitfallPos: Vector2(tx, ty)));
      }
      return;
    }

    if (type == 'PITFALL_RESCUED') {
      final rx = (msg['tileX'] as num?)?.toDouble() ?? 0.0;
      final ry = (msg['tileY'] as num?)?.toDouble() ?? 0.0;
      print('[BLOC IN] Received PITFALL_RESCUED at ($rx, $ry)');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          clearTrappedPitfall: true,
          rescuedPitfallPos: Vector2(rx, ry),
          pitfallRescueTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      return;
    }

    if (type == 'TRAP_TRIGGERED') {
      print('[BLOC IN] Received TRAP_TRIGGERED (Spike Alert) from partner');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(spikeAlertTrigger: DateTime.now().millisecondsSinceEpoch));
      }
      return;
    }

    if (type == 'RUNE_STEPPED') {
      final correctCount = (msg['correctCount'] as num?)?.toInt() ?? 0;
      print('[BLOC IN] Received RUNE_STEPPED from partner: $correctCount');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(runeActivatedCount: correctCount));
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
          partnerUsername: active.partnerUsername ?? active.session.partnerUsername,
          partnerAvatarConfig: active.partnerAvatarConfig ?? active.session.partnerAvatarConfig,
          partnerTastes: (active.partnerTastes != null && active.partnerTastes!.isNotEmpty)
              ? active.partnerTastes!
              : active.session.partnerTastes,
          seed: newSeed,
        );
        print('[BLOC IN] Storing pendingRoleSwapSession for Act $newAct: $currentRole -> $newRole (Seed: $newSeed, Partner: ${active.session.partnerId})');
        emit(active.copyWith(pendingRoleSwapSession: updatedSession));
      }
      return;
    }

    if (type == 'CAMPFIRE_START') {
      print('[BLOC IN] Received CAMPFIRE_START from server: $msg');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(isCampfireActive: true));
      }
      return;
    }

    if (type == 'CAMPFIRE_ANSWER') {
      final round = (msg['round'] as num?)?.toInt() ?? 0;
      final optionId = msg['optionId'] as String?;
      print('[BLOC IN] Partner selected option in campfire round $round: $optionId');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          partnerCampfireOptionId: optionId,
          partnerCampfireRound: round,
          partnerCampfireAnswerTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      return;
    }

    if (type == 'CAMPFIRE_NEXT_ROUND') {
      final round = (msg['round'] as num?)?.toInt() ?? 0;
      print('[BLOC IN] Partner requested next campfire round: $round');
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          campfireNextRoundTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
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

    if (type == 'HOME_AVATAR_MOVE') {
      final gx = (msg['gridX'] as num?)?.toDouble();
      final gy = (msg['gridY'] as num?)?.toDouble();
      if (gx != null && gy != null && state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          partnerHomeMovePos: Vector2(gx, gy),
          partnerHomeMoveTrigger: DateTime.now().millisecondsSinceEpoch,
          clearPartnerHomeChair: true,
        ));
      }
      return;
    }

    if (type == 'HOME_AVATAR_STAND') {
      final gx = (msg['gridX'] as num?)?.toDouble();
      final gy = (msg['gridY'] as num?)?.toDouble();
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          clearPartnerHomeChair: true,
          partnerHomeMovePos: (gx != null && gy != null) ? Vector2(gx, gy) : null,
          partnerHomeStandTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      return;
    }

    if (type == 'HOME_AVATAR_SIT') {
      final chairId = msg['chairId'] as String?;
      final slotIndex = (msg['slotIndex'] as num?)?.toInt() ?? 0;
      if (chairId != null && state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          partnerHomeChairId: chairId,
          partnerHomeSlotIndex: slotIndex,
          partnerHomeSitTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      return;
    }

    if (type == 'HOME_ACTION') {
      final actionType = msg['actionType'] as String? ?? '';
      final message = msg['message'] as String? ?? '';
      if (state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          homeActionType: actionType,
          homeActionMessage: message,
          homeActionTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      return;
    }

    if (type == 'HOME_EMOTE') {
      final emote = msg['emote'] as String?;
      if (emote != null && state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          latestEmote: emote,
          emoteTrigger: DateTime.now().millisecondsSinceEpoch,
        ));
      }
      return;
    }

    if (type == 'HOME_CHAT') {
      final text = msg['text'] as String?;
      if (text != null && state is ActiveGameState) {
        final active = state as ActiveGameState;
        emit(active.copyWith(
          homeChatText: text,
          homeChatTrigger: DateTime.now().millisecondsSinceEpoch,
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
      ChatService.ensureConnected();
      return;
    }

    if (type == 'GAME_OVER') {
      print('[BLOC IN] Received GAME_OVER from server');
      webSocketClient.setSessionActive(false);
      emit(TerminatedGameState(reason: msg['reason'] as String? ?? 'Session ended.'));
      ChatService.ensureConnected();
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
      // Note: If state is MatchmakingQueueState, stay in MatchmakingQueueState while client auto-reconnects
    } else if (netState == WebSocketConnectionState.disconnected) {
      if (state is MatchmakingQueueState) {
        print('[BLOC IN] Disconnected while in queue. Returning to GameInitialState (Main Menu).');
        webSocketClient.setSessionActive(false);
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
