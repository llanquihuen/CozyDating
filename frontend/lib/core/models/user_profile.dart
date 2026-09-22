import 'dart:convert';
import 'avatar_config.dart';
import 'lifestyle_badges.dart';
import 'preference_tags.dart';
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
  final bool isVerified;
  final String? verificationSelfie;
  final String gender;
  final String seekingGender;
  final bool isInternational;
  final double? latitude;
  final double? longitude;
  final LifestyleBadges lifestyle;

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
    this.isVerified = false,
    this.verificationSelfie,
    this.gender = 'OTHER',
    this.seekingGender = 'ANY',
    this.isInternational = false,
    this.latitude,
    this.longitude,
    this.lifestyle = const LifestyleBadges(),
  });

  /// Primary photo for fallback/compatibility
  String? get primaryPhoto => (profilePhoto != null && profilePhoto!.isNotEmpty)
      ? profilePhoto
      : (photos.isNotEmpty ? photos.first : null);

  /// Guaranteed list of photos (minimum 1 fallback if photo exists)
  List<String> get allPhotos {
    final list = <String>[];
    if (profilePhoto != null && profilePhoto!.isNotEmpty) {
      list.add(profilePhoto!);
    }
    for (final p in photos) {
      if (!list.contains(p)) {
        list.add(p);
      }
    }
    return list;
  }

  /// Formatted user-facing dating intent string (e.g. '🌱 Conocer sin prisa (Slow Dating)')
  String get formattedIntent => PreferenceCatalog.formatIntent(intent);

  /// Intent emoji (e.g. '🌱', '💍', '🎮', '☕')
  String get intentEmoji => PreferenceCatalog.getIntentEmoji(intent);

  /// Intent title without emoji (e.g. 'Conocer sin prisa (Slow Dating)')
  String get intentTitle => PreferenceCatalog.getIntentTitle(intent);

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
    bool? isVerified,
    String? verificationSelfie,
    String? gender,
    String? seekingGender,
    bool? isInternational,
    double? latitude,
    double? longitude,
    LifestyleBadges? lifestyle,
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
      isVerified: isVerified ?? this.isVerified,
      verificationSelfie: verificationSelfie ?? this.verificationSelfie,
      gender: gender ?? this.gender,
      seekingGender: seekingGender ?? this.seekingGender,
      isInternational: isInternational ?? this.isInternational,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lifestyle: lifestyle ?? this.lifestyle,
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
      'photos': jsonEncode(photos),
      'bio': bio,
      'intent': intent,
      'maxDistanceKm': maxDistanceKm,
      'roomConfig': roomConfig.toJson(),
      'isVerified': isVerified,
      if (verificationSelfie != null) 'verificationSelfie': verificationSelfie,
      'gender': gender,
      'seekingGender': seekingGender,
      'isInternational': isInternational,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (lifestyle.hasAnyBadge) 'lifestyle': lifestyle.toJson(),
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

    LifestyleBadges parsedLifestyle;
    try {
      final rawLifestyle = map['lifestyle'];
      if (rawLifestyle is String && rawLifestyle.isNotEmpty && rawLifestyle != '{}') {
        parsedLifestyle = LifestyleBadges.fromJson(rawLifestyle);
      } else if (rawLifestyle is Map<String, dynamic>) {
        parsedLifestyle = LifestyleBadges.fromMap(rawLifestyle);
      } else {
        parsedLifestyle = const LifestyleBadges();
      }
    } catch (_) {
      parsedLifestyle = const LifestyleBadges();
    }

    final singlePhoto = map['profilePhoto'] as String?;

    String resolvedIntent = map['intent'] as String? ?? '';
    if (resolvedIntent.isEmpty) {
      for (final t in parsedTastes) {
        if (t.startsWith('intent_')) {
          resolvedIntent = t;
          break;
        }
      }
    }
    if (resolvedIntent.isEmpty) {
      resolvedIntent = 'intent_slow';
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
      intent: resolvedIntent,
      maxDistanceKm: (map['maxDistanceKm'] as num?)?.toDouble() ?? 25.0,
      roomConfig: room,
      isVerified: map['isVerified'] == true || map['is_verified'] == true || map['is_verified'] == 1,
      verificationSelfie: map['verificationSelfie'] as String? ?? map['verification_selfie'] as String?,
      gender: map['gender'] as String? ?? 'OTHER',
      seekingGender: map['seekingGender'] as String? ?? map['seeking_gender'] as String? ?? 'ANY',
      isInternational: map['isInternational'] == true || map['is_international'] == true || map['is_international'] == 1,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      lifestyle: parsedLifestyle,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserProfile.fromJson(String source) => UserProfile.fromMap(jsonDecode(source));
}
