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
import 'widgets/dungeon_escape_countdown_banner.dart';
import 'widgets/dungeon_mission_hud.dart';
import 'widgets/emote_wheel_widget.dart';
import 'widgets/role_swap_transition_dialog.dart';
import 'screens/role_swap_cinematic_view.dart';
import '../campfire/screens/campfire_view.dart';
import 'dart:async';
import 'dart:math';

class GameView extends StatefulWidget {
  final ActiveGameState state;

  const GameView({super.key, required this.state});

  @override
  State<GameView> createState() => _GameViewState();
}

class _GameViewState extends State<GameView> with SingleTickerProviderStateMixin {
  late DungeonGame _dungeonGame;
  bool _hasKey = false;
  bool _isShowingRoleSwapDialog = false;

  late AnimationController _aimHandAnimController;
  late Animation<double> _aimHandOpacityAnimation;
  bool _hasAimedFlashlight = false;
  bool _isMapLoaded = false;

  Vector2? _lastExplorerPos;
  Vector2? _lastHandledPingPos;
  int? _lastHandledDisarmTrigger;
  int? _lastHandledGateTrigger;
  int? _lastHandledEmoteTrigger;
  int? _lastHandledRescueTrigger;

  @override
  void initState() {
    super.initState();

    // 360-degree flashlight hand tutorial animation runs for 2.6 seconds then self-dismisses once map is loaded
    _aimHandAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _aimHandOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 65,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
    ]).animate(_aimHandAnimController);

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
      onMapLoaded: _onMapLoaded,
      onSanctuaryReached: () {
        if (!mounted) return;
        context.read<GameBloc>().add(const SendSanctuaryReachedEvent());
      },
      onExplorerMoved: (pos) {
        if (!mounted) return;
        _dismissFlashlightHint();
        _lastExplorerPos = pos;
      },
      onExplorerMovedFull: (pos, dir, moving) {
        if (!mounted) return;
        _dismissFlashlightHint();
        _lastExplorerPos = pos;
        _sendDungeonState(direction: dir, isMoving: moving);
      },
      onFlashlightAim: _dismissFlashlightHint,
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

    if (_dungeonGame.isMapLoaded) {
      _onMapLoaded();
    }
  }

  void _onMapLoaded() {
    if (!mounted || _isMapLoaded) return;
    setState(() {
      _isMapLoaded = true;
    });
    if (!_hasAimedFlashlight) {
      _aimHandAnimController.forward().then((_) {
        if (mounted && !_hasAimedFlashlight) {
          setState(() => _hasAimedFlashlight = true);
        }
      });
    }
  }

  void _dismissFlashlightHint() {
    if (!_hasAimedFlashlight && mounted) {
      setState(() => _hasAimedFlashlight = true);
      _aimHandAnimController.stop();
    }
  }

  @override
  void dispose() {
    _aimHandAnimController.dispose();
    super.dispose();
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

                // 3b. Action Button: Tapar Trampa (activates when right before an unrepaired pitfall)
                Positioned(
                  bottom: 92,
                  right: 20,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _dungeonGame.canCoverTrap,
                    builder: (context, canCover, child) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: canCover
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFFB300).withValues(alpha: 0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: ElevatedButton.icon(
                          key: const ValueKey('cover_trap_button'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            backgroundColor: canCover
                                ? const Color(0xFF6D4C41)
                                : Colors.white.withValues(alpha: 0.08),
                            foregroundColor: canCover ? Colors.white : Colors.white38,
                            disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
                            disabledForegroundColor: Colors.white30,
                            elevation: canCover ? 4 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: canCover
                                    ? const Color(0xFFFFD54F)
                                    : Colors.white24,
                                width: canCover ? 1.8 : 1.0,
                              ),
                            ),
                          ),
                          onPressed: canCover
                              ? () {
                                  final pit = _dungeonGame.getNearbyCoverablePitfall();
                                  if (pit != null) {
                                    final trapPos = pit.position;
                                    if (_dungeonGame.coverNearbyPitfall()) {
                                      context.read<GameBloc>().add(
                                        SendPitfallRescueEvent(trapPos.x, trapPos.y),
                                      );
                                    }
                                  }
                                }
                              : null,
                          icon: Icon(
                            Icons.handyman_rounded,
                            size: 18,
                            color: canCover ? const Color(0xFFFFD54F) : Colors.white30,
                          ),
                          label: Text(
                            'TAPAR TRAMPA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: canCover ? Colors.white : Colors.white38,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 4. Floating Hand 360° Flashlight Hint (appears only after map is loaded, non-blocking)
                if (_isMapLoaded && !_hasAimedFlashlight)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildFloatingHandAimHint(),
                    ),
                  ),

                // 5. Giant 7-Segment Escape Countdown Clock ("00:15 - ¡HUYE! EL PORTAL SE CIERRA EN:")
                if (seconds > 0)
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Center(
                        child: DungeonEscapeCountdownBanner(
                          secondsRemaining: seconds,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFloatingHandAimHint() {
    return AnimatedBuilder(
      animation: _aimHandAnimController,
      builder: (context, child) {
        final progress = _aimHandAnimController.value;
        final opacity = _aimHandOpacityAnimation.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              // Center around explorer's canvas position or center of screen
              Offset center;
              if (_dungeonGame.isLoaded) {
                try {
                  final feetWorld = _dungeonGame.explorer.feetPosition;
                  final canvasPos = _dungeonGame.camera.viewfinder.localToGlobal(feetWorld);
                  center = Offset(canvasPos.x, canvasPos.y);
                } catch (_) {
                  center = Offset(size.width / 2, size.height / 2 - 30);
                }
              } else {
                center = Offset(size.width / 2, size.height / 2 - 30);
              }

              const double radius = 64.0;
              // Angle sweeps 360 degrees clockwise starting from top (-pi/2)
              final angle = -pi / 2 + (2 * pi * progress);
              final handPos = center + Offset(cos(angle) * radius, sin(angle) * radius);

              return Stack(
                children: [
                  // Glowing 360 flashlight trajectory arc
                  CustomPaint(
                    size: size,
                    painter: _Flashlight360ArcPainter(
                      progress: progress,
                      center: center,
                      radius: radius,
                    ),
                  ),
                  // Floating hand holding touch pose along the 360 circle
                  Positioned(
                    left: handPos.dx - 18,
                    top: handPos.dy - 20,
                    child: Transform.rotate(
                      angle: angle + pi / 4,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amberAccent.withValues(alpha: 0.75),
                              blurRadius: 18,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.touch_app,
                          color: Colors.amberAccent,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  // Informative badge
                  Positioned(
                    top: (center.dy + radius + 28).clamp(0.0, size.height - 60.0),
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rotate_right, color: Colors.amberAccent, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Toca o arrastra para girar la linterna en 360°',
                              style: TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _Flashlight360ArcPainter extends CustomPainter {
  final double progress;
  final Offset center;
  final double radius;

  _Flashlight360ArcPainter({
    required this.progress,
    required this.center,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Faint circular guide
    final guidePaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, guidePaint);

    if (progress <= 0.01) return;

    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // 2. Outer warm neon glow along the arc
    final glowPaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 9
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawArc(arcRect, -pi / 2, sweepAngle, false, glowPaint);

    // 3. Core bright gold arc line
    final corePaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;
    canvas.drawArc(arcRect, -pi / 2, sweepAngle, false, corePaint);
  }

  @override
  bool shouldRepaint(covariant _Flashlight360ArcPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.center != center;
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
