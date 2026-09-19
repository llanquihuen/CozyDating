import 'package:flutter/material.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../../core/widgets/fullscreen_photo_viewer.dart';
import '../../chat/screens/private_chat_screen.dart';
import '../../mailbox/models/mailbox_models.dart';

class MatchRevealCelebrationView extends StatefulWidget {
  final UserProfile localUser;
  final UserProfile partnerUser;
  final String partnerName;
  final bool isCelebration;
  final bool isMutualMatch;
  final bool isPreview;
  final VoidCallback? onReturnHome;

  const MatchRevealCelebrationView({
    super.key,
    required this.localUser,
    required this.partnerUser,
    required this.partnerName,
    this.isCelebration = true,
    this.isMutualMatch = true,
    this.isPreview = false,
    this.onReturnHome,
  });

  @override
  State<MatchRevealCelebrationView> createState() => _MatchRevealCelebrationViewState();
}

class _MatchRevealCelebrationViewState extends State<MatchRevealCelebrationView>
    with SingleTickerProviderStateMixin {
  late final PageController _photoPageController;
  late final AnimationController _pulseController;
  int _currentPhotoIndex = 0;

  List<String> _photos = [];
  String _bio = '';
  String _intent = '';
  int _age = 24;
  String _commune = 'Santiago';

  @override
  void initState() {
    super.initState();
    _photoPageController = PageController();
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

    if (combinedPhotos.isEmpty) {
      combinedPhotos.add('assets/images/default_avatar.png');
    }

    _photos = combinedPhotos;

    _bio = partner.bio.isNotEmpty
        ? partner.bio
        : AvatarStorageService.getUserBio(partnerId);

    if (_bio.isEmpty) {
      _bio = 'Aventurero(a) en busca de momentos genuinos, buenas charlas y partidas cooperativas ✨.';
    }

    _intent = partner.intent.isNotEmpty
        ? partner.intent
        : AvatarStorageService.getUserIntent(partnerId);

    if (_intent.isEmpty) {
      _intent = 'Conectar con calma y ver qué surge 🌱';
    }

    _age = partner.age > 0 ? partner.age : 24;
    _commune = partner.commune.isNotEmpty ? partner.commune : 'Santiago';
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildPhotoSlot(String photoUrl) {
    final resolvedUrl = AppConfig.resolveMediaUrl(photoUrl);
    if (resolvedUrl.startsWith('assets/')) {
      return Image.asset(
        resolvedUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1E293B),
          child: const Center(
            child: Icon(Icons.person_outline, size: 50, color: Colors.white30),
          ),
        ),
      );
    } else if (resolvedUrl.startsWith('http://') || resolvedUrl.startsWith('https://')) {
      return Image.network(
        resolvedUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: const Color(0xFF1E293B),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD54F)),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1E293B),
          child: const Center(
            child: Icon(Icons.person_outline, size: 50, color: Colors.white30),
          ),
        ),
      );
    } else {
      return Container(
        color: const Color(0xFF1E293B),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                (widget.isCelebration || widget.isMutualMatch) ? Icons.favorite_rounded : Icons.local_fire_department_rounded,
                size: 48,
                color: (widget.isCelebration || widget.isMutualMatch) ? const Color(0xFFE11D48) : const Color(0xFFFF6D00),
              ),
              const SizedBox(height: 8),
              Text(
                widget.partnerName,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }
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

    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: widget.isPreview
              ? const Color(0xFF38BDF8)
              : (isPendingDate ? const Color(0xFFFFB74D) : const Color(0xFFE11D48)),
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
                  colors: widget.isPreview
                      ? const [Color(0xFF0284C7), Color(0xFF6366F1)]
                      : (isPendingDate
                          ? const [Color(0xFFFF6D00), Color(0xFFD97706)]
                          : const [Color(0xFFE11D48), Color(0xFF9333EA)]),
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
                      widget.isPreview
                          ? '👁️✨'
                          : (isPendingDate ? '🔥💌✨' : '✨💖✨'),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isPreview
                              ? 'VISTA PREVIA DE TU PERFIL'
                              : (widget.isCelebration
                                  ? '¡ES UN MATCH MUTUO!'
                                  : (widget.isMutualMatch ? 'PERFIL COMPLETO' : 'CITA EN LA FOGATA')),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          widget.isPreview
                              ? 'Así te verán tus citas al terminar la Fogata'
                              : (widget.isCelebration
                                  ? 'Ambos han elegido conectar'
                                  : (widget.isMutualMatch
                                      ? 'Conexión Mutua • ${widget.partnerName}'
                                      : 'Decisión pendiente • ${widget.partnerName}')),
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

            // Middle Scrollable Section: Photos & Profile info
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Expansive Photos Carousel
                    SizedBox(
                      height: 360,
                      width: double.infinity,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          PageView.builder(
                            controller: _photoPageController,
                            itemCount: _photos.length,
                            onPageChanged: (idx) {
                              setState(() {
                                _currentPhotoIndex = idx;
                              });
                            },
                            itemBuilder: (context, index) {
                              return _buildPhotoSlot(_photos[index]);
                            },
                          ),

                          // Left & Right tap zones for quick photo flip + Center tap to open fullscreen
                          if (_photos.length > 1)
                            Positioned.fill(
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        if (_currentPhotoIndex > 0) {
                                          _photoPageController.previousPage(
                                            duration: const Duration(milliseconds: 220),
                                            curve: Curves.easeInOut,
                                          );
                                        } else {
                                          FullScreenPhotoViewer.open(
                                            context,
                                            photos: _photos,
                                            initialIndex: _currentPhotoIndex,
                                            title: widget.partnerName,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        FullScreenPhotoViewer.open(
                                          context,
                                          photos: _photos,
                                          initialIndex: _currentPhotoIndex,
                                          title: widget.partnerName,
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onTap: () {
                                        if (_currentPhotoIndex < _photos.length - 1) {
                                          _photoPageController.nextPage(
                                            duration: const Duration(milliseconds: 220),
                                            curve: Curves.easeInOut,
                                          );
                                        } else {
                                          FullScreenPhotoViewer.open(
                                            context,
                                            photos: _photos,
                                            initialIndex: _currentPhotoIndex,
                                            title: widget.partnerName,
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () {
                                  FullScreenPhotoViewer.open(
                                    context,
                                    photos: _photos,
                                    initialIndex: 0,
                                    title: widget.partnerName,
                                  );
                                },
                              ),
                            ),

                          // Top Story-style dash indicators
                          if (_photos.length > 1)
                            Positioned(
                              top: 10,
                              left: 12,
                              right: 12,
                              child: Row(
                                children: List.generate(_photos.length, (idx) {
                                  final isActive = idx == _currentPhotoIndex;
                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 2),
                                      height: 3.5,
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 2),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),

                          // Subtle gradient shadow at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 70,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.75),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Photos counter tag (top right)
                          Positioned(
                            top: 22,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_camera_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_currentPhotoIndex + 1}/${_photos.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Fullscreen "Ampliar" button (bottom right)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                FullScreenPhotoViewer.open(
                                  context,
                                  photos: _photos,
                                  initialIndex: _currentPhotoIndex,
                                  title: widget.partnerName,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white30, width: 0.9),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.4),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white.withOpacity(0.95)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Ampliar',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.95),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // User Info Card
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name, Age & Commune
                          Row(
                            children: [
                              Text(
                                '${widget.partnerName}, $_age',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 21,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF0284C7)),
                                ),
                                child: Text(
                                  _commune,
                                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Intent Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.pinkAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.pinkAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🎯', style: TextStyle(fontSize: 12)),
                                const SizedBox(width: 6),
                                Text(
                                  _intent,
                                  style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 11.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Bio ("Acerca de mí")
                          const Text(
                            'Acerca de mí',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Text(
                              _bio,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
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
