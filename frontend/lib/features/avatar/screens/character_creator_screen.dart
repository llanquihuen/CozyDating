import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../games/character_preview_game.dart';

class CharacterCreatorScreen extends StatefulWidget {
  final AvatarConfig? initialConfig;
  final ValueChanged<AvatarConfig>? onSaved;
  final int initialScreenMode;

  const CharacterCreatorScreen({
    super.key,
    this.initialConfig,
    this.onSaved,
    this.initialScreenMode = 0,
  });

  @override
  State<CharacterCreatorScreen> createState() => _CharacterCreatorScreenState();
}

class _CharacterCreatorScreenState extends State<CharacterCreatorScreen>
    with TickerProviderStateMixin {
  late AvatarConfig _currentConfig;
  late CharacterPreviewGame _previewGame;
  late Set<String> _selectedTastes;

  // 0: Modo Personaje (Avatar), 1: Modo Perfil de Citas (Tinder-style)
  int _screenModeIndex = 0;

  // Sub-sección Personaje: 0: Rostro & Cabello, 1: Vestimenta & Estilo
  int _mainSectionIndex = 0;

  late TabController _faceTabController;
  late TabController _clothesTabController;
  final bool _syncBrowsWithHair = true;
  double _dragDeltaAccumulator = 0.0;
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

  @override
  void initState() {
    super.initState();
    _screenModeIndex = widget.initialScreenMode;
    _currentConfig = widget.initialConfig ?? AvatarStorageService.loadConfig();
    final loadedTastes = AuthService.currentUser?.tastes ?? [];
    _selectedTastes = Set<String>.from(loadedTastes);
    final activeId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    _currentPhoto = AuthService.currentUser?.profilePhoto ?? AvatarStorageService.getUserPhoto(activeId);
    _isVerified = AuthService.currentUser?.isVerified ?? false;
    _verificationSelfie = AuthService.currentUser?.verificationSelfie;
    
    final loadedPhotos = AuthService.currentUser?.photos ?? AvatarStorageService.getUserPhotos(activeId);
    _userPhotos = List<String>.from(loadedPhotos);
    if (_currentPhoto == null && _userPhotos.isNotEmpty) {
      _currentPhoto = _userPhotos.removeAt(0);
    } else if (_currentPhoto != null && _userPhotos.contains(_currentPhoto)) {
      _userPhotos.remove(_currentPhoto);
    }

    _bioController = TextEditingController(
      text: AuthService.currentUser?.bio.isNotEmpty == true
          ? AuthService.currentUser!.bio
          : AvatarStorageService.getUserBio(activeId),
    );
    _selectedIntent = AuthService.currentUser?.intent.isNotEmpty == true
        ? AuthService.currentUser!.intent
        : AvatarStorageService.getUserIntent(activeId);
    _selectedDistanceKm = AuthService.currentUser?.maxDistanceKm ?? AvatarStorageService.getUserMaxDistance(activeId);
    _userAge = AuthService.currentUser?.age ?? 24;
    _userCommune = AuthService.currentUser?.commune ?? 'Santiago';

    _previewGame = CharacterPreviewGame(
      config: _currentConfig,
      initialFaceZoom: true,
    );
    _faceTabController = TabController(length: 3, vsync: this);
    _clothesTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _faceTabController.dispose();
    _clothesTabController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _onMainSectionChanged(int index) {
    if (_mainSectionIndex == index) return;
    setState(() {
      _mainSectionIndex = index;
    });
    // Auto adjust camera zoom according to active section
    _previewGame.setFaceFocus(index == 0);
  }

  void _updateConfig(AvatarConfig newConfig) {
    setState(() {
      _currentConfig = newConfig;
    });
    _previewGame.updateConfig(newConfig);
  }

  void _randomizeAvatar() {
    final rand = Random();
    final randomSkin = AvatarConfig.skinTones[rand.nextInt(AvatarConfig.skinTones.length)];
    final randomEyeColor = AvatarConfig.eyeColors[rand.nextInt(AvatarConfig.eyeColors.length)];
    final randomHairColor = AvatarConfig.hairColors[rand.nextInt(AvatarConfig.hairColors.length)];
    final randomTopColor = AvatarConfig.clothingColors[rand.nextInt(AvatarConfig.clothingColors.length)];
    final randomBottomColor = AvatarConfig.clothingColors[rand.nextInt(AvatarConfig.clothingColors.length)];

    final newConfig = AvatarConfig(
      bodyType: AvatarConfig.availableBodyTypes[rand.nextInt(AvatarConfig.availableBodyTypes.length)],
      faceShape: AvatarConfig.availableFaceShapes[rand.nextInt(AvatarConfig.availableFaceShapes.length)],
      skinColor: randomSkin,
      eyeStyle: AvatarConfig.availableEyeStyles[rand.nextInt(AvatarConfig.availableEyeStyles.length)],
      eyeColor: randomEyeColor,
      eyebrowStyle: 'none',
      eyebrowColor: randomHairColor,
      noseStyle: AvatarConfig.availableNoseStyles[rand.nextInt(AvatarConfig.availableNoseStyles.length)],
      mouthStyle: AvatarConfig.availableMouthStyles[rand.nextInt(AvatarConfig.availableMouthStyles.length)],
      faceDetail: 'none',
      faceDetailColor: const Color(0xFFFF7777),
      hairStyle: AvatarConfig.availableHairStyles[rand.nextInt(AvatarConfig.availableHairStyles.length)],
      hairColor: randomHairColor,
      topStyle: AvatarConfig.availableTopStyles[rand.nextInt(AvatarConfig.availableTopStyles.length)],
      topColor: randomTopColor,
      bottomStyle: AvatarConfig.availableBottomStyles[rand.nextInt(AvatarConfig.availableBottomStyles.length)],
      bottomColor: randomBottomColor,
      shoeStyle: AvatarConfig.availableShoeStyles[rand.nextInt(AvatarConfig.availableShoeStyles.length)],
      shoeColor: const Color(0xFF334155),
      accessoryStyle: 'none',
      accessoryColor: const Color(0xFFEAB308),
    );

    _updateConfig(newConfig);
  }

  void _saveAndClose() {
    if (_currentPhoto == null || _currentPhoto!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes definir tu Foto de Perfil oficial para citas.'),
          backgroundColor: Colors.deepOrange,
        ),
      );
      setState(() {
        _screenModeIndex = 1;
      });
      return;
    }

    AvatarStorageService.saveConfig(_currentConfig);
    AuthService.saveAvatarConfig(_currentConfig);
    AuthService.updateTastes(_selectedTastes.toList());

    final activeId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    AvatarStorageService.saveUserPhotos(activeId, _userPhotos);
    AvatarStorageService.saveUserPhoto(activeId, _currentPhoto!);
    AvatarStorageService.saveUserBio(activeId, _bioController.text.trim());
    AvatarStorageService.saveUserIntent(activeId, _selectedIntent);
    AvatarStorageService.saveUserMaxDistance(activeId, _selectedDistanceKm);

    AuthService.updateProfilePhoto(_currentPhoto!);
    AuthService.updateProfilePhotos(_userPhotos);

    AuthService.updateDatingProfile(
      profilePhoto: _currentPhoto,
      photos: _userPhotos,
      bio: _bioController.text.trim(),
      intent: _selectedIntent,
      maxDistanceKm: _selectedDistanceKm,
      age: _userAge,
      commune: _userCommune,
      isVerified: _isVerified,
    );

    widget.onSaved?.call(_currentConfig);
    if (Navigator.canPop(context)) {
      Navigator.pop(context, _currentConfig);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            _buildModeToggleHeader(),
            Expanded(
              child: _screenModeIndex == 0
                  ? (isWide ? _buildWideLayout() : _buildNarrowLayout())
                  : _buildDatingProfileLayout(isWide),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E293B),
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
            ),
            child: const Icon(Icons.brush, color: Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Armario • Avatar & Perfil',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFFF8FAFC),
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Personaliza tu personaje pixel art',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Aleatorio',
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
            ),
            child: const Icon(Icons.casino, color: Color(0xFFA78BFA), size: 18),
          ),
          onPressed: _randomizeAvatar,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0, top: 8, bottom: 8, left: 4),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: const Color(0xFF0284C7).withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: _saveAndClose,
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              'Guardar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggleHeader() {
    return Container(
      color: const Color(0xFF1E293B),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _screenModeIndex = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _screenModeIndex == 0 ? const Color(0xFF0284C7) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.face,
                        size: 18,
                        color: _screenModeIndex == 0 ? Colors.white : Colors.white60,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Versión Personaje',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _screenModeIndex == 0 ? Colors.white : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _screenModeIndex = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _screenModeIndex == 1 ? const Color(0xFFE11D48) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 18,
                        color: _screenModeIndex == 1 ? Colors.white : Colors.white60,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Perfil de Citas',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _screenModeIndex == 1 ? Colors.white : Colors.white60,
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
    );
  }

  Widget _buildDatingProfileLayout(bool isWide) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 40 : 16,
        vertical: 20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Foto de Perfil Oficial & Verificación Facial
              _buildOfficialPhotoAndVerificationSection(),
              const SizedBox(height: 20),

              // 2. Galería de Pasatiempos (Hasta 5 fotos)
              _buildHobbyGallerySection(),
              const SizedBox(height: 24),

              // 2. Acerca de mí (Biografía)
              _buildBioSection(),
              const SizedBox(height: 24),

              // 3. Proximidad y Ubicación
              _buildDistanceAndLocationSection(),
              const SizedBox(height: 24),

              // 4. Tus Vibes, Ejes & Gustos Cozy (Incluye tu Intención de Cita oficial como 1er Eje)
              _buildTastesSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
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
              const Row(
                children: [
                  Icon(Icons.badge_outlined, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Foto de Perfil Oficial',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _isVerified
                      ? const Color(0xFF059669).withOpacity(0.2)
                      : const Color(0xFFD97706).withOpacity(0.2),
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
              const Row(
                children: [
                  Icon(Icons.photo_library, color: Color(0xFFFB7185), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Galería de Pasatiempos',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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

  Future<void> _pickAndUploadProfilePhoto(ImageSource source, BuildContext dialogContext) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (dialogContext.mounted) Navigator.pop(dialogContext);

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

      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name.isNotEmpty
          ? pickedFile.name
          : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';

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
                      child: Text('O fotos de muestra recomendadas', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
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
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (pickedFile == null) return;
      if (dialogContext.mounted) Navigator.pop(dialogContext);

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
                Text('Subiendo foto a la galería...'),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }

      final bytes = await pickedFile.readAsBytes();
      final filename = pickedFile.name.isNotEmpty
          ? pickedFile.name
          : 'hobby_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final uploadedUrl = await AuthService.uploadMediaPhoto(bytes, filename, setAsProfile: false);
      if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
        if (_userPhotos.length < 5) {
          setState(() {
            _userPhotos.add(uploadedUrl);
          });
          AuthService.updateProfilePhotos(_userPhotos);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Foto añadida a tu galería de pasatiempos!'),
              backgroundColor: Color(0xFF059669),
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
                  'Sube una foto de tus pasatiempos o momentos:',
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
                        label: const Text('Galería', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

    final picker = ImagePicker();
    final pickedFile = await showDialog<XFile?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.face_retouching_natural, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Certificación Facial', style: TextStyle(color: Colors.white, fontSize: 16)),
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
            onPressed: () => Navigator.pop(ctx, null),
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
            onPressed: () async {
              try {
                final file = await picker.pickImage(
                  source: ImageSource.camera,
                  preferredCameraDevice: CameraDevice.front,
                  maxWidth: 1200,
                  maxHeight: 1200,
                  imageQuality: 85,
                );
                if (ctx.mounted) Navigator.pop(ctx, file);
              } catch (_) {
                // Fallback para emuladores o plataformas sin cámara
                final file = await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: 1200,
                  maxHeight: 1200,
                );
                if (ctx.mounted) Navigator.pop(ctx, file);
              }
            },
          ),
        ],
      ),
    );

    if (pickedFile == null) return;

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
              hintText: 'Ej: Amante del café de especialidad, la música lo-fi y las partidas cooperativas. Busco conectar sin prisas ✨',
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


  Widget _buildDistanceAndLocationSection() {
    final communes = [
      'Santiago', 'Providencia', 'Las Condes', 'Ñuñoa', 'La Florida', 'Maipú',
      'Puente Alto', 'San Miguel', 'Viña del Mar', 'Valparaíso', 'Concepción',
      'La Serena', 'Coquimbo', 'Antofagasta', 'Temuco', 'Rancagua'
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
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Text(
                'Ubicación & Radio de Búsqueda',
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
            'El emparejamiento calcula la distancia real en kilómetros entre ambas ubicaciones.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),

          // Comuna y Edad
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tu Comuna / Ciudad:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: communes.contains(_userCommune) ? _userCommune : 'Santiago',
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          items: communes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _userCommune = val);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Edad:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF475569)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_userAge años', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Slider de Distancia
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Distancia máxima preferida:',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
              ),
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
              const Row(
                children: [
                  Icon(Icons.interests, color: Color(0xFFA855F7), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Tus Vibes, Ejes & Gustos Cozy',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
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
                            'Elige 1 favorito',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(cat.description, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
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

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left column: Interactive Preview Studio
        SizedBox(
          width: 360,
          child: _buildPreviewPanel(isHorizontal: false),
        ),
        Container(
          width: 1,
          color: const Color(0xFF334155),
        ),
        // Right column: Multi-stage customization studio
        Expanded(
          child: _buildCustomizationWorkspace(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        // Top section: Compact Preview Studio (Canvas on Left, Controls on Right)
        SizedBox(
          height: 235,
          child: _buildPreviewPanel(isHorizontal: true),
        ),
        Container(
          height: 1,
          color: const Color(0xFF334155),
        ),
        // Bottom section: Customization Workspace
        Expanded(
          child: _buildCustomizationWorkspace(),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // PREVIEW STUDIO PANEL (CANVAS ON LEFT, CONTROLS ON RIGHT)
  // -------------------------------------------------------------
  Widget _buildPreviewPanel({required bool isHorizontal}) {
    final canvasWidget = Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155), width: 2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1E293B),
                Color(0xFF0F172A),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              _dragDeltaAccumulator += details.delta.dx;
              const double stepThreshold = 18.0;
              if (_dragDeltaAccumulator >= stepThreshold) {
                setState(() {
                  _previewGame.rotateRight();
                });
                _dragDeltaAccumulator -= stepThreshold;
              } else if (_dragDeltaAccumulator <= -stepThreshold) {
                setState(() {
                  _previewGame.rotateLeft();
                });
                _dragDeltaAccumulator += stepThreshold;
              }
            },
            onHorizontalDragEnd: (_) {
              _dragDeltaAccumulator = 0.0;
            },
            child: GameWidget(game: _previewGame),
          ),
        ),
        // Camera Mode Badge (clickable toggle)
        Positioned(
          top: 8,
          left: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _previewGame.toggleFaceFocus();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _previewGame.isFaceZoom
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF818CF8),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _previewGame.isFaceZoom ? Icons.zoom_in : Icons.accessibility_new,
                    size: 12,
                    color: _previewGame.isFaceZoom
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFA5B4FC),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _previewGame.isFaceZoom ? 'Zoom Rostro' : 'Cuerpo Entero',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _previewGame.isFaceZoom
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFFA5B4FC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Rotate quick buttons
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuickRotateBtn(Icons.rotate_left, () {
                setState(() {
                  _previewGame.rotateLeft();
                });
              }),
              const SizedBox(width: 4),
              _buildQuickRotateBtn(Icons.rotate_right, () {
                setState(() {
                  _previewGame.rotateRight();
                });
              }),
            ],
          ),
        ),
      ],
    );

    final controlsWidget = _buildSectionSwitcherPanel();

    return Container(
      color: const Color(0xFF131A2A),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: isHorizontal
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: Canvas
                Expanded(
                  flex: 5,
                  child: canvasWidget,
                ),
                const SizedBox(width: 12),
                // Right: Controls
                Expanded(
                  flex: 6,
                  child: controlsWidget,
                ),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 3, child: canvasWidget),
                const SizedBox(height: 8),
                Expanded(flex: 2, child: controlsWidget),
              ],
            ),
    );
  }

  Widget _buildQuickRotateBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A).withOpacity(0.85),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Icon(icon, size: 14, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildSectionSwitcherPanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.tune_rounded, size: 14, color: Color(0xFF38BDF8)),
              SizedBox(width: 6),
              Text(
                'SECCIONES DE EDICIÓN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildSectionTabButton(
              index: 0,
              title: '1. Rostro & Cabello',
              subtitle: 'Zoom Primer Plano',
              icon: Icons.face_retouching_natural,
              activeColor: const Color(0xFF0284C7),
              activeBorderColor: const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildSectionTabButton(
              index: 1,
              title: '2. Vestimenta & Estilo',
              subtitle: 'Cuerpo Completo',
              icon: Icons.dry_cleaning,
              activeColor: const Color(0xFF7C3AED),
              activeBorderColor: const Color(0xFFA78BFA),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // MAIN CUSTOMIZATION WORKSPACE (2 SECTIONS)
  // -------------------------------------------------------------
  Widget _buildCustomizationWorkspace() {
    return Column(
      children: [
        // Sub-tabs for the selected section
        Container(
          color: const Color(0xFF1E293B),
          child: _mainSectionIndex == 0
              ? TabBar(
                  controller: _faceTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: const Color(0xFF38BDF8),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF38BDF8),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.face, size: 18), text: 'Cara & Piel'),
                    Tab(icon: Icon(Icons.visibility, size: 18), text: 'Expresión & Ojos'),
                    Tab(icon: Icon(Icons.content_cut, size: 18), text: 'Peinado'),
                  ],
                )
              : TabBar(
                  controller: _clothesTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: const Color(0xFFA78BFA),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFFA78BFA),
                  unselectedLabelColor: const Color(0xFF94A3B8),
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(icon: Icon(Icons.checkroom, size: 18), text: 'Prenda Superior'),
                    Tab(icon: Icon(Icons.style, size: 18), text: 'Prenda Inferior'),
                    Tab(icon: Icon(Icons.roller_skating, size: 18), text: 'Calzado'),
                    Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Accesorios'),
                  ],
                ),
        ),
        // Content view
        Expanded(
          child: _mainSectionIndex == 0
              ? TabBarView(
                  controller: _faceTabController,
                  children: [
                    _buildFaceShapeAndSkinTab(),
                    _buildEyesAndExpressionTab(),
                    _buildHairTab(),
                  ],
                )
              : TabBarView(
                  controller: _clothesTabController,
                  children: [
                    _buildTopClothingTab(),
                    _buildBottomClothingTab(),
                    _buildShoesTab(),
                    _buildAccessoriesTab(),
                  ],
                ),
        ),
        // Bottom Navigation Bar with Quick Step Toggle
        _buildBottomActionBar(),
      ],
    );
  }

  Widget _buildSectionTabButton({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color activeColor,
    required Color activeBorderColor,
  }) {
    final isSelected = _mainSectionIndex == index;
    return GestureDetector(
      onTap: () => _onMainSectionChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeBorderColor : const Color(0xFF334155),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isSelected ? activeBorderColor : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: activeBorderColor,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          if (_mainSectionIndex == 1) ...[
            Expanded(
              flex: 4,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                onPressed: () => _onMainSectionChanged(0),
                icon: const Icon(Icons.arrow_back, size: 15),
                label: const Text(
                  'Volver a Rostro',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                ),
                onPressed: _saveAndClose,
                icon: const Icon(Icons.check, size: 15),
                label: const Text(
                  'Guardar',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                onPressed: () => _onMainSectionChanged(1),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text(
                  'Continuar a Ropa ➔',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SECCIÓN 1: ROSTRO & CABELLO TABS
  // -------------------------------------------------------------
  Widget _buildFaceShapeAndSkinTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          icon: Icons.wc,
          title: 'Tipo de Cuerpo / Género',
          subtitle: 'Selecciona la complexión base femenina o masculina',
        ),
        _buildOptionList(
          options: AvatarConfig.availableBodyTypes,
          selected: _currentConfig.bodyType,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(bodyType: val)),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          icon: Icons.face_6,
          title: 'Forma del Rostro / Cabeza',
          subtitle: 'Contorno base del personaje (OCTOPLAYER 8-Dir)',
        ),
        _buildOptionList(
          options: AvatarConfig.availableFaceShapes,
          selected: _currentConfig.faceShape,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(faceShape: val)),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Tono de Piel',
          subtitle: 'Selecciona una tonalidad natural para la tez',
        ),
        _buildColorPalette(
          colors: AvatarConfig.skinTones,
          selectedColor: _currentConfig.skinColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(skinColor: color)),
        ),
      ],
    );
  }

  Widget _buildEyesAndExpressionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          icon: Icons.remove_red_eye,
          title: 'Estilo de Ojos',
          subtitle: 'Expresión visual de la mirada (8 Direcciones)',
        ),
        _buildOptionList(
          options: AvatarConfig.availableEyeStyles,
          selected: _currentConfig.eyeStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(eyeStyle: val)),
        ),
        const SizedBox(height: 18),
        _buildSectionHeader(
          icon: Icons.color_lens,
          title: 'Color del Iris',
          subtitle: 'Tonalidad de los ojos',
        ),
        _buildColorPalette(
          colors: AvatarConfig.eyeColors,
          selectedColor: _currentConfig.eyeColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(eyeColor: color)),
        ),
        const SizedBox(height: 18),
        _buildSectionHeader(
          icon: Icons.brush,
          title: 'Color de Cejas',
          subtitle: 'Tonalidad de las cejas',
        ),
        _buildColorPalette(
          colors: AvatarConfig.hairColors,
          selectedColor: _currentConfig.eyebrowColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(eyebrowColor: color)),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          icon: Icons.arrow_drop_down_circle,
          title: 'Nariz',
          subtitle: 'Estilo de nariz (8 Direcciones)',
        ),
        _buildOptionList(
          options: AvatarConfig.availableNoseStyles,
          selected: _currentConfig.noseStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(noseStyle: val)),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          icon: Icons.sentiment_satisfied_alt,
          title: 'Boca & Expresión',
          subtitle: 'Sonrisa o actitud del avatar (8 Direcciones)',
        ),
        _buildOptionList(
          options: AvatarConfig.availableMouthStyles,
          selected: _currentConfig.mouthStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(mouthStyle: val)),
        ),
      ],
    );
  }

  Widget _buildHairTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          icon: Icons.content_cut,
          title: 'Estilo de Cabello',
          subtitle: 'Cortes clásicos, modernos y anime',
        ),
        _buildOptionList(
          options: AvatarConfig.availableHairStyles,
          selected: _currentConfig.hairStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(hairStyle: val)),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader(
          icon: Icons.color_lens,
          title: 'Color de Cabello',
          subtitle: 'Paleta completa de tonos naturales y de fantasía',
        ),
        _buildColorPalette(
          colors: AvatarConfig.hairColors,
          selectedColor: _currentConfig.hairColor,
          onColorSelected: (color) {
            final updated = _currentConfig.copyWith(
              hairColor: color,
              eyebrowColor: _syncBrowsWithHair ? color : _currentConfig.eyebrowColor,
            );
            _updateConfig(updated);
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // SECCIÓN 2: VESTIMENTA & ESTILO TABS
  // -------------------------------------------------------------
  Widget _buildTopClothingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          icon: Icons.checkroom,
          title: 'Prenda Superior',
          subtitle: 'Camisas, sudaderas, chaquetas y túnicas de explorador',
        ),
        _buildOptionList(
          options: AvatarConfig.availableTopStyles,
          selected: _currentConfig.topStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(topStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color de Prenda Superior',
          subtitle: 'Elige la tintura de la tela superior',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.topColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(topColor: color)),
        ),
      ],
    );
  }

  Widget _buildBottomClothingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          icon: Icons.style,
          title: 'Prenda Inferior',
          subtitle: 'Pantalones, shorts, faldas y overoles',
        ),
        _buildOptionList(
          options: AvatarConfig.availableBottomStyles,
          selected: _currentConfig.bottomStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(bottomStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color de Prenda Inferior',
          subtitle: 'Tonalidad para la parte inferior del atuendo',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.bottomColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(bottomColor: color)),
        ),
      ],
    );
  }

  Widget _buildShoesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          icon: Icons.roller_skating,
          title: 'Calzado',
          subtitle: 'Botas de aventura, zapatillas y zapatos casuales',
        ),
        _buildOptionList(
          options: AvatarConfig.availableShoeStyles,
          selected: _currentConfig.shoeStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(shoeStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color del Calzado',
          subtitle: 'Cuero, goma o tela tintada',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.shoeColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(shoeColor: color)),
        ),
      ],
    );
  }

  Widget _buildAccessoriesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader(
          icon: Icons.auto_awesome,
          title: 'Accesorio Temático',
          subtitle: 'Gafas de erudito, bandanas, auriculares y flores',
        ),
        _buildOptionList(
          options: AvatarConfig.availableAccessoryStyles,
          selected: _currentConfig.accessoryStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(accessoryStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color de Accesorio',
          subtitle: 'Personaliza los detalles metálicos o telas accesorias',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.accessoryColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(accessoryColor: color)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // HELPER WIDGETS (PROFESSIONAL GAMING UI)
  // -------------------------------------------------------------
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            margin: const EdgeInsets.only(top: 2, right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF38BDF8)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFF1F5F9),
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionList({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return InkWell(
          onTap: () => onSelected(opt),
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                width: isSelected ? 1.8 : 1.0,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withOpacity(0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
            ),
            child: Text(
              AvatarConfig.formatName(opt),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorPalette({
    required List<Color> colors,
    required Color selectedColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((color) {
        final isSelected = color.value == selectedColor.value;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: color.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _SimulatedFaceScanDialog extends StatefulWidget {
  const _SimulatedFaceScanDialog();

  @override
  State<_SimulatedFaceScanDialog> createState() => _SimulatedFaceScanDialogState();
}

class _SimulatedFaceScanDialogState extends State<_SimulatedFaceScanDialog>
    with SingleTickerProviderStateMixin {
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

