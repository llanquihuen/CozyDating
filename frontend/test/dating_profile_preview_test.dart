import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/services/auth_service.dart';
import 'package:frontend/features/avatar/screens/character_creator_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.setCurrentUserForTesting(
      UserProfile(
        id: 'user_preview_test',
        username: 'Valeria',
        profilePhoto: 'https://example.com/valeria_profile.jpg',
        photos: const [
          'https://example.com/valeria_extra1.jpg',
          'https://example.com/valeria_extra2.jpg',
        ],
        bio: 'Me encanta el té verde, los juegos indies y leer bajo la lluvia 🍵📖.',
        intent: 'Citas con calma 🌱',
        age: 25,
        commune: 'Providencia',
        tastes: const ['game_coop', 'cinema_ghibli'],
        avatarConfig: const AvatarConfig(),
      ),
    );
  });

  group('Dating Profile Preview Mode Tests', () {
    testWidgets('CharacterCreatorScreen displays preview banner and launches preview modal', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: CharacterCreatorScreen(
            initialScreenMode: 1, // Dating Profile mode
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that the preview banner is rendered
      expect(find.text('Vista Previa de tu Perfil'), findsOneWidget);
      expect(find.text('Comprueba cómo verán tu perfil y fotos al terminar la Fogata'), findsOneWidget);
      expect(find.text('Ver perfil'), findsOneWidget);

      // Also verify the AppBar preview button
      expect(find.text('Vista previa'), findsOneWidget);

      // Tap on Ver perfil button to open the preview modal
      await tester.tap(find.text('Ver perfil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the preview modal is displayed with proper header
      expect(find.text('VISTA PREVIA DE TU PERFIL'), findsOneWidget);
      expect(find.text('Así te verán tus citas al terminar la Fogata'), findsOneWidget);

      // Verify the user details in the preview
      expect(find.text('Valeria, 25'), findsOneWidget);
      expect(find.text('Providencia'), findsWidgets);
      expect(find.text('Citas con calma 🌱'), findsWidgets);
      expect(find.text('Me encanta el té verde, los juegos indies y leer bajo la lluvia 🍵📖.'), findsWidgets);

      // Verify combined photos counter (1 profile photo + 2 extra photos = 3)
      expect(find.text('1/3'), findsOneWidget);

      // Verify the bottom button is Volver a editar mi perfil
      final backBtn = find.text('Volver a editar mi perfil');
      expect(backBtn, findsOneWidget);

      // Tap Volver a editar mi perfil to close preview
      await tester.tap(backBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify modal is closed
      expect(find.text('VISTA PREVIA DE TU PERFIL'), findsNothing);
    });
  });
}
