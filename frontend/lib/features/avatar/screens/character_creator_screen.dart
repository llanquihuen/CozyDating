import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../games/character_preview_game.dart';

class CharacterCreatorScreen extends StatefulWidget {
  final AvatarConfig? initialConfig;
  final ValueChanged<AvatarConfig>? onSaved;

  const CharacterCreatorScreen({
    super.key,
    this.initialConfig,
    this.onSaved,
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

  // Dating Profile fields (Tinder style: 1 to 6 photos, bio, intent, distance, age, commune)
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
    _currentConfig = widget.initialConfig ?? AvatarStorageService.loadConfig();
    final loadedTastes = AuthService.currentUser?.tastes ?? [];
    _selectedTastes = Set<String>.from(loadedTastes);
    final activeId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    _currentPhoto = AuthService.currentUser?.profilePhoto ?? AvatarStorageService.getUserPhoto(activeId);
    
    final loadedPhotos = AuthService.currentUser?.photos ?? AvatarStorageService.getUserPhotos(activeId);
    _userPhotos = List<String>.from(loadedPhotos);
    if (_userPhotos.isEmpty && _currentPhoto != null && _currentPhoto!.isNotEmpty) {
      _userPhotos.add(_currentPhoto!);
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
    if (_userPhotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes añadir al menos 1 foto para tu perfil de citas.'),
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
    AvatarStorageService.saveUserPhoto(activeId, _userPhotos.first);
    AvatarStorageService.saveUserBio(activeId, _bioController.text.trim());
    AvatarStorageService.saveUserIntent(activeId, _selectedIntent);
    AvatarStorageService.saveUserMaxDistance(activeId, _selectedDistanceKm);

    AuthService.updateDatingProfile(
      photos: _userPhotos,
      bio: _bioController.text.trim(),
      intent: _selectedIntent,
      maxDistanceKm: _selectedDistanceKm,
      age: _userAge,
      commune: _userCommune,
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
              // 1. Fotos de Perfil (1 a 6 fotos)
              _buildPhotosSection(),
              const SizedBox(height: 24),

              // 2. Acerca de mí (Biografía)
              _buildBioSection(),
              const SizedBox(height: 24),

              // 3. Intención de Cita
              _buildIntentSection(),
              const SizedBox(height: 24),

              // 4. Proximidad y Ubicación
              _buildDistanceAndLocationSection(),
              const SizedBox(height: 24),

              // 5. Intereses y Gustos Cozy
              _buildTastesSection(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotosSection() {
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
                    'Tus Fotos Reales',
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
                  color: _userPhotos.isEmpty ? Colors.red.withOpacity(0.2) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _userPhotos.isEmpty ? Colors.red : const Color(0xFF475569),
                  ),
                ),
                child: Text(
                  '${_userPhotos.length} / 6 fotos (mín. 1)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _userPhotos.isEmpty ? Colors.redAccent : const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Solo se revelarán en HD a tu compañero si ambos confirman Match al final de la fogata.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemCount: 6,
            itemBuilder: (context, index) {
              if (index < _userPhotos.length) {
                final photoUrl = _userPhotos[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF334155),
                          child: const Icon(Icons.broken_image, color: Colors.white54),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.amber, size: 12),
                              SizedBox(width: 3),
                              Text('Principal', style: TextStyle(color: Colors.white, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: GestureDetector(
                        onTap: () {
                          if (_userPhotos.length <= 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Debes conservar al menos 1 foto en tu perfil.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }
                          setState(() {
                            _userPhotos.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.75),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                return GestureDetector(
                  onTap: _showAddPhotoDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF475569),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo, color: Color(0xFF38BDF8), size: 26),
                        SizedBox(height: 6),
                        Text(
                          'Añadir',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
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

  void _showAddPhotoDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.add_photo_alternate, color: Color(0xFF38BDF8)),
            SizedBox(width: 8),
            Text('Añadir Foto al Perfil', style: TextStyle(color: Colors.white, fontSize: 16)),
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
                  'Elige una foto de muestra o pega un enlace web (URL):',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                const Text(
                  'O selecciona una foto cozy de ejemplo:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _samplePhotoPresets.map((url) {
                    return GestureDetector(
                      onTap: () {
                        if (_userPhotos.length < 6) {
                          setState(() {
                            _userPhotos.add(url);
                          });
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
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final url = textController.text.trim();
              if (url.isNotEmpty && _userPhotos.length < 6) {
                setState(() {
                  _userPhotos.add(url);
                });
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Añadir URL'),
          ),
        ],
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

  Widget _buildIntentSection() {
    final intents = [
      {'id': 'intent_slow', 'emoji': '☕', 'title': 'Slow Dating', 'desc': 'Conectar con calma y buena vibra'},
      {'id': 'intent_serious', 'emoji': '💍', 'title': 'Relación Seria', 'desc': 'Buscando algo lindo a largo plazo'},
      {'id': 'intent_gaming_duo', 'emoji': '🎮', 'title': 'Gaming Duo', 'desc': 'Compañero/a de juegos y risas'},
      {'id': 'intent_cozy_chats', 'emoji': '💬', 'title': 'Charlas Cozy', 'desc': 'Conversaciones profundas y té nocturno'},
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
              Icon(Icons.flag_circle, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                '¿Cuál es tu intención?',
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
            'Se mostrará en la tarjeta de inicio para asegurar expectativas alineadas.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Column(
            children: intents.map((item) {
              final isSelected = _selectedIntent == item['id'];
              return GestureDetector(
                onTap: () => setState(() => _selectedIntent = item['id']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF59E0B).withOpacity(0.15) : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(item['emoji']!, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title']!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSelected ? const Color(0xFFFBBF24) : Colors.white,
                              ),
                            ),
                            Text(
                              item['desc']!,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 18),
                    ],
                  ),
                ),
              );
            }).toList(),
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
                    'Gustos & Intereses Cozy',
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
            'Las cartas de la fogata se seleccionarán basándose en lo que ambos tengan en común.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PreferenceCatalog.categories.expand((cat) => cat.items).map((item) {
              final isSelected = _selectedTastes.contains(item.id);
              return FilterChip(
                label: Text('${item.emoji} ${item.title}'),
                selected: isSelected,
                selectedColor: const Color(0xFFA855F7).withOpacity(0.25),
                backgroundColor: const Color(0xFF0F172A),
                checkmarkColor: const Color(0xFFC084FC),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFE9D5FF) : Colors.white70,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFA855F7) : const Color(0xFF334155),
                  ),
                ),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _selectedTastes.add(item.id);
                    } else {
                      _selectedTastes.remove(item.id);
                    }
                  });
                },
              );
            }).toList(),
          ),
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
