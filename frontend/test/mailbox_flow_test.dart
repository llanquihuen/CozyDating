import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/mailbox/models/mailbox_models.dart';
import 'package:frontend/features/mailbox/screens/mailbox_screen.dart';
import 'package:frontend/features/mailbox/services/mailbox_service.dart';

void main() {
  group('Mailbox Models & Flow Widget Tests', () {
    test('MailboxLetter parsing and status mapping', () {
      final map = {
        'id': 'letter_test_1',
        'partnerId': 'partner_123',
        'partnerName': 'Elena',
        'partnerPhoto': 'https://example.com/photo.jpg',
        'partnerAge': 24,
        'partnerCommune': 'Providencia',
        'commonTastes': '["game_coop","life_coffee_tea"]',
        'myDecision': 'KEEP_IN_TOUCH',
        'myNote': '¡Gran partida!',
        'partnerNote': '¡Me encantó!',
        'isMutualMatch': true,
        'createdAt': '2026-09-03T01:00:00.000Z',
      };

      final letter = MailboxLetter.fromMap(map);

      expect(letter.id, equals('letter_test_1'));
      expect(letter.partnerName, equals('Elena'));
      expect(letter.partnerPhoto, equals('https://example.com/photo.jpg'));
      expect(letter.partnerAge, equals(24));
      expect(letter.myDecision, equals(MailboxDecision.keepInTouch));
      expect(letter.isMutualMatch, isTrue);
      expect(letter.commonTastes.length, equals(2));
    });

    testWidgets('MailboxScreen renders pending letters and tabs', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed a pending letter
      MailboxService.addDateLetter(
        MailboxLetter(
          id: 'test_date_1',
          partnerId: 'user_bob',
          partnerName: 'Bob',
          partnerAvatar: const AvatarConfig(),
          partnerPhoto: 'https://example.com/bob.jpg',
          partnerAge: 26,
          partnerCommune: 'Santiago',
          commonTastes: const ['game_coop', 'cinema_ghibli'],
          myDecision: MailboxDecision.pending,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MailboxScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and tabs
      expect(find.text('Buzón de Recuerdos'), findsOneWidget);
      expect(find.textContaining('Nuevas'), findsOneWidget);
      expect(find.textContaining('Mutuas'), findsOneWidget);
      expect(find.text('📜 Baúl'), findsOneWidget);

      // Verify pending letter details
      expect(find.text('Carta de la Fogata'), findsOneWidget);
      expect(find.text('Bob, 26'), findsOneWidget);
      expect(find.text('📍 Santiago'), findsOneWidget);

      // Verify decision buttons
      final keepInTouchFinder = find.text('💌 Seguir en contacto');
      expect(keepInTouchFinder, findsOneWidget);
      expect(find.text('🕊️ Guardar recuerdo'), findsOneWidget);

      // Ensure visible and tap
      await tester.ensureVisible(keepInTouchFinder);
      await tester.pumpAndSettle();
      await tester.tap(keepInTouchFinder);
      await tester.pumpAndSettle();

      // Unread count should update to 0
      expect(MailboxService.unreadLettersCount.value, equals(0));
    });
  });
}
