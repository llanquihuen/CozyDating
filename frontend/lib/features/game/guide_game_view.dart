import 'dart:async' as async;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/room_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import 'bloc/game_bloc.dart';
import 'guide_dungeon_game.dart';
import 'services/dungeon_generator.dart';
import 'widgets/dungeon_mission_hud.dart';
import 'widgets/emote_wheel_widget.dart';
import 'widgets/role_swap_transition_dialog.dart';
import 'screens/role_swap_cinematic_view.dart';
import '../campfire/screens/campfire_view.dart';

class GuideGameView extends StatefulWidget {
  final ActiveGameState state;

  const GuideGameView({super.key, required this.state});

  @override
  State<GuideGameView> createState() => _GuideGameViewState();
}

class _GuideGameViewState extends State<GuideGameView> {
  late GuideDungeonGame _guideGame;
  int? _lastHandledDisarmTrigger;
  int? _lastHandledGateTrigger;
  int? _lastHandledEmoteTrigger;
  int? _lastHandledSpikeAlertTrigger;
  bool _showSpikeAlert = false;
  async.Timer? _spikeAlertTimer;
  bool _isShowingRoleSwapDialog = false;
  bool _isShowingCampfire = false;

  @override
  void initState() {
    super.initState();
    // Use deterministic shared seed from server or fallback to deterministic room hash
    final sharedSeed = widget.state.session.seed ??
        DungeonGenerator.deterministicStringSeed(widget.state.session.roomId);

    final localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    var partnerCandidate = widget.state.session.partnerId;
    if (partnerCandidate.isEmpty || partnerCandidate == localUserId) {
      if (localUserId == 'alice') {
        partnerCandidate = 'bob';
      } else if (localUserId == 'bob') {
        partnerCandidate = 'alice';
      } else if (localUserId == 'charlie') {
        partnerCandidate = 'david';
      } else {
        partnerCandidate = 'bob';
      }
    }
    final partnerAvatar = widget.state.partnerAvatarConfig ?? AvatarStorageService.getUserConfig(partnerCandidate);

    _guideGame = GuideDungeonGame(
      dungeonMapData: DungeonGenerator.generateMap(
        seed: sharedSeed,
        act: widget.state.session.act,
      ),
      explorerAvatarConfig: partnerAvatar,
      onPingTap: (pingPos) {
        if (!mounted) return;
        context.read<GameBloc>().add(SendPingEvent(pingPos.x, pingPos.y));
      },
    );
  }

