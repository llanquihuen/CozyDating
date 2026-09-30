import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/lobby/screens/cozy_lobby_view.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/services/avatar_storage_service.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';
import 'package:frontend/features/lobby/lighting/room_lighting_renderer.dart';
import 'package:frontend/features/lobby/lighting/room_lighting_system.dart';
import 'package:frontend/features/lobby/screens/lighting_panel_sheet.dart';

CozyRoomGame _game({LightingConfig lighting = const LightingConfig(ceilingLights: []), List<String>? selections}) {
  return CozyRoomGame(
    avatarConfig: AvatarStorageService.getUserConfig('alice'),
    roomConfig: const RoomConfig(furniture: [], interiorWalls: []).copyWith(lighting: lighting),
    onCeilingLightSelected: selections == null ? null : (id) => selections.add(id ?? '<none>'),
  );
}

void main() {
  group('Phase 4 — ceiling light editing', () {
    test('add selects the new light; update, switch and delete keep config in sync', () {
      final selections = <String>[];
      final game = _game(selections: selections);

      final light = game.addCeilingLight();
      expect(game.roomConfig.lighting.ceilingLights, [light]);
      expect(game.selectedCeilingLightId, light.id);
      expect(selections, [light.id]);

      game.updateCeilingLight(light.id, (c) => c.copyWith(color: LightColor.cold, radius: 4));
      expect(game.selectedCeilingLight!.color, LightColor.cold);
      expect(game.selectedCeilingLight!.radius, 4);

      game.setLightOn(light.id, false);
      expect(game.selectedCeilingLight!.on, isFalse);

      game.deleteSelectedCeilingLight();
      expect(game.roomConfig.lighting.ceilingLights, isEmpty);
      expect(game.selectedCeilingLightId, isNull);
      expect(selections.last, '<none>');
    });

    test('master switch does not touch individual states and survives export', () {
      final game = _game(
        lighting: const LightingConfig(ceilingLights: [
          CeilingLightConfig(id: 'a', gridX: 2, gridY: 2),
          CeilingLightConfig(id: 'b', gridX: 6, gridY: 6, on: false),
        ]),
      );
      game.setLightingMasterOn(false);
      game.setLightingAmbient(AmbientMode.night);
      final exported = game.exportCurrentRoomConfig();
      expect(exported.lighting.masterOn, isFalse);
      expect(exported.lighting.ambient, AmbientMode.night);
      expect(exported.lighting.ceilingLights.map((c) => c.on), [true, false]);
      expect(RoomConfig.fromJson(exported.toJson()).lighting, exported.lighting);
    });

    test('master switch only gates ceiling lights; lamps and objects are untouched', () {
      final game = _game(lighting: const LightingConfig(ceilingLights: [CeilingLightConfig(id: 'c1', gridX: 2, gridY: 2)]));
      game.lighting.setLights(const [
        LightSourceDef(id: 'c1', u: 4, v: 4, radius: 6, color: Color(0xFFFFFFFF), isCeiling: true),
        LightSourceDef(id: 'lamp', u: 8, v: 8, radius: 4, color: Color(0xFFFFC48A), affectedByMaster: false),
        LightSourceDef(id: 'desk', u: 12, v: 12, radius: 4, color: Color(0xFFB388FF), affectedByMaster: false, on: false),
      ]);
      game.lighting.settle();

      game.setLightingMasterOn(false);
      game.lighting.update(1);
      expect(game.lighting.lightById('c1')!.level, 0, reason: 'ceiling gated');
      expect(game.ceilingLightById('c1')!.on, isTrue, reason: 'ceiling keeps its own state');
      expect(game.isLightOn('lamp'), isTrue, reason: 'lamp untouched by the master');
      expect(game.lighting.lightById('lamp')!.level, 1);

      // Objects stay freely switchable while the master is off.
      game.setLightOn('desk', true);
      game.setLightOn('lamp', false);
      game.lighting.update(1);
      expect(game.lighting.lightById('desk')!.level, 1);
      expect(game.lighting.lightById('lamp')!.level, 0);

      game.setLightingMasterOn(true);
      game.lighting.update(1);
      expect(game.lighting.lightById('c1')!.level, 1);
      expect(game.isLightOn('lamp'), isFalse, reason: 'master never switches objects back on');
      expect(game.isLightOn('desk'), isTrue);
    });

    test('automatic ambient follows the injected clock; manual pick sticks', () {
      final game = _game();
      var now = DateTime(2026, 9, 30, 12);
      game.clock = () => now;
      expect(game.effectiveAmbient, AmbientMode.day);
      now = DateTime(2026, 9, 30, 22);
      expect(game.effectiveAmbient, AmbientMode.night);

      game.setLightingAmbient(AmbientMode.evening);
      expect(game.effectiveAmbient, AmbientMode.evening);
      expect(game.lighting.ambient, AmbientMode.evening);

      game.setLightingAmbientAuto();
      expect(game.effectiveAmbient, AmbientMode.night);
      expect(game.lighting.ambient, AmbientMode.night);
      expect(game.exportCurrentRoomConfig().lighting.autoAmbient, isTrue);
    });

    test('drag math: floor screen point ↔ sub-grid round-trips', () {
      for (final (u, v) in [(0.0, 0.0), (3.0, 11.0), (8.5, 2.25), (16.0, 16.0)]) {
        final p = lightingSubGridToScreen(u, v);
        final back = lightingScreenToSubGrid(p.dx, p.dy);
        expect(back.dx, closeTo(u, 1e-9));
        expect(back.dy, closeTo(v, 1e-9));
      }
    });

    test('sector names fall back to "Sala" without furniture', () {
      final game = _game();
      expect(game.lightSectorNames(), {0: 'Sala'});
    });
  });

  group('Phase 4 — lights panel', () {
    Future<(CozyRoomGame, List<int>)> pumpPanel(WidgetTester tester, LightingConfig lighting) async {
      final game = _game(lighting: lighting);
      final changes = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: LightingPanelSheet(game: game, onChanged: () => changes.add(1)),
          ),
        ),
      ));
      return (game, changes);
    }

    testWidgets('master switch, ambient and per-light switch drive the game', (tester) async {
      final (game, changes) = await pumpPanel(
        tester,
        const LightingConfig(ceilingLights: [CeilingLightConfig(id: 'c1', gridX: 4, gridY: 4)]),
      );
      expect(find.text('Luz de techo 1'), findsOneWidget);
      expect(find.text('SALA'), findsOneWidget);

      // Master switch is the first Switch in the header.
      await tester.tap(find.byType(Switch).first);
      await tester.pump();
      expect(game.roomConfig.lighting.masterOn, isFalse);
      expect(find.textContaining('no se ven afectados'), findsOneWidget);
      expect(game.ceilingLightById('c1')!.on, isTrue, reason: 'individual state untouched');

      // Automatic by default; picking a mode by hand switches it off, and Auto brings it back.
      expect(game.isAmbientAuto, isTrue);
      expect(find.textContaining('Sigue la hora del teléfono'), findsOneWidget);
      await tester.tap(find.text('Noche'));
      await tester.pump();
      expect(game.roomConfig.lighting.ambient, AmbientMode.night);
      expect(game.isAmbientAuto, isFalse);
      expect(find.textContaining('Sigue la hora del teléfono'), findsNothing);
      await tester.tap(find.text('Auto'));
      await tester.pump();
      expect(game.isAmbientAuto, isTrue);
      await tester.tap(find.text('Noche'));
      await tester.pump();

      await tester.tap(find.byType(Switch).last);
      await tester.pump();
      expect(game.ceilingLightById('c1')!.on, isFalse);
      expect(changes.length, 5);
    });

    testWidgets('ceiling row expands to colour chips', (tester) async {
      final (game, _) = await pumpPanel(
        tester,
        const LightingConfig(ceilingLights: [CeilingLightConfig(id: 'c1', gridX: 4, gridY: 4)]),
      );
      await tester.tap(find.text('Luz de techo 1'));
      await tester.pump();
      await tester.tap(find.text('Fría'));
      await tester.pump();
      expect(game.ceilingLightById('c1')!.color, LightColor.cold);
    });

    testWidgets('empty state explains how to add ceiling lights', (tester) async {
      await pumpPanel(tester, const LightingConfig(ceilingLights: []));
      expect(find.textContaining('Aún no tienes luces de techo'), findsOneWidget);
    });
  });

  group('Phase 4 — lobby integration', () {
    Future<void> pumpLobby(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<GameBloc>.value(
          value: GameBloc(webSocketClient: WebSocketClient()),
          child: CozyLobbyView(activeUserId: 'alice', onUserChanged: (_) {}),
        ),
      ));
    }

    testWidgets('lights button: tap = general switch, tune icon = panel', (tester) async {
      await pumpLobby(tester);
      expect(find.text('Luces'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lights_master_button')));
      await tester.pump();
      expect(find.text('🌑 Luces de techo apagadas'), findsOneWidget);

      await tester.tap(find.byKey(const Key('lights_panel_button')));
      await tester.pumpAndSettle();
      expect(find.text('💡 Iluminación'), findsOneWidget);
      expect(find.text('Techo apagado'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3)); // let the debounced save + toast timers run
    });

    testWidgets('decorate mode offers "Luz de techo" and the new light shows in the panel', (tester) async {
      await pumpLobby(tester);
      await tester.tap(find.text('Mi Hogar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decorar Muebles'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_ceiling_light_button')));
      await tester.pump();
      expect(find.textContaining('Luz de techo agregada'), findsOneWidget);

      // The new light is selected, so its floating toolbar follows it every frame and
      // pumpAndSettle would never settle — pump fixed steps instead.
      expect(find.byTooltip('Color, intensidad y alcance'), findsOneWidget);
      await tester.tap(find.byKey(const Key('lights_panel_button')));
      await tester.pump(const Duration(milliseconds: 500));
      // The default room already has 4 ceiling lights, so the new one is the 5th (further
      // down the panel's list — scroll to it).
      await tester.scrollUntilVisible(find.text('Luz de techo 5'), 80, scrollable: find.byType(Scrollable).last);
      expect(find.text('Luz de techo 5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
