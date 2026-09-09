import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sitting Backleg Layering Tests', () {
    test('Priority Sandwich on chair: backleg < chair base < avatar < backrest overlay', () {
      final chair = IsometricFurnitureComponent(
        id: 'simple_chair',
        typeName: 'simple_chair',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 1.0,
        gridHeight: 1.0,
        rotation: 3, // NW -> Avatar faces direction 6 (northWest)
        footprint: '1x1',
      );

      final avatar = IsometricAvatarComponent(
        gridX: 4.0,
        gridY: 4.0,
        config: const AvatarConfig(bodyType: 'male'),
      );

      final backrestOverlay = ChairBackrestOverlayComponent(chair);
      backrestOverlay.update(0.016);

      avatar.sitOnChair(chair);
      avatar.backlegComponent?.update(0.016);

      final backleg = avatar.backlegComponent;
      expect(backleg, isNotNull);

      // Verify the 4-layer sandwich:
      // 1. Backleg is BEHIND chair base
      expect(backleg!.priority, equals(chair.priority - 2));
      expect(backleg.priority, lessThan(chair.priority),
          reason: 'Backleg must render behind the chair seat');

      // 2. Chair base is BEHIND avatar main body
      expect(chair.priority, lessThan(avatar.priority),
          reason: 'Avatar main body must render on top of the seat');
      expect(avatar.priority, equals(chair.priority + 10));

      // 3. Avatar main body is BEHIND chair backrest overlay
      expect(avatar.priority, lessThan(backrestOverlay.priority),
          reason: 'Chair backrest overlay must render on top of avatar');
      expect(backrestOverlay.priority, equals(chair.priority + 20));
    });

    test('Priority Sandwich on sofa (simple_sofa) in rotation 2 (NE)', () {
      final sofa = IsometricFurnitureComponent(
        id: 'simple_sofa',
        typeName: 'simple_sofa',
        gridX: 2.0,
        gridY: 3.0,
        gridWidth: 2.0,
        gridHeight: 1.0,
        rotation: 2, // NE -> Avatar faces direction 4 (northEast)
        footprint: '2x1',
      );

      final avatar = IsometricAvatarComponent(
        gridX: 2.0,
        gridY: 3.0,
        config: const AvatarConfig(bodyType: 'female'),
      );

      avatar.sitOnChair(sofa);
      avatar.backlegComponent?.update(0.016);

      final backleg = avatar.backlegComponent;
      expect(backleg, isNotNull);
      expect(backleg!.priority, equals(sofa.priority - 2),
          reason: 'Backleg must sit behind the sofa cushion/base');
      expect(avatar.priority, equals(sofa.priority + 10));
      expect(avatar.avatarRenderer.direction, equals(AvatarDirection.northEast));
    });

    test('Backleg component position matches avatar position and deactivates upon standing up', () {
      final chair = IsometricFurnitureComponent(
        id: 'plush_armchair',
        typeName: 'plush_armchair',
        gridX: 5.0,
        gridY: 5.0,
        rotation: 3, // NW
      );

      final avatar = IsometricAvatarComponent(
        gridX: 5.0,
        gridY: 5.0,
        config: const AvatarConfig(bodyType: 'male'),
      );

      avatar.sitOnChair(chair);
      avatar.backlegComponent?.update(0.016);

      expect(avatar.isSitting, isTrue);
      expect(avatar.backlegComponent!.position, equals(avatar.position));
      expect(avatar.backlegComponent!.size, equals(avatar.size));

      // Stand up
      avatar.standUp();
      expect(avatar.isSitting, isFalse);
      expect(avatar.sittingChair, isNull);
    });

    test('ModularAvatarComponent defaults renderBacklegSeparately to false and can toggle', () {
      final modular = ModularAvatarComponent(
        config: const AvatarConfig(),
        direction: AvatarDirection.northWest,
      );

      expect(modular.renderBacklegSeparately, isFalse);
      modular.renderBacklegSeparately = true;
      expect(modular.renderBacklegSeparately, isTrue);
    });

    test('ModularAvatarComponent with boots correctly tracks sitting state and hasBackleg', () {
      final modular = ModularAvatarComponent(
        config: const AvatarConfig(
          shoeStyle: 'boots',
          shoeColor: Color(0xFF78350F),
        ),
        direction: AvatarDirection.northEast,
      );

      expect(modular.isSitting, isFalse);
      modular.sitDown();
      expect(modular.isSitting, isTrue);

      // In NE, sitting avatar direction is 4
      expect(modular.direction, equals(AvatarDirection.northEast));
    });
  });
}
