import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/mailbox/models/mailbox_models.dart';
import 'package:frontend/features/revelation/screens/double_blind_vote_view.dart';
import 'package:frontend/features/revelation/screens/match_reveal_celebration_view.dart';
import 'package:frontend/features/campfire/widgets/post_campfire_decision_dialog.dart';

void main() {
  group('Revelation & Double Blind Match Tests', () {
    testWidgets('DoubleBlindVoteView renders secret vote options and triggers callback', (tester) async {
      bool? voteResult;

      const partner = UserProfile(
        id: 'bob',
        username: 'Bob',
        bio: 'Me encanta la música y los videojuegos',
        intent: 'Citas con calma 🌱',
        age: 26,
        commune: 'Providencia',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoubleBlindVoteView(
              partnerUser: partner,
              partnerName: 'Bob',
              onVoteSubmitted: (wantsMatch) {
                voteResult = wantsMatch;
              },
            ),
          ),
        ),
      );

      expect(find.text('VOTACIÓN A CIEGAS'), findsOneWidget);
      expect(find.text('¿Te gustaría conectar con Bob?'), findsOneWidget);
      expect(find.text('¡Quiero conectar!'), findsOneWidget);
      expect(find.text('Seguir mi camino'), findsOneWidget);

      // Tap "¡Quiero conectar!"
      await tester.tap(find.text('¡Quiero conectar!'));
      await tester.pump();

      expect(voteResult, isTrue);
      expect(find.text('Esperando la decisión de Bob...'), findsOneWidget);
    });

    testWidgets('MatchRevealCelebrationView renders photos, bio, intent, and chat button', (tester) async {
      bool homeReturned = false;

      const localUser = UserProfile(
        id: 'alice',
        username: 'Alice',
      );

      const partner = UserProfile(
        id: 'bob',
        username: 'Bob',
        bio: 'Amante del café y las aventuras cooperativas.',
        intent: 'Amor y complicidad 💖',
        age: 26,
        commune: 'Las Condes',
        photos: ['assets/images/characters/female_preview.png'],
        avatarConfig: AvatarConfig(bodyType: 'male'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchRevealCelebrationView(
              localUser: localUser,
              partnerUser: partner,
              partnerName: 'Bob',
              onReturnHome: () {
                homeReturned = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('¡HUBO CHISPA MUTUA!'), findsOneWidget);
      expect(find.text('Ambos han sentido esa química especial'), findsOneWidget);
      expect(find.text('Bob, 26'), findsOneWidget);
      expect(find.text('Las Condes'), findsOneWidget);
      expect(find.text('Amor y complicidad 💖'), findsOneWidget);
      expect(find.text('Amante del café y las aventuras cooperativas.'), findsOneWidget);
      expect(find.text('Aceptar'), findsOneWidget);
      expect(find.text('Escribir a Bob'), findsNothing);

      // Tap Aceptar to return home
      await tester.tap(find.text('Aceptar'));
      await tester.pump();
      expect(homeReturned, isTrue);
    });

    testWidgets('MatchRevealCelebrationView renders friendship match correctly', (tester) async {
      const localUser = UserProfile(id: 'alice', username: 'Alice');
      const partner = UserProfile(
        id: 'bob',
        username: 'Bob',
        age: 26,
        commune: 'Las Condes',
        photos: ['assets/images/characters/female_preview.png'],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MatchRevealCelebrationView(
              localUser: localUser,
              partnerUser: partner,
              partnerName: 'Bob',
              matchType: ConnectionType.friendship,
            ),
          ),
        ),
      );

      expect(find.text('¡NUEVA AMISTAD MUTUA!'), findsOneWidget);
      expect(find.text('Coincidieron en ser compañeros de aventuras'), findsOneWidget);
    });

    testWidgets('MatchRevealCelebrationView in full profile mode renders chat and close buttons', (tester) async {
      bool closed = false;

      const localUser = UserProfile(
        id: 'alice',
        username: 'Alice',
      );

      const partner = UserProfile(
        id: 'bob',
        username: 'Bob',
        bio: 'Amante del café y las aventuras cooperativas.',
        intent: 'Amor y complicidad 💖',
        age: 26,
        commune: 'Las Condes',
        photos: ['assets/images/characters/female_preview.png'],
        avatarConfig: AvatarConfig(bodyType: 'male'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MatchRevealCelebrationView(
              localUser: localUser,
              partnerUser: partner,
              partnerName: 'Bob',
              isCelebration: false,
              onReturnHome: () {
                closed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('CHISPA MUTUA'), findsOneWidget);
      expect(find.text('Conexión Romántica • Bob'), findsOneWidget);
      expect(find.text('Escribir a Bob'), findsOneWidget);
      expect(find.text('Cerrar perfil'), findsOneWidget);

      await tester.tap(find.text('Cerrar perfil'));
      await tester.pump();
      expect(closed, isTrue);
    });

    testWidgets('PostCampfireDecisionDialog renders ternary buttons, secret ballot notice and postpone action', (tester) async {
      MailboxDecision? selectedDecision;
      bool postponed = false;

      final letter = MailboxLetter(
        id: 'date_test_1',
        partnerId: 'bob',
        partnerName: 'Bob',
        partnerAvatar: const AvatarConfig(),
        partnerAge: 26,
        partnerCommune: 'Las Condes',
        partnerBio: 'Me gusta cocinar y jugar coop.',
        commonTastes: ['game_coop'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCampfireDecisionDialog(
              letter: letter,
              coinsEarned: 150,
              onDecision: (decision) {
                selectedDecision = decision;
              },
              onPostponeToHome: () {
                postponed = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('+150 MONEDAS · AVENTURA SUPERADA'), findsOneWidget);
      expect(find.text('¿Cómo sentiste la conexión con Bob?'), findsOneWidget);
      expect(find.textContaining('Tu voto es secreto'), findsOneWidget);
      expect(find.text('¡Hubo Chispa! (Romance)'), findsOneWidget);
      expect(find.text('Gran Onda (Amistad / Dúo)'), findsOneWidget);
      expect(find.text('Dejar como un buen recuerdo'), findsOneWidget);
      expect(find.text('💭 Déjame pensarlo · Ir a mi Hogar'), findsOneWidget);

      // Tap Romance
      await tester.ensureVisible(find.text('¡Hubo Chispa! (Romance)'));
      await tester.tap(find.text('¡Hubo Chispa! (Romance)'));
      await tester.pump();

      expect(selectedDecision, equals(MailboxDecision.romance));
    });
  });
}
