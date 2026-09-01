import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/preference_tags.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/auth/screens/fun_registration_wizard.dart';

void main() {
  group('Auth & UserProfile Serialization Tests', () {
    test('UserProfile serialization roundtrip', () {
      final user = UserProfile(
        id: 'user_123',
        username: 'AlexExplorer',
        email: 'alex@cozy.com',
        age: 25,
        commune: 'Providencia',
        ticketsBalance: 5,
        avatarConfig: const AvatarConfig(hairStyle: 'long_flow', topStyle: 'jacket'),
        tastes: const ['intent_slow', 'tech_pc_gamer', 'music_lofi', 'pet_cat'],
        roomConfig: const RoomConfig(wallpaper: 'solid_sage_green'),
      );

      final jsonStr = user.toJson();
      final reconstructed = UserProfile.fromJson(jsonStr);

      expect(reconstructed.id, equals('user_123'));
      expect(reconstructed.username, equals('AlexExplorer'));
      expect(reconstructed.email, equals('alex@cozy.com'));
      expect(reconstructed.age, equals(25));
      expect(reconstructed.commune, equals('Providencia'));
      expect(reconstructed.ticketsBalance, equals(5));
      expect(reconstructed.avatarConfig.hairStyle, equals('long_flow'));
      expect(reconstructed.tastes, contains('tech_pc_gamer'));
      expect(reconstructed.tastes, contains('pet_cat'));
      expect(reconstructed.roomConfig.wallpaper, equals('solid_sage_green'));
    });
  });

  group('Preference Catalog & Starter Room Generation Tests', () {
    test('Categories contain dating intentions and diverse subcategories', () {
      expect(PreferenceCatalog.categories.length, greaterThanOrEqualTo(8));
      final intentCat = PreferenceCatalog.categories.firstWhere((c) => c.id == 'dating_intentions');
      expect(intentCat.isSingleSelect, isTrue);
      expect(intentCat.items.length, greaterThanOrEqualTo(4));
    });

    test('generateStarterRoomConfig injects tech and pet furniture based on tastes', () {
      final room = PreferenceCatalog.generateStarterRoomConfig(
        baseTheme: 'modern',
        selectedTastes: ['intent_slow', 'tech_pc_gamer', 'pet_cat', 'music_lofi'],
        avatarConfig: const AvatarConfig(),
      );

      expect(room.wallpaper, equals('solid_white_plaster'));
      expect(room.floor, equals('solid_slate_gray'));

      final furnitureIds = room.furniture.map((f) => f.typeName).toList();
      expect(furnitureIds, contains('gaming_pc_desk'));
      expect(furnitureIds, contains('cat_tree_tower'));
      expect(furnitureIds, contains('vinyl_record_player'));
    });

    test('generateStarterRoomConfig injects cinema and anime furniture based on tastes', () {
      final room = PreferenceCatalog.generateStarterRoomConfig(
        baseTheme: 'mystic',
        selectedTastes: ['intent_slow', 'cinema_ghibli', 'art_anime_manga', 'life_plants'],
        avatarConfig: const AvatarConfig(),
      );

      final furnitureIds = room.furniture.map((f) => f.typeName).toList();
      expect(furnitureIds, isNotEmpty);
    });
  });

  group('FunRegistrationWizardScreen Widget Tests', () {
    testWidgets('Step 2 renders complete Avatar Creator with 2 sections and zoom controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FunRegistrationWizardScreen(
            onRegistrationSuccess: () {},
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Fill Step 1 Form
      await tester.enterText(find.byType(TextFormField).at(0), 'GamerCozy');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.enterText(find.byType(TextFormField).at(2), 'gamer@cozy.com');
      await tester.pump(const Duration(milliseconds: 100));

      // Tap Continuar to Step 2
      await tester.tap(find.text('Continuar ➔'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Step 2 Avatar Section 1
      expect(find.text('1. Rostro & Cabello'), findsOneWidget);
      expect(find.text('2. Vestimenta & Estilo'), findsOneWidget);
      expect(find.text('Cara & Piel'), findsOneWidget);
      expect(find.text('Expresión & Ojos'), findsOneWidget);
      expect(find.text('Peinado'), findsOneWidget);
      expect(find.text('Sorpréndeme 🎲'), findsOneWidget);

      // Tap Section 2 (Vestimenta & Estilo)
      await tester.tap(find.text('2. Vestimenta & Estilo'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.widgetWithText(Tab, 'Prenda Superior'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Prenda Inferior'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Calzado'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Accesorios'), findsOneWidget);
    });
  });
}
