import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/game_models.dart';
import '../../../core/models/room_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import 'bloc/game_bloc.dart';
import 'dungeon_game.dart';
import 'guide_game_view.dart';
import 'services/dungeon_generator.dart';
import 'widgets/dpad_widget.dart';
import 'widgets/dungeon_mission_hud.dart';
import 'widgets/emote_wheel_widget.dart';
import 'widgets/role_swap_transition_dialog.dart';
import 'screens/role_swap_cinematic_view.dart';
import '../campfire/screens/campfire_view.dart';
import 'dart:async';

class GameView extends StatefulWidget {
  final ActiveGameState state;

  const GameView({super.key, required this.state});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  late DungeonGame _dungeonGame;
  bool _hasKey = false;
  bool _isShowingRoleSwapDialog = false;

  Vector2? _lastExplorerPos;
  Vector2? _lastHandledPingPos;
  int? _lastHandledDisarmTrigger;
  int? _lastHandledGateTrigger;
  int? _lastHandledEmoteTrigger;
  int? _lastHandledRescueTrigger;

  @override
  void initState() {
    super.initState();
    // Use deterministic shared seed from server or fallback to deterministic room hash
    final sharedSeed = widget.state.session.seed ??
        DungeonGenerator.deterministicStringSeed(widget.state.session.roomId);
    final localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    final explorerAvatar = AvatarStorageService.getUserConfig(localUserId);

    _dungeonGame = DungeonGame(
      dungeonMapData: DungeonGenerator.generateMap(
        seed: sharedSeed,
        act: widget.state.session.act,
      ),
      explorerAvatarConfig: explorerAvatar,
      onSanctuaryReached: () {
        if (!mounted) return;
        context.read<GameBloc>().add(const SendSanctuaryReachedEvent());
      },
      onExplorerMoved: (pos) {
        if (!mounted) return;
        _lastExplorerPos = pos;
      },
      onExplorerMovedFull: (pos, dir, moving) {
        if (!mounted) return;
        _lastExplorerPos = pos;
        _sendDungeonState(direction: dir, isMoving: moving);
      },
      onKeyStatusChanged: (hasKey) {
        if (!mounted) return;
        setState(() {
          _hasKey = hasKey;
        });
      },
      onExplorerTrapped: (tilePos) {
        if (!mounted) return;
        context.read<GameBloc>().add(SendPitfallTrappedEvent(tilePos.x, tilePos.y));
      },
      onExplorerSpikeHit: () {
        if (!mounted) return;
        context.read<GameBloc>().add(const SendSpikeAlertEvent());
      },
      onRuneProgress: (correct, total, rune, isCorrect) {
        if (!mounted) return;
        context.read<GameBloc>().add(SendRuneProgressEvent(
          correctCount: correct,
          totalCount: total,
          rune: rune,
          isCorrect: isCorrect,
        ));
      },
      onRuneFeedback: (message) {
        // Logging feedback cleanly without intrusive snackbars over D-Pad
        print('[EXPLORER FEEDBACK] $message');
      },
    );
  }

