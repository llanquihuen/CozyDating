import 'dart:async' as async;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../cinematics/role_swap_cinematic_game.dart';

class RoleSwapCinematicView extends StatefulWidget {
  final String newRole;
  final AvatarConfig localAvatarConfig;
  final AvatarConfig? partnerAvatarConfig;
  final String partnerName;
  final VoidCallback onProceed;

  const RoleSwapCinematicView({
    super.key,
    required this.newRole,
    required this.localAvatarConfig,
    this.partnerAvatarConfig,
    required this.partnerName,
    required this.onProceed,
  });

  @override
  State<RoleSwapCinematicView> createState() => _RoleSwapCinematicViewState();
}

class _RoleSwapCinematicViewState extends State<RoleSwapCinematicView> {
  late final RoleSwapCinematicGame _cinematicGame;
  int _secondsLeft = 8;
  async.Timer? _countdownTimer;
  bool _hasProceeded = false;

  @override
  void initState() {
    super.initState();

    final isNewExplorer = widget.newRole.toUpperCase() == 'EXPLORER';
    final localWasExplorer = !isNewExplorer;

    _cinematicGame = RoleSwapCinematicGame(
      localAvatarConfig: widget.localAvatarConfig,
      partnerAvatarConfig: widget.partnerAvatarConfig,
      localWasExplorer: localWasExplorer,
      onCinematicFinished: () {
        if (mounted && !_hasProceeded) {
          _proceed();
        }
      },
    );

    _countdownTimer = async.Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          timer.cancel();
          _proceed();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _proceed() {
    if (_hasProceeded) return;
    _hasProceeded = true;
    _countdownTimer?.cancel();
    widget.onProceed();
  }

  @override
  Widget build(BuildContext context) {
    final isNewExplorer = widget.newRole.toUpperCase() == 'EXPLORER';

    return WillPopScope(
      onWillPop: () async => false, // Prevent accidental back during cinematic
      child: Scaffold(
        backgroundColor: const Color(0xFF080811),
        body: SafeArea(
          child: Column(
            children: [
              // Top Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amberAccent),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'ACTO 2 • EL RELEVO',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Compañero: ${widget.partnerName}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Animated Flame Cinematic Canvas
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: (isNewExplorer ? Colors.deepOrangeAccent : Colors.tealAccent)
                            .withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GameWidget(
                    game: _cinematicGame,
                  ),
                ),
              ),

              // Bottom Narrative & Briefing Card
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Role Mission Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141724),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isNewExplorer
                                ? Colors.deepOrangeAccent.withOpacity(0.6)
                                : Colors.tealAccent.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isNewExplorer ? '🔦' : '🧭',
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isNewExplorer
                                      ? 'TU NUEVO ROL: EXPLORADOR'
                                      : 'TU NUEVO ROL: GUÍA DEL LABERINTO',
                                  style: TextStyle(
                                    color: isNewExplorer ? Colors.deepOrangeAccent : Colors.tealAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isNewExplorer
                                  ? 'Ahora tomas la linterna mágica. Adéntrate en el laberinto, sigue los destellos de tu compañero y pisa las runas secretas.'
                                  : 'Ahora tienes el mapa estelar. Ilumina el camino con toques mágicos, alerta a tu compañero de las púas y desactívalas a tiempo.',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Continue Action Button with countdown
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isNewExplorer ? Colors.deepOrange.shade800 : Colors.teal.shade800,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                          ),
                          onPressed: _proceed,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.play_arrow_rounded, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                'Entrar al Acto 2 (${_secondsLeft}s)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
