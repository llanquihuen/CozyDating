import 'dart:convert';
import 'avatar_config.dart';
import 'room_config.dart';

class UserProfile {
  final String id;
  final String username;
  final String? email;
  final int age;
  final String commune;
  final int ticketsBalance;
  final AvatarConfig avatarConfig;
  final List<String> tastes;
  final RoomConfig roomConfig;

  const UserProfile({
    required this.id,
    required this.username,
    this.email,
    this.age = 20,
    this.commune = 'Santiago',
    this.ticketsBalance = 5,
    this.avatarConfig = const AvatarConfig(),
    this.tastes = const [],
    this.roomConfig = const RoomConfig(),
  });

  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    int? age,
    String? commune,
    int? ticketsBalance,
    AvatarConfig? avatarConfig,
    List<String>? tastes,
    RoomConfig? roomConfig,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      age: age ?? this.age,
      commune: commune ?? this.commune,
      ticketsBalance: ticketsBalance ?? this.ticketsBalance,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      tastes: tastes ?? this.tastes,
      roomConfig: roomConfig ?? this.roomConfig,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      if (email != null) 'email': email,
      'age': age,
      'commune': commune,
      'ticketsBalance': ticketsBalance,
      'avatarConfig': jsonEncode(avatarConfig.toJson()),
      'tastes': jsonEncode(tastes),
      'roomConfig': roomConfig.toJson(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    AvatarConfig avatar;
    try {
      final rawAvatar = map['avatarConfig'];
      if (rawAvatar is String && rawAvatar.isNotEmpty && rawAvatar != '{}') {
        final decoded = jsonDecode(rawAvatar);
        if (decoded is Map<String, dynamic>) {
          avatar = AvatarConfig.fromJson(decoded);
        } else {
          avatar = const AvatarConfig();
        }
      } else if (rawAvatar is Map<String, dynamic>) {
        avatar = AvatarConfig.fromJson(rawAvatar);
      } else {
        avatar = const AvatarConfig();
      }
    } catch (_) {
      avatar = const AvatarConfig();
    }

    RoomConfig room;
    try {
      final rawRoom = map['roomConfig'];
      if (rawRoom is String && rawRoom.isNotEmpty && rawRoom != '{}') {
        room = RoomConfig.fromJson(rawRoom);
      } else if (rawRoom is Map<String, dynamic>) {
        room = RoomConfig.fromMap(rawRoom);
      } else {
        room = const RoomConfig();
      }
    } catch (_) {
      room = const RoomConfig();
    }

    List<String> parsedTastes = [];
    try {
      final rawTastes = map['tastes'];
      if (rawTastes is String && rawTastes.isNotEmpty) {
        final decoded = jsonDecode(rawTastes);
        if (decoded is List) {
          parsedTastes = List<String>.from(decoded);
        }
      } else if (rawTastes is List) {
        parsedTastes = List<String>.from(rawTastes);
      }
    } catch (_) {
      parsedTastes = [];
    }

    return UserProfile(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      email: map['email'],
      age: (map['age'] as num?)?.toInt() ?? 20,
      commune: map['commune'] ?? 'Santiago',
      ticketsBalance: (map['ticketsBalance'] as num?)?.toInt() ?? 5,
      avatarConfig: avatar,
      tastes: parsedTastes,
      roomConfig: room,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(jsonDecode(source));
}
