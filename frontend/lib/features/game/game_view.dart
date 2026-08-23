import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/game_models.dart';
import '../../../core/network/websocket_client.dart';
import 'bloc/game_bloc.dart';
import 'dungeon_game.dart';
import 'guide_game_view.dart';
import 'services/dungeon_generator.dart';
import 'widgets/dpad_widget.dart';
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

  Vector2? _lastExplorerPos;
  Vector2? _lastHandledPingPos;
  int? _lastHandledDisarmTrigger;
  int? _lastHandledGateTrigger;

  @override
  void initState() {
    super.initState();
    // Use deterministic shared seed from server or fallback to deterministic room hash
    final sharedSeed = widget.state.session.seed ??
        DungeonGenerator.deterministicStringSeed(widget.state.session.roomId);
    _dungeonGame = DungeonGame(
      dungeonMapData: DungeonGenerator.generateMap(
        seed: sharedSeed,
        act: widget.state.session.act,
      ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔑 Golden Key Collected! Head to the Exit Door!'),
            backgroundColor: Colors.amber,
          ),
        );
      },
      onRuneFeedback: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: message.contains('❌') ? Colors.red.shade900 : Colors.cyan.shade900,
            duration: const Duration(seconds: 2),
          ),
        );
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
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.deepOrangeAccent),
                ),
                child: const Text(
                  'EXPLORER',
                  style: TextStyle(
                    color: Colors.deepOrangeAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _hasKey ? Colors.amber.withOpacity(0.25) : Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _hasKey ? Colors.amber : Colors.white24),
                ),
                child: Text(
                  _hasKey ? '🔑 KEY HELD' : '🔑 NEED KEY',
                  style: TextStyle(
                    color: _hasKey ? Colors.amberAccent : Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.redAccent, size: 24),
              tooltip: 'Exit Game',
              onPressed: () => _showExitDialog(context),
            ),
          ],
        ),
        body: Stack(
          children: [
            // 1. Flame 2D Game Canvas
            Positioned.fill(
              child: GameWidget(
                game: _dungeonGame,
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

            // 3. Portal Open Countdown Banner (top center)
            Positioned(
              top: 16,
              left: 24,
              right: 24,
              child: ValueListenableBuilder<int>(
                valueListenable: _dungeonGame.portalRemainingSeconds,
                builder: (context, seconds, child) {
                  if (seconds <= 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: seconds <= 3 ? Colors.redAccent : Colors.cyanAccent,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (seconds <= 3 ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.35),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cyclone,
                          color: seconds <= 3 ? Colors.redAccent : Colors.cyanAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '¡PORTAL ABIERTO! Cierra en: ${seconds}s',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: seconds <= 3 ? Colors.redAccent : Colors.cyanAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