  @override
  void dispose() {
    _spikeAlertTimer?.cancel();
    super.dispose();
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
    final secretRunes = _guideGame.dungeonMapData?.secretRuneSequence ?? const ['SOL', 'MOON', 'SNAKE'];
    final clueText = secretRunes.map((r) => DungeonGenerator.getRuneLabel(r)).join(' ➔ ');

    return BlocListener<GameBloc, GameState>(
      listener: (context, state) {
        if (state is ActiveGameState) {
          if (state.latestDungeonState != null) {
            final ds = state.latestDungeonState!;
            _guideGame.updateExplorerRemotePosition(
              Vector2(ds.playerX, ds.playerY),
              direction: ds.direction,
              isMoving: ds.isMoving,
            );
          }
          if (state.trapsDisarmedTrigger != null && state.trapsDisarmedTrigger != _lastHandledDisarmTrigger) {
            _lastHandledDisarmTrigger = state.trapsDisarmedTrigger;
            _guideGame.disarmAllTraps();
          }
          if (state.runeGateUnlockedTrigger != null && state.runeGateUnlockedTrigger != _lastHandledGateTrigger) {
            _lastHandledGateTrigger = state.runeGateUnlockedTrigger;
            _guideGame.unlockRuneGate();
          }
          if (state.latestEmote != null && state.emoteTrigger != _lastHandledEmoteTrigger) {
            _lastHandledEmoteTrigger = state.emoteTrigger;
            _guideGame.showFloatingEmote(state.latestEmote!);
          }
          if (state.spikeAlertTrigger != null && state.spikeAlertTrigger != _lastHandledSpikeAlertTrigger) {
            _lastHandledSpikeAlertTrigger = state.spikeAlertTrigger;
            setState(() {
              _showSpikeAlert = true;
            });
            _spikeAlertTimer?.cancel();
            _spikeAlertTimer = async.Timer(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() => _showSpikeAlert = false);
              }
            });
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
          if (state.isCampfireActive && !_isShowingCampfire) {
            _isShowingCampfire = true;
            final localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
            final localTastes = (AuthService.currentUser?.tastes != null && AuthService.currentUser!.tastes.isNotEmpty)
                ? AuthService.currentUser!.tastes
                : AvatarStorageService.getUserTastes(localUserId);

            final localProfile = AuthService.currentUser?.copyWith(tastes: localTastes) ??
                UserProfile(
                  id: localUserId,
                  username: 'Tú',
                  avatarConfig: AvatarStorageService.getUserConfig(localUserId),
                  roomConfig: AvatarStorageService.getUserRoomConfig(localUserId),
                  tastes: localTastes,
                );

            final partnerTastes = (state.partnerTastes != null && state.partnerTastes!.isNotEmpty)
                ? state.partnerTastes!
                : (state.session.partnerTastes.isNotEmpty
                    ? state.session.partnerTastes
                    : AvatarStorageService.getUserTastes(state.session.partnerId));

            final partnerProfile = UserProfile(
              id: state.session.partnerId,
              username: state.partnerUsername ?? state.session.partnerUsername ?? 'Compañero',
              avatarConfig: state.partnerAvatarConfig ?? state.session.partnerAvatarConfig ?? const AvatarConfig(),
              roomConfig: state.partnerRoomConfig ?? state.session.partnerRoomConfig ?? const RoomConfig(),
              tastes: partnerTastes,
            );

            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                opaque: true,
                pageBuilder: (cContext, _, __) => CampfireView(
                  localUser: localProfile,
                  partnerUser: partnerProfile,
                  partnerName: partnerProfile.username,
                  partnerAvatarConfig: partnerProfile.avatarConfig,
                  seed: state.session.seed,
                  onReturnHome: () {
                    Navigator.of(cContext).popUntil((route) => route.isFirst);
                  },
                ),
                transitionsBuilder: (_, animation, __, child) =>
                    FadeTransition(opacity: animation, child: child),
                transitionDuration: const Duration(milliseconds: 600),
              ),
            );
          }
        }
      },
      child: ValueListenableBuilder<int>(
        valueListenable: _guideGame.portalRemainingSeconds,
        builder: (context, seconds, child) {
          return Scaffold(
            backgroundColor: const Color(0xFF121212),
            appBar: DungeonMissionHud(
              isGuide: true,
              targetRuneSequence: secretRunes,
              currentActivatedCount: widget.state.runeActivatedCount,
              portalSecondsRemaining: seconds,
              onExitPressed: () => _showExitDialog(context),
            ),
            body: Stack(
              children: [
                // 1. Fully Illuminated Guide Map Canvas (100% stable, NEVER moves or shifts)
                Positioned.fill(
                  child: GameWidget(
                    game: _guideGame,
                  ),
                ),

                // 2. Floating Alert Overlay (Floats OVER the canvas without shifting the map)
                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: DungeonAlertOverlay(
                    isGuide: true,
                    isTrapped: widget.state.trappedPitfallPos != null,
                    showSpikeAlert: _showSpikeAlert,
                    onRescuePressed: () {
                      final trapPos = widget.state.trappedPitfallPos;
                      if (trapPos != null) {
                        _guideGame.rescueExplorerFromPitfall(trapPos);
                        context.read<GameBloc>().add(SendPitfallRescueEvent(trapPos.x, trapPos.y));
                      }
                    },
                  ),
                ),

                // 2. Floating Emote Wheel (right side above bottom panel)
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: EmoteWheelWidget(
                    onEmoteSelected: (emote) {
                      _guideGame.showFloatingEmote(emote);
                      context.read<GameBloc>().add(SendEmoteEvent(emote));
                    },
                  ),
                ),

            // 4. Tactical Controls & Secret Combination Banner (bottom center)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Secret Rune Combination Clue Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amberAccent, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '📜 COMBINACIÓN SECRETA DEL PORTÓN RÚNICO',
                          style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          clueText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      _guideGame.disarmAllTraps();
                      context.read<GameBloc>().add(const SendDisarmTrapsEvent());
                    },
                    icon: const Icon(Icons.shield_outlined, size: 18),
                    label: const Text('🛡️ Desactivar Púas (Desarmar 5 segundos)', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Room: ${session.roomId} | Partner: ${session.partnerId}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
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
