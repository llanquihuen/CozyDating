import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_catalog.dart';
import 'package:frontend/core/models/avatar_config.dart';

void main() {
  group('AvatarCatalog', () {
    test('every catalog item survives a JSON round trip', () {
      for (final item in AvatarCatalog.items) {
        final config = switch (item.slot) {
          AvatarCatalog.eyes => AvatarConfig(eyeStyle: item.id),
          AvatarCatalog.nose => AvatarConfig(noseStyle: item.id),
          AvatarCatalog.mouth => AvatarConfig(mouthStyle: item.id),
          AvatarCatalog.hair => AvatarConfig(hairStyle: item.id),
          AvatarCatalog.top => AvatarConfig(topStyle: item.id),
          AvatarCatalog.bottom => AvatarConfig(bottomStyle: item.id),
          AvatarCatalog.shoes => AvatarConfig(shoeStyle: item.id),
          AvatarCatalog.dress => AvatarConfig(dressStyle: item.id),
          AvatarCatalog.mark => AvatarConfig(marks: [item.id]),
          AvatarCatalog.blush || AvatarCatalog.eyeshadow || AvatarCatalog.eyeliner || AvatarCatalog.lipstick =>
            AvatarConfig(makeup: {item.slot: item.id}),
          _ => AvatarConfig(accessories: {item.slot: item.id}),
        };
        expect(AvatarConfig.fromJson(config.toJson()), equals(config), reason: '${item.slot}/${item.id}');
      }
    });

    test('unknown styles fall back to defaults', () {
      final config = AvatarConfig.fromJson({
        'eyeStyle': 'laser_eyes',
        'hairStyle': 'mohawk_2099',
        'shoeStyle': 'rocket_boots',
        'accessories': {'glasses': 'x_ray', 'hat': 'none'},
        'marks': ['freckles', 'unknown_tattoo'],
      });
      expect(config.eyeStyle, 'cateyes');
      expect(config.hairStyle, 'long_flow');
      expect(config.shoeStyle, 'none');
      expect(config.accessories, isEmpty);
      expect(config.marks, ['freckles']);
    });

    test('men see masculine + neutral items, women feminine + neutral, non-binary everything', () {
      final men = AvatarCatalog.options(AvatarCatalog.hair, gender: 'MAN', bodyType: 'male');
      final women = AvatarCatalog.options(AvatarCatalog.hair, gender: 'WOMAN', bodyType: 'female');
      final nonBinary = AvatarCatalog.options(AvatarCatalog.hair, gender: 'NON_BINARY', bodyType: 'male');

      expect(men, containsAll(['none', 'comb_over', 'bangs']));
      expect(men, isNot(contains('twintails')));
      expect(women, containsAll(['twintails', 'long_flow', 'bangs']));
      expect(women, isNot(contains('comb_over')));
      expect(nonBinary, containsAll({...men, ...women}));
      expect(men.first, 'none');
    });

    test('only items with art for the body are offered', () {
      const femaleOnly = AvatarItem(AvatarCatalog.top, 'test_dress', 'Vestido', fits: ['female']);
      expect(AvatarCatalog.isAllowed(femaleOnly, gender: 'NON_BINARY', bodyType: 'female'), isTrue);
      expect(AvatarCatalog.isAllowed(femaleOnly, gender: 'NON_BINARY', bodyType: 'male'), isFalse);
    });

    test('body is locked for men and women, free otherwise', () {
      expect(AvatarCatalog.lockedBodyFor('MAN'), 'male');
      expect(AvatarCatalog.lockedBodyFor('WOMAN'), 'female');
      expect(AvatarCatalog.lockedBodyFor('NON_BINARY'), isNull);
      expect(AvatarCatalog.lockedBodyFor('OTHER'), isNull);
    });
  });

  group('Makeup', () {
    test('styles and colours survive a JSON round trip; unknown ones are dropped', () {
      final config = const AvatarConfig()
          .withMakeup('blush', 'blush_anime')
          .withMakeup('lipstick', 'lip_bold')
          .withMakeupColor('lipstick', const Color(0xFF8E1F3D));
      expect(AvatarConfig.fromJson(config.toJson()), equals(config));
      expect(config.makeupColor('blush'), AvatarConfig.defaultMakeupColors['blush']);

      final bad = AvatarConfig.fromJson({
        'makeup': {'blush': 'glitter_bomb', 'glasses': 'nice_lenses', 'eyeshadow': 'shadow_soft'},
        'accessories': {'blush': 'blush_soft'},
      });
      expect(bad.makeup, {'eyeshadow': 'shadow_soft'});
      expect(bad.accessories, isEmpty);
    });

    test('removing a makeup style empties its slot', () {
      final config = const AvatarConfig().withMakeup('blush', 'blush_soft').withMakeup('blush', 'none');
      expect(config.makeup, isEmpty);
      expect(config.makeupIn('blush'), 'none');
    });
  });

  group('AvatarConfig.restrictedTo', () {
    const feminineLook = AvatarConfig(
      bodyType: 'female',
      hairStyle: 'twintails',
      topStyle: 'jacket',
      accessories: {'glasses': 'nice_lenses'},
      marks: ['freckles'],
    );

    test('a man gets the male body and loses feminine items, keeping neutral ones', () {
      final config = feminineLook.restrictedTo('MAN');
      expect(config.bodyType, 'male');
      expect(config.hairStyle, isNot('twintails'));
      expect(AvatarCatalog.find(AvatarCatalog.hair, config.hairStyle)!.audience, isNot(AvatarAudience.feminine));
      expect(config.topStyle, 'jacket');
      expect(config.accessories, {'glasses': 'nice_lenses'});
      expect(config.marks, ['freckles']);
    });

    test('a woman gets the female body and loses masculine items', () {
      final config = const AvatarConfig(bodyType: 'male', hairStyle: 'comb_over').restrictedTo('WOMAN');
      expect(config.bodyType, 'female');
      expect(config.hairStyle, isNot('comb_over'));
    });

    test('non-binary players keep any body and any item', () {
      expect(feminineLook.copyWith(bodyType: 'male').restrictedTo('NON_BINARY'),
          equals(feminineLook.copyWith(bodyType: 'male')));
    });

    test('allowed configs are left untouched', () {
      expect(feminineLook.restrictedTo('WOMAN'), equals(feminineLook));
    });
  });
}
