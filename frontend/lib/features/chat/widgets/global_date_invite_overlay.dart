import 'package:flutter/material.dart';
import '../../../core/models/avatar_config.dart';
import '../services/chat_service.dart';
import '../../mailbox/models/mailbox_models.dart';

/// Global overlay widget that listens to incoming date invites and shows
/// a persistent top banner/modal across ANY screen in the app.
class GlobalDateInviteOverlay extends StatelessWidget {
  final Widget child;

  const GlobalDateInviteOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        ValueListenableBuilder<Map<String, dynamic>?>(
          valueListenable: ChatService.incomingDateInviteNotifier,
          builder: (context, invite, _) {
            if (invite == null) return const SizedBox.shrink();

            final inviterName = invite['inviterName'] as String? ?? 'Tu Compañero';
            final title = invite['title'] as String? ?? 'Cita Especial';
            final dateType = invite['dateType'] as String? ?? 'CRYPT';
            final matchId = invite['matchId'] as String? ?? '';
            final fromUserId = invite['fromUserId'] as String? ?? '';

            String icon = '💌';
            if (dateType == 'CAMPFIRE') icon = '🔥';
            if (dateType == 'HOME') icon = '🏠';
            if (dateType == 'CRYPT') icon = '🗡️';

            return Material(
              color: Colors.black54,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF231F33),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFB300), width: 1.8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB300).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFB300).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Text(icon, style: const TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '¡Invitación a Cita de $inviterName!',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '¿Deseas aceptar e iniciar la cita ahora?',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            // Reject Button
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent.shade100,
                                  side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  ChatService.dismissDateInvite(matchId, partnerId: fromUserId);
                                },
                                child: const Text(
                                  'Rechazar',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Accept Button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6D00),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () {
                                  // Create dummy letter payload to fulfill acceptDateInvite
                                  final dummyLetter = MailboxLetter(
                                    id: matchId,
                                    partnerId: fromUserId,
                                    partnerName: inviterName,
                                    partnerAvatar: const AvatarConfig(),
                                    myDecision: MailboxDecision.keepInTouch,
                                    isMutualMatch: true,
                                    createdAt: DateTime.now(),
                                  );

                                  ChatService.acceptDateInvite(
                                    letter: dummyLetter,
                                    dateType: dateType,
                                    title: title,
                                  );

                                  // Pop all stacked routes back to root so the game/lobby launches cleanly
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                },
                                icon: const Icon(Icons.check_circle_outline, size: 16),
                                label: const Text(
                                  'Aceptar y Entrar',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
