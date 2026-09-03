import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/campfire/screens/campfire_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        return Uint8List.fromList([
          0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
          0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
          0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
          0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
          0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
          0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
        ]).buffer.asByteData();
      },
    );
  });

  const dummyLocalUser = UserProfile(
    id: 'user_1',
    username: 'Sofi',
    avatarConfig: AvatarConfig(bodyType: 'female', topStyle: 'hoodie'),
    tastes: ['game_coop', 'intent_gaming_duo'],
  );

  const dummyPartnerUser = UserProfile(
    id: 'user_2',
    username: 'Matias',
    avatarConfig: AvatarConfig(bodyType: 'male', topStyle: 'jacket'),
    tastes: ['game_coop', 'intent_gaming_duo'],
  );

  group('Campfire View Flow Widget Tests', () {
    testWidgets('Renders Campfire View with initial round, question and discrete exit button', (tester) async {
      bool returnedHome = false;

      await tester.pumpWidget(
        MaterialApp(
          home: CampfireView(
            localUser: dummyLocalUser,
            partnerUser: dummyPartnerUser,
            partnerName: 'Matias',
            onReturnHome: () {
              returnedHome = true;
            },
          ),
        ),
      );

      // Verify Round 1 indicator, discrete exit, and discrete category badge
      expect(find.text('Ronda 1 de 3'), findsOneWidget);
      expect(find.text('Reclamar botín y salir'), findsOneWidget);
      expect(find.text('🌿 Pasión en Común'), findsOneWidget);

      // Verify questions and options rendered
      expect(find.textContaining('PASIÓN COMPARTIDA'), findsOneWidget);

      // Tap discrete exit
      await tester.tap(find.text('Reclamar botín y salir'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(returnedHome, isTrue);
    });

    testWidgets('Selecting an option highlights choice and shows waiting indicator', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CampfireView(
            localUser: dummyLocalUser,
            partnerUser: dummyPartnerUser,
            partnerName: 'Matias',
            onReturnHome: () {},
          ),
        ),
      );

      // Find first option and tap it
      final firstOption = find.textContaining('El estratega');
      expect(firstOption, findsOneWidget);

      await tester.tap(firstOption);
      await tester.pump(const Duration(milliseconds: 100));

      // Local tag "Tú" and waiting indicator should appear
      expect(find.text('Tú'), findsOneWidget);
      expect(find.text('Matias está eligiendo su respuesta...'), findsOneWidget);
    });
  });
}
