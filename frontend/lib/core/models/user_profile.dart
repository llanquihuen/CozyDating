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
  final int coinsBalance;
  final AvatarConfig avatarConfig;
  final List<String> tastes;
  final String? profilePhoto;
  final List<String> photos;
  final String bio;
  final String intent;
  final double maxDistanceKm;
  final RoomConfig roomConfig;

  const UserProfile({
    required this.id,
    required this.username,
    this.email,
    this.age = 20,
    this.commune = 'Santiago',
    this.ticketsBalance = 5,
    this.coinsBalance = 100,
    this.avatarConfig = const AvatarConfig(),
    this.tastes = const [],
    this.profilePhoto,
    this.photos = const [],
    this.bio = '',
    this.intent = 'intent_slow',
    this.maxDistanceKm = 25.0,
    this.roomConfig = const RoomConfig(),
  });

  /// Primary photo for fallback/compatibility
  String? get primaryPhoto => photos.isNotEmpty ? photos.first : profilePhoto;

  /// Guaranteed list of photos (minimum 1 fallback if photo exists)
  List<String> get allPhotos {
    if (photos.isNotEmpty) return photos;
    if (profilePhoto != null && profilePhoto!.isNotEmpty) return [profilePhoto!];
    return const [];
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? email,
    int? age,
    String? commune,
    int? ticketsBalance,
    int? coinsBalance,
    AvatarConfig? avatarConfig,
    List<String>? tastes,
    String? profilePhoto,
    List<String>? photos,
    String? bio,
    String? intent,
    double? maxDistanceKm,
    RoomConfig? roomConfig,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      age: age ?? this.age,
      commune: commune ?? this.commune,
      ticketsBalance: ticketsBalance ?? this.ticketsBalance,
      coinsBalance: coinsBalance ?? this.coinsBalance,
      avatarConfig: avatarConfig ?? this.avatarConfig,
      tastes: tastes ?? this.tastes,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      photos: photos ?? this.photos,
      bio: bio ?? this.bio,
      intent: intent ?? this.intent,
      maxDistanceKm: maxDistanceKm ?? this.maxDistanceKm,
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
      'coinsBalance': coinsBalance,
      'avatarConfig': jsonEncode(avatarConfig.toJson()),
      'tastes': jsonEncode(tastes),
      if (primaryPhoto != null) 'profilePhoto': primaryPhoto,
      'photos': jsonEncode(allPhotos),
      'bio': bio,
      'intent': intent,
      'maxDistanceKm': maxDistanceKm,
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

    List<String> parsedPhotos = [];
    try {
      final rawPhotos = map['photos'];
      if (rawPhotos is String && rawPhotos.isNotEmpty) {
        final decoded = jsonDecode(rawPhotos);
        if (decoded is List) {
          parsedPhotos = List<String>.from(decoded);
        }
      } else if (rawPhotos is List) {
        parsedPhotos = List<String>.from(rawPhotos);
      }
    } catch (_) {
      parsedPhotos = [];
    }

    final singlePhoto = map['profilePhoto'] as String?;
    if (parsedPhotos.isEmpty && singlePhoto != null && singlePhoto.isNotEmpty) {
      parsedPhotos = [singlePhoto];
    }

    return UserProfile(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      email: map['email'],
      age: (map['age'] as num?)?.toInt() ?? 20,
      commune: map['commune'] ?? 'Santiago',
      ticketsBalance: (map['ticketsBalance'] as num?)?.toInt() ?? 5,
      coinsBalance: (map['coinsBalance'] as num?)?.toInt() ?? 100,
      avatarConfig: avatar,
      tastes: parsedTastes,
      profilePhoto: singlePhoto,
      photos: parsedPhotos,
      bio: map['bio'] as String? ?? '',
      intent: map['intent'] as String? ?? 'intent_slow',
      maxDistanceKm: (map['maxDistanceKm'] as num?)?.toDouble() ?? 25.0,
      roomConfig: room,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(jsonDecode(source));
}
