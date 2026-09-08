import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/services/avatar_storage_service.dart';
import 'package:frontend/features/chat/models/chat_message.dart';
import 'package:frontend/features/chat/screens/private_chat_screen.dart';
import 'package:frontend/features/chat/services/chat_service.dart';
import 'package:frontend/features/mailbox/models/mailbox_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multiplayer Chat, Date Invites & Privacy Presence Tests', () {
    final testLetter = MailboxLetter(
      id: 'match_mp_test_1',
      partnerId: 'sofia_mp',
      partnerName: 'Sofía',
      partnerAvatar: const AvatarConfig(),
      partnerAge: 24,
      partnerCommune: 'Providencia',
      partnerNote: '¡Hola! Qué buena partida.',
      myNote: '¡Totalmente!',
      isMutualMatch: true,
      myDecision: MailboxDecision.keepInTouch,
      createdAt: DateTime.now(),
    );

    test('ChatService sends messages without simulated bot reply', () async {
      final notifier = ChatService.getConversationNotifier(testLetter);
      final initialCount = notifier.value.length;

      ChatService.sendMessage(
        letter: testLetter,
        text: 'Hola Sofía, ¿cómo estás?',
      );

      expect(notifier.value.length, equals(initialCount + 1));
      final lastMsg = notifier.value.last;
      expect(lastMsg.text, equals('Hola Sofía, ¿cómo estás?'));
      expect(lastMsg.isFromMe, isTrue);

      // Wait to ensure no bot timer replies
      await Future.delayed(const Duration(milliseconds: 1600));
      expect(notifier.value.length, equals(initialCount + 1));
    });

    test('Privacy Mode: toggles between ONLINE and INVISIBLE', () {
      const testUser = 'alice';
      expect(AvatarStorageService.getPresenceMode(testUser), equals('ONLINE'));

      ChatService.setPresenceMode('INVISIBLE');
      expect(AvatarStorageService.getPresenceMode(testUser), equals('INVISIBLE'));

      ChatService.setPresenceMode('ONLINE');
      expect(AvatarStorageService.getPresenceMode(testUser), equals('ONLINE'));
    });

    test('Presence status updates partnerPresenceNotifier dynamically', () {
      ChatService.partnerPresenceNotifier.value = {'sofia_mp': false};
      expect(ChatService.partnerPresenceNotifier.value['sofia_mp'], isFalse);

      // Simulate receiving online presence
      final updated = Map<String, bool>.from(ChatService.partnerPresenceNotifier.value);
      updated['sofia_mp'] = true;
      ChatService.partnerPresenceNotifier.value = updated;

      expect(ChatService.partnerPresenceNotifier.value['sofia_mp'], isTrue);
    });

    testWidgets('PrivateChatScreen shows dynamic presence (En línea vs Desconectado)', (tester) async {
      // Start with partner offline
      ChatService.partnerPresenceNotifier.value = {'sofia_mp': false};

      await tester.pumpWidget(
        MaterialApp(
          home: PrivateChatScreen(letter: testLetter),
        ),
      );

      // Header should display "Desconectado"
      expect(find.textContaining('Desconectado'), findsOneWidget);

      // Now update partner presence to online
      ChatService.partnerPresenceNotifier.value = {'sofia_mp': true};
      await tester.pump();

      // Header should now display "En línea"
      expect(find.textContaining('En línea'), findsOneWidget);
    });

    testWidgets('PrivateChatScreen renders active Date Invite banner with Accept button', (tester) async {
      ChatService.activeInvitesNotifier.value = {
        testLetter.id: {
          'inviteId': 'invite_mp_rec_1',
          'matchId': testLetter.id,
          'fromMe': false,
          'fromUserId': testLetter.partnerId,
          'inviterName': testLetter.partnerName,
          'dateType': 'CRYPT',
          'title': 'La Cripta de la Luna',
          'status': 'PENDING',
        }
      };

      await tester.pumpWidget(
        MaterialApp(
          home: PrivateChatScreen(letter: testLetter),
        ),
      );
      await tester.pump();

      // Partner invite banner should have "Aceptar y Jugar"
      expect(find.text('Aceptar y Jugar'), findsOneWidget);
    });
  });
}
