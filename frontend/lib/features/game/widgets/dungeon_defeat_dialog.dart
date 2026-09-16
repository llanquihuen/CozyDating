import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/games/character_preview_game.dart';
import 'package:flame/game.dart';

class DungeonDefeatDialog extends StatefulWidget {
  final AvatarConfig localAvatar;
  final AvatarConfig? partnerAvatar;
  final String partnerName;
  final VoidCallback onProceedToCampfire;
  final int autoProceedSeconds;
  final String defeatTitle;
  final String? defeatSubtitle;

  const DungeonDefeatDialog({
    super.key,
    required this.localAvatar,
    this.partnerAvatar,
    required this.partnerName,
    required this.onProceedToCampfire,
    this.autoProceedSeconds = 8,
    this.defeatTitle = '¡SE APAGÓ LA LINTERNA!',
    this.defeatSubtitle,
  });

  @override
  State<DungeonDefeatDialog> createState() => _DungeonDefeatDialogState();
}

class _DungeonDefeatDialogState extends State<DungeonDefeatDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late int _secondsLeft;
  Timer? _countdownTimer;
  bool _hasProceeded = false;

  @override
  void initState() {
    super.initState();
    _secondsLeft = widget.autoProceedSeconds;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 1) {
          _secondsLeft--;
        } else {
          _secondsLeft = 0;
          timer.cancel();
          _proceed();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _proceed() {
    if (_hasProceeded) return;
    _hasProceeded = true;
    _countdownTimer?.cancel();
    widget.onProceedToCampfire();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2A1C24),
                Color(0xFF1C131E),
                Color(0xFF0F0A14),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.deepOrangeAccent.withValues(alpha: 0.7), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withValues(alpha: 0.25),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Lantern / Moon Badge Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.deepOrange.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.deepOrangeAccent, width: 2),
                ),
                child: const Icon(
                  Icons.nightlight_round,
                  color: Colors.deepOrangeAccent,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                widget.defeatTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.deepOrangeAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.defeatSubtitle ?? 'El laberinto se cerró por hoy con ${widget.partnerName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),

              // Avatars Preview Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatarCircle(widget.localAvatar),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 28),
                  ),
                  if (widget.partnerAvatar != null)
                    _buildAvatarCircle(widget.partnerAvatar!),
                ],
              ),
              const SizedBox(height: 18),

              // Description
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: const Text(
                  'El tiempo de la expedición se ha terminado, pero cuidaron el uno del otro. Vamos al calor de la fogata a charlar de lo ocurrido y relajarse.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Coins Consolation Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                    SizedBox(width: 6),
                    Text(
                      '+50 monedas de consuelo',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Button: Continue to Campfire with countdown
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: const Color(0xFFF97316).withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _proceed,
                  icon: const Icon(Icons.local_fire_department, size: 22),
                  label: Text(
                    'Ir a la Fogata 🔥 (${_secondsLeft}s)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildAvatarCircle(AvatarConfig config) {
    return Container(
      width: 70,
      height: 85,
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A1C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GameWidget(
          key: ValueKey('defeat_avatar_${config.hashCode}'),
          game: CharacterPreviewGame(
            config: config,
            initialFaceZoom: false,
          ),
        ),
      ),
    );
  }
}
