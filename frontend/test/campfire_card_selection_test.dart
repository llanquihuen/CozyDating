import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/campfire/models/campfire_models.dart';
import 'package:frontend/features/campfire/services/campfire_card_catalog.dart';

void main() {
  group('Campfire Card Catalog & Selection Engine Tests', () {
    test('Selects shared passion when users share a taste like game_coop', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['game_coop', 'food_coffee', 'intent_slow'],
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['game_coop', 'cinema_scifi', 'intent_slow'],
      );

      final cards = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 42);

      expect(cards.length, equals(3));
      // Round 1 should be shared passion with matchReason
      expect(cards[0].type, equals(CampfireCardType.sharedPassion));
      expect(cards[0].matchReason, contains('Coincidencia'));

      // Round 3 should be romantic connection because both have intent_slow
      expect(cards[2].type, equals(CampfireCardType.deepConnection));
      expect(cards[2].matchReason, contains('Intención Compartida'));
    });

    test('Falls back to discoveryWildcard when users share zero tastes', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['music_rock_metal', 'tech_pc_gamer'],
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['life_fitness', 'life_plants'],
      );

      final cards = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 100);

      expect(cards.length, equals(3));
      // Round 1 should be discovery wildcard
      expect(cards[0].type, equals(CampfireCardType.discoveryWildcard));
      expect(cards[0].matchReason, contains('Descubrimiento Mutuo'));
    });

    test('Detects contrast when one is night owl and the other is early bird', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['vibe_night_owl', 'intent_gaming_duo'],
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['vibe_early_bird', 'intent_gaming_duo'],
      );

      final cards = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 100);

      expect(cards.length, equals(3));
      // Round 2 should be rhythm contrast specifying Alice and Bob
      expect(cards[1].type, equals(CampfireCardType.curiousContrast));
      expect(cards[1].matchReason, contains('[Alice: Criatura Nocturna 🌙] vs [Bob: Madrugador(a) ☀️]'));

      // Round 3 should be friendship connection because both have intent_gaming_duo
      expect(cards[2].type, equals(CampfireCardType.deepConnection));
      expect(cards[2].matchReason, contains('Intención Compartida'));
    });

    test('Selects mirrorComplicity when users have identical high affinity', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['game_coop', 'cinema_ghibli', 'life_coffee_tea'],
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['game_coop', 'cinema_ghibli', 'life_coffee_tea'],
      );

      final cards = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 123);

      expect(cards.length, equals(3));
      // Round 2 should be mirror complicity
      expect(cards[1].type, equals(CampfireCardType.mirrorComplicity));
      expect(cards[1].matchReason, contains('Complicidad de Espejo'));
    });

    test('Selects specialized mixed card when romance meets friendship', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['intent_serious'], // Romance
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['intent_gaming_duo'], // Friendship
      );

      final cards = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 777);

      expect(cards.length, equals(3));
      // Round 3 should be specialized mixed card for Romance vs Friendship
      expect(cards[2].type, equals(CampfireCardType.universalValues));
      expect(cards[2].matchReason, contains('Intenciones Mixtas'));
      expect(cards[2].matchReason, contains('[Alice: Relación Seria 💍] vs [Bob: Dúo Gamer 🎮]'));
    });

    test('Selects specialized mixed card when Slow Dating meets Serious Relationship', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['intent_slow'],
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['intent_serious'],
      );

      final cards = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 999);

      expect(cards.length, equals(3));
      expect(cards[2].type, equals(CampfireCardType.deepConnection));
      expect(cards[2].matchReason, contains('Ritmos de Romance'));
      expect(cards[2].matchReason, contains('[Alice: Slow Dating 🌱] vs [Bob: Relación Seria 💍]'));
    });

    test('Selects specialized mixed card when Gaming Duo meets Cozy Chats', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['intent_gaming_duo'],
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['intent_cozy_chats'],
      );

      final cards = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 555);

      expect(cards.length, equals(3));
      expect(cards[2].type, equals(CampfireCardType.deepConnection));
      expect(cards[2].matchReason, contains('Estilos de Convivencia'));
      expect(cards[2].matchReason, contains('[Alice: Dúo Gamer 🎮] vs [Bob: Charlas de Café ☕]'));
    });

    test('Picks different common tastes when users share multiple tastes', () {
      const userA = UserProfile(
        id: 'user_a',
        username: 'Alice',
        tastes: ['game_coop', 'game_cozy', 'cinema_ghibli', 'life_coffee_tea', 'pet_cat'],
      );
      const userB = UserProfile(
        id: 'user_b',
        username: 'Bob',
        tastes: ['game_coop', 'game_cozy', 'cinema_ghibli', 'life_coffee_tea', 'pet_cat'],
      );

      final cards1 = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 1);
      final cards2 = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 10);
      final cards3 = CampfireCardCatalog.selectCardsForUsers(userA, userB, seed: 50);

      // Should be able to choose different categories based on random seed
      final chosenCategories = {cards1[0].categoryHeader, cards2[0].categoryHeader, cards3[0].categoryHeader};
      expect(chosenCategories.length, greaterThan(1));
    });

    test('Generates 100% identical cards and questions on both devices regardless of argument order', () {
      const luis = UserProfile(
        id: 'luis_123',
        username: 'Luis',
        tastes: ['game_coop', 'cinema_scifi', 'tech_pc_gamer', 'life_coffee_tea', 'intent_cozy_chats', 'vibe_night_owl'],
      );
      const sofia = UserProfile(
        id: 'sofia_456',
        username: 'Sofia',
        tastes: ['cinema_scifi', 'game_coop', 'life_coffee_tea', 'tech_pc_gamer', 'intent_cozy_chats', 'vibe_night_owl'],
      );

      const sharedSeed = 888444;

      // On Luis's device: localUser is Luis, partner is Sofia
      final luisCards = CampfireCardCatalog.selectCardsForUsers(luis, sofia, seed: sharedSeed);

      // On Sofia's device: localUser is Sofia, partner is Luis
      final sofiaCards = CampfireCardCatalog.selectCardsForUsers(sofia, luis, seed: sharedSeed);

      expect(luisCards.length, equals(3));
      expect(sofiaCards.length, equals(3));

      for (int i = 0; i < 3; i++) {
        expect(luisCards[i].id, equals(sofiaCards[i].id), reason: 'Round ${i + 1} card ID must match');
        expect(luisCards[i].question, equals(sofiaCards[i].question), reason: 'Round ${i + 1} question must match');
        expect(luisCards[i].options.length, equals(sofiaCards[i].options.length));
      }
    });
  });
}
