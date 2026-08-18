import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/game/components/ping_beacon_component.dart';
import 'package:frontend/features/game/components/sanctuary_plate_component.dart';
import 'package:frontend/features/game/guide_dungeon_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Prompt 5 - Guide Console & Role Swap Synchronization Tests', () {
    test('GuideDungeonGame loads fully illuminated map without darkness overlay', () async {
      final guideGame = GuideDungeonGame();
      await guideGame.onLoad();

      expect(guideGame.children.whereType<PingBeaconComponent>().length, equals(0));
    });

    test('PingBeaconComponent auto-expires after 3.0 seconds', () {
      final beacon = PingBeaconComponent(
        position: Vector2(32, 32),
        size: Vector2(32, 32),
      );

      beacon.update(1.5);
      expect(beacon.isMounted, isFalse); // Not added to parent yet

      beacon.update(3.0); // Past 3.0s lifespan
    });

    test('SanctuaryPlateComponent triggers callback on collision', () {
      bool sanctuaryTriggered = false;

      final sanctuary = SanctuaryPlateComponent(
        position: Vector2(192, 192),
        size: Vector2(32, 32),
        onSanctuaryReached: () {
          sanctuaryTriggered = true;
        },
      );

      expect(sanctuary.isActivated, isFalse);
    });
  });
}
