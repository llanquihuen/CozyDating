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
    Future<void> fillStep1AndContinue(WidgetTester tester) async {
      await tester.enterText(find.byType(TextFormField).at(0), 'GamerCozy');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.enterText(find.byType(TextFormField).at(2), 'gamer@cozy.com');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('Continuar ➔'));
      await tester.tap(find.text('Continuar ➔'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('Step 2 is the shared avatar editor, with a skip hint until the avatar is touched',
        (tester) async {
      await tester.pumpWidget(MaterialApp(home: FunRegistrationWizardScreen(onRegistrationSuccess: () {})));
      await tester.pump(const Duration(milliseconds: 100));
      await fillStep1AndContinue(tester);

      for (final tab in ['Cuerpo', 'Cara', 'Maquillaje', 'Pelo', 'Ropa', 'Accesorios']) {
        expect(find.text(tab), findsOneWidget, reason: tab);
      }
      expect(find.text('Complexión'), findsNothing, reason: 'default gender MAN: body locked');
      final skip = find.textContaining('Saltar por ahora');
      expect(skip, findsOneWidget);

      await tester.tap(find.text('Pelo'));
      await tester.pump();
      await tester.ensureVisible(find.text('Rapado'));
      await tester.pump();
      await tester.tap(find.text('Rapado'));
      await tester.pump();
      expect(skip, findsNothing, reason: 'the avatar was touched');

      await tester.tap(skip.evaluate().isEmpty ? find.text('Continuar ➔') : skip);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('3. Gustos & Vibes'), findsOneWidget);
    });

    testWidgets('a gender chosen in step 1 reaches the avatar editor', (tester) async {
      await tester.pumpWidget(MaterialApp(home: FunRegistrationWizardScreen(onRegistrationSuccess: () {})));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.ensureVisible(find.text('✨ No binario'));
      await tester.tap(find.text('✨ No binario'));
      await tester.pump();
      await fillStep1AndContinue(tester);

      expect(find.text('Complexión'), findsOneWidget, reason: 'non-binary players pick their body');
    });
  });
}
