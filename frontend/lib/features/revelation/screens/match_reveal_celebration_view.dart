import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/models/lifestyle_badges.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../../core/widgets/fullscreen_photo_viewer.dart';
import '../../chat/screens/private_chat_screen.dart';
import '../../mailbox/models/mailbox_models.dart';
import '../../profile/card/card_entrance.dart';
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

  /// How long the character face shows before the card turns over to the real face (the reveal):
  /// it is dealt in and shines first.
  static const Duration revealDelay = Duration(milliseconds: 1900);

  @override
  State<MatchRevealCelebrationView> createState() => _MatchRevealCelebrationViewState();
}

class _MatchRevealCelebrationViewState extends State<MatchRevealCelebrationView> with SingleTickerProviderStateMixin {
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

  ProfileCardTheme get _cardTheme =>
      cardThemeOf(_partnerCard.effectiveCardStyle.normalizedFor(_partnerCard.tastes).themeId);
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

    _bio = partner.bio.isNotEmpty ? partner.bio : AvatarStorageService.getUserBio(partnerId);

    if (_bio.isEmpty) {
      _bio = 'Aventurero(a) en busca de momentos genuinos, buenas charlas y partidas cooperativas ✨.';
    }

    _age = partner.age > 0 ? partner.age : 24;
    _commune = partner.commune.isNotEmpty ? partner.commune : 'Santiago';
    _lifestyle = partner.lifestyle.hasAnyBadge ? partner.lifestyle : AvatarStorageService.getUserLifestyle(partnerId);

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
      titleText = widget.isMutualMatch ? (isFriendship ? 'AMISTAD MUTUA' : 'CHISPA MUTUA') : 'CITA EN LA FOGATA';
    }

    void close() {
      if (widget.onReturnHome != null) {
        widget.onReturnHome!();
      } else {
        Navigator.of(context).pop();
      }
    }

    // The card leads: one slim row above it, the main button below, and the dialog exactly as wide as
    // the card (no frame around it, no empty sides). Its height is what is left of the screen.
    const chrome = 40.0 + 8 + 44 + 12 + 12 + 50 + 12; // header, switch, button and gaps, with some slack
    final screen = MediaQuery.sizeOf(context);
    final cardHeight = screen.height - 24 - chrome;
    final cardWidth =
        math.max(200.0, math.min(screen.width - 20, math.min(420.0, cardHeight * ProfileCard.aspectRatio)));

    final ({String label, IconData? icon, Color color, VoidCallback onPressed}) main = widget.isPreview
        ? (
            label: 'Volver a editar mi perfil',
            icon: Icons.edit_note_rounded,
            color: const Color(0xFF0284C7),
            onPressed: close
          )
        : widget.isCelebration
            ? (label: 'Aceptar', icon: null, color: const Color(0xFFE11D48), onPressed: close)
            : isPendingDate
                ? (
                    label: 'Volver a tomar decisión',
                    icon: Icons.arrow_back_rounded,
                    color: const Color(0xFFFF6D00),
                    onPressed: close,
                  )
                : (
                    label: 'Escribir a ${widget.partnerName}',
                    icon: Icons.chat_bubble_rounded,
                    color: const Color(0xFFE11D48),
                    onPressed: _openPrivateChat,
                  );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: SizedBox(
        width: cardWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // What this is, in one line, and a quiet way out.
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: gradientColors),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.9, end: 1.1).animate(
                                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                              ),
                              child: Text(iconEmoji, style: const TextStyle(fontSize: 14)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                titleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Cerrar perfil',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                      onPressed: close,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CardFaceSwitch(
              real: _showReal,
              onChanged: (real) {
                _revealTimer?.cancel();
                setState(() => _showReal = real);
              },
              accent: _cardAccent,
              onAccent: _cardTheme.onAccent(_cardAccent),
            ),
            const SizedBox(height: 12),
            // The partner's two-sided card: dealt in on the character face, then it turns over to
            // the person (the reveal). A tap opens it at full screen.
            SizedBox(
              width: cardWidth,
              height: cardWidth / ProfileCard.aspectRatio,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openFullCard,
                      child: CardEntrance(
                        shineColor: _cardAccent,
                        child: ProfileCard(profile: _partnerCard, showReal: _showReal, avatarHeroTag: _heroTag),
                      ),
                    ),
                  ),
                  if (_showReal && _photos.isNotEmpty)
                    Positioned(
                      left: 12,
                      top: 24,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () => FullScreenPhotoViewer.open(
                            context,
                            photos: _photos,
                            initialIndex: 0,
                            title: widget.partnerName,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                                const SizedBox(width: 5),
                                const Text(
                                  'Ver fotos',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                Text('  ${_photos.length}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: main.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                icon: main.icon == null ? const SizedBox.shrink() : Icon(main.icon, size: 20),
                label: Text(main.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5)),
                onPressed: main.onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
