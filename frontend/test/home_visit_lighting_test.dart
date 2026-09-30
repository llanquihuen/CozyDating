import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/room_config.dart';
import 'package:frontend/core/models/user_profile.dart';
import 'package:frontend/core/network/websocket_client.dart';
import 'package:frontend/features/game/bloc/game_bloc.dart';
import 'package:frontend/features/home_visit/screens/home_visit_view.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';
import 'package:frontend/features/lobby/lighting/room_lighting_system.dart';

class _MockWebSocketClient extends WebSocketClient {
  final List<Map<String, dynamic>> sentMessages = [];
  final StreamController<Map<String, dynamic>> _messages = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<WebSocketConnectionState> get stateStream => Stream.value(WebSocketConnectionState.connected);

  @override
  Stream<Map<String, dynamic>> get messageStream => _messages.stream;

  void addMessage(Map<String, dynamic> msg) => _messages.add(msg);

  @override
  Future<void> connect(String url, String token) async {}

  @override
  void sendMessage(Map<String, dynamic> data) => sentMessages.add(data);

  @override
  void dispose() {
    _messages.close();
    super.dispose();
  }
}

const _sessionInit = {
  'type': 'SESSION_INIT',
  'roomId': 'room_home_light',
  'role': 'EXPLORER',
  'act': 1,
  'seed': 1,
  'mode': 'HOME',
  'isHomeVisitActive': true,
  'hostUserId': 'host',
  'partnerId': 'guest',
  'partnerUsername': 'Bob',
};

CozyRoomGame _gameWith(List<LightSourceDef> lights, {LightingConfig? lighting, VoidCallback? onChanged}) {
  final game = CozyRoomGame(
    avatarConfig: const AvatarConfig(),
    roomConfig: RoomConfig(lighting: lighting ?? const LightingConfig(ceilingLights: [])),
    onLightingChanged: onChanged,
  );
  game.lighting.setLights(lights);
  game.lighting.settle();
  return game;
}

const _emitters = [
  LightSourceDef(id: 'lamp', u: 8, v: 8, radius: 4, color: Color(0xFFFFC48A), affectedByMaster: false),
  LightSourceDef(id: 'tv', u: 10, v: 10, radius: 4, color: Color(0xFF9EC9FF), affectedByMaster: false, on: false),
  LightSourceDef(
      id: 'win', u: 7, v: 1.5, radius: 6, color: Color(0xFFD6E6FF), anim: LightAnim.daylight,
      affectedByMaster: false, toggleable: false),
];