  void _sendDungeonState({String direction = 'down', bool isMoving = false}) {
    if (!mounted) return;
    if (_lastExplorerPos != null) {
      context.read<GameBloc>().add(SendPlayerMoveEvent(
        DungeonStatePayload(
          playerX: _lastExplorerPos!.x,
          playerY: _lastExplorerPos!.y,
          role: 'EXPLORER',
          direction: direction,
          isMoving: isMoving,
          activeTraps: const {},
          blockPositions: const {},
        ),
      ));
    }
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange),
            SizedBox(width: 10),
            Text('¿Deseas salir de la partida?'),
          ],
        ),
        content: const Text(
          'Puedes salir amigablemente (si tuviste una emergencia real) o aplicar un bloqueo permanente si te sentiste incómodo/a.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<GameBloc>().add(const SendEmergencyDisconnectEvent(shouldBlock: false));
            },
            child: const Text('Salir sin bloquear'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<GameBloc>().add(const SendEmergencyDisconnectEvent(shouldBlock: true));
            },
            child: const Text('Salir y Bloquear'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.state.session;
    final isExplorer = session.role == 'EXPLORER';

    // Render Guide Console if user role is GUIDE
    if (!isExplorer) {
      return GuideGameView(state: widget.state);
    }

    return BlocListener<GameBloc, GameState>(
      listener: (context, state) {
        if (state is ActiveGameState) {
          if (state.latestPingPos != null && state.latestPingPos != _lastHandledPingPos) {
            _lastHandledPingPos = state.latestPingPos;
            // Use addTrailPoint for the smooth "writing" look
            _dungeonGame.addTrailPoint(state.latestPingPos!);
          }
          if (state.trapsDisarmedTrigger != null && state.trapsDisarmedTrigger != _lastHandledDisarmTrigger) {
            _lastHandledDisarmTrigger = state.trapsDisarmedTrigger;
            _dungeonGame.disarmAllTraps();
          }
          if (state.runeGateUnlockedTrigger != null && state.runeGateUnlockedTrigger != _lastHandledGateTrigger) {
            _lastHandledGateTrigger = state.runeGateUnlockedTrigger;
            _dungeonGame.unlockRuneGate();
          }
          if (state.latestEmote != null && state.emoteTrigger != _lastHandledEmoteTrigger) {
            _lastHandledEmoteTrigger = state.emoteTrigger;
            _dungeonGame.showFloatingEmote(state.latestEmote!);
          }
          if (state.pitfallRescueTrigger != null && state.pitfallRescueTrigger != _lastHandledRescueTrigger) {
            _lastHandledRescueTrigger = state.pitfallRescueTrigger;
            if (state.rescuedPitfallPos != null) {
              _dungeonGame.rescueExplorerFromPitfall(state.rescuedPitfallPos!);
            }
          }
          if (state.pendingRoleSwapSession != null && !_isShowingRoleSwapDialog) {
            _isShowingRoleSwapDialog = true;
            final localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
            final localAvatar = AvatarStorageService.getUserConfig(localUserId);
            Navigator.of(context).push(
              PageRouteBuilder(
                opaque: true,
                pageBuilder: (cinematicContext, _, __) => RoleSwapCinematicView(
                  newRole: state.pendingRoleSwapSession!.role,
                  localAvatarConfig: localAvatar,
                  partnerAvatarConfig: state.partnerAvatarConfig,
                  partnerName: state.partnerUsername ?? 'Compañero',
                  onProceed: () {
                    Navigator.of(cinematicContext).pop();
                    _isShowingRoleSwapDialog = false;
                    context.read<GameBloc>().add(const ApplyRoleSwapEvent());
                  },
                ),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        }
      },
      child: ValueListenableBuilder<int>(
        valueListenable: _dungeonGame.portalRemainingSeconds,
        builder: (context, seconds, child) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: DungeonMissionHud(
              isGuide: false,
              targetRuneSequence: _dungeonGame.dungeonMapData?.secretRuneSequence ?? const ['SOL', 'MOON', 'SNAKE'],
              currentActivatedCount: _dungeonGame.currentSteppedSequence.length,
              portalSecondsRemaining: seconds,
              hasKey: _hasKey,
              onExitPressed: () => _showExitDialog(context),
            ),
            body: Stack(
              children: [
                // 1. Flame 2D Game Canvas (Fixed, 100% stable)
                Positioned.fill(
                  child: GameWidget(
                    game: _dungeonGame,
                  ),
                ),

                // 2. Floating Alert Overlay (Floats OVER the canvas without shifting the map)
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: DungeonAlertOverlay(
                    isGuide: false,
                    isTrapped: widget.state.trappedPitfallPos != null || _dungeonGame.isExplorerTrapped,
                  ),
                ),

                // 2. Touch D-Pad Overlay & Debug Footer (bottom left)
                Positioned(
                  bottom: 24,
                  left: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DPadWidget(game: _dungeonGame),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'Room: ${session.roomId}\nPartner: ${session.partnerId}',
                          style: const TextStyle(color: Colors.white38, fontSize: 10, height: 1.2),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Floating Emote Wheel (bottom right)
                Positioned(
                  bottom: 24,
                  right: 20,
                  child: EmoteWheelWidget(
                    onEmoteSelected: (emote) {
                      _dungeonGame.showFloatingEmote(emote);
                      context.read<GameBloc>().add(SendEmoteEvent(emote));
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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

@Preview(name: 'Game - Explorer View')
Widget previewGameExplorer() {
  final session = SessionInitPayload(
    roomId: 'preview-room-123',
    role: 'EXPLORER',
    mode: 'STANDARD',
    partnerId: 'PreviewPartner',
  );
  
  final mockClient = _MockWebSocketClient();

  return BlocProvider(
    create: (context) => GameBloc(webSocketClient: mockClient),
    child: GameView(state: ActiveGameState(session: session)),
  );
}

@Preview(name: 'Game - Guide View')
Widget previewGameGuide() {
  final session = SessionInitPayload(
    roomId: 'preview-room-123',
    role: 'GUIDE',
    mode: 'STANDARD',
    partnerId: 'PreviewPartner',
  );

  final mockClient = _MockWebSocketClient();

  return BlocProvider(
    create: (context) => GameBloc(webSocketClient: mockClient),
    child: GameView(state: ActiveGameState(session: session)),
  );
}
