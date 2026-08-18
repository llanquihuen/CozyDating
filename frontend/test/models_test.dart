import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/game_models.dart';

void main() {
  group('Dart Network Models Serialization Tests', () {
    test('PlayerProfileMini Serialization', () {
      final profile = PlayerProfileMini(
        userId: 'userA',
        username: 'Alice',
        commune: 'Santiago',
        age: 25,
      );

      final jsonMap = profile.toJson();
      expect(jsonMap['userId'], 'userA');
      expect(jsonMap['username'], 'Alice');
      expect(jsonMap['commune'], 'Santiago');
      expect(jsonMap['age'], 25);

      final decoded = PlayerProfileMini.fromJson(jsonMap);
      expect(decoded.userId, 'userA');
      expect(decoded.username, 'Alice');
      expect(decoded.commune, 'Santiago');
      expect(decoded.age, 25);
    });

    test('SessionInitPayload Serialization', () {
      final payload = SessionInitPayload(
        roomId: 'room_1234',
        role: 'EXPLORER',
        mode: 'VOICE',
        livekitToken: 'tokenA',
        partnerId: 'userB',
      );

      final jsonMap = payload.toJson();
      expect(jsonMap['roomId'], 'room_1234');
      expect(jsonMap['role'], 'EXPLORER');
      expect(jsonMap['mode'], 'VOICE');
      expect(jsonMap['livekitToken'], 'tokenA');
      expect(jsonMap['partnerId'], 'userB');

      final decoded = SessionInitPayload.fromJson(jsonMap);
      expect(decoded.roomId, 'room_1234');
      expect(decoded.role, 'EXPLORER');
      expect(decoded.mode, 'VOICE');
      expect(decoded.livekitToken, 'tokenA');
      expect(decoded.partnerId, 'userB');
    });

    test('DungeonStatePayload Serialization', () {
      final payload = DungeonStatePayload(
        playerX: 10.5,
        playerY: 20.0,
        role: 'EXPLORER',
        activeTraps: {'trap1': true},
        blockPositions: {'blockA': {'x': 2, 'y': 3}},
      );

      final jsonMap = payload.toJson();
      expect(jsonMap['playerX'], 10.5);
      expect(jsonMap['playerY'], 20.0);
      expect(jsonMap['role'], 'EXPLORER');
      expect(jsonMap['activeTraps']['trap1'], true);

      final decoded = DungeonStatePayload.fromJson(jsonMap);
      expect(decoded.playerX, 10.5);
      expect(decoded.playerY, 20.0);
      expect(decoded.role, 'EXPLORER');
      expect(decoded.activeTraps['trap1'], true);
    });

    test('GameMessage Serialization', () {
      final msg = GameMessage(
        type: 'PLAYER_MOVE',
        payload: {
          'playerX': 5.0,
          'playerY': 7.0,
          'role': 'GUIDE',
        },
      );

      final rawString = msg.toJsonString();
      final decodedMap = jsonDecode(rawString) as Map<String, dynamic>;
      
      expect(decodedMap['type'], 'PLAYER_MOVE');
      expect(decodedMap['playerX'], 5.0);
      expect(decodedMap['playerY'], 7.0);
      expect(decodedMap['role'], 'GUIDE');
    });
  });
}
