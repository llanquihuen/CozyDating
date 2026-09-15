import 'dart:async' as async;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import 'bloc/game_bloc.dart';
import 'guide_dungeon_game.dart';
import 'services/dungeon_generator.dart';
import 'widgets/dungeon_escape_countdown_banner.dart';
import 'widgets/dungeon_mission_hud.dart';
import 'widgets/emote_wheel_widget.dart';
import 'screens/role_swap_cinematic_view.dart';

class GuideGameView extends StatefulWidget {
  final ActiveGameState state;

  const GuideGameView({super.key, required this.state});

  @override
  State<GuideGameView> createState() => _GuideGameViewState();
}

class _GuideGameViewState extends State<GuideGameView> with SingleTickerProviderStateMixin {
  late GuideDungeonGame _guideGame;
  int? _lastHandledDisarmTrigger;
  int? _lastHandledGateTrigger;
  int? _lastHandledEmoteTrigger;
  int? _lastHandledSpikeAlertTrigger;
  int? _lastHandledRescueTrigger;
  bool _showSpikeAlert = false;
  async.Timer? _spikeAlertTimer;
  bool _isShowingRoleSwapDialog = false;

  bool _hasDrawnFirstStroke = false;
  bool _isMapLoaded = false;
  late AnimationController _handAnimController;
  late Animation<double> _handOpacityAnimation;

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

