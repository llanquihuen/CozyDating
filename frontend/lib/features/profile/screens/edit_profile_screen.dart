import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/lifestyle_badges.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../avatar/widgets/lifestyle_badges_sheet.dart';
import '../card/profile_card.dart';

/// "Editar perfil": the real face of the profile card, live, on top (it shrinks while scrolling),
/// and every part of the dating profile below, in this order: photos, about me, lifestyle badges,
/// vibes and tastes, who you are and who you seek, then distance and the age filter. Changes are a
/// draft until "Guardar"; leaving with unsaved changes asks first.
///
/// The sections were moved from the old character screen with their behaviour unchanged (photo
/// upload, selfie verification, badges, tastes).
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.avatarConfig, this.onSaved});

  /// The player's avatar, shown on the card (and refitted if the gender changes).
  final AvatarConfig avatarConfig;

  /// Called after saving, with the avatar fitted to the (possibly new) gender.
  final ValueChanged<AvatarConfig>? onSaved;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late Set<String> _selectedTastes;
  String? _currentPhoto;
  bool _isVerified = false;
  String? _verificationSelfie;

  // Dating Profile fields (Tinder style: official profile photo + up to 5 hobby photos)
  late List<String> _userPhotos;
  late TextEditingController _bioController;
  late String _selectedIntent;
  late double _selectedDistanceKm;
  late int _userAge;
  late String _userCommune;
  late String _userGender;
  late String _seekingGender;
  late bool _isInternational;
  late TextEditingController _communeController;
  late LifestyleBadges _currentLifestyle;

  /// Age range sought; both null = no age filter (the default).
  int? _seekingAgeMin;
  int? _seekingAgeMax;

  /// What the form held when it opened, to tell unsaved changes apart.
  late String _savedSignature;

  final List<String> _samplePhotoPresets = const [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=600&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=600&auto=format&fit=crop&q=80',
  ];

  static const String _prefPendingCameraActionKey = 'pending_character_creator_camera_action';
  static const String _actionSelfieVerification = 'selfie_verification';
  static const String _actionProfilePhoto = 'profile_photo';

  static const int _minAge = 18;
  static const int _maxAge = 99;

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    final activeId = user?.id ?? AvatarStorageService.activeUserId;
    _selectedTastes = Set<String>.from(user?.tastes ?? AvatarStorageService.getUserTastes(activeId));
    _currentPhoto = user?.profilePhoto ?? AvatarStorageService.getUserPhoto(activeId);
    _isVerified = user?.isVerified ?? false;
    _verificationSelfie = user?.verificationSelfie;
    _userPhotos = List<String>.from(user?.photos ?? AvatarStorageService.getUserPhotos(activeId));
    _bioController = TextEditingController(
      text: user?.bio.isNotEmpty == true ? user!.bio : AvatarStorageService.getUserBio(activeId),
    );
    _selectedIntent = user?.intent.isNotEmpty == true ? user!.intent : AvatarStorageService.getUserIntent(activeId);
    _selectedDistanceKm = user?.maxDistanceKm ?? AvatarStorageService.getUserMaxDistance(activeId);
    _userAge = user?.age ?? 24;
    _userCommune = user?.commune ?? 'Santiago';
    _userGender = user?.gender ?? 'OTHER';
    _seekingGender = user?.seekingGender ?? 'ANY';
    _isInternational = user?.isInternational ?? false;
    _communeController = TextEditingController(text: _userCommune);
    _currentLifestyle = user?.lifestyle ?? AvatarStorageService.getUserLifestyle(activeId);
    _seekingAgeMin = user?.seekingAgeMin;
    _seekingAgeMax = user?.seekingAgeMax;
    _savedSignature = _signature;
    _bioController.addListener(_refresh);
    _communeController.addListener(_refresh);

    // Recuperación de imágenes si Android LMK destruyó el Activity en dispositivos de 4GB (ej. Redmi 12)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLostCameraData();
    });
  }

  void _refresh() => setState(() {});

  Future<void> _checkLostCameraData() async {
    try {
      final picker = ImagePicker();
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final pendingAction = prefs.getString(_prefPendingCameraActionKey);
      await prefs.remove(_prefPendingCameraActionKey);

      final file = response.file;
      if (file != null) {
        if (pendingAction == _actionSelfieVerification) {
          if (mounted) {
            await _processVerificationSelfie(file);
          }
        } else if (pendingAction == _actionProfilePhoto) {
          if (mounted) {
            await _uploadAndSetProfilePhoto(file);
          }
        }
      } else if (response.exception != null && mounted) {
        debugPrint('[EditProfileScreen] Excepción recuperada de ImagePicker: ${response.exception}');
      }
    } catch (e) {
      debugPrint('[EditProfileScreen] Error en _checkLostCameraData: $e');
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _communeController.dispose();
    super.dispose();
  }

  String get _resolvedCommune =>
      _communeController.text.trim().isNotEmpty ? _communeController.text.trim() : _userCommune;

  /// Every editable field, to compare against [_savedSignature].
  String get _signature => [
        _currentPhoto,
        _userPhotos.join('|'),
        _bioController.text.trim(),
        _selectedIntent,
        (_selectedTastes.toList()..sort()).join('|'),
        _selectedDistanceKm,
        _resolvedCommune,
        _userGender,
        _seekingGender,
        _isInternational,
        _currentLifestyle.toJson(),
        _seekingAgeMin,
        _seekingAgeMax,
      ].join('~');

  bool get _isDirty => _signature != _savedSignature;

  /// The profile as it will look once saved (drives the live card).
  UserProfile get _draft {
    final user = AuthService.currentUser ??
        UserProfile(id: AvatarStorageService.activeUserId, username: AvatarStorageService.activeUserId);
    return user
        .copyWith(
          avatarConfig: widget.avatarConfig,
          profilePhoto: _currentPhoto,
          photos: _userPhotos,
          bio: _bioController.text.trim(),
          intent: _selectedIntent,
          tastes: _selectedTastes.toList(),
          commune: _resolvedCommune,
          age: _userAge,
          isVerified: _isVerified,
          lifestyle: _currentLifestyle,
        )
        .withSeekingAgeRange(_seekingAgeMin, _seekingAgeMax);
  }

  void _saveAndClose() {
    if (_currentPhoto == null || _currentPhoto!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes definir tu Foto de Perfil oficial para citas.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      return;
    }

    AuthService.updateTastes(_selectedTastes.toList());

    final activeId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    AvatarStorageService.saveUserPhotos(activeId, _userPhotos);
    AvatarStorageService.saveUserPhoto(activeId, _currentPhoto!);
    AvatarStorageService.saveUserBio(activeId, _bioController.text.trim());
    AvatarStorageService.saveUserIntent(activeId, _selectedIntent);
    AvatarStorageService.saveUserMaxDistance(activeId, _selectedDistanceKm);

    final initialPhoto = AuthService.currentUser?.profilePhoto;
    if (_currentPhoto != null && _currentPhoto != initialPhoto) {
      AuthService.updateProfilePhoto(_currentPhoto!);
    }

    AuthService.updateDatingProfile(
      profilePhoto: _currentPhoto,
      photos: _userPhotos,
      bio: _bioController.text.trim(),
      intent: _selectedIntent,
      maxDistanceKm: _selectedDistanceKm,
      age: _userAge,
      commune: _resolvedCommune,
      isVerified: _isVerified,
      gender: _userGender,
      seekingGender: _seekingGender,
      isInternational: _isInternational,
      lifestyle: _currentLifestyle,
    );
    AuthService.updateSeekingAgeRange(_seekingAgeMin, _seekingAgeMax);
    AvatarStorageService.saveUserLifestyle(activeId, _currentLifestyle);
    AuthService.updateLifestyle(_currentLifestyle);
    AuthService.saveProfileToBackend();

    _savedSignature = _signature;
    widget.onSaved?.call(widget.avatarConfig.restrictedTo(_userGender));
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _confirmLeave() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('¿Descartar cambios?', style: TextStyle(color: Colors.white, fontSize: 17)),
        content: const Text(
          'Si sales ahora, tu perfil queda como estaba.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir editando', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar', style: TextStyle(color: Color(0xFFF87171))),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dirty = _isDirty;
    return PopScope(
      canPop: !dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F172A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text('Editar perfil', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: _saveAndClose,
                style: FilledButton.styleFrom(
                  backgroundColor: dirty ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                  foregroundColor: dirty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  visualDensity: VisualDensity.compact,
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverPersistentHeader(pinned: true, delegate: _CardHeader(profile: _draft)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                sliver: SliverList.list(
                  children: [
                    _sectionLabel(1, 'Tus fotos'),
                    _buildOfficialPhotoAndVerificationSection(),
                    const SizedBox(height: 16),
                    _buildHobbyGallerySection(),
                    _sectionLabel(2, 'Acerca de mí'),
                    _buildBioSection(),
                    _sectionLabel(3, 'Quién eres y cómo es tu realidad de vida'),
                    _buildLifestyleBadgesSection(),
                    _sectionLabel(4, 'Vibes y gustos'),
                    _buildTastesSection(),
                    _sectionLabel(5, 'A quién buscas conocer'),
                    _buildIdentitySection(),
                    _sectionLabel(6, 'Distancia y edad de búsqueda'),
                    _buildDistanceAndAgeSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(int number, String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, number == 1 ? 4 : 28, 4, 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: Color(0xFF334155), shape: BoxShape.circle),
            child:
                Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialPhotoAndVerificationSection() {
    final hasPhoto = _currentPhoto != null && _currentPhoto!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isVerified ? const Color(0xFF10B981).withOpacity(0.5) : const Color(0xFF334155),
          width: _isVerified ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                  child: Row(
                children: [
                  Icon(Icons.badge_outlined, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Flexible(
                      child: Text(
                    'Foto de Perfil Oficial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _isVerified ? const Color(0xFF059669).withOpacity(0.2) : const Color(0xFFD97706).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isVerified ? Icons.verified : Icons.warning_amber_rounded,
                      size: 14,
                      color: _isVerified ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isVerified ? 'Certificado 🛡️' : 'Sin Certificar ⚠️',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _isVerified ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tu foto principal visible en citas. Requiere certificación facial con selfie para comprobar tu identidad.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),

          // Main Photo Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo Display
              GestureDetector(
                onTap: _showChangeProfilePhotoDialog,
                child: Container(
                  width: 125,
                  height: 155,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _isVerified ? const Color(0xFF10B981) : const Color(0xFF475569),
                      width: 2,
                    ),
                    boxShadow: [
                      if (_isVerified)
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.25),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasPhoto
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              AppConfig.resolveMediaUrl(_currentPhoto!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Center(
                                child: Icon(Icons.broken_image, color: Colors.white38),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                color: Colors.black.withOpacity(0.65),
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit, color: Colors.white70, size: 12),
                                    SizedBox(width: 4),
                                    Text('Cambiar', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, color: Color(0xFF38BDF8), size: 28),
                            SizedBox(height: 6),
                            Text('Elegir Foto', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 16),

              // Actions & Verification Status Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isVerified) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF064E3B).withOpacity(0.6),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF059669)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF34D399), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Identidad comprobada. Tienes acceso total a citas y matchmaking en la Mazmorra.',
                                style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 11.5, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF94A3B8),
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.refresh, size: 14),
                        label: const Text('Re-certificar con selfie', style: TextStyle(fontSize: 11)),
                        onPressed: _startSelfieVerification,
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF78350F).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD97706)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFFBBF24), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Obligatorio: tómate una selfie rápida para comparar rasgos faciales y certificar tu cuenta.',
                                style: TextStyle(color: Color(0xFFFEF3C7), fontSize: 11.5, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.camera_front, size: 18),
                        label: const Text(
                          '🤳 Certificar con Selfie Rápida',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        onPressed: _startSelfieVerification,
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF38BDF8),
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.image, size: 14),
                      label: const Text('Cambiar Foto de Perfil', style: TextStyle(fontSize: 11.5)),
                      onPressed: _showChangeProfilePhotoDialog,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHobbyGallerySection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                  child: Row(
                children: [
                  Icon(Icons.photo_library, color: Color(0xFFFB7185), size: 20),
                  SizedBox(width: 8),
                  Flexible(
                      child: Text(
                    'Galería de Pasatiempos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Text(
                  '${_userPhotos.length} / 5 fotos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Comparte fotos de tus hobbies, viajes, mascotas o lugares. No requieren certificación y se revelarán tras match mutuo.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: 5,
            itemBuilder: (context, index) {
              if (index < _userPhotos.length) {
                final photoUrl = _userPhotos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        AppConfig.resolveMediaUrl(photoUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF334155),
                            child: const Icon(Icons.broken_image, color: Colors.white38, size: 20),
                          );
                        },
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _userPhotos.removeAt(index);
                          });
                          AuthService.updateProfilePhotos(_userPhotos);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 12),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return GestureDetector(
                  onTap: _showAddHobbyPhotoDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF475569),
                        width: 1.2,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Color(0xFF38BDF8), size: 22),
                        SizedBox(height: 4),
                        Text('Añadir', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10)),
                      ],
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndSetProfilePhoto(XFile pickedFile) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Subiendo Foto Oficial al servidor...'),
            ],
          ),
          duration: Duration(seconds: 4),
        ),
      );
    }

    try {
      final bytes = await pickedFile.readAsBytes();
      final filename =
          pickedFile.name.isNotEmpty ? pickedFile.name : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final uploadedUrl = await AuthService.uploadMediaPhoto(bytes, filename, setAsProfile: true);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        setState(() {
          _currentPhoto = uploadedUrl;
          _isVerified = false; // Requiere certificar la nueva foto
        });
        AuthService.updateProfilePhoto(uploadedUrl);

        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto oficial actualizada. Recuerda certificarla con tu selfie 🤳'),
              backgroundColor: Color(0xFF0284C7),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al subir la foto de perfil al servidor'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _pickAndUploadProfilePhoto(ImageSource source, BuildContext dialogContext) async {
    if (dialogContext.mounted) Navigator.pop(dialogContext);

    XFile? pickedFile;
    try {
      if (source == ImageSource.camera) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefPendingCameraActionKey, _actionProfilePhoto);
      }

      // Pausar motor Flame para ceder memoria y CPU en dispositivos de gama de entrada

      final picker = ImagePicker();
      pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1080,
        maxHeight: 1080,
        imageQuality: 80,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al acceder a la cámara o galería: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefPendingCameraActionKey);
      } catch (_) {}
    }

    if (pickedFile != null && mounted) {
      await _uploadAndSetProfilePhoto(pickedFile);
    }
  }

  void _showChangeProfilePhotoDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.badge_outlined, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Foto de Perfil Oficial', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Elige tu foto de perfil desde tu dispositivo:',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Galería', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadProfilePhoto(ImageSource.gallery, dialogContext),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Cámara', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadProfilePhoto(ImageSource.camera, dialogContext),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF334155))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('O fotos de muestra recomendadas',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _samplePhotoPresets.map((url) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentPhoto = url;
                          _isVerified = false;
                        });
                        AuthService.updateProfilePhoto(url);
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Foto de muestra seleccionada. Realiza la certificación para activarla 🤳'),
                            backgroundColor: Color(0xFF0284C7),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'O pega una URL: https://...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty) {
                setState(() {
                  _currentPhoto = url;
                  _isVerified = false;
                });
                AuthService.updateProfilePhoto(url);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Usar URL'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadHobbyPhoto(ImageSource source, BuildContext dialogContext) async {
    try {
      final availableSlots = 5 - _userPhotos.length;
      if (availableSlots <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ya alcanzaste el límite máximo de 5 fotos en la galería'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (dialogContext.mounted) Navigator.pop(dialogContext);

      final picker = ImagePicker();
      List<XFile> pickedFiles = [];

      try {
        if (source == ImageSource.gallery) {
          pickedFiles = await picker.pickMultiImage(
            maxWidth: 1080,
            maxHeight: 1080,
            imageQuality: 80,
          );
        } else {
          final single = await picker.pickImage(
            source: ImageSource.camera,
            maxWidth: 1080,
            maxHeight: 1080,
            imageQuality: 80,
          );
          if (single != null) {
            pickedFiles.add(single);
          }
        }
      } finally {}

      if (pickedFiles.isEmpty) return;

      final toUpload = pickedFiles.take(availableSlots).toList();
      final List<String> newlyUploaded = [];

      for (int i = 0; i < toUpload.length; i++) {
        final file = toUpload[i];
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(toUpload.length > 1
                      ? 'Subiendo foto ${i + 1} de ${toUpload.length} a la galería...'
                      : 'Subiendo foto a la galería...'),
                ],
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        }

        final bytes = await file.readAsBytes();
        final filename = file.name.isNotEmpty ? file.name : 'hobby_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';

        final uploadedUrl = await AuthService.uploadMediaPhoto(bytes, filename, setAsProfile: false);
        if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
          newlyUploaded.add(uploadedUrl);
        }
      }

      if (newlyUploaded.isNotEmpty) {
        setState(() {
          _userPhotos.addAll(newlyUploaded);
        });
        await AuthService.updateProfilePhotos(_userPhotos);
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newlyUploaded.length == 1
                  ? '¡Foto añadida a tu galería de pasatiempos!'
                  : '¡${newlyUploaded.length} fotos añadidas a tu galería!'),
              backgroundColor: const Color(0xFF059669),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar foto: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showAddHobbyPhotoDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.photo_library, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Añadir Foto a Galería', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sube fotos de tus pasatiempos o momentos (puedes seleccionar varias):',
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.photo_library, size: 18),
                        label: const Text('Galería (Múltiples)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadHobbyPhoto(ImageSource.gallery, dialogContext),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF38BDF8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Cámara', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        onPressed: () => _pickAndUploadHobbyPhoto(ImageSource.camera, dialogContext),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFF334155))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('O fotos de muestra', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                    ),
                    Expanded(child: Divider(color: Color(0xFF334155))),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _samplePhotoPresets.map((url) {
                    return GestureDetector(
                      onTap: () {
                        if (_userPhotos.length < 5) {
                          setState(() {
                            _userPhotos.add(url);
                          });
                          AuthService.updateProfilePhotos(_userPhotos);
                          Navigator.pop(dialogContext);
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'https://images.unsplash.com/...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty && _userPhotos.length < 5) {
                setState(() {
                  _userPhotos.add(url);
                });
                AuthService.updateProfilePhotos(_userPhotos);
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Añadir URL'),
          ),
        ],
      ),
    );
  }

  Future<void> _processVerificationSelfie(XFile pickedFile) async {
    if (!mounted) return;

    // Mostrar diálogo interactivo de escaneo biométrico
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SimulatedFaceScanDialog(),
    );

    try {
      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name.isNotEmpty ? pickedFile.name : 'selfie.jpg';

      // Esperar 1.2 segundos para mostrar el progreso de escaneo visual
      await Future.delayed(const Duration(milliseconds: 1200));

      final result = await AuthService.verifyIdentity(bytes, filename);

      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo de escaneo
      }

      if (result['verified'] == true) {
        setState(() {
          _isVerified = true;
          _verificationSelfie = result['selfieUrl'] as String?;
        });

        if (mounted) {
          _showVerificationSuccessDialog(result);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'No se pudo verificar la identidad facial.'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error durante la verificación: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _startSelfieVerification() async {
    if (_currentPhoto == null || _currentPhoto!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero debes seleccionar una Foto de Perfil Oficial antes de verificar.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final shouldOpenCamera = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Flexible(child: Text('Certificación Facial', style: TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tómate una selfie rápida de frente con buena iluminación.',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'El sistema comparará biométricamente tu rostro con tu Foto de Perfil Oficial para validar que eres una persona real.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.camera_front, size: 18),
            label: const Text('Abrir Cámara Frontal'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (shouldOpenCamera != true) return;
    if (!mounted) return;

    final picker = ImagePicker();
    XFile? pickedFile;

    try {
      // 1. Registrar intención pendiente para LMK en Android de gama baja
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefPendingCameraActionKey, _actionSelfieVerification);

      // 2. Pausar motor Flame para ceder memoria y CPU al sensor nativo de MIUI

      pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
    } catch (_) {
      // Fallback para emuladores o plataformas sin cámara frontal directa
      try {
        pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 75,
        );
      } catch (e) {
        debugPrint('[EditProfileScreen] Error en fallback de selección de selfie: $e');
      }
    } finally {
      // Reanudar Flame y limpiar bandera si el proceso sobrevivió
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefPendingCameraActionKey);
      } catch (_) {}
    }

    if (pickedFile == null) return;
    if (!mounted) return;

    await _processVerificationSelfie(pickedFile);
  }

  void _showVerificationSuccessDialog(Map<String, dynamic> result) {
    final similarity = result['similarity'] != null ? '${(result['similarity'] as num).toStringAsFixed(1)}%' : '98.5%';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified, color: Color(0xFF10B981), size: 48),
            ),
            const SizedBox(height: 16),
            const Text(
              '¡Identidad Certificada! 🛡️',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Coincidencia facial: $similarity (AWS Rekognition Simulado)',
              style: const TextStyle(color: Color(0xFF34D399), fontSize: 12.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu perfil ha recibido el distintivo de confianza. Ahora puedes ingresar a las citas en la Mazmorra Cooperativa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.3),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('¡Excelente!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 8),
              Text(
                'Acerca de mí',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cuenta qué te apasiona, tu café o juego favorito, o qué buscas en una conexión.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 180,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'Ej: Amante del café de especialidad, la música lo-fi y las partidas cooperativas. Busco conectar sin prisas ✨',
              hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF475569)),
              ),
              counterStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleBadgesSection() {
    final activeBadges = _currentLifestyle.activeBadges;
    final hasBadges = activeBadges.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasBadges ? const Color(0xFF0284C7).withOpacity(0.5) : const Color(0xFF334155),
          width: hasBadges ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.badge_rounded, color: Color(0xFF38BDF8), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¿Quién eres y cómo es tu realidad de vida actual?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_currentLifestyle.activeCount}/12',
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Insignias opcionales para que tu cita conozca tus hábitos y estilo de vida antes de la fogata.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // Active Badges Chips preview
          if (hasBadges) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: activeBadges.map((b) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.6), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 6),
                      Text(
                        b.label,
                        style: const TextStyle(
                          color: Color(0xFFE2E8F0),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
          ],

          // Button to open LifestyleBadgesSheet
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF38BDF8),
                side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: const Color(0xFF0284C7).withOpacity(0.08),
              ),
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: Text(
                hasBadges
                    ? 'Gestionar mis Insignias (${_currentLifestyle.activeCount}/12 activas)'
                    : '+ Añadir Insignias a mi Ficha',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                LifestyleBadgesSheet.show(
                  context,
                  initialLifestyle: _currentLifestyle,
                  onSaved: (updated) {
                    setState(() {
                      _currentLifestyle = updated;
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTastesSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.interests, color: Color(0xFFA855F7), size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tus Vibes, Ejes & Gustos Cozy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedTastes.length} seleccionados',
                style: const TextStyle(color: Color(0xFFC084FC), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Los 4 primeros ejes son obligatorios para conectar en sintonía. Los dilemas y gustos alimentan las preguntas de la fogata.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          ...PreferenceCatalog.categories.map((cat) {
            final hasSelected = cat.items.any((it) => _selectedTastes.contains(it.id));
            final isObligatoryAndMissing = cat.isRequired && !hasSelected;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isObligatoryAndMissing
                      ? const Color(0xFFEF4444).withOpacity(0.6)
                      : (cat.isRequired ? const Color(0xFFF59E0B).withOpacity(0.4) : const Color(0xFF334155)),
                  width: isObligatoryAndMissing ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                      if (cat.isRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isObligatoryAndMissing
                                ? const Color(0xFFEF4444).withOpacity(0.2)
                                : const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isObligatoryAndMissing ? '⚠️ Requerido' : '✓ Listo',
                            style: TextStyle(
                              color: isObligatoryAndMissing ? const Color(0xFFF87171) : const Color(0xFFFBBF24),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (cat.isSingleSelect)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Opcional • Elige solo 1',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Opcional',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cat.isSingleSelect && !cat.isRequired
                        ? '${cat.description} (Opcional - solo se puede elegir 1)'
                        : cat.description,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cat.items.map((item) {
                      final isSelected = _selectedTastes.contains(item.id);
                      return FilterChip(
                        label: Text('${item.emoji} ${item.title}'),
                        selected: isSelected,
                        selectedColor: cat.isRequired
                            ? const Color(0xFFF59E0B).withOpacity(0.3)
                            : const Color(0xFFA855F7).withOpacity(0.3),
                        backgroundColor: const Color(0xFF1E293B),
                        checkmarkColor: cat.isRequired ? const Color(0xFFFBBF24) : const Color(0xFFC084FC),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? (cat.isRequired ? const Color(0xFFF59E0B) : const Color(0xFFA855F7))
                                : const Color(0xFF334155),
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (cat.isSingleSelect) {
                              // Desmarcar otros items de la misma categoría
                              for (final other in cat.items) {
                                _selectedTastes.remove(other.id);
                              }
                              if (selected) {
                                _selectedTastes.add(item.id);
                                if (cat.id == 'dating_intentions') {
                                  _selectedIntent = item.id;
                                  AvatarStorageService.saveUserIntent(
                                    AuthService.currentUser?.id ?? AvatarStorageService.activeUserId,
                                    item.id,
                                  );
                                }
                              }
                            } else {
                              if (selected) {
                                _selectedTastes.add(item.id);
                              } else {
                                _selectedTastes.remove(item.id);
                              }
                            }
                          });
                          AuthService.updateTastes(_selectedTastes.toList());
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Who you are and who you seek (gender and the gender sought), paired mutually by matchmaking.
  Widget _buildIdentitySection() {
    final genderOptions = [
      {'value': 'MAN', 'label': '👨 Hombre'},
      {'value': 'WOMAN', 'label': '👩 Mujer'},
      {'value': 'NON_BINARY', 'label': '✨ No binario'},
    ];

    final seekingOptions = [
      {'value': 'WOMAN', 'label': '👩 Mujeres'},
      {'value': 'MAN', 'label': '👨 Hombres'},
      {'value': 'ANY', 'label': '💫 Todos'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección Identidad & Búsqueda
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFFFF4081), size: 20),
              SizedBox(width: 8),
              Flexible(
                  child: Text(
                'Identidad & A Quién Buscas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'El emparejamiento empareja solo a personas con compatibilidad mutua.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // ¿Cómo te identificas? (Soy)
          const Text('Soy:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: genderOptions.map((opt) {
              final isSelected = _userGender == opt['value'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                selectedColor: const Color(0xFFFF4081).withOpacity(0.3),
                backgroundColor: const Color(0xFF0F172A),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFFF4081) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFFF4081) : const Color(0xFF475569),
                ),
                onSelected: (selected) {
                  if (!selected) return;
                  setState(() => _userGender = opt['value']!);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ¿A quién buscas? (Busco)
          const Text('Busco conocer:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: seekingOptions.map((opt) {
              final isSelected = _seekingGender == opt['value'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                selectedColor: const Color(0xFF38BDF8).withOpacity(0.3),
                backgroundColor: const Color(0xFF0F172A),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _seekingGender = opt['value']!);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool get _hasAgeFilter => _seekingAgeMin != null || _seekingAgeMax != null;

  /// Where you are, how far to search, and the optional age range sought.
  Widget _buildDistanceAndAgeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección Ubicación
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Flexible(
                  child: Text(
                'Tu Ciudad / Comuna',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Escribe la ciudad o comuna donde resides para calcular distancias aproximadas.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // Campo de texto de Ciudad y Edad
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _communeController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_city, color: Color(0xFF10B981), size: 18),
                    hintText: 'Ej. Santiago, Valdivia, Viña...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Text(
                  '$_userAge años',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nota de privacidad amigable
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tu privacidad está protegida: Solo calculamos proximidad aproximada (~2 km), nunca tu calle ni dirección exacta.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 12),

          // Alcance Internacional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explorar sin fronteras (Global):',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Emparejar con compañeros de otros países',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              )),
              Switch(
                value: _isInternational,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) {
                  setState(() => _isInternational = val);
                },
              ),
            ],
          ),

          if (!_isInternational) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                    child: const Text(
                  'Distancia máxima preferida:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Text(
                    _selectedDistanceKm >= 100 ? 'Sin límite (Nacional)' : '${_selectedDistanceKm.toInt()} km',
                    style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            Slider(
              value: _selectedDistanceKm.clamp(5.0, 100.0),
              min: 5.0,
              max: 100.0,
              divisions: 19,
              activeColor: const Color(0xFF10B981),
              inactiveColor: const Color(0xFF334155),
              onChanged: (val) {
                setState(() => _selectedDistanceKm = val);
              },
            ),
            const Text(
              '💡 Si transcurren más de 15 segundos sin personas en tu radio, la búsqueda se expandirá gradualmente para no hacerte esperar.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 12),

          // Filtro de edad: apagado por defecto; si se activa, cuenta en ambos sentidos
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrar por edad',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Solo te emparejamos si cada uno está en el rango del otro.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasAgeFilter,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: (on) => setState(() {
                  if (on) {
                    // Start around the player's own age.
                    _seekingAgeMin = (_userAge - 5).clamp(_minAge, _maxAge);
                    _seekingAgeMax = (_userAge + 5).clamp(_minAge, _maxAge);
                  } else {
                    _seekingAgeMin = null;
                    _seekingAgeMax = null;
                  }
                }),
              ),
            ],
          ),
          if (_hasAgeFilter) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edad que buscas:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_seekingAgeMin ?? _minAge} – ${_seekingAgeMax ?? _maxAge} años',
                  style: const TextStyle(color: Color(0xFF7DD3FC), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(
                (_seekingAgeMin ?? _minAge).toDouble(),
                (_seekingAgeMax ?? _maxAge).toDouble(),
              ),
              min: _minAge.toDouble(),
              max: _maxAge.toDouble(),
              divisions: _maxAge - _minAge,
              activeColor: const Color(0xFF38BDF8),
              inactiveColor: const Color(0xFF334155),
              labels: RangeLabels('${_seekingAgeMin ?? _minAge}', '${_seekingAgeMax ?? _maxAge}'),
              onChanged: (range) => setState(() {
                _seekingAgeMin = range.start.round();
                _seekingAgeMax = range.end.round();
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// The card's real face pinned above the form, shrinking from full size to a small preview as the
/// form scrolls.
class _CardHeader extends SliverPersistentHeaderDelegate {
  _CardHeader({required this.profile});

  final UserProfile profile;

  @override
  double get maxExtent => 360;

  @override
  double get minExtent => 150;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Center(child: ProfileCard(profile: profile, showReal: true, flipDuration: Duration.zero)),
      ),
    );
  }

  @override
  bool shouldRebuild(_CardHeader old) => true;
}

class _SimulatedFaceScanDialog extends StatefulWidget {
  const _SimulatedFaceScanDialog();

  @override
  State<_SimulatedFaceScanDialog> createState() => _SimulatedFaceScanDialogState();
}

class _SimulatedFaceScanDialogState extends State<_SimulatedFaceScanDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  int _step = 0;

  final List<String> _steps = const [
    'Detectando puntos y proporciones faciales...',
    'Generando vector de embedding biométrico...',
    'Comparando con Foto Oficial en AWS Rekognition (Simulado)...',
    'Validando coincidencia y liveness...',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _progressSteps();
  }

  void _progressSteps() async {
    for (int i = 1; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        setState(() {
          _step = i;
        });
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            // Scanning Visualizer
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0F172A),
                    border: Border.all(
                      color: Color.lerp(const Color(0xFF0284C7), const Color(0xFF10B981), _animController.value)!,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.3 + 0.3 * _animController.value),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        size: 64,
                        color: Colors.white.withOpacity(0.4 + 0.4 * _animController.value),
                      ),
                      Positioned(
                        top: 20 + 70 * _animController.value,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, Color(0xFF38BDF8), Color(0xFF34D399), Colors.transparent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withOpacity(0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Escaneo Biométrico',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _steps[_step],
                key: ValueKey(_step),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor: const Color(0xFF0F172A),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Simulación de AWS Rekognition activa',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
