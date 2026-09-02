import 'package:flutter/material.dart';

/// Top App Bar containing the unified mission state:
/// - Role pill (Guide / Explorer)
/// - 3 Rune Sockets
/// - Portal countdown timer
/// - Key status indicator
/// - Exit button
///
/// Has a strictly fixed height (56px) so the dungeon canvas never jumps or resizes.
class DungeonMissionHud extends StatelessWidget implements PreferredSizeWidget {
  final bool isGuide;
  final List<String> targetRuneSequence;
  final int currentActivatedCount;
  final int portalSecondsRemaining;
  final bool hasKey;
  final VoidCallback? onExitPressed;

  const DungeonMissionHud({
    super.key,
    required this.isGuide,
    required this.targetRuneSequence,
    required this.currentActivatedCount,
    required this.portalSecondsRemaining,
    this.hasKey = false,
    this.onExitPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56.0);

  String _getRuneIcon(String rune) {
    switch (rune.toUpperCase()) {
      case 'SOL':
        return '☀️';
      case 'MOON':
        return '🌙';
      case 'SNAKE':
        return '🐍';
      case 'LIGHTNING':
        return '⚡';
      default:
        return '✨';
    }
  }

  Color _getRuneColor(String rune) {
    switch (rune.toUpperCase()) {
      case 'SOL':
        return Colors.amber;
      case 'MOON':
        return Colors.indigoAccent;
      case 'SNAKE':
        return Colors.greenAccent;
      case 'LIGHTNING':
        return Colors.cyanAccent;
      default:
        return Colors.amberAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final runes = targetRuneSequence.isNotEmpty
        ? targetRuneSequence
        : const ['SOL', 'MOON', 'SNAKE'];

    return Container(
      color: const Color(0xFF121212),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGuide
                        ? Colors.teal.withOpacity(0.2)
                        : Colors.deepOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGuide ? Colors.tealAccent : Colors.deepOrangeAccent,
                    ),
                  ),
                  child: Text(
                    isGuide ? '🧭 GUÍA' : '🔦 EXPLORADOR',
                    style: TextStyle(
                      color: isGuide ? Colors.tealAccent : Colors.deepOrangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const Spacer(),

                // 3 Rune Sockets
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(runes.length, (index) {
                    final rune = runes[index];
                    final isUnlocked = index < currentActivatedCount;
                    final showRune = isGuide || isUnlocked;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: isUnlocked
                            ? Colors.amber.withOpacity(0.25)
                            : Colors.white.withOpacity(0.06),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isUnlocked
                              ? Colors.amberAccent
                              : (showRune ? _getRuneColor(rune).withOpacity(0.6) : Colors.white24),
                          width: isUnlocked ? 2.0 : 1.0,
                        ),
                        boxShadow: isUnlocked
                            ? [
                                BoxShadow(
                                  color: Colors.amberAccent.withOpacity(0.4),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          showRune ? _getRuneIcon(rune) : '?',
                          style: TextStyle(
                            fontSize: showRune ? 16 : 14,
                            color: isUnlocked
                                ? Colors.amberAccent
                                : (showRune ? Colors.white : Colors.white38),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }),
                ),

                // Portal Countdown (if open)
                if (portalSecondsRemaining > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (portalSecondsRemaining <= 4 ? Colors.redAccent : Colors.cyan)
                          .withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: portalSecondsRemaining <= 4 ? Colors.redAccent : Colors.cyanAccent,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: portalSecondsRemaining <= 4 ? Colors.redAccent : Colors.cyanAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${portalSecondsRemaining}s',
                          style: TextStyle(
                            color: portalSecondsRemaining <= 4 ? Colors.redAccent : Colors.cyanAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Spacer(),

                // Key indicator (if not guide)
                if (!isGuide && hasKey)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amberAccent),
                    ),
                    child: const Text('🔑', style: TextStyle(fontSize: 12)),
                  ),

                // Close button
                if (onExitPressed != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.redAccent, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Salir',
                    onPressed: onExitPressed,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating tactical notification that renders directly OVER (por sobre) the canvas
/// without resizing or shifting the game map layout.
class DungeonAlertOverlay extends StatelessWidget {
  final bool isGuide;
  final bool isTrapped;
  final bool showSpikeAlert;
  final VoidCallback? onRescuePressed;

  const DungeonAlertOverlay({
    super.key,
    required this.isGuide,
    this.isTrapped = false,
    this.showSpikeAlert = false,
    this.onRescuePressed,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTrapped && !showSpikeAlert) {
      return const SizedBox.shrink();
    }

    if (isTrapped) {
      if (isGuide) {
        return GestureDetector(
          onTap: onRescuePressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade900, Colors.amber.shade900],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amberAccent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.45),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handshake_outlined, color: Colors.amberAccent, size: 20),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '🪢 ¡Compañero atrapado! TOCA AQUÍ PARA RESCATAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orangeAccent, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
              SizedBox(width: 8),
              Text(
                '¡Atrapado en una grieta! Esperando auxilio del Guía...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }
    }

    if (showSpikeAlert) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.redAccent.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              isGuide
                  ? '⚠️ ¡Compañero herido por púas! Usa tu escudo abajo.'
                  : '⚠️ ¡Púas detectadas! Espera que el Guía las desactive.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
