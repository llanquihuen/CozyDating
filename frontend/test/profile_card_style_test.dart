import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/preference_tags.dart';
import 'package:frontend/core/models/profile_card_style.dart';
import 'package:frontend/core/models/user_profile.dart';

void main() {
  group('ProfileCardStyle', () {
    test('every theme hint is a real taste and every theme has hints', () {
      final known = {for (final c in PreferenceCatalog.categories) for (final i in c.items) i.id};
      expect(ProfileCardStyle.themeHints.keys.toSet(), ProfileCardStyle.themeIds.toSet());
      for (final entry in ProfileCardStyle.themeHints.entries) {
        for (final taste in entry.value) {
          expect(known, contains(taste), reason: '${entry.key}: $taste');
        }
      }
    });

    test('the default theme follows the tastes, and features the first non-intent tastes', () {
      final gamer = ProfileCardStyle.defaultFor(['intent_slow', 'plat_pc', 'game_mmo', 'fuel_coffee', 'music_synthwave']);
      expect(gamer.themeId, 'arcade');
      expect(gamer.featuredTastes, ['plat_pc', 'game_mmo', 'fuel_coffee'], reason: 'the intent is never featured');
      expect(ProfileCardStyle.defaultFor(const []).themeId, ProfileCardStyle.defaultTheme);
      expect(ProfileCardStyle.defaultFor(['pet_cat']).themeId, ProfileCardStyle.defaultTheme, reason: 'no hint matched');
    });

    test('normalizing keeps only owned, featurable tastes (1-5), a known theme and a short phrase', () {
      const tastes = ['intent_slow', 'pet_cat', 'fuel_tea', 'life_plants', 'game_cozy', 'music_lofi']; // matcha 2, cafe 1
      final style = const ProfileCardStyle(
        themeId: 'unknown_theme',
        phrase: '   Plantas,   yoga y matcha latte todas las mañanas antes del trabajo y del gimnasio   ',
        featuredTastes: ['intent_slow', 'pet_dog', 'pet_cat', 'pet_cat', 'fuel_tea', 'life_plants', 'game_cozy', 'music_lofi', 'life_books'],
      ).normalizedFor(tastes);
      expect(style.themeId, 'matcha', reason: 'unknown theme -> suggested by the tastes');
      expect(style.featuredTastes, ['pet_cat', 'fuel_tea', 'life_plants', 'game_cozy', 'music_lofi']);
      expect(style.phrase.length, lessThanOrEqualTo(ProfileCardStyle.maxPhraseLength));
      expect(style.phrase, startsWith('Plantas, yoga'), reason: 'spaces collapsed and trimmed');

      final emptied = const ProfileCardStyle(featuredTastes: ['pet_dog']).normalizedFor(tastes);
      expect(emptied.featuredTastes, ['pet_cat', 'fuel_tea', 'life_plants'], reason: 'none left: back to the default 3');
    });

    test('the phrase limit counts characters as people see them (emoji are one)', () {
      final phrase = List.filled(59, 'a').join() + '🐈‍⬛🐈‍⬛';
      final style = ProfileCardStyle(phrase: phrase).normalizedFor(const []);
      expect(style.phrase, List.filled(59, 'a').join() + '🐈‍⬛');
    });

    test('JSON round trip, and malformed input falls back to defaults', () {
      const style = ProfileCardStyle(
        themeId: 'coast',
        accent: Color(0xFF87CEEB),
        phrase: 'Surf al amanecer',
        featuredTastes: ['vacation_beach', 'pet_dog'],
      );
      expect(ProfileCardStyle.tryParse(style.toJson()), style);
      expect(ProfileCardStyle.tryParse(style.toMap()), style);
      expect(style.toMap()['accent'], '#87CEEB');

      expect(ProfileCardStyle.tryParse(null), isNull);
      expect(ProfileCardStyle.tryParse(''), isNull);
      expect(ProfileCardStyle.tryParse('{}'), isNull);
      expect(ProfileCardStyle.tryParse('not json'), isNull);
      final junk = ProfileCardStyle.tryParse('{"themeId": 4, "accent": "#XYZ", "featuredTastes": ["a", 3, null]}')!;
      expect(junk.themeId, ProfileCardStyle.defaultTheme);
      expect(junk.accent, isNull);
      expect(junk.featuredTastes, ['a']);
    });
  });

  group('UserProfile card fields', () {
    test('read from the server response (card style as a JSON string, ages as numbers)', () {
      final user = UserProfile.fromMap({
        'id': 'u1',
        'username': 'Kai',
        'tastes': '["plat_pc","game_mmo"]',
        'bio': 'Hago el mejor ramen',
        'cardStyle': '{"themeId":"arcade","phrase":"Speedruns","featuredTastes":["plat_pc"]}',
        'seekingAgeMin': 24,
        'seekingAgeMax': null,
      });
      expect(user.bio, 'Hago el mejor ramen');
      expect(user.cardStyle!.themeId, 'arcade');
      expect(user.cardStyle!.phrase, 'Speedruns');
      expect(user.seekingAgeMin, 24);
      expect(user.seekingAgeMax, isNull);
      expect(user.hasAgeFilter, isTrue);
    });

    test('old accounts: no style chosen and no age filter', () {
      final user = UserProfile.fromMap({'id': 'u2', 'username': 'Hana', 'tastes': '["fuel_tea","life_plants"]'});
      expect(user.cardStyle, isNull);
      expect(user.hasAgeFilter, isFalse);
      expect(user.effectiveCardStyle.themeId, 'matcha');
      expect(user.effectiveCardStyle.featuredTastes, ['fuel_tea', 'life_plants']);
    });

    test('round trip through toMap, copyWith keeps the age range and withSeekingAgeRange clears it', () {
      final user = const UserProfile(id: 'u3', username: 'Nyx', tastes: ['music_rock_metal'])
          .copyWith(cardStyle: const ProfileCardStyle(themeId: 'metal', featuredTastes: ['music_rock_metal']))
          .withSeekingAgeRange(25, 35);
      final back = UserProfile.fromMap(user.toMap());
      expect(back.cardStyle, user.cardStyle);
      expect([back.seekingAgeMin, back.seekingAgeMax], [25, 35]);

      final renamed = user.copyWith(username: 'Nyx2');
      expect([renamed.seekingAgeMin, renamed.seekingAgeMax], [25, 35]);
      final cleared = user.withSeekingAgeRange(null, null);
      expect(cleared.hasAgeFilter, isFalse);
      expect(cleared.cardStyle, user.cardStyle);
    });
  });
}
