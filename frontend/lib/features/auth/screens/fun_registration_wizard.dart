import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/auth_service.dart';
import '../../avatar/games/character_preview_game.dart';
import '../../avatar/screens/character_creator_screen.dart';
import '../../lobby/games/cozy_room_game.dart';

class FunRegistrationWizardScreen extends StatefulWidget {
  final VoidCallback onRegistrationSuccess;

  const FunRegistrationWizardScreen({
    super.key,
    required this.onRegistrationSuccess,
  });

  @override
  State<FunRegistrationWizardScreen> createState() => _FunRegistrationWizardScreenState();
}

class _FunRegistrationWizardScreenState extends State<FunRegistrationWizardScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0; // 0: Identity, 1: Avatar, 2: Tastes & Intentions, 3: Room Starter Pack
  bool _isLoading = false;

  // Step 1: Identity Data
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int _selectedAge = 24;
  String _selectedCommune = 'Santiago';
  final _formKey = GlobalKey<FormState>();

  final List<String> _communes = const [
    'Santiago', 'Providencia', 'Las Condes', 'Ñuñoa', 'La Florida',
    'Maipú', 'Viña del Mar', 'Valparaíso', 'Concepción', 'La Serena',
    'Antofagasta', 'Temuco', 'Puerto Montt', 'Otra Región'
  ];

  // Step 2: Avatar Data & Controllers
  late AvatarConfig _avatarConfig;
  late CharacterPreviewGame _avatarPreviewGame;
  late TabController _avatarFaceTabController;
  late TabController _avatarClothesTabController;
  int _avatarMainSectionIndex = 0;
  bool _syncBrowsWithHair = true;
  double _dragDeltaAccumulator = 0.0;

  // Step 3: Tastes Data
  final Set<String> _selectedTastes = {
    'intent_slow', // Default friendly intention
    'vibe_homebody',
    'game_cozy',
    'music_lofi',
    'life_coffee_tea',
    'pet_cat',
  };

  // Step 4: Room & Theme Data
  String _selectedRoomTheme = 'rustic'; // 'rustic', 'modern', 'mystic'
  late RoomConfig _previewRoomConfig;
  late CozyRoomGame _roomPreviewGame;

  @override
  void initState() {
    super.initState();
    _avatarConfig = const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFFCD5B5),
      eyeStyle: 'cateyes',
      hairStyle: 'long_flow',
      topStyle: 'jacket',
      topColor: Color(0xFFDC2626),
      bottomStyle: 'jeans',
    );
    _avatarPreviewGame = CharacterPreviewGame(
      config: _avatarConfig,
      initialFaceZoom: true,
    );
    _avatarFaceTabController = TabController(length: 3, vsync: this);
    _avatarClothesTabController = TabController(length: 4, vsync: this);

    _updateRoomPreview();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _avatarFaceTabController.dispose();
    _avatarClothesTabController.dispose();
    super.dispose();
  }

  void _onAvatarMainSectionChanged(int index) {
    if (_avatarMainSectionIndex == index) return;
    setState(() {
      _avatarMainSectionIndex = index;
    });
    _avatarPreviewGame.setFaceFocus(index == 0);
  }

  void _updateAvatarConfig(AvatarConfig newConfig) {
    setState(() {
      _avatarConfig = newConfig;
    });
    _avatarPreviewGame.updateConfig(newConfig);
    _updateRoomPreview();
  }

  void _updateRoomPreview() {
    _previewRoomConfig = PreferenceCatalog.generateStarterRoomConfig(
      baseTheme: _selectedRoomTheme,
      selectedTastes: _selectedTastes.toList(),
      avatarConfig: _avatarConfig,
    );
    _roomPreviewGame = CozyRoomGame(
      avatarConfig: _avatarConfig,
      roomConfig: _previewRoomConfig,
    );
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
      shoeStyle: 'none',
      shoeColor: const Color(0xFF78350F),
      accessoryStyle: 'none',
      accessoryColor: const Color(0xFFEAB308),
    );

    _updateAvatarConfig(newConfig);
  }

  Future<void> _completeRegistration() async {
    setState(() {
      _isLoading = true;
    });

    final starterRoom = PreferenceCatalog.generateStarterRoomConfig(
      baseTheme: _selectedRoomTheme,
      selectedTastes: _selectedTastes.toList(),
      avatarConfig: _avatarConfig,
    );

    final result = await AuthService.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      age: _selectedAge,
      commune: _selectedCommune,
      avatarConfig: _avatarConfig,
      tastes: _selectedTastes.toList(),
      roomConfig: starterRoom,
    );

    setState(() {
      _isLoading = false;
    });

    if (result.success && mounted) {
      // Show celebration dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1C27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFFFB300), width: 1.5),
          ),
          title: const Row(
            children: [
              Text('🎉 ', style: TextStyle(fontSize: 24)),
              Expanded(
                child: Text(
                  '¡Bienvenido(a) a Cozy Dating!',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Tu personaje y tu nuevo hogar han sido creados con éxito. ¡Has recibido 5 tickets de bienvenida para explorar y conocer gente!',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amberAccent),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.confirmation_number_rounded, color: Colors.amberAccent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '5 Tickets de Aventura Listos',
                      style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                widget.onRegistrationSuccess();
              },
              child: const Text('¡Entrar a mi Lobby!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Error al registrar usuario'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;
    }
    if (_currentStep == 1) {
      _updateRoomPreview();
    }
    if (_currentStep == 2) {
      _updateRoomPreview();
    }
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeRegistration();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF13111C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1C27),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white70),
          onPressed: _prevStep,
        ),
        title: _buildStepIndicator(),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStepView(),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    final titles = ['1. Identidad', '2. Tu Avatar', '3. Gustos & Vibes', '4. Tu Hogar'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          titles[_currentStep],
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final isActive = index <= _currentStep;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == _currentStep ? 24 : 12,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFFFFB300) : Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2Avatar();
      case 2:
        return _buildStep3Tastes();
      case 3:
        return _buildStep4RoomStarter();
      default:
        return const SizedBox.shrink();
    }
  }

  // -------------------------------------------------------------
  // STEP 1: IDENTITY & CREDENTIALS
  // -------------------------------------------------------------
  Widget _buildStep1Identity() {
    return SingleChildScrollView(
      key: const ValueKey('step_0'),
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('✨ Crea tu Cuenta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            const Text('Elige tu nombre de aventurero y datos básicos para iniciar.', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 24),

            // Username
            TextFormField(
              controller: _usernameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Nombre de Aventurero (Username)',
                prefixIcon: const Icon(Icons.person, color: Color(0xFFFFB300)),
                filled: true,
                fillColor: const Color(0xFF1E1C27),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Ingresa un nombre de usuario';
                if (val.trim().length < 3) return 'Mínimo 3 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Contraseña Secreta',
                prefixIcon: const Icon(Icons.lock, color: Color(0xFFFFB300)),
                filled: true,
                fillColor: const Color(0xFF1E1C27),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.length < 4) return 'Mínimo 4 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email (Required)
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Correo Electrónico (Para recuperar tu cuenta)',
                prefixIcon: const Icon(Icons.email, color: Color(0xFFFFB300)),
                filled: true,
                fillColor: const Color(0xFF1E1C27),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Ingresa tu correo electrónico';
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(val.trim())) return 'Ingresa un correo electrónico válido (ej: nombre@dominio.com)';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Age Slider
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C27),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Edad:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                      Text('$_selectedAge años 🎉', style: const TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Slider(
                    value: _selectedAge.toDouble(),
                    min: 18,
                    max: 60,
                    divisions: 42,
                    activeColor: const Color(0xFFFFB300),
                    onChanged: (val) {
                      setState(() {
                        _selectedAge = val.toInt();
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Commune Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCommune,
              dropdownColor: const Color(0xFF1E1C27),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tu Comuna / Región',
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFFFFB300)),
                filled: true,
                fillColor: const Color(0xFF1E1C27),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _communes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCommune = val);
              },
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // STEP 2: AVATAR CREATION & CUSTOMIZATION (ESTILO ARMARIO COMPLETO)
  // -------------------------------------------------------------
  Widget _buildStep2Avatar() {
    return Column(
      key: const ValueKey('step_1'),
      children: [
        // Top section: Interactive Vertical Preview Studio with Controls
        SizedBox(
          height: 200,
          child: _buildAvatarPreviewPanel(),
        ),
        Container(
          height: 1,
          color: const Color(0xFF334155),
        ),
        // Bottom section: Customization Workspace (2 Sections + SubTabs + Color Palettes)
        Expanded(
          child: _buildAvatarCustomizationWorkspace(),
        ),
      ],
    );
  }

  Widget _buildAvatarPreviewPanel() {
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
                color: Colors.black.withValues(alpha: 0.4),
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
                  _avatarPreviewGame.rotateRight();
                });
                _dragDeltaAccumulator -= stepThreshold;
              } else if (_dragDeltaAccumulator <= -stepThreshold) {
                setState(() {
                  _avatarPreviewGame.rotateLeft();
                });
                _dragDeltaAccumulator += stepThreshold;
              }
            },
            onHorizontalDragEnd: (_) {
              _dragDeltaAccumulator = 0.0;
            },
            child: GameWidget(game: _avatarPreviewGame),
          ),
        ),
        // Camera Mode Badge (clickable toggle)
        Positioned(
          top: 8,
          left: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _avatarPreviewGame.toggleFaceFocus();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _avatarPreviewGame.isFaceZoom
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFF818CF8),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _avatarPreviewGame.isFaceZoom ? Icons.zoom_in : Icons.accessibility_new,
                    size: 12,
                    color: _avatarPreviewGame.isFaceZoom
                        ? const Color(0xFF38BDF8)
                        : const Color(0xFFA5B4FC),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _avatarPreviewGame.isFaceZoom ? 'Zoom Rostro' : 'Cuerpo Entero',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _avatarPreviewGame.isFaceZoom
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
                  _avatarPreviewGame.rotateLeft();
                });
              }),
              const SizedBox(width: 4),
              _buildQuickRotateBtn(Icons.rotate_right, () {
                setState(() {
                  _avatarPreviewGame.rotateRight();
                });
              }),
            ],
          ),
        ),
      ],
    );

    final controlsWidget = Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Randomize Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            foregroundColor: const Color(0xFFA78BFA),
            side: const BorderSide(color: Color(0xFF8B5CF6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onPressed: _randomizeAvatar,
          icon: const Icon(Icons.casino, size: 16),
          label: const Text(
            'Sorpréndeme 🎲',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),

        // Walk toggle button
        InkWell(
          onTap: () {
            setState(() {
              _avatarPreviewGame.toggleWalk();
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _avatarPreviewGame.isWalking
                  ? const Color(0xFFDC2626).withValues(alpha: 0.2)
                  : const Color(0xFF16A34A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _avatarPreviewGame.isWalking
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _avatarPreviewGame.isWalking ? Icons.pause : Icons.directions_walk,
                  size: 15,
                  color: _avatarPreviewGame.isWalking
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF86EFAC),
                ),
                const SizedBox(width: 6),
                Text(
                  _avatarPreviewGame.isWalking ? 'Pausar' : 'Caminar',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _avatarPreviewGame.isWalking
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF86EFAC),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Zoom shortcut
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF38BDF8),
            side: const BorderSide(color: Color(0xFF0284C7)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onPressed: () {
            setState(() {
              _avatarPreviewGame.toggleFaceFocus();
            });
          },
          icon: Icon(
            _avatarPreviewGame.isFaceZoom ? Icons.accessibility_new : Icons.zoom_in,
            size: 15,
          ),
          label: Text(
            _avatarPreviewGame.isFaceZoom ? 'Ver Cuerpo' : 'Ver Rostro',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );

    return Container(
      color: const Color(0xFF131A2A),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Vertical Rectangular Canvas
          Expanded(
            flex: 5,
            child: canvasWidget,
          ),
          const SizedBox(width: 12),
          // Right: Studio Controls
          Expanded(
            flex: 5,
            child: controlsWidget,
          ),
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
          color: const Color(0xFF0F172A).withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF475569)),
        ),
        child: Icon(icon, size: 13, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildAvatarCustomizationWorkspace() {
    return Column(
      children: [
        // Top 2-Section Switcher Header
        _buildAvatarMainSectionSwitcher(),
        // Sub-tabs for the selected section
        Container(
          color: const Color(0xFF1E293B),
          child: _avatarMainSectionIndex == 0
              ? TabBar(
                  controller: _avatarFaceTabController,
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
                  controller: _avatarClothesTabController,
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
          child: _avatarMainSectionIndex == 0
              ? TabBarView(
                  controller: _avatarFaceTabController,
                  children: [
                    _buildFaceShapeAndSkinTab(),
                    _buildEyesAndExpressionTab(),
                    _buildHairTab(),
                  ],
                )
              : TabBarView(
                  controller: _avatarClothesTabController,
                  children: [
                    _buildTopClothingTab(),
                    _buildBottomClothingTab(),
                    _buildShoesTab(),
                    _buildAccessoriesTab(),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildAvatarMainSectionSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: const Color(0xFF131A2A),
      child: Row(
        children: [
          // Section 1: Rostro & Cabello
          Expanded(
            child: _buildSectionTabButton(
              index: 0,
              title: '1. Rostro & Cabello',
              subtitle: 'Piel, Ojos, Pelo',
              icon: Icons.face_retouching_natural,
              activeColor: const Color(0xFF0284C7),
              activeBorderColor: const Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 10),
          // Section 2: Vestimenta & Estilo
          Expanded(
            child: _buildSectionTabButton(
              index: 1,
              title: '2. Vestimenta & Estilo',
              subtitle: 'Ropa y Calzado',
              icon: Icons.dry_cleaning,
              activeColor: const Color(0xFF7C3AED),
              activeBorderColor: const Color(0xFFA78BFA),
            ),
          ),
        ],
      ),
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
    final isSelected = _avatarMainSectionIndex == index;
    return GestureDetector(
      onTap: () => _onAvatarMainSectionChanged(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeBorderColor : const Color(0xFF334155),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : const Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9,
                      color: isSelected ? activeBorderColor : const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
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
          subtitle: 'Selecciona la complexión base',
        ),
        _buildOptionList(
          options: AvatarConfig.availableBodyTypes,
          selected: _avatarConfig.bodyType,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(bodyType: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.face_6,
          title: 'Forma del Rostro',
          subtitle: 'Contorno base del personaje',
        ),
        _buildOptionList(
          options: AvatarConfig.availableFaceShapes,
          selected: _avatarConfig.faceShape,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(faceShape: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Tono de Piel',
          subtitle: 'Selecciona una tonalidad para la tez',
        ),
        _buildColorPalette(
          colors: AvatarConfig.skinTones,
          selectedColor: _avatarConfig.skinColor,
          onColorSelected: (color) => _updateAvatarConfig(_avatarConfig.copyWith(skinColor: color)),
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
          subtitle: 'Expresión visual de la mirada',
        ),
        _buildOptionList(
          options: AvatarConfig.availableEyeStyles,
          selected: _avatarConfig.eyeStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(eyeStyle: val)),
        ),
        const SizedBox(height: 18),
        _buildSectionHeader(
          icon: Icons.color_lens,
          title: 'Color del Iris (Ojos)',
          subtitle: 'Tonalidad de los ojos',
        ),
        _buildColorPalette(
          colors: AvatarConfig.eyeColors,
          selectedColor: _avatarConfig.eyeColor,
          onColorSelected: (color) => _updateAvatarConfig(_avatarConfig.copyWith(eyeColor: color)),
        ),
        const SizedBox(height: 18),
        _buildSectionHeader(
          icon: Icons.brush,
          title: 'Color de Cejas',
          subtitle: 'Tonalidad de las cejas',
        ),
        _buildColorPalette(
          colors: AvatarConfig.hairColors,
          selectedColor: _avatarConfig.eyebrowColor,
          onColorSelected: (color) => _updateAvatarConfig(_avatarConfig.copyWith(eyebrowColor: color)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.arrow_drop_down_circle,
          title: 'Nariz',
          subtitle: 'Estilo de nariz',
        ),
        _buildOptionList(
          options: AvatarConfig.availableNoseStyles,
          selected: _avatarConfig.noseStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(noseStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.sentiment_satisfied_alt,
          title: 'Boca & Expresión',
          subtitle: 'Sonrisa o actitud del avatar',
        ),
        _buildOptionList(
          options: AvatarConfig.availableMouthStyles,
          selected: _avatarConfig.mouthStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(mouthStyle: val)),
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
          selected: _avatarConfig.hairStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(hairStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.color_lens,
          title: 'Color de Cabello',
          subtitle: 'Paleta completa de tonos naturales y de fantasía',
        ),
        _buildColorPalette(
          colors: AvatarConfig.hairColors,
          selectedColor: _avatarConfig.hairColor,
          onColorSelected: (color) {
            final updated = _avatarConfig.copyWith(
              hairColor: color,
              eyebrowColor: _syncBrowsWithHair ? color : _avatarConfig.eyebrowColor,
            );
            _updateAvatarConfig(updated);
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
          subtitle: 'Camisas, sudaderas, chaquetas y túnicas',
        ),
        _buildOptionList(
          options: AvatarConfig.availableTopStyles,
          selected: _avatarConfig.topStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(topStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color de Prenda Superior',
          subtitle: 'Elige la tintura de la tela superior',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _avatarConfig.topColor,
          onColorSelected: (color) => _updateAvatarConfig(_avatarConfig.copyWith(topColor: color)),
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
          selected: _avatarConfig.bottomStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(bottomStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color de Prenda Inferior',
          subtitle: 'Tonalidad para la parte inferior del atuendo',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _avatarConfig.bottomColor,
          onColorSelected: (color) => _updateAvatarConfig(_avatarConfig.copyWith(bottomColor: color)),
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
          selected: _avatarConfig.shoeStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(shoeStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color del Calzado',
          subtitle: 'Cuero, goma o tela tintada',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _avatarConfig.shoeColor,
          onColorSelected: (color) => _updateAvatarConfig(_avatarConfig.copyWith(shoeColor: color)),
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
          selected: _avatarConfig.accessoryStyle,
          onSelected: (val) => _updateAvatarConfig(_avatarConfig.copyWith(accessoryStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader(
          icon: Icons.palette,
          title: 'Color de Accesorio',
          subtitle: 'Personaliza los detalles del accesorio',
        ),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _avatarConfig.accessoryColor,
          onColorSelected: (color) => _updateAvatarConfig(_avatarConfig.copyWith(accessoryColor: color)),
        ),
      ],
    );
  }

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
              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
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
                        color: const Color(0xFF0284C7).withValues(alpha: 0.35),
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
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                else
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
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

  // -------------------------------------------------------------
  // STEP 3: TASTES & INTENTIONS (CATEGORIZED SELECTOR)
  // -------------------------------------------------------------
  Widget _buildStep3Tastes() {
    return ListView.builder(
      key: const ValueKey('step_2'),
      padding: const EdgeInsets.all(16.0),
      itemCount: PreferenceCatalog.categories.length,
      itemBuilder: (context, catIndex) {
        final cat = PreferenceCatalog.categories[catIndex];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          color: const Color(0xFF1E1C27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cat.id == 'dating_intentions' ? const Color(0xFFFFB300) : Colors.white12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cat.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                    if (cat.isSingleSelect)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Obligatorio', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(cat.description, style: const TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cat.items.map((item) {
                    final isSelected = _selectedTastes.contains(item.id);
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(item.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(item.title, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white)),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFFB300),
                      backgroundColor: const Color(0xFF282538),
                      checkmarkColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: isSelected ? const Color(0xFFFFB300) : Colors.white24),
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (cat.isSingleSelect) {
                            // Remove other items in this category
                            for (final other in cat.items) {
                              _selectedTastes.remove(other.id);
                            }
                            if (selected) _selectedTastes.add(item.id);
                          } else {
                            if (selected) {
                              _selectedTastes.add(item.id);
                            } else {
                              _selectedTastes.remove(item.id);
                            }
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // STEP 4: ROOM STARTER PACK (THEMED LOBBY PREVIEW)
  // -------------------------------------------------------------
  Widget _buildStep4RoomStarter() {
    return Column(
      key: const ValueKey('step_3'),
      children: [
        // Theme selector buttons
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF1E1C27),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🏡 Tu Primer Hogar (Generado según tus gustos)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildThemeOption('rustic', '🪵 Cabaña Roble', const Color(0xFFE5A65D)),
                  const SizedBox(width: 8),
                  _buildThemeOption('modern', '◻️ Moderno Gris', const Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  _buildThemeOption('mystic', '🌌 Noche Índigo', const Color(0xFFA78BFA)),
                ],
              ),
            ],
          ),
        ),

        // Live Room Game Preview
        Expanded(
          child: Stack(
            children: [
              Container(
                color: const Color(0xFF16141D),
                child: GameWidget(game: _roomPreviewGame),
              ),
              Positioned(
                bottom: 12,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Muebles temáticos añadidos por tus gustos (${_previewRoomConfig.furniture.length} objetos)',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(String themeKey, String label, Color color) {
    final isSelected = _selectedRoomTheme == themeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRoomTheme = themeKey;
            _updateRoomPreview();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : const Color(0xFF282538),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? color : Colors.white12, width: isSelected ? 2 : 1),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF1E1C27),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _prevStep,
              child: const Text('Atrás'),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentStep == 3 ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _nextStep,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      _currentStep == 3 ? '✨ Finalizar Registro & Entrar' : 'Continuar ➔',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
