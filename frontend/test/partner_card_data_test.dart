import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/mailbox/models/mailbox_models.dart';

void main() {
  final serverLetter = {
    'id': 'match_1',
    'partnerId': 'bob',
    'partnerName': 'Bob',
    'partnerAge': 26,
    'partnerCommune': 'Providencia',
    'partnerPhoto': 'https://example.com/bob.jpg',
    'partnerBio': 'Bio real de Bob',
    'partnerCardStyle': '{"themeId":"forest","phrase":"Cabañas y leña","featuredTastes":["vacation_cabin"]}',
    'partnerVerified': true,
    'partnerTastes': '["vacation_cabin","pet_dog"]',
    'commonTastes': '["game_coop"]',
    'myDecision': 'PENDING',
  };

  test('a letter from the server keeps the partner card: style, seal, tastes and real bio', () {
    final letter = MailboxLetter.fromMap(serverLetter);
    expect(letter.partnerCardStyle!.themeId, 'forest');
    expect(letter.partnerVerified, isTrue);
    expect(letter.partnerTastes, ['vacation_cabin', 'pet_dog']);
    expect(letter.partnerBio, 'Bio real de Bob');

    final again = MailboxLetter.fromMap(letter.toMap());
    expect(again.partnerCardStyle, letter.partnerCardStyle);
    expect(again.partnerVerified, isTrue);
    expect(again.partnerTastes, letter.partnerTastes);
  });

  test('the partner card profile keeps the featured tastes and the reveal fields', () {
    final profile = MailboxLetter.fromMap(serverLetter).partnerCardProfile;
    expect(profile.username, 'Bob');
    expect(profile.age, 26);
    expect(profile.bio, 'Bio real de Bob');
    expect(profile.isVerified, isTrue);
    expect(profile.allPhotos, ['https://example.com/bob.jpg']);
    expect(profile.effectiveCardStyle.featuredTastes, ['vacation_cabin'],
        reason: 'the featured taste survives normalization');
    expect(profile.effectiveCardStyle.phrase, 'Cabañas y leña');
  });

  test('old letters without card data still give a card (default style from the tastes)', () {
    final letter = MailboxLetter.fromMap({
      'id': 'old',
      'partnerId': 'carla',
      'partnerName': 'Carla',
      'commonTastes': '["fuel_tea","life_plants"]',
    });
    expect(letter.partnerCardStyle, isNull);
    expect(letter.partnerVerified, isFalse);
    expect(letter.partnerCardProfile.effectiveCardStyle.themeId, 'matcha');
  });
}
