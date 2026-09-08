import 'package:flutter/material.dart';

/// Modal bottom sheet that presents options for a new date invitation
Future<void> showDateInviteSheet(
  BuildContext context, {
  required String partnerName,
  required void Function(String dateType, String title) onSelect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1B2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('⚔️', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(
                  'Nueva Cita con $partnerName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Elige la experiencia que te gustaría compartir:',
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
            ),
            const SizedBox(height: 18),

            // Option 1: Crypt expedition
            _buildDateOptionTile(
              icon: '🗡️',
              title: 'Expedición en la Cripta',
              subtitle: 'Explorador y Guía superando trampas y acertijos juntos.',
              onTap: () {
                Navigator.of(ctx).pop();
                onSelect('CRYPT', 'Expedición en la Cripta 🗡️');
              },
            ),
            const SizedBox(height: 10),

            // Option 2: Direct Campfire Round 2
            _buildDateOptionTile(
              icon: '🔥',
              title: 'Fogata de Conexión (Nivel 2)',
              subtitle: 'Saltar directo a la fogata con preguntas más íntimas y profundas.',
              onTap: () {
                Navigator.of(ctx).pop();
                onSelect('CAMPFIRE', 'Fogata de Conexión Profunda 🔥');
              },
            ),
            const SizedBox(height: 10),

            // Option 3: Visit home
            _buildDateOptionTile(
              icon: '🏠',
              title: 'Visitar mi Hogar',
              subtitle: 'Compartir un té virtual en tu habitación decorada.',
              onTap: () {
                Navigator.of(ctx).pop();
                onSelect('HOME', 'Visita al Hogar ☕');
              },
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildDateOptionTile({
  required String icon,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF28243A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white30, size: 14),
        ],
      ),
    ),
  );
}
