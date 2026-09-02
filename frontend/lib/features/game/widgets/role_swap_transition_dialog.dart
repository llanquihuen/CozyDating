import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/games/character_preview_game.dart';

class RoleSwapTransitionDialog extends StatefulWidget {
  final String newRole;
  final AvatarConfig? localAvatar;
  final AvatarConfig? partnerAvatar;
  final String partnerName;
  final VoidCallback onProceed;

  const RoleSwapTransitionDialog({
    super.key,
    required this.newRole,
    this.localAvatar,
    this.partnerAvatar,
    required this.partnerName,
    required this.onProceed,
  });

  @override
  State<RoleSwapTransitionDialog> createState() => _RoleSwapTransitionDialogState();
}

class _RoleSwapTransitionDialogState extends State<RoleSwapTransitionDialog> {
  int _secondsLeft = 4;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft -= 1;
        });
      } else {
        timer.cancel();
        widget.onProceed();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNowGuide = widget.newRole == 'GUIDE';

    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissing by back button
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E102F), Color(0xFF0F0B18)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amberAccent, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withOpacity(0.25),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mystic Icon Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amberAccent.withOpacity(0.15),
                  border: Border.all(color: Colors.amberAccent, width: 1.5),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.amberAccent,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title & Subtitle
              const Text(
                '✨ ¡Primer Desafío Superado!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'EL RELEVO: EL PUENTE DE LOS DOS MUNDOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 20),

              // Avatars facing each other
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatarSlot(widget.localAvatar, 'Tú'),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Icon(
                      Icons.sync_alt_rounded,
                      color: Colors.amberAccent.withOpacity(0.8),
                      size: 28,
                    ),
                  ),
                  _buildAvatarSlot(widget.partnerAvatar, widget.partnerName),
                ],
              ),
              const SizedBox(height: 20),

              // Role description card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isNowGuide ? Colors.tealAccent : Colors.deepOrangeAccent,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      isNowGuide ? '🧭 AHORA ERES EL GUÍA' : '🔦 AHORA ERES EL EXPLORADOR',
                      style: TextStyle(
                        color: isNowGuide ? Colors.tealAccent : Colors.deepOrangeAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isNowGuide
                          ? 'Tomas el mapa estelar para guiar a tu compañero y desactivar las trampas.'
                          : 'Tomas la linterna para avanzar por los pasadizos y activar los sellos.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Proceed Button with countdown
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () {
                    _countdownTimer?.cancel();
                    widget.onProceed();
                  },
                  child: Text(
                    '¡Comenzar Acto 2! ($_secondsLeft s)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarSlot(AvatarConfig? config, String label) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: config != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GameWidget(
                    game: CharacterPreviewGame(
                      config: config,
                      initialFaceZoom: false,
                    ),
                  ),
                )
              : const Center(
                  child: Icon(Icons.person, color: Colors.white54, size: 28),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
