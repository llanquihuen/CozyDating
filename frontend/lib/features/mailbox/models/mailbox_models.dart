import 'dart:convert';
import '../../../core/models/avatar_config.dart';
import '../../../core/services/avatar_storage_service.dart';

enum MailboxDecision {
  pending,
  keepInTouch,
  archived,
}

class MailboxLetter {
  final String id;
  final String? ownerId;
  final String partnerId;
  final String partnerName;
  final AvatarConfig partnerAvatar;
  final String? partnerPhoto;
  final List<String> partnerPhotos;
  final String? partnerBio;
  final String? partnerIntent;
  final int partnerAge;
  final String partnerCommune;
  final List<String> commonTastes;
  final MailboxDecision myDecision;
  final String? myNote;
  final String? partnerNote;
  final bool isMutualMatch;
  final bool isCelebrated;
  final DateTime createdAt;

  const MailboxLetter({
    required this.id,
    this.ownerId,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    this.partnerPhoto,
    this.partnerPhotos = const [],
    this.partnerBio,
    this.partnerIntent,
    this.partnerAge = 24,
    this.partnerCommune = 'Santiago',
    this.commonTastes = const [],
    this.myDecision = MailboxDecision.pending,
    this.myNote,
    this.partnerNote,
    this.isMutualMatch = false,
    this.isCelebrated = false,
    required this.createdAt,
  });

  List<String> get effectivePhotos {
    if (partnerPhotos.isNotEmpty) return partnerPhotos;
    final stored = AvatarStorageService.getUserPhotos(partnerId);
    if (stored.isNotEmpty) return stored;
    if (partnerPhoto != null && partnerPhoto!.isNotEmpty) return [partnerPhoto!];
    return const [];
  }

  String get effectiveBio {
    if (partnerBio != null && partnerBio!.isNotEmpty) return partnerBio!;
    final stored = AvatarStorageService.getUserBio(partnerId);
    if (stored.isNotEmpty) return stored;
    return 'Amante de las aventuras cooperativas, las buenas charlas y momentos sinceros ✨.';
  }

  String get effectiveIntent {
    if (partnerIntent != null && partnerIntent!.isNotEmpty) return partnerIntent!;
    final stored = AvatarStorageService.getUserIntent(partnerId);
    if (stored.isNotEmpty) return stored;
    return 'Citas con calma 🌱';
  }

