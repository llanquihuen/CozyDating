import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'avatar_config.dart';
import 'room_config.dart';

class PlayerProfileMini extends Equatable {
  final String userId;
  final String username;
  final String commune;
  final int age;

  const PlayerProfileMini({
    required this.userId,
    required this.username,
    required this.commune,
    required this.age,
  });

  factory PlayerProfileMini.fromJson(Map<String, dynamic> json) {
    return PlayerProfileMini(
      userId: json['userId'] as String? ?? '',
      username: json['username'] as String? ?? '',
      commune: json['commune'] as String? ?? '',
      age: (json['age'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'commune': commune,
      'age': age,
    };
  }

  @override
  List<Object?> get props => [userId, username, commune, age];
}

class GameMessage extends Equatable {
  final String type;
  final Map<String, dynamic> payload;

  const GameMessage({required this.type, required this.payload});

  factory GameMessage.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final payload = Map<String, dynamic>.from(json)..remove('type');
    return GameMessage(type: type, payload: payload);
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      ...payload,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  @override
  List<Object?> get props => [type, payload];
}

class SessionInitPayload extends Equatable {
  final String roomId;
  final String role;
  final String mode;
  final String? livekitToken;
  final String partnerId;
  final String? partnerUsername;
  final AvatarConfig? partnerAvatarConfig;
  final RoomConfig? partnerRoomConfig;
  final int act;
  final int? seed;

  const SessionInitPayload({
    required this.roomId,
    required this.role,
    required this.mode,
    this.livekitToken,
    required this.partnerId,
    this.partnerUsername,
    this.partnerAvatarConfig,
    this.partnerRoomConfig,
    this.act = 1,
    this.seed,
  });

  factory SessionInitPayload.fromJson(Map<String, dynamic> json) {
    AvatarConfig? avatar;
    if (json['partnerAvatarConfig'] != null) {
      if (json['partnerAvatarConfig'] is Map) {
        avatar = AvatarConfig.fromJson(Map<String, dynamic>.from(json['partnerAvatarConfig'] as Map));
      }
    }

    RoomConfig? room;
    if (json['partnerRoomConfig'] != null) {
      if (json['partnerRoomConfig'] is Map) {
        room = RoomConfig.fromMap(Map<String, dynamic>.from(json['partnerRoomConfig'] as Map));
      }
    }

    return SessionInitPayload(
      roomId: json['roomId'] as String? ?? '',
      role: json['role'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      livekitToken: json['livekitToken'] as String?,
      partnerId: json['partnerId'] as String? ?? '',
      partnerUsername: json['partnerUsername'] as String?,
      partnerAvatarConfig: avatar,
      partnerRoomConfig: room,
      act: (json['act'] as num?)?.toInt() ?? 1,
      seed: (json['seed'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'role': role,
      'mode': mode,
      'livekitToken': livekitToken,
      'partnerId': partnerId,
      if (partnerUsername != null) 'partnerUsername': partnerUsername,
      if (partnerAvatarConfig != null) 'partnerAvatarConfig': partnerAvatarConfig!.toJson(),
      if (partnerRoomConfig != null) 'partnerRoomConfig': partnerRoomConfig!.toMap(),
      'act': act,
      'seed': seed,
    };
  }

  @override
  List<Object?> get props => [
    roomId,
    role,
    mode,
    livekitToken,
    partnerId,
    partnerUsername,
    partnerAvatarConfig,
    partnerRoomConfig,
    act,
    seed,
  ];
}

class DungeonStatePayload extends Equatable {
  final double playerX;
  final double playerY;
  final double? chaserX;
  final double? chaserY;
  final String role;
  final String direction;
  final bool isMoving;
  final Map<String, dynamic> activeTraps;
  final Map<String, dynamic> blockPositions;

  const DungeonStatePayload({
    required this.playerX,
    required this.playerY,
    this.chaserX,
    this.chaserY,
    required this.role,
    this.direction = 'down',
    this.isMoving = false,
    required this.activeTraps,
    required this.blockPositions,
  });

  factory DungeonStatePayload.fromJson(Map<String, dynamic> json) {
    return DungeonStatePayload(
      playerX: (json['playerX'] as num?)?.toDouble() ?? 0.0,
      playerY: (json['playerY'] as num?)?.toDouble() ?? 0.0,
      chaserX: (json['chaserX'] as num?)?.toDouble(),
      chaserY: (json['chaserY'] as num?)?.toDouble(),
      role: json['role'] as String? ?? 'EXPLORER',
      direction: json['direction'] as String? ?? 'down',
      isMoving: json['isMoving'] as bool? ?? false,
      activeTraps: json['activeTraps'] as Map<String, dynamic>? ?? const {},
      blockPositions: json['blockPositions'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'playerX': playerX,
      'playerY': playerY,
      'chaserX': chaserX,
      'chaserY': chaserY,
      'role': role,
      'direction': direction,
      'isMoving': isMoving,
      'activeTraps': activeTraps,
      'blockPositions': blockPositions,
    };
  }

  @override
  List<Object?> get props => [
        playerX,
        playerY,
        chaserX,
        chaserY,
        role,
        direction,
        isMoving,
        activeTraps,
        blockPositions,
      ];
}
