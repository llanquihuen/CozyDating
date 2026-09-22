import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/preference_tags.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/mailbox/models/mailbox_models.dart';

void main() {
  group('PreferenceCatalog Intent Formatting Tests', () {
    test('formats canonical intent IDs with emojis and user-facing titles', () {
      expect(
        PreferenceCatalog.formatIntent('intent_slow'),
        equals('🌱 Conocer sin prisa (Slow Dating)'),
      );
      expect(
        PreferenceCatalog.formatIntent('intent_serious'),
        equals('💍 Relación seria & bonita'),
      );
      expect(
        PreferenceCatalog.formatIntent('intent_gaming_duo'),
        equals('🎮 Dúo gamer & complicidad'),
      );
      expect(
        PreferenceCatalog.formatIntent('intent_cozy_chats'),
        equals('☕ Charlas de café y amistad'),
      );
    });

    test('formatIntent with includeEmoji = false returns clean title without emoji', () {
      expect(
        PreferenceCatalog.formatIntent('intent_slow', includeEmoji: false),
        equals('Conocer sin prisa (Slow Dating)'),
      );
      expect(
        PreferenceCatalog.formatIntent('intent_serious', includeEmoji: false),
        equals('Relación seria & bonita'),
      );
      expect(
        PreferenceCatalog.formatIntent('intent_gaming_duo', includeEmoji: false),
        equals('Dúo gamer & complicidad'),
      );
      expect(
        PreferenceCatalog.formatIntent('intent_cozy_chats', includeEmoji: false),
        equals('Charlas de café y amistad'),
      );
    });

    test('handles null and empty gracefully with default Slow Dating', () {
      expect(
        PreferenceCatalog.formatIntent(null),
        equals('🌱 Conocer sin prisa (Slow Dating)'),
      );
      expect(
        PreferenceCatalog.formatIntent(''),
        equals('🌱 Conocer sin prisa (Slow Dating)'),
      );
      expect(
        PreferenceCatalog.formatIntent('   '),
        equals('🌱 Conocer sin prisa (Slow Dating)'),
      );
    });

    test('preserves user custom text or legacy formatted intent', () {
      expect(
        PreferenceCatalog.formatIntent('Amor y complicidad 💖'),
        equals('Amor y complicidad 💖'),
      );
      expect(
        PreferenceCatalog.formatIntent('Citas con calma 🌱'),
        equals('Citas con calma 🌱'),
      );
    });

    test('getIntentEmoji extracts appropriate emoji for all intentions', () {
      expect(PreferenceCatalog.getIntentEmoji('intent_slow'), equals('🌱'));
      expect(PreferenceCatalog.getIntentEmoji('intent_serious'), equals('💍'));
      expect(PreferenceCatalog.getIntentEmoji('intent_gaming_duo'), equals('🎮'));
      expect(PreferenceCatalog.getIntentEmoji('intent_cozy_chats'), equals('☕'));
      expect(PreferenceCatalog.getIntentEmoji(null), equals('🌱'));
    });
  });

  group('UserProfile and MailboxLetter Intent Integration Tests', () {
    test('UserProfile exposes formattedIntent, intentEmoji, and intentTitle', () {
      const user = UserProfile(
        id: 'u1',
        username: 'Clara',
        intent: 'intent_serious',
      );

      expect(user.formattedIntent, equals('💍 Relación seria & bonita'));
      expect(user.intentEmoji, equals('💍'));
      expect(user.intentTitle, equals('Relación seria & bonita'));
    });

    test('UserProfile.fromMap recovers intent from tastes if map["intent"] is missing', () {
      final userMap = {
        'id': 'u2',
        'username': 'Tomas',
        'tastes': ['game_coop', 'cinema_ghibli', 'intent_gaming_duo'],
      };

      final profile = UserProfile.fromMap(userMap);
      expect(profile.intent, equals('intent_gaming_duo'));
      expect(profile.formattedIntent, equals('🎮 Dúo gamer & complicidad'));
    });

    test('MailboxLetter.effectiveIntent returns user-directed text instead of raw key', () {
      final letter = MailboxLetter(
        id: 'letter_1',
        partnerId: 'partner_99',
        partnerName: 'Lucas',
        partnerAvatar: const AvatarConfig(),
        partnerIntent: 'intent_slow',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(letter.effectiveIntent, equals('🌱 Conocer sin prisa (Slow Dating)'));
      expect(letter.intentEmoji, equals('🌱'));
      expect(letter.intentTitle, equals('Conocer sin prisa (Slow Dating)'));
    });

  });
}