  MailboxLetter copyWith({
    String? id,
    String? ownerId,
    String? partnerId,
    String? partnerName,
    AvatarConfig? partnerAvatar,
    String? partnerPhoto,
    List<String>? partnerPhotos,
    String? partnerBio,
    String? partnerIntent,
    int? partnerAge,
    String? partnerCommune,
    List<String>? commonTastes,
    MailboxDecision? myDecision,
    String? myNote,
    String? partnerNote,
    bool? isMutualMatch,
    bool? isCelebrated,
    DateTime? createdAt,
  }) {
    return MailboxLetter(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      partnerPhoto: partnerPhoto ?? this.partnerPhoto,
      partnerPhotos: partnerPhotos ?? this.partnerPhotos,
      partnerBio: partnerBio ?? this.partnerBio,
      partnerIntent: partnerIntent ?? this.partnerIntent,
      partnerAge: partnerAge ?? this.partnerAge,
      partnerCommune: partnerCommune ?? this.partnerCommune,
      commonTastes: commonTastes ?? this.commonTastes,
      myDecision: myDecision ?? this.myDecision,
      myNote: myNote ?? this.myNote,
      partnerNote: partnerNote ?? this.partnerNote,
      isMutualMatch: isMutualMatch ?? this.isMutualMatch,
      isCelebrated: isCelebrated ?? this.isCelebrated,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MailboxLetter.fromMap(Map<String, dynamic> map) {
    AvatarConfig avatar = const AvatarConfig();
    try {
      final rawAvatar = map['partnerAvatar'];
      if (rawAvatar is Map<String, dynamic>) {
        avatar = AvatarConfig.fromJson(rawAvatar);
      } else if (rawAvatar is String && rawAvatar.isNotEmpty) {
        final decoded = jsonDecode(rawAvatar);
        if (decoded is Map<String, dynamic>) {
          avatar = AvatarConfig.fromJson(decoded);
        }
      }
    } catch (_) {}

    List<String> parsedTastes = [];
    final rawTastes = map['commonTastes'];
    if (rawTastes is List) {
      parsedTastes = rawTastes.map((e) => e.toString()).toList();
    } else if (rawTastes is String && rawTastes.isNotEmpty) {
      if (rawTastes.startsWith('[') && rawTastes.endsWith(']')) {
        final cleaned = rawTastes.substring(1, rawTastes.length - 1);
        parsedTastes = cleaned.split(',').map((e) => e.replaceAll('"', '').trim()).where((e) => e.isNotEmpty).toList();
      }
    }

    final pId = map['partnerId']?.toString() ?? '';

    List<String> parsedPhotos = [];
    final rawPhotos = map['partnerPhotos'];
    if (rawPhotos is List) {
      parsedPhotos = rawPhotos.map((e) => e.toString()).toList();
    } else if (rawPhotos is String && rawPhotos.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPhotos);
        if (decoded is List) {
          parsedPhotos = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    if (parsedPhotos.isEmpty && map['partnerPhoto'] != null && map['partnerPhoto'].toString().isNotEmpty) {
      parsedPhotos = [map['partnerPhoto'].toString()];
    }
    if (parsedPhotos.isEmpty && pId.isNotEmpty) {
      parsedPhotos = AvatarStorageService.getUserPhotos(pId);
    }

    final bio = map['partnerBio']?.toString() ?? (pId.isNotEmpty ? AvatarStorageService.getUserBio(pId) : null);
    final intent = map['partnerIntent']?.toString() ?? (pId.isNotEmpty ? AvatarStorageService.getUserIntent(pId) : null);

    final decisionStr = (map['myDecision'] as String? ?? 'PENDING').toUpperCase();
    MailboxDecision decision = MailboxDecision.pending;
    if (decisionStr == 'KEEP_IN_TOUCH') {
      decision = MailboxDecision.keepInTouch;
    } else if (decisionStr == 'ARCHIVED' || decisionStr == 'ARCHIVE') {
      decision = MailboxDecision.archived;
    }

    DateTime parsedDate;
    try {
      parsedDate = map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return MailboxLetter(
      id: map['id']?.toString() ?? '',
      ownerId: map['ownerId']?.toString(),
      partnerId: pId,
      partnerName: map['partnerName']?.toString() ?? 'Compañero',
      partnerAvatar: avatar,
      partnerPhoto: map['partnerPhoto']?.toString(),
      partnerPhotos: parsedPhotos,
      partnerBio: bio,
      partnerIntent: intent,
      partnerAge: (map['partnerAge'] as num?)?.toInt() ?? 24,
      partnerCommune: map['partnerCommune']?.toString() ?? 'Santiago',
      commonTastes: parsedTastes,
      myDecision: decision,
      myNote: map['myNote']?.toString(),
      partnerNote: map['partnerNote']?.toString(),
      isMutualMatch: map['isMutualMatch'] == true,
      isCelebrated: map['isCelebrated'] == true,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ownerId': ownerId,
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerAvatar': partnerAvatar.toJson(),
      'partnerPhoto': partnerPhoto,
      'partnerPhotos': partnerPhotos,
      'partnerBio': partnerBio,
      'partnerIntent': partnerIntent,
      'partnerAge': partnerAge,
      'partnerCommune': partnerCommune,
      'commonTastes': commonTastes,
      'myDecision': myDecision == MailboxDecision.keepInTouch
          ? 'KEEP_IN_TOUCH'
          : (myDecision == MailboxDecision.archived ? 'ARCHIVE' : 'PENDING'),
      'myNote': myNote,
      'partnerNote': partnerNote,
      'isMutualMatch': isMutualMatch,
      'isCelebrated': isCelebrated,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
