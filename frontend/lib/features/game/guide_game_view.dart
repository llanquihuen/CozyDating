import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/game_bloc.dart';
import 'guide_dungeon_game.dart';
import 'services/dungeon_generator.dart';

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

  @override
  void initState() {
    super.initState();
    // Use roomId.hashCode as deterministic seed so Guide and Explorer share identical map & puzzle sequence
    final sharedSeed = widget.state.session.roomId.hashCode;
    _guideGame = GuideDungeonGame(
      dungeonMapData: DungeonGenerator.generateMap(
        seed: sharedSeed,
        act: widget.state.session.act,
      ),
      onPingTap: (pingPos) {
        if (!mounted) return;
        context.read<GameBloc>().add(SendPingEvent(pingPos.x, pingPos.y));
      },
    );
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
            _guideGame.updateExplorerRemotePosition(Vector2(ds.playerX, ds.playerY));
          }
          if (state.trapsDisarmedTrigger != null && state.trapsDisarmedTrigger != _lastHandledDisarmTrigger) {
            _lastHandledDisarmTrigger = state.trapsDisarmedTrigger;
            _guideGame.disarmAllTraps();
          }
          if (state.runeGateUnlockedTrigger != null && state.runeGateUnlockedTrigger != _lastHandledGateTrigger) {
            _lastHandledGateTrigger = state.runeGateUnlockedTrigger;
            _guideGame.unlockRuneGate();
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          backgroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.teal.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.tealAccent),
            ),
            child: const Text(
              'GUIDE CONSOLE',
              style: TextStyle(
                color: Colors.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
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
            // 1. Fully Illuminated Guide Map Canvas
            Positioned.fill(
              child: GameWidget(
                game: _guideGame,
              ),
            ),

            // 2. Tactical Controls & Secret Combination Banner (bottom center)
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
      ),
    );
  }
}
