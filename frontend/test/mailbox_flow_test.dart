import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/mailbox/models/mailbox_models.dart';
import 'package:frontend/features/mailbox/screens/mailbox_screen.dart';
import 'package:frontend/features/mailbox/services/mailbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MailboxService.clear();
  });

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
      final romanceFinder = find.text('Chispa');
      expect(romanceFinder, findsOneWidget);
      expect(find.text('Amistad'), findsOneWidget);
      expect(find.text('Pasar'), findsOneWidget);

      // Ensure visible and tap
      await tester.ensureVisible(romanceFinder);
      await tester.pumpAndSettle();
      await tester.tap(romanceFinder);
      await tester.pumpAndSettle();

      // Unread count should update to 0
      expect(MailboxService.unreadLettersCount.value, equals(0));
    });

    testWidgets('Tapping "Ver perfil completo" on pending letter displays Cita en la Fogata instead of Conexión Mutua', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      MailboxService.addDateLetter(
        MailboxLetter(
          id: 'pending_sofia_1',
          partnerId: 'user_sofia',
          partnerName: 'Sofia',
          partnerAvatar: const AvatarConfig(),
          partnerPhoto: 'https://example.com/sofia1.jpg',
          partnerPhotos: const [
            'https://example.com/sofia1.jpg',
            'https://example.com/sofia2.jpg',
          ],
          partnerBio: 'Amante de los juegos y la música.',
          partnerIntent: 'Amistad y ver qué surge ✨',
          partnerAge: 23,
          partnerCommune: 'Providencia',
          commonTastes: const ['game_coop'],
          myDecision: MailboxDecision.pending,
          isMutualMatch: false,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MailboxScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify pending card shows Sofia and carousel
      expect(find.text('Carta de la Fogata'), findsOneWidget);
      expect(find.text('Sofia, 23'), findsOneWidget);
      final viewProfileBtn = find.text('Ver perfil y 2 fotos');
      expect(viewProfileBtn, findsOneWidget);

      // Tap to open full profile modal
      await tester.tap(viewProfileBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Header should show Cita en la Fogata / Decisión pendiente, NOT Conexión Mutua
      expect(find.text('CITA EN LA FOGATA'), findsOneWidget);
      expect(find.text('Decisión pendiente • Sofia'), findsOneWidget);
      expect(find.textContaining('Conexión Mutua'), findsNothing);

      // Actions should show 'Volver a tomar decisión', NOT 'Escribir a Sofia'
      expect(find.text('Volver a tomar decisión'), findsOneWidget);
      expect(find.text('Escribir a Sofia'), findsNothing);

      // Tap 'Volver a tomar decisión' to close modal
      await tester.tap(find.text('Volver a tomar decisión'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CITA EN LA FOGATA'), findsNothing);
    });

    testWidgets('Tapping a Mutual Match card opens full profile with all photos and bio', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed a mutual match with multiple photos
      MailboxService.addDateLetter(
        MailboxLetter(
          id: 'mutual_date_1',
          partnerId: 'user_claire',
          partnerName: 'Claire',
          partnerAvatar: const AvatarConfig(),
          partnerPhoto: 'https://example.com/claire1.jpg',
          partnerPhotos: const [
            'https://example.com/claire1.jpg',
            'https://example.com/claire2.jpg',
          ],
          partnerBio: 'Amante de la astronomía y el buen café.',
          partnerIntent: 'Citas con calma 🌱',
          partnerAge: 25,
          partnerCommune: 'Las Condes',
          commonTastes: const ['game_coop', 'nature_hiking'],
          myDecision: MailboxDecision.keepInTouch,
          isMutualMatch: true,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MailboxScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Mutuas tab
      final mutuasTab = find.textContaining('Mutuas');
      expect(mutuasTab, findsOneWidget);
      await tester.tap(mutuasTab);
      await tester.pumpAndSettle();

      // Verify mutual card displays Claire and photo badge
      expect(find.text('Claire'), findsOneWidget);
      expect(find.text('25 años • Las Condes'), findsOneWidget);
      expect(find.text('2 fotos'), findsOneWidget);

      // Tap on the card
      await tester.tap(find.text('Claire'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Full profile modal should be displayed
      expect(find.text('CHISPA MUTUA'), findsOneWidget);
      expect(find.text('Conexión Romántica • Claire'), findsOneWidget);
      expect(find.text('Claire, 25'), findsOneWidget);
      expect(find.text('Las Condes'), findsOneWidget);
      expect(find.text('Amante de la astronomía y el buen café.'), findsOneWidget);
      expect(find.text('Escribir a Claire'), findsOneWidget);
      expect(find.text('Cerrar perfil'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cerrar perfil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('CHISPA MUTUA'), findsNothing);
    });

    test('Pending date letters persist across app restarts and restore badge count', () async {
      const testUserId = 'luis_test';
      final letter = MailboxLetter(
        id: 'date_persisted_1',
        partnerId: 'sofia_123',
        partnerName: 'Sofia',
        partnerAvatar: const AvatarConfig(),
        partnerAge: 24,
        partnerCommune: 'Santiago',
        commonTastes: const ['game_coop', 'intent_slow'],
        myDecision: MailboxDecision.pending,
        createdAt: DateTime.now(),
      );

      // Add letter to mailbox (simulating date completion)
      await MailboxService.addDateLetter(letter, userId: testUserId);
      expect(MailboxService.unreadLettersCount.value, equals(1));

      // Simulate app restart: RAM cache is cleared completely
      MailboxService.clear();
      expect(MailboxService.unreadLettersCount.value, equals(0));

      // Fetch letters on new app start
      final restoredLetters = await MailboxService.fetchLetters(userId: testUserId);
      expect(restoredLetters.length, equals(1));
      expect(restoredLetters.first.id, equals('date_persisted_1'));
      expect(restoredLetters.first.partnerName, equals('Sofia'));
      expect(restoredLetters.first.myDecision, equals(MailboxDecision.pending));
      expect(MailboxService.unreadLettersCount.value, equals(1));
    });

    test('Different users do not leak letters to each other (strict isolation)', () async {
      SharedPreferences.setMockInitialValues({});
      MailboxService.clear();

      const userA = 'user_luis';
      const userB = 'user_seth';

      // User A finishes a date with Sofia
      final letterA = MailboxLetter(
        id: 'date_luis_sofia',
        partnerId: 'sofia_123',
        partnerName: 'Sofia',
        partnerAvatar: const AvatarConfig(),
        myDecision: MailboxDecision.pending,
        createdAt: DateTime.now(),
      );
      await MailboxService.addDateLetter(letterA, userId: userA);
      expect(MailboxService.unreadLettersCount.value, equals(1));

      // User A logs out (MailboxService.clear is called)
      MailboxService.clear();

      // User B logs in and fetches letters
      final sethLetters = await MailboxService.fetchLetters(userId: userB);
      // Seth has 0 letters, and must NOT have Sofia's letter from Luis!
      expect(sethLetters.isEmpty, isTrue);
      expect(MailboxService.unreadLettersCount.value, equals(0));

      // User B finishes a date with Blaze
      final letterB = MailboxLetter(
        id: 'date_seth_blaze',
        partnerId: 'blaze_456',
        partnerName: 'Blaze',
        partnerAvatar: const AvatarConfig(),
        myDecision: MailboxDecision.pending,
        createdAt: DateTime.now(),
      );
      await MailboxService.addDateLetter(letterB, userId: userB);
      expect(MailboxService.unreadLettersCount.value, equals(1));

      // Switch back to User A without clearing manually (simulate dirty switch)
      final luisLetters = await MailboxService.fetchLetters(userId: userA);
      // Luis must ONLY have Sofia, NOT Blaze!
      expect(luisLetters.length, equals(1));
      expect(luisLetters.first.partnerName, equals('Sofia'));

      // Switch back to User B
      final sethLettersAgain = await MailboxService.fetchLetters(userId: userB);
      // Seth must ONLY have Blaze, NOT Sofia!
      expect(sethLettersAgain.length, equals(1));
      expect(sethLettersAgain.first.partnerName, equals('Blaze'));
    });

    testWidgets('Both profile photo and additional photos are combined together in card and full profile modal', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final letter = MailboxLetter(
        id: 'date_combined_photos',
        partnerId: 'user_combined',
        partnerName: 'Camila',
        partnerAvatar: const AvatarConfig(),
        partnerPhoto: 'https://example.com/camila_profile.jpg',
        partnerPhotos: const [
          'https://example.com/camila_extra1.jpg',
          'https://example.com/camila_extra2.jpg',
        ],
        partnerBio: 'Fotógrafa aficionada y jugadora de rol.',
        partnerAge: 26,
        partnerCommune: 'Ñuñoa',
        commonTastes: const ['game_rpg'],
        myDecision: MailboxDecision.pending,
        createdAt: DateTime.now(),
      );

      // Verify effectivePhotos contains both profile photo and all additional photos
      expect(letter.effectivePhotos.length, equals(3));
      expect(letter.effectivePhotos[0], equals('https://example.com/camila_profile.jpg'));
      expect(letter.effectivePhotos[1], equals('https://example.com/camila_extra1.jpg'));
      expect(letter.effectivePhotos[2], equals('https://example.com/camila_extra2.jpg'));

      MailboxService.addDateLetter(letter);

      await tester.pumpWidget(
        const MaterialApp(
          home: MailboxScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Card shows all 3 photos
      expect(find.text('Ver perfil y 3 fotos'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);

      // Tap to open full profile modal
      await tester.tap(find.text('Ver perfil y 3 fotos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Modal is open, showing full profile with all 3 photos combined
      expect(find.text('CITA EN LA FOGATA'), findsOneWidget);
      expect(find.text('Decisión pendiente • Camila'), findsOneWidget);
      expect(find.text('1/3'), findsNWidgets(2)); // 1 on card behind + 1 on modal dialog
    });

    testWidgets('Tapping Ampliar button launches FullScreenPhotoViewer with zoom and full navigation', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      MailboxService.addDateLetter(
        MailboxLetter(
          id: 'fullscreen_test_1',
          partnerId: 'user_fullscreen',
          partnerName: 'Lucas',
          partnerAvatar: const AvatarConfig(),
          partnerPhoto: 'https://example.com/lucas1.jpg',
          partnerPhotos: const [
            'https://example.com/lucas2.jpg',
          ],
          partnerAge: 25,
          partnerCommune: 'Providencia',
          commonTastes: const ['game_coop'],
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

      // Find Ampliar button and tap it
      final ampliarFinder = find.text('Ampliar');
      expect(ampliarFinder, findsWidgets);

      await tester.tap(ampliarFinder.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Visor Inmersivo Fullscreen should be open with Lucas' name, reset zoom and zoom hint
      expect(find.text('Lucas'), findsOneWidget);
      expect(find.text('Pellizca para hacer zoom • Desliza para navegar'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);

      // Close fullscreen viewer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Returned safely back to mailbox
      expect(find.text('Buzón de Recuerdos'), findsOneWidget);
    });
  });
}
