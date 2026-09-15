import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/game_models.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/game/components/darkness_overlay_component.dart';
import 'package:frontend/features/game/dungeon_game.dart';
import 'package:frontend/features/game/game_view.dart';
import 'package:frontend/features/game/services/dungeon_generator.dart';

class _MockWebSocketClient extends WebSocketClient {
  @override
  Stream<WebSocketConnectionState> get stateStream => Stream.value(WebSocketConnectionState.connected);
  @override
  Stream<Map<String, dynamic>> get messageStream => const Stream.empty();
  @override
  Future<void> connect(String url, String token) async {}
  @override
  void sendMessage(Map<String, dynamic> data) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('360 Flashlight Aiming & Angle Mapping Tests', () {
    test('DungeonGame.angleToAvatarDirection maps all 8 sectors accurately', () {
      // 0 rad -> East
      expect(DungeonGame.angleToAvatarDirection(0.0), AvatarDirection.east);
      expect(DungeonGame.angleToAvatarDirection(0.1), AvatarDirection.east);
      expect(DungeonGame.angleToAvatarDirection(-0.1), AvatarDirection.east);

      // pi / 4 (45 deg) -> SouthEast
      expect(DungeonGame.angleToAvatarDirection(pi / 4), AvatarDirection.southEast);

      // pi / 2 (90 deg) -> South
      expect(DungeonGame.angleToAvatarDirection(pi / 2), AvatarDirection.south);

      // 3 * pi / 4 (135 deg) -> SouthWest
      expect(DungeonGame.angleToAvatarDirection(3 * pi / 4), AvatarDirection.southWest);

      // pi or -pi (180 deg) -> West
      expect(DungeonGame.angleToAvatarDirection(pi), AvatarDirection.west);
      expect(DungeonGame.angleToAvatarDirection(-pi), AvatarDirection.west);

      // -3 * pi / 4 (-135 deg) -> NorthWest
      expect(DungeonGame.angleToAvatarDirection(-3 * pi / 4), AvatarDirection.northWest);

      // -pi / 2 (-90 deg) -> North
      expect(DungeonGame.angleToAvatarDirection(-pi / 2), AvatarDirection.north);

      // -pi / 4 (-45 deg) -> NorthEast
      expect(DungeonGame.angleToAvatarDirection(-pi / 4), AvatarDirection.northEast);
    });

    test('aimFlashlightAtWorld updates customFlashlightAngle and avatar facing', () async {
      final mapData = DungeonGenerator.generateMap(seed: 12345, act: 1);
      final gameWithAim = DungeonGame(
        dungeonMapData: mapData,
      );
      bool aimCallbackTriggered = false;
      final testGame = DungeonGame(
        dungeonMapData: mapData,
        onFlashlightAim: () => aimCallbackTriggered = true,
      );
      await testGame.onLoad();

      final feetPos = testGame.explorer.feetPosition;

      // Aim to the right (East)
      testGame.aimFlashlightAtWorld(feetPos + Vector2(100, 0));
      expect(testGame.customFlashlightAngle, isNotNull);
      expect((testGame.customFlashlightAngle! - 0.0).abs() < 0.01, isTrue);
      expect(testGame.explorer.avatarRenderer.direction, AvatarDirection.east);
      expect(aimCallbackTriggered, isTrue);

      // Aim upwards (North)
      testGame.aimFlashlightAtWorld(feetPos + Vector2(0, -100));
      expect((testGame.customFlashlightAngle! - (-pi / 2)).abs() < 0.01, isTrue);
      expect(testGame.explorer.avatarRenderer.direction, AvatarDirection.north);

      // Aim diagonal down-left (SouthWest)
      testGame.aimFlashlightAtWorld(feetPos + Vector2(-100, 100));
      expect(testGame.explorer.avatarRenderer.direction, AvatarDirection.southWest);

      // Moving explorer resets customFlashlightAngle so movement direction takes over
      testGame.explorer.setMovementDirection(Vector2(0, 1));
      expect(testGame.customFlashlightAngle, isNull);
    });

    test('DarknessOverlayComponent tracks customFlashlightAngle smoothly', () async {
      final mapData = DungeonGenerator.generateMap(seed: 12345, act: 1);
      final game = DungeonGame(dungeonMapData: mapData);
      await game.onLoad();

      final overlay = game.world.children.whereType<DarknessOverlayComponent>().first;
      final feetPos = game.explorer.feetPosition;

      // Aim East (0 rad)
      game.aimFlashlightAtWorld(feetPos + Vector2(100, 0));
      expect(game.customFlashlightAngle, isNotNull);

      // Advance game time to let overlay interpolate
      for (int i = 0; i < 20; i++) {
        game.update(0.016);
      }

      // Raycast testing at aiming direction
      final hitPoint = overlay.castRayForTesting(feetPos.toOffset(), game.customFlashlightAngle!, 100.0);
      expect(hitPoint.dx, greaterThan(feetPos.x));
    });

    testWidgets('GameView displays 360 flashlight hand hint and dismisses on timer', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final session = SessionInitPayload(
        roomId: 'test-room-1',
        role: 'EXPLORER',
        mode: 'STANDARD',
        partnerId: 'partner-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider(
            create: (_) => GameBloc(webSocketClient: _MockWebSocketClient()),
            child: GameView(state: ActiveGameState(session: session)),
          ),
        ),
      );

      // Before map finishes loading, tutorial hint is NOT visible (user requirement)
      expect(find.text('Toca o arrastra para girar la linterna en 360°'), findsNothing);

      // Advance time for map and components to finish loading
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.text('Toca o arrastra para girar la linterna en 360°'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsOneWidget);

      // Advance past tutorial animation duration: auto-dismisses
      await tester.pump(const Duration(milliseconds: 2800));
      await tester.pump();
      expect(find.text('Toca o arrastra para girar la linterna en 360°'), findsNothing);
    });
  });
}
