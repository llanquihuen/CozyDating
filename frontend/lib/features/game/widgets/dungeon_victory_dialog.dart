import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../../avatar/games/character_preview_game.dart';
import 'package:flame/game.dart';

class DungeonVictoryDialog extends StatefulWidget {
  final AvatarConfig localAvatar;
  final AvatarConfig? partnerAvatar;
  final String partnerName;
  final VoidCallback onProceedToCampfire;

  const DungeonVictoryDialog({
    super.key,
    required this.localAvatar,
    this.partnerAvatar,
    required this.partnerName,
    required this.onProceedToCampfire,
  });

  @override
  State<DungeonVictoryDialog> createState() => _DungeonVictoryDialogState();
}

class _DungeonVictoryDialogState extends State<DungeonVictoryDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
                Color(0xFF2C1E4A),
                Color(0xFF18122B),
                Color(0xFF0F0A1C),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.8), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 28,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy / Badge Icon
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.amber.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.amberAccent, width: 2),
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: Colors.amberAccent,
                  size: 42,
                ),
              ),
              const SizedBox(height: 16),

              // Victory Title
              const Text(
                '¡MAZMORRA CONQUISTADA!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '¡Gran trabajo en equipo con ${widget.partnerName}!',
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
                  // Local Avatar
                  _buildAvatarCircle(widget.localAvatar),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.handshake, color: Colors.pinkAccent, size: 28),
                  ),
                  // Partner Avatar
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
                  'Superaron las trampas, descifraron las runas y cruzaron el portal juntos. Ha llegado la hora de relajarse y conocerse mejor.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Coins Bonus Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                      '+100 monedas de expedición',
                      style: TextStyle(
                        color: Colors.amberAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Big Action Button: Continue to Campfire
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
                  onPressed: widget.onProceedToCampfire,
                  icon: const Icon(Icons.local_fire_department, size: 22),
                  label: const Text(
                    'Descansar en la Fogata 🔥',
                    style: TextStyle(
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
          key: ValueKey('victory_avatar_${config.hashCode}'),
          game: CharacterPreviewGame(
            config: config,
            initialFaceZoom: false,
          ),
        ),
      ),
    );
  }
}
