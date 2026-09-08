import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/services/avatar_storage_service.dart';
import 'package:frontend/features/chat/models/chat_message.dart';
import 'package:frontend/features/chat/screens/private_chat_screen.dart';
import 'package:frontend/features/chat/services/chat_service.dart';
import 'package:frontend/features/chat/widgets/global_date_invite_overlay.dart';
import 'package:frontend/features/mailbox/models/mailbox_models.dart';
import 'package:frontend/features/mailbox/screens/mailbox_screen.dart';
import 'package:frontend/features/mailbox/services/mailbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Post-Campfire Coins, Mailbox and Private Chat Tests', () {
    const testUser = UserProfile(
      id: 'test_player',
      username: 'Player1',
      coinsBalance: 100,
    );

    test('Coins accrual updates AvatarStorageService balance correctly', () {
      final initialCoins = AvatarStorageService.getUserCoins(testUser.id);
      AvatarStorageService.addCoins(testUser.id, 150);
      final updatedCoins = AvatarStorageService.getUserCoins(testUser.id);

      expect(updatedCoins, equals(initialCoins + 150));
    });

    test('MailboxService receives date letter and increments unread count', () {
      final initialBadge = MailboxService.unreadLettersCount.value;

      final letter = MailboxLetter(
        id: 'date_test_123',
        partnerId: 'sofia_partner',
        partnerName: 'Sofía',
        partnerAvatar: const AvatarConfig(),
        partnerAge: 23,
        partnerCommune: 'Providencia',
        commonTastes: const ['game_coop', 'intent_slow'],
        myDecision: MailboxDecision.pending,
        createdAt: DateTime.now(),
      );

      MailboxService.addDateLetter(letter);

      expect(MailboxService.unreadLettersCount.value, equals(initialBadge + 1));
    });

    testWidgets('PrivateChatScreen renders partner header, initial notes and sends messages', (tester) async {
      final mutualLetter = MailboxLetter(
        id: 'match_chat_test',
        partnerId: 'matias_partner',
        partnerName: 'Matías',
        partnerAvatar: const AvatarConfig(),
        partnerAge: 25,
        partnerCommune: 'Santiago',
        partnerNote: '¡Qué gran partida en la cripta! ☕',
        myNote: '¡Me divertí un montón!',
        isMutualMatch: true,
        myDecision: MailboxDecision.keepInTouch,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PrivateChatScreen(letter: mutualLetter),
        ),
      );

      // Verify header renders partner name and slow dating badge
      expect(find.text('Matías'), findsOneWidget);
      expect(find.textContaining('Slow Dating:'), findsOneWidget);

      // Verify pre-seeded notes rendered as chat messages
      expect(find.text('¡Qué gran partida en la cripta! ☕'), findsOneWidget);
      expect(find.text('¡Me divertí un montón!'), findsOneWidget);

      // Verify first icebreaker chip is available
      final icebreaker = find.textContaining('¡Hola! Me encantó');
      expect(icebreaker, findsOneWidget);

      // Tap icebreaker chip to send
      await tester.tap(icebreaker);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('¡Hola! Me encantó'), findsWidgets);

      // Wait for partner simulated reply timer to complete
      await tester.pump(const Duration(milliseconds: 1600));
    });

    testWidgets('MailboxScreen renders mutual match and Chat button', (tester) async {
      final mutualMatchLetter = MailboxLetter(
        id: 'date_mutual_view_test',
        partnerId: 'clara_partner',
        partnerName: 'Clara',
        partnerAvatar: const AvatarConfig(),
        partnerAge: 24,
        partnerCommune: 'Ñuñoa',
        partnerNote: 'Me encantó nuestra charla 🌸',
        isMutualMatch: true,
        myDecision: MailboxDecision.keepInTouch,
        createdAt: DateTime.now(),
      );

      MailboxService.addDateLetter(mutualMatchLetter);

      await tester.pumpWidget(
        const MaterialApp(
          home: MailboxScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Go to tab 2: Mutuas
      await tester.tap(find.textContaining('Mutuas'));
      await tester.pumpAndSettle();

      // Verify "Chatear" and "Invitar a Cita" buttons are present in mutual match card
      expect(find.text('Chatear'), findsOneWidget);
      expect(find.text('Invitar a Cita'), findsOneWidget);
    });

    testWidgets('PrivateChatScreen opens Date Invite dialog when Invitar a Cita button is pressed', (tester) async {
      final mutualLetter = MailboxLetter(
        id: 'match_date_invite_flow',
        partnerId: 'lucas_partner',
        partnerName: 'Lucas',
        partnerAvatar: const AvatarConfig(),
        partnerAge: 27,
        partnerCommune: 'Providencia',
        isMutualMatch: true,
        myDecision: MailboxDecision.keepInTouch,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PrivateChatScreen(letter: mutualLetter),
        ),
      );

      // Verify "Invitar a Cita" button is in AppBar
      final inviteBtn = find.text('Invitar a Cita');
      expect(inviteBtn, findsOneWidget);

      // Tap "Invitar a Cita"
      await tester.tap(inviteBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet modal opened with the 3 date options
      expect(find.textContaining('Nueva Cita con Lucas'), findsOneWidget);
      expect(find.text('Expedición en la Cripta'), findsOneWidget);
      expect(find.text('Fogata de Conexión (Nivel 2)'), findsOneWidget);
      expect(find.text('Visitar mi Hogar'), findsOneWidget);

      // Tap "Expedición en la Cripta"
      await tester.tap(find.text('Expedición en la Cripta'));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify active date invite banner is shown at top of chat (not cluttering messages)
      expect(find.textContaining('Expedición en la Cripta'), findsWidgets);
      expect(find.text('Invitación enviada'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('MailboxScreen Invitar a Cita button directly opens date options modal', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mutualLetter = MailboxLetter(
        id: 'match_direct_invite_test',
        partnerId: 'sofia_partner',
        partnerName: 'Sofía',
        partnerAvatar: const AvatarConfig(),
        partnerAge: 25,
        partnerCommune: 'Ñuñoa',
        isMutualMatch: true,
        myDecision: MailboxDecision.keepInTouch,
        createdAt: DateTime.now(),
      );

      MailboxService.addDateLetter(mutualLetter);

      await tester.pumpWidget(
        const MaterialApp(
          home: MailboxScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Go to tab 2: Mutuas
      await tester.tap(find.textContaining('Mutuas'));
      await tester.pumpAndSettle();

      // Tap "Invitar a Cita" on the first mutual match card
      final inviteBtn = find.text('Invitar a Cita').first;
      await tester.tap(inviteBtn);
      await tester.pumpAndSettle();

      // Verify the sheet opened directly with date options
      expect(find.textContaining('Nueva Cita con'), findsOneWidget);
      expect(find.text('Expedición en la Cripta'), findsOneWidget);
      expect(find.text('Fogata de Conexión (Nivel 2)'), findsOneWidget);
      expect(find.text('Visitar mi Hogar'), findsOneWidget);
    });

    testWidgets('GlobalDateInviteOverlay renders top banner on incoming invite and allows rejecting', (tester) async {
      ChatService.incomingDateInviteNotifier.value = null;

      await tester.pumpWidget(
        const MaterialApp(
          home: GlobalDateInviteOverlay(
            child: Scaffold(
              body: Center(child: Text('Cualquier Pantalla')),
            ),
          ),
        ),
      );

      expect(find.text('Cualquier Pantalla'), findsOneWidget);
      expect(find.textContaining('¡Invitación a Cita de'), findsNothing);

      // Simulate incoming invite from Bob
      ChatService.incomingDateInviteNotifier.value = {
        'matchId': 'match_global_123',
        'fromUserId': 'bob',
        'inviterName': 'Bob',
        'dateType': 'CAMPFIRE',
        'title': 'Fogata de Conexión Profunda 🔥',
      };
      await tester.pumpAndSettle();

      // Verify banner appears over the screen
      expect(find.textContaining('¡Invitación a Cita de Bob!'), findsOneWidget);
      expect(find.text('Fogata de Conexión Profunda 🔥'), findsOneWidget);
      expect(find.text('Aceptar y Entrar'), findsOneWidget);
      expect(find.text('Rechazar'), findsOneWidget);

      // Tap "Rechazar"
      await tester.tap(find.text('Rechazar'));
      await tester.pumpAndSettle();

      // Verify banner disappeared
      expect(ChatService.incomingDateInviteNotifier.value, isNull);
      expect(find.textContaining('¡Invitación a Cita de Bob!'), findsNothing);
    });
  });
}
