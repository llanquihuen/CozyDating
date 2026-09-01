import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/preference_tags.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/models/user_profile.dart';

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
        selectedTastes: ['intent_serious', 'cinema_ghibli', 'anime_romance', 'life_plants'],
        avatarConfig: const AvatarConfig(),
      );

      expect(room.wallpaper, equals('starry_night'));

      final furnitureIds = room.furniture.map((f) => f.typeName).toList();
      expect(furnitureIds, contains('home_theater_tv'));
      expect(furnitureIds, contains('wall_poster_cinema'));
      expect(furnitureIds, contains('manga_shelf'));
      expect(furnitureIds, contains('wall_poster_anime'));
      expect(furnitureIds, contains('monstera_plant_pot'));
    });
  });
}
