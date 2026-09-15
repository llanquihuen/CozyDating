import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';

class DoubleBlindVoteView extends StatefulWidget {
  final UserProfile partnerUser;
  final String partnerName;
  final ValueChanged<bool> onVoteSubmitted;

  const DoubleBlindVoteView({
    super.key,
    required this.partnerUser,
    required this.partnerName,
    required this.onVoteSubmitted,
  });

  @override
  State<DoubleBlindVoteView> createState() => _DoubleBlindVoteViewState();
}

class _DoubleBlindVoteViewState extends State<DoubleBlindVoteView> {
  bool? _selectedVote;
  bool _isSubmitting = false;

  void _submitVote(bool wantsMatch) {
    if (_isSubmitting) return;
    setState(() {
      _selectedVote = wantsMatch;
      _isSubmitting = true;
    });
    widget.onVoteSubmitted(wantsMatch);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF131520),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE11D48).withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE11D48)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔒', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 6),
                  Text(
                    'VOTACIÓN A CIEGAS',
                    style: TextStyle(
                      color: Color(0xFFFDA4AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Question Title
            Text(
              '¿Te gustaría conectar con ${widget.partnerName}?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 10),

            // Explanation
            const Text(
              'Tu elección es 100% secreta. Solo si ambas personas eligen conectar, se revelarán sus perfiles completos con fotos y se habilitará el chat privado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            if (_isSubmitting) ...[
              const CircularProgressIndicator(color: Color(0xFFE11D48)),
              const SizedBox(height: 14),
              Text(
                _selectedVote == true
                  ? 'Esperando la decisión de ${widget.partnerName}...'
                  : 'Guardando tu decisión...',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
            ] else ...[
              // Option 1: YES! Match!
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () => _submitVote(true),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('💖', style: TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Text(
                        '¡Quiero conectar!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Option 2: Polite Pass
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => _submitVote(false),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🌱', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        'Seguir mi camino',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
