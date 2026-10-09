import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/models/lifestyle_badges.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../../core/widgets/fullscreen_photo_viewer.dart';
import '../../chat/screens/private_chat_screen.dart';
import '../../mailbox/models/mailbox_models.dart';
import '../../profile/card/card_themes.dart';
import '../../profile/card/profile_card.dart';
import '../../profile/view/card_face_switch.dart';
import '../../profile/view/profile_card_view.dart';

class MatchRevealCelebrationView extends StatefulWidget {
  final UserProfile localUser;
  final UserProfile partnerUser;
  final String partnerName;
  final bool isCelebration;
  final bool isMutualMatch;
  final ConnectionType matchType;
  final bool isPreview;
  final VoidCallback? onReturnHome;

  const MatchRevealCelebrationView({
    super.key,
    required this.localUser,
    required this.partnerUser,
    required this.partnerName,
    this.isCelebration = true,
    this.isMutualMatch = true,
    this.matchType = ConnectionType.romance,
    this.isPreview = false,
    this.onReturnHome,
  });

  /// How long the character face shows before the card flips to the real face (the reveal).
  static const Duration revealDelay = Duration(milliseconds: 1100);

  @override
  State<MatchRevealCelebrationView> createState() => _MatchRevealCelebrationViewState();
}

class _MatchRevealCelebrationViewState extends State<MatchRevealCelebrationView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  List<String> _photos = [];
  String _bio = '';
  int _age = 24;
  String _commune = 'Santiago';
  late LifestyleBadges _lifestyle;

  /// Starts on the character face; flips to the real face shortly after opening (the reveal).
  bool _showReal = false;
  Timer? _revealTimer;

  /// The partner as their card shows them, with the photos, bio and badges resolved above.
  UserProfile get _partnerCard => widget.partnerUser.copyWith(
        username: widget.partnerName,
        profilePhoto: _photos.isNotEmpty ? _photos.first : '',
        photos: _photos.skip(1).toList(),
        bio: _bio,
        age: _age,
        commune: _commune,
        lifestyle: _lifestyle,
      );

  late final Object _heroTag = Object();

  ProfileCardTheme get _cardTheme => cardThemeOf(_partnerCard.effectiveCardStyle.normalizedFor(_partnerCard.tastes).themeId);
  Color get _cardAccent => _cardTheme.accentOf(_partnerCard.effectiveCardStyle);

  void _openFullCard() {
    _revealTimer?.cancel();
    ProfileCardView.open(
      context,
      profile: _partnerCard,
      initiallyReal: _showReal,
      avatarHeroTag: _showReal ? null : _heroTag,
    );
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Resolve partner photos, bio, etc.
    final partner = widget.partnerUser;
    final partnerId = partner.id;

    final combinedPhotos = <String>[];
    void addPhoto(String? photo) {
      if (photo != null) {
        final trimmed = photo.trim();
        if (trimmed.isNotEmpty && !combinedPhotos.contains(trimmed)) {
          combinedPhotos.add(trimmed);
        }
      }
    }

    // 1. Primary profile photo from partnerUser or storage
    if (partner.profilePhoto != null && partner.profilePhoto!.trim().isNotEmpty) {
      addPhoto(partner.profilePhoto);
    } else {
      addPhoto(AvatarStorageService.getUserPhoto(partnerId));
    }

    // 2. Photos from partnerUser
    if (partner.photos.isNotEmpty) {
      for (final p in partner.photos) {
        addPhoto(p);
      }
    } else {
      for (final p in AvatarStorageService.getUserPhotos(partnerId)) {
        addPhoto(p);
      }
    }
    _photos = combinedPhotos;

    _bio = partner.bio.isNotEmpty
        ? partner.bio
        : AvatarStorageService.getUserBio(partnerId);

    if (_bio.isEmpty) {
      _bio = 'Aventurero(a) en busca de momentos genuinos, buenas charlas y partidas cooperativas ✨.';
    }

    _age = partner.age > 0 ? partner.age : 24;
    _commune = partner.commune.isNotEmpty ? partner.commune : 'Santiago';
    _lifestyle = partner.lifestyle.hasAnyBadge
        ? partner.lifestyle
        : AvatarStorageService.getUserLifestyle(partnerId);

    // A moment on the character face, then the card turns over.
    _revealTimer = Timer(MatchRevealCelebrationView.revealDelay, () {
      if (mounted) setState(() => _showReal = true);
    });
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _openPrivateChat() {
    final letter = MailboxLetter(
      id: 'match_${widget.partnerUser.id}_${DateTime.now().millisecondsSinceEpoch}',
      partnerId: widget.partnerUser.id,
      partnerName: widget.partnerName,
      partnerAvatar: widget.partnerUser.avatarConfig,
      partnerPhoto: _photos.isNotEmpty ? _photos.first : null,
      partnerAge: _age,
      partnerCommune: _commune,
      commonTastes: widget.partnerUser.tastes,
      myDecision: MailboxDecision.keepInTouch,
      isMutualMatch: true,
      matchType: widget.matchType,
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PrivateChatScreen(letter: letter),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPendingDate = !widget.isCelebration && !widget.isMutualMatch;
    final isFriendship = widget.matchType == ConnectionType.friendship;

    Color borderColor;
    if (widget.isPreview) {
      borderColor = const Color(0xFF38BDF8);
    } else if (isPendingDate) {
      borderColor = const Color(0xFFFFB74D);
    } else if (isFriendship) {
      borderColor = const Color(0xFF0D9488);
    } else {
      borderColor = const Color(0xFFE11D48);
    }

    List<Color> gradientColors;
    if (widget.isPreview) {
      gradientColors = const [Color(0xFF0284C7), Color(0xFF6366F1)];
    } else if (isPendingDate) {
      gradientColors = const [Color(0xFFFF6D00), Color(0xFFD97706)];
    } else if (isFriendship) {
      gradientColors = const [Color(0xFF0D9488), Color(0xFF059669)];
    } else {
      gradientColors = const [Color(0xFFE11D48), Color(0xFF9333EA)];
    }

    String iconEmoji;
    if (widget.isPreview) {
      iconEmoji = '👁️✨';
    } else if (isPendingDate) {
      iconEmoji = '🔥💌✨';
    } else if (isFriendship) {
      iconEmoji = '✨🤝✨';
    } else {
      iconEmoji = '✨💖✨';
    }

    String titleText;
    if (widget.isPreview) {
      titleText = 'VISTA PREVIA DE TU PERFIL';
    } else if (widget.isCelebration) {
      titleText = isFriendship ? '¡NUEVA AMISTAD MUTUA!' : '¡HUBO CHISPA MUTUA!';
    } else {
      titleText = widget.isMutualMatch
          ? (isFriendship ? 'AMISTAD MUTUA' : 'CHISPA MUTUA')
          : 'CITA EN LA FOGATA';
    }

    String subtitleText;
    if (widget.isPreview) {
      subtitleText = 'Así te verán tus citas al terminar la Fogata';
    } else if (widget.isCelebration) {
      subtitleText = isFriendship
          ? 'Coincidieron en ser compañeros de aventuras'
          : 'Ambos han sentido esa química especial';
    } else {
      subtitleText = widget.isMutualMatch
          ? (isFriendship ? 'Amistad • ${widget.partnerName}' : 'Conexión Romántica • ${widget.partnerName}')
          : 'Decisión pendiente • ${widget.partnerName}';
    }

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: borderColor,
          width: 2,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: Column(
          children: [
            // Top Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: Text(
                      iconEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          subtitleText,
                          style: const TextStyle(
                            color: Color(0xFFFDE68A),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // The partner's two-sided card: it shows their character face, then flips to the real
            // one (the reveal). The switch turns it over again; a tap opens it at full screen.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _openFullCard,
                          child: ProfileCard(profile: _partnerCard, showReal: _showReal, avatarHeroTag: _heroTag),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CardFaceSwitch(
                      real: _showReal,
                      onChanged: (real) {
                        _revealTimer?.cancel();
                        setState(() => _showReal = real);
                      },
                      accent: _cardAccent,
                      onAccent: _cardTheme.onAccent(_cardAccent),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Toca la tarjeta para verla completa',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                        ),
                        if (_photos.isNotEmpty) ...[
                          const SizedBox(width: 6, height: 1),
                          TextButton.icon(
                            onPressed: () => FullScreenPhotoViewer.open(
                              context,
                              photos: _photos,
                              initialIndex: 0,
                              title: widget.partnerName,
                            ),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('Ver fotos'),
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFDE68A)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.isPreview
                  ? SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 22),
                        label: const Text(
                          'Volver a editar mi perfil',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        onPressed: () {
                          if (widget.onReturnHome != null) {
                            widget.onReturnHome!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    )
                  : (widget.isCelebration
                      ? SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE11D48),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 4,
                            ),
                            onPressed: () {
                              if (widget.onReturnHome != null) {
                                widget.onReturnHome!();
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text(
                              'Aceptar',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        )
                      : (isPendingDate
                          ? SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF6D00),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 4,
                                ),
                                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                                label: const Text(
                                  'Volver a tomar decisión',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                onPressed: () {
                                  if (widget.onReturnHome != null) {
                                    widget.onReturnHome!();
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                            )
                          : Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE11D48),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 4,
                                    ),
                                    icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                                    label: Text(
                                      'Escribir a ${widget.partnerName}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    onPressed: _openPrivateChat,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () {
                                    if (widget.onReturnHome != null) {
                                      widget.onReturnHome!();
                                    } else {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  style: TextButton.styleFrom(foregroundColor: Colors.white54),
                                  child: const Text(
                                    'Cerrar perfil',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ))),
            ),
          ],
        ),
      ),
    );
  }
}