void main() {
  group('Phase 7 — lighting snapshot', () {
    test('host snapshot applied on the guest reproduces the same lighting, without echo', () {
      final host = _gameWith(
        [
          const LightSourceDef(id: 'c1', u: 4, v: 4, radius: 6, color: Color(0xFFFFFFFF), isCeiling: true),
          ..._emitters,
        ],
        lighting: const LightingConfig(ceilingLights: [CeilingLightConfig(id: 'c1', gridX: 2, gridY: 2)]),
      );
      host.setLightingMasterOn(false);
      host.setLightingAmbient(AmbientMode.night);
      host.setLightOn('lamp', false);
      host.setLightOn('tv', true);

      final snap = host.lightingSnapshot();
      expect(snap['emitters'], {'lamp': false, 'tv': true}, reason: 'windows are not switchable, not sent');

      var echoes = 0;
      final guest = _gameWith([..._emitters], onChanged: () => echoes++);
      guest.applyLightingSnapshot(snap);

      expect(guest.roomConfig.lighting, host.roomConfig.lighting);
      expect(guest.effectiveAmbient, AmbientMode.night);
      expect(guest.lighting.masterOn, isFalse);
      expect(guest.isLightOn('lamp'), isFalse);
      expect(guest.isLightOn('tv'), isTrue);
      expect(echoes, 0, reason: 'applying a remote snapshot must not broadcast it back');
    });

    test('snapshot survives the JSON round trip of the socket', () {
      final host = _gameWith([..._emitters]);
      host.setLightingAmbient(AmbientMode.evening);
      final wire = <String, dynamic>{'type': 'HOME_LIGHTING', ...host.lightingSnapshot()};
      // What the relay hands over: plain JSON maps.
      final received = Map<String, dynamic>.from(wire);
      final guest = _gameWith([..._emitters]);
      guest.applyLightingSnapshot({'lighting': received['lighting'], 'emitters': received['emitters']});
      expect(guest.roomConfig.lighting.ambient, AmbientMode.evening);
      expect(guest.roomConfig.lighting.autoAmbient, isFalse);
    });
  });

  group('Phase 7 — GameBloc HOME_LIGHTING', () {
    late _MockWebSocketClient ws;
    late GameBloc bloc;

    setUp(() {
      ws = _MockWebSocketClient();
      bloc = GameBloc(webSocketClient: ws);
    });

    tearDown(() {
      bloc.close();
      ws.dispose();
    });

    test('sends a snapshot and a request', () async {
      bloc.add(const SendHomeLightingEvent(snapshot: {
        'lighting': {'masterOn': false},
        'emitters': {'lamp': true},
      }));
      bloc.add(const SendHomeLightingEvent(request: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final sent = ws.sentMessages.where((m) => m['type'] == 'HOME_LIGHTING').toList();
      expect(sent, hasLength(2));
      expect(sent[0]['lighting'], {'masterOn': false});
      expect(sent[0]['emitters'], {'lamp': true});
      expect(sent[0].containsKey('request'), isFalse);
      expect(sent[1]['request'], isTrue);
    });

    test('incoming snapshot and request land in the state', () async {
      ws.addMessage(Map<String, dynamic>.from(_sessionInit));
      await expectLater(bloc.stream, emitsThrough(isA<ActiveGameState>()));

      ws.addMessage({
        'type': 'HOME_LIGHTING',
        'lighting': {'masterOn': false},
        'emitters': {'tv': true},
      });
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<GameState>((s) =>
            s is ActiveGameState &&
            s.partnerHomeLightingTrigger != null &&
            (s.partnerHomeLighting!['emitters'] as Map)['tv'] == true)),
      );

      ws.addMessage({'type': 'HOME_LIGHTING', 'request': true});
      await expectLater(
        bloc.stream,
        emitsThrough(predicate<GameState>((s) => s is ActiveGameState && s.homeLightingRequestTrigger != null)),
      );
    });
  });

  group('Phase 7 — HomeVisitView', () {
    const host = UserProfile(id: 'host', username: 'Alice', avatarConfig: AvatarConfig(), roomConfig: RoomConfig());
    const guest = UserProfile(id: 'guest', username: 'Bob', avatarConfig: AvatarConfig(), roomConfig: RoomConfig());

    Future<(_MockWebSocketClient, GameBloc)> pumpVisit(WidgetTester tester, {required bool isHost}) async {
      final ws = _MockWebSocketClient();
      final bloc = GameBloc(webSocketClient: ws);
      addTearDown(() {
        bloc.close();
        ws.dispose();
      });
      await tester.pumpWidget(MaterialApp(
        home: BlocProvider<GameBloc>.value(
          value: bloc,
          child: HomeVisitView(
            localUser: isHost ? host : guest,
            partnerUser: isHost ? guest : host,
            isHost: isHost,
            hostName: 'Alice',
            hostRoomConfig: const RoomConfig(),
            onLeave: () {},
          ),
        ),
      ));
      await tester.pump();
      return (ws, bloc);
    }

    testWidgets('guest asks for the live lighting on arrival and has no lights button', (tester) async {
      final (ws, _) = await pumpVisit(tester, isHost: false);
      expect(ws.sentMessages.where((m) => m['type'] == 'HOME_LIGHTING' && m['request'] == true), hasLength(1));
      expect(find.byKey(const Key('visit_lights_master_button')), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('host: lights button broadcasts a snapshot; a guest request is answered', (tester) async {
      final (ws, _) = await pumpVisit(tester, isHost: true);
      expect(ws.sentMessages.where((m) => m['type'] == 'HOME_LIGHTING'), isEmpty, reason: 'host does not request');

      await tester.tap(find.byKey(const Key('visit_lights_master_button')));
      await tester.pump();
      final sent = ws.sentMessages.where((m) => m['type'] == 'HOME_LIGHTING').toList();
      expect(sent, hasLength(1));
      expect((sent.single['lighting'] as Map)['masterOn'], isFalse);

      ws.addMessage(Map<String, dynamic>.from(_sessionInit));
      await tester.pump(const Duration(milliseconds: 50));
      ws.addMessage({'type': 'HOME_LIGHTING', 'request': true});
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(ws.sentMessages.where((m) => m['type'] == 'HOME_LIGHTING'), hasLength(2));
      await tester.pump(const Duration(seconds: 5)); // flush toast + debounced save timers
    });
  });
}
