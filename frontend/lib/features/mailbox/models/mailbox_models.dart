import '../../../core/models/avatar_config.dart';

enum MailboxDecision {
  pending,
  keepInTouch,
  archived,
}

class MailboxLetter {
  final String id;
  final String partnerId;
  final String partnerName;
  final AvatarConfig partnerAvatar;
  final String? partnerPhoto;
  final int partnerAge;
  final String partnerCommune;
  final List<String> commonTastes;
  final MailboxDecision myDecision;
  final String? myNote;
  final String? partnerNote;
  final bool isMutualMatch;
  final DateTime createdAt;

  const MailboxLetter({
    required this.id,
    required this.partnerId,
    required this.partnerName,
    required this.partnerAvatar,
    this.partnerPhoto,
    this.partnerAge = 24,
    this.partnerCommune = 'Santiago',
    this.commonTastes = const [],
    this.myDecision = MailboxDecision.pending,
    this.myNote,
    this.partnerNote,
    this.isMutualMatch = false,
    required this.createdAt,
  });

  MailboxLetter copyWith({
    String? id,
    String? partnerId,
    String? partnerName,
    AvatarConfig? partnerAvatar,
    String? partnerPhoto,
    int? partnerAge,
    String? partnerCommune,
    List<String>? commonTastes,
    MailboxDecision? myDecision,
    String? myNote,
    String? partnerNote,
    bool? isMutualMatch,
    DateTime? createdAt,
  }) {
    return MailboxLetter(
      id: id ?? this.id,
      partnerId: partnerId ?? this.partnerId,
      partnerName: partnerName ?? this.partnerName,
      partnerAvatar: partnerAvatar ?? this.partnerAvatar,
      partnerPhoto: partnerPhoto ?? this.partnerPhoto,
      partnerAge: partnerAge ?? this.partnerAge,
      partnerCommune: partnerCommune ?? this.partnerCommune,
      commonTastes: commonTastes ?? this.commonTastes,
      myDecision: myDecision ?? this.myDecision,
      myNote: myNote ?? this.myNote,
      partnerNote: partnerNote ?? this.partnerNote,
      isMutualMatch: isMutualMatch ?? this.isMutualMatch,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory MailboxLetter.fromMap(Map<String, dynamic> map) {
    AvatarConfig avatar = const AvatarConfig();
    try {
      final rawAvatar = map['partnerAvatar'];
      if (rawAvatar is Map<String, dynamic>) {
        avatar = AvatarConfig.fromJson(rawAvatar);
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
      partnerId: map['partnerId']?.toString() ?? '',
      partnerName: map['partnerName']?.toString() ?? 'Compañero',
      partnerAvatar: avatar,
      partnerPhoto: map['partnerPhoto']?.toString(),
      partnerAge: (map['partnerAge'] as num?)?.toInt() ?? 24,
      partnerCommune: map['partnerCommune']?.toString() ?? 'Santiago',
      commonTastes: parsedTastes,
      myDecision: decision,
      myNote: map['myNote']?.toString(),
      partnerNote: map['partnerNote']?.toString(),
      isMutualMatch: map['isMutualMatch'] == true,
      createdAt: parsedDate,
    );
  }
}
