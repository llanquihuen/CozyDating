import 'dart:typed_data';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';
import 'package:frontend/features/game/cinematics/role_swap_cinematic_game.dart';
import 'package:frontend/features/game/screens/role_swap_cinematic_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyLocalConfig = AvatarConfig(
    bodyType: 'female',
    hairStyle: 'braids',
    hairColor: Colors.black,
    skinColor: const Color(0xFFF1C27D),
    topStyle: 'jacket',
    topColor: Colors.grey.shade900,
  );

  final dummyPartnerConfig = AvatarConfig(
    bodyType: 'male',
    hairStyle: 'undercut',
    hairColor: Colors.brown,
    skinColor: const Color(0xFFE0AC69),
    topStyle: 'hoodie',
    topColor: Colors.teal,
  );

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

  group('Role Swap Full-Screen Cinematic Tests', () {
    test('RoleSwapCinematicGame advances through walking, item exchange, and finish phases', () async {
      bool finishedCalled = false;

      final game = RoleSwapCinematicGame(
        localAvatarConfig: dummyLocalConfig,
        partnerAvatarConfig: dummyPartnerConfig,
        localWasExplorer: true,
        onCinematicFinished: () {
          finishedCalled = true;
        },
      );

      await game.onLoad();
      game.onGameResize(Vector2(800, 600));

      // Initially walking in
      expect(game.currentPhase, equals(CinematicPhase.walkingIn));
      expect(game.leftAvatar.isMoving, isTrue);
      expect(game.leftAvatar.direction, equals(AvatarDirection.east));

      // Advance 1.5s -> still walking in
      game.update(1.5);
      expect(game.currentPhase, equals(CinematicPhase.walkingIn));

      // Advance past 2.2s -> item exchange phase
      game.update(1.0); // Total 2.5s
      expect(game.currentPhase, equals(CinematicPhase.itemExchange));
      expect(game.leftAvatar.isMoving, isFalse);

      // Advance past 4.6s -> walking out with swapped directions
      game.update(2.5); // Total 5.0s
      expect(game.currentPhase, equals(CinematicPhase.walkingOut));
      expect(game.leftAvatar.isMoving, isTrue);
      expect(game.leftAvatar.direction, equals(AvatarDirection.west));

      // Advance to completion (>7.5s)
      game.update(3.0); // Total 8.0s
      expect(game.currentPhase, equals(CinematicPhase.finished));
      expect(finishedCalled, isTrue);
    });

    testWidgets('RoleSwapCinematicView renders briefing card and triggers onProceed on tap', (tester) async {
      bool proceedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: RoleSwapCinematicView(
            newRole: 'EXPLORER',
            localAvatarConfig: dummyLocalConfig,
            partnerAvatarConfig: dummyPartnerConfig,
            partnerName: 'Camila',
            onProceed: () {
              proceedCalled = true;
            },
          ),
        ),
      );

      // Verify title & partner information
      expect(find.text('ACTO 2 • EL RELEVO'), findsOneWidget);
      expect(find.text('Compañero: Camila'), findsOneWidget);

      // Verify briefing for new Explorer role
      expect(find.text('TU NUEVO ROL: EXPLORADOR'), findsOneWidget);
      expect(find.textContaining('Ahora tomas la linterna mágica'), findsOneWidget);

      // Verify continue button
      expect(find.textContaining('Entrar al Acto 2'), findsOneWidget);

      // Tap proceed button
      await tester.tap(find.textContaining('Entrar al Acto 2'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(proceedCalled, isTrue);
    });

    testWidgets('RoleSwapCinematicView renders briefing card for Guide role', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoleSwapCinematicView(
            newRole: 'GUIDE',
            localAvatarConfig: dummyLocalConfig,
            partnerAvatarConfig: dummyPartnerConfig,
            partnerName: 'Lucas',
            onProceed: () {},
          ),
        ),
      );

      expect(find.text('TU NUEVO ROL: GUÍA DEL LABERINTO'), findsOneWidget);
      expect(find.textContaining('Ahora tienes el mapa estelar'), findsOneWidget);
    });
  });
}