    // Floating hand hint runs for 2 seconds then self-dismisses once map is loaded
    _handAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _handOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
    ]).animate(_handAnimController);

    _guideGame = GuideDungeonGame(
      dungeonMapData: DungeonGenerator.generateMap(
        seed: sharedSeed,
        act: widget.state.session.act,
      ),
      explorerAvatarConfig: partnerAvatar,
      onMapLoaded: _onMapLoaded,
      onPingTap: (pingPos) {
        if (!mounted) return;
        if (!_hasDrawnFirstStroke) {
          _handAnimController.stop();
          setState(() => _hasDrawnFirstStroke = true);
        }
        context.read<GameBloc>().add(SendPingEvent(pingPos.x, pingPos.y));
      },
    );

    if (_guideGame.isMapLoaded) {
      _onMapLoaded();
    }
  }

  void _onMapLoaded() {
    if (!mounted || _isMapLoaded) return;
    setState(() {
      _isMapLoaded = true;
    });
    if (!_hasDrawnFirstStroke) {
      _handAnimController.forward().then((_) {
        if (mounted && !_hasDrawnFirstStroke) {
          setState(() => _hasDrawnFirstStroke = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _handAnimController.dispose();
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
    final secretRunes = _guideGame.dungeonMapData?.secretRuneSequence ?? const ['SOL', 'MOON', 'SNAKE'];

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
          if (state.pitfallRescueTrigger != null && state.pitfallRescueTrigger != _lastHandledRescueTrigger) {
            _lastHandledRescueTrigger = state.pitfallRescueTrigger;
            if (state.rescuedPitfallPos != null) {
              _guideGame.rescueExplorerFromPitfall(state.rescuedPitfallPos!);
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

                // 3. Floating Emote Wheel (repositioned higher on the right, aligned with action buttons)
                Positioned(
                  bottom: 118,
                  right: 16,
                  child: EmoteWheelWidget(
                    onEmoteSelected: (emote) {
                      _guideGame.showFloatingEmote(emote);
                      context.read<GameBloc>().add(SendEmoteEvent(emote));
                    },
                  ),
                ),

                // 4. Floating Hand Drawing Hint (appears only after map is loaded, non-blocking)
                if (_isMapLoaded && !_hasDrawnFirstStroke)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _buildFloatingHandDrawingHint(),
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

                // 6. Tactical Controls & Secret Combination Banner (bottom center)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Guide Warning Notice for Traps marked with X
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF200505).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFF1744).withValues(alpha: 0.75), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF1744).withValues(alpha: 0.20),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.close_rounded, color: Color(0xFFFF1744), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Avisa al explorador las trampas marcadas con X',
                                style: TextStyle(
                                  color: Color(0xFFFFCDD2),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Tactical Action Buttons (under the map on the left)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          backgroundColor: const Color(0xFF0D9488),
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: Colors.tealAccent, width: 1),
                          ),
                        ),
                        onPressed: () {
                          _guideGame.disarmAllTraps();
                          context.read<GameBloc>().add(const SendDisarmTrapsEvent());
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('🛡️ ¡Trampas desactivadas por 5 segundos!'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        },
                        icon: const Icon(Icons.shield, size: 16),
                        label: const Text(
                          'Desarmar Púas (5s)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Dedicated Rescue Button (activates when partner is trapped in pitfall)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: widget.state.trappedPitfallPos != null
                              ? [
                                  BoxShadow(
                                    color: Colors.orangeAccent.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            backgroundColor: widget.state.trappedPitfallPos != null
                                ? const Color(0xFFEA580C)
                                : Colors.white.withValues(alpha: 0.08),
                            foregroundColor: widget.state.trappedPitfallPos != null
                                ? Colors.white
                                : Colors.white38,
                            disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
                            disabledForegroundColor: Colors.white30,
                            elevation: widget.state.trappedPitfallPos != null ? 4 : 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: widget.state.trappedPitfallPos != null
                                    ? Colors.amberAccent
                                    : Colors.white24,
                                width: widget.state.trappedPitfallPos != null ? 1.5 : 1.0,
                              ),
                            ),
                          ),
                          onPressed: widget.state.trappedPitfallPos != null
                              ? () {
                                  final trapPos = widget.state.trappedPitfallPos;
                                  if (trapPos != null) {
                                    _guideGame.rescueExplorerFromPitfall(trapPos);
                                    context.read<GameBloc>().add(SendPitfallRescueEvent(trapPos.x, trapPos.y));
                                  }
                                }
                              : null,
                          icon: Icon(
                            Icons.handshake_outlined,
                            size: 16,
                            color: widget.state.trappedPitfallPos != null
                                ? Colors.amberAccent
                                : Colors.white30,
                          ),
                          label: Text(
                            'TOCA AQUÍ PARA RESCATAR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                              color: widget.state.trappedPitfallPos != null
                                  ? Colors.white
                                  : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Intuitive Secret Rune Combination Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18122B).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.7), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.amberAccent.withValues(alpha: 0.15),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'ORDEN SECRETO DE LAS RUNAS (Comunícalo a tu cita)',
                                  style: TextStyle(
                                    color: Colors.amberAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (int i = 0; i < secretRunes.length; i++) ...[
                                    if (i > 0)
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.arrow_forward, color: Colors.amber, size: 14),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2C1E4A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${i + 1}º ',
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            DungeonGenerator.getRuneLabel(secretRunes[i]),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildFloatingHandDrawingHint() {
    return AnimatedBuilder(
      animation: _handAnimController,
      builder: (context, child) {
        final progress = _handAnimController.value;
        final opacity = _handOpacityAnimation.value.clamp(0.0, 1.0);

        return Opacity(
          opacity: opacity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              final center = Offset(size.width / 2, size.height / 2 - 20);
              final tip = center + _getTrailPoint(progress);

              return Stack(
                children: [
                  // Animated neon trail being drawn across the maze
                  CustomPaint(
                    size: size,
                    painter: _HandDrawingTrailPainter(progress: progress, center: center),
                  ),
                  // Floating hand holding touch/drawing pose
                  Positioned(
                    left: tip.dx - 14,
                    top: tip.dy - 18,
                    child: Transform.rotate(
                      angle: -0.22,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.cyanAccent.withValues(alpha: 0.65),
                              blurRadius: 16,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.touch_app,
                          color: Colors.cyanAccent,
                          size: 40,
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

  static Offset _getTrailPoint(double t) {
    final p0 = const Offset(-80, 25);
    final p1 = const Offset(-30, -50);
    final p2 = const Offset(30, 45);
    final p3 = const Offset(80, -25);

    final oneMinusT = 1.0 - t;
    final b0 = oneMinusT * oneMinusT * oneMinusT;
    final b1 = 3 * oneMinusT * oneMinusT * t;
    final b2 = 3 * oneMinusT * t * t;
    final b3 = t * t * t;

    return Offset(
      b0 * p0.dx + b1 * p1.dx + b2 * p2.dx + b3 * p3.dx,
      b0 * p0.dy + b1 * p1.dy + b2 * p2.dy + b3 * p3.dy,
    );
  }
}

class _HandDrawingTrailPainter extends CustomPainter {
  final double progress;
  final Offset center;

  _HandDrawingTrailPainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02) return;

    final path = Path();
    const steps = 60;
    final maxStep = (steps * progress.clamp(0.0, 1.0)).toInt();

    if (maxStep < 2) return;

    final firstPt = center + _GuideGameViewState._getTrailPoint(0.0);
    path.moveTo(firstPt.dx, firstPt.dy);

    for (int i = 1; i <= maxStep; i++) {
      final t = i / steps;
      final pt = center + _GuideGameViewState._getTrailPoint(t);
      path.lineTo(pt.dx, pt.dy);
    }

    // Outer neon glow
    final glowPaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.45)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    canvas.drawPath(path, glowPaint);

    // Inner bright neon line
    final corePaint = Paint()
      ..color = Colors.cyanAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, corePaint);

    // Tip glow dot
    final tip = center + _GuideGameViewState._getTrailPoint(progress.clamp(0.0, 1.0));
    final dotGlow = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawCircle(tip, 8, dotGlow);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tip, 4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _HandDrawingTrailPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.center != center;
  }
}
