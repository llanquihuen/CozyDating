import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/lifestyle_badges.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/features/avatar/widgets/lifestyle_badges_sheet.dart';

void main() {
  group('LifestyleBadges Model Tests', () {
    test('Default constructor has 0 active badges and hasAnyBadge is false', () {
      const badges = LifestyleBadges();
      expect(badges.activeCount, 0);
      expect(badges.hasAnyBadge, false);
      expect(badges.activeBadges, isEmpty);
      expect(badges.toMap(), isEmpty);
    });

    test('toMap and fromMap serialize and deserialize active badges properly', () {
      const badges = LifestyleBadges(
        smoking: 'no_smoke',
        drinking: 'social',
        diet: 'vegetarian',
        heightCm: 178,
        kids: 'want_kids',
        pets: 'dog',
        zodiac: 'aries',
        education: 'university',
        occupation: 'Game Developer',
        languages: ['Español', 'Inglés'],
        religion: 'spiritual',
        exercise: 'often',
      );

      expect(badges.activeCount, 12);
      expect(badges.hasAnyBadge, true);

      final map = badges.toMap();
      expect(map['smoking'], 'no_smoke');
      expect(map['drinking'], 'social');
      expect(map['diet'], 'vegetarian');
      expect(map['heightCm'], 178);
      expect(map['kids'], 'want_kids');
      expect(map['pets'], 'dog');
      expect(map['zodiac'], 'aries');
      expect(map['education'], 'university');
      expect(map['occupation'], 'Game Developer');
      expect(map['languages'], ['Español', 'Inglés']);
      expect(map['religion'], 'spiritual');
      expect(map['exercise'], 'often');

      final fromMap = LifestyleBadges.fromMap(map);
      expect(fromMap.smoking, 'no_smoke');
      expect(fromMap.heightCm, 178);
      expect(fromMap.occupation, 'Game Developer');
      expect(fromMap.languages, ['Español', 'Inglés']);
      expect(fromMap.activeCount, 12);

      final activeList = fromMap.activeBadges;
      expect(activeList.length, 12);

      // Verify height badge
      final heightItem = activeList.firstWhere((i) => i.key == 'height');
      expect(heightItem.icon, '📏');
      expect(heightItem.label, '178 cm');

      // Verify smoking badge
      final smokeItem = activeList.firstWhere((i) => i.key == 'smoking');
      expect(smokeItem.icon, '🚭');
      expect(smokeItem.label, 'No fumo');
    });

    test('Omitted or prefer_not_say badges are not marked active', () {
      const badges = LifestyleBadges(
        smoking: 'prefer_not_say',
        drinking: 'no_drink',
      );

      expect(badges.activeCount, 1);
      final activeList = badges.activeBadges;
      expect(activeList.length, 1);
      expect(activeList.first.key, 'drinking');
      expect(activeList.first.icon, '🚫');
      expect(activeList.first.label, 'No bebo');
    });

    test('UserProfile seamlessly integrates LifestyleBadges', () {
      const badges = LifestyleBadges(
        smoking: 'no_smoke',
        heightCm: 172,
        pets: 'cat',
      );

      final profile = UserProfile(
        id: 'user_test',
        username: 'CozyPlayer',
        lifestyle: badges,
      );

      expect(profile.lifestyle.activeCount, 3);
      expect(profile.lifestyle.heightCm, 172);

      final json = profile.toJson();
      final restored = UserProfile.fromJson(json);
      expect(restored.lifestyle.activeCount, 3);
      expect(restored.lifestyle.smoking, 'no_smoke');
      expect(restored.lifestyle.heightCm, 172);
      expect(restored.lifestyle.pets, 'cat');
    });

    testWidgets('LifestyleBadgesSheet opens and renders properly inside showModalBottomSheet', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  LifestyleBadgesSheet.show(
                    context,
                    initialLifestyle: const LifestyleBadges(),
                    onSaved: (_) {},
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('¿Quién eres y cómo es tu realidad de vida actual?'), findsOneWidget);
      expect(find.text('HÁBITOS DE CONVIVENCIA'), findsOneWidget);
      expect(find.text('Fumar'), findsOneWidget);
      expect(find.text('Tomar'), findsOneWidget);
    });
  });
}
