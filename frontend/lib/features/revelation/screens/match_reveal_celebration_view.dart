import 'package:flutter/material.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../chat/screens/private_chat_screen.dart';
import '../../mailbox/models/mailbox_models.dart';

class MatchRevealCelebrationView extends StatefulWidget {
  final UserProfile localUser;
  final UserProfile partnerUser;
  final String partnerName;
  final bool isCelebration;
  final VoidCallback onReturnHome;

  const MatchRevealCelebrationView({
    super.key,
    required this.localUser,
    required this.partnerUser,
    required this.partnerName,
    this.isCelebration = true,
    required this.onReturnHome,
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

    _photos = (partner.photos.isNotEmpty)
        ? partner.photos
        : AvatarStorageService.getUserPhotos(partnerId);

    if (_photos.isEmpty) {
      final singlePhoto = partner.profilePhoto ?? AvatarStorageService.getUserPhoto(partnerId);
      if (singlePhoto != null && singlePhoto.isNotEmpty) {
        _photos = [singlePhoto];
      } else {
        _photos = ['assets/images/default_avatar.png'];
      }
    }

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
    if (photoUrl.startsWith('assets/')) {
      return Image.asset(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF1E293B),
          child: const Center(
            child: Icon(Icons.person_outline, size: 50, color: Colors.white30),
          ),
        ),
      );
    } else if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
      return Image.network(
        photoUrl,
        fit: BoxFit.cover,
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
              const Icon(Icons.favorite_rounded, size: 48, color: Color(0xFFE11D48)),
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
    return Dialog(
      backgroundColor: const Color(0xFF0F172A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFE11D48), width: 2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 660),
        child: Column(
          children: [
            // Top Header: Confetti / Match badge
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFF9333EA)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  ScaleTransition(
                    scale: Tween<double>(begin: 0.9, end: 1.15).animate(
                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: const Text('✨💖✨', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isCelebration ? '¡ES UN MATCH MUTUO!' : 'PERFIL COMPLETO',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          widget.isCelebration ? 'Ambos han elegido conectar' : 'Conexión Mutua • ${widget.partnerName}',
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
                    // Photos Carousel (1 to 6 photos)
                    SizedBox(
                      height: 280,
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
                          // Subtle gradient shadow at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 60,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Dots Indicator
                          if (_photos.length > 1)
                            Positioned(
                              bottom: 12,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(_photos.length, (idx) {
                                  final isActive = idx == _currentPhotoIndex;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: isActive ? 16 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isActive ? Colors.white : Colors.white54,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          // Photos counter tag (top right)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_currentPhotoIndex + 1}/${_photos.length} fotos',
                                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
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
                                  fontSize: 20,
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

            // Bottom Actions: Aceptar (on first celebration) or Chat & Close (on full profile)
            Padding(
              padding: const EdgeInsets.all(16),
              child: widget.isCelebration
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
                        onPressed: widget.onReturnHome,
                        child: const Text(
                          'Aceptar',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
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
                          onPressed: widget.onReturnHome,
                          style: TextButton.styleFrom(foregroundColor: Colors.white54),
                          child: const Text(
                            'Cerrar perfil',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
