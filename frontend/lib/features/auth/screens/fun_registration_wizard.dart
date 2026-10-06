import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/auth_service.dart';
import '../../avatar/editor/avatar_editor_controller.dart';
import '../../avatar/services/avatar_thumbnail_service.dart';
import '../../avatar/widgets/avatar_editor.dart';
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

class _FunRegistrationWizardScreenState extends State<FunRegistrationWizardScreen> {
  int _currentStep = 0; // 0: Identity, 1: Avatar, 2: Tastes & Intentions, 3: Room Starter Pack
  bool _isLoading = false;

  // Step 1: Identity Data
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  int _selectedAge = 24;
  String _selectedCommune = 'Santiago';
  String _selectedGender = 'MAN';
  String _selectedSeeking = 'WOMAN';
  final _communeTextController = TextEditingController(text: 'Santiago');
  final _formKey = GlobalKey<FormState>();

  final List<String> _communes = const [
    'Santiago', 'Providencia', 'Las Condes', 'Ñuñoa', 'La Florida',
    'Maipú', 'Viña del Mar', 'Valparaíso', 'Concepción', 'La Serena',
    'Antofagasta', 'Temuco', 'Puerto Montt', 'Otra Región'
  ];

  // Step 2: Avatar (the shared editor; its thumbnail cache outlives leaving and re-entering the step)
  late final AvatarEditorController _avatarEditor;
  final AvatarThumbnailService _avatarThumbnails = AvatarThumbnailService();
  AvatarConfig get _avatarConfig => _avatarEditor.config;

  // Step 3: Tastes Data
  final Set<String> _selectedTastes = {
    'intent_slow',     // 1. Intención: Slow Dating
    'vibe_introvert',   // 2. Batería Social: Introvertido
    'vibe_night_owl',   // 3. Ritmo: Criatura Nocturna
    'vibe_homebody',    // 4. Fin de semana: Casa & Mantita
    'plat_pc',          // Dilema Gamer: PC
    'fuel_coffee',      // Dilema Combustible: Café
    'pet_cat',          // Dilema Mascotas: Gatos
    'vacation_cabin',   // Dilema Vacaciones: Cabaña
    'game_cozy',        // Gustos libres
    'music_lofi',
  };

  // Step 4: Room & Theme Data
  String _selectedRoomTheme = 'rustic'; // 'rustic', 'modern', 'mystic'
  late RoomConfig _previewRoomConfig;
  late CozyRoomGame _roomPreviewGame;

  @override
  void initState() {
    super.initState();
    _avatarEditor = AvatarEditorController(
      initial: const AvatarConfig(
        faceShape: 'oval',
        skinColor: Color(0xFFFCD5B5),
        eyeStyle: 'cateyes',
        hairStyle: 'long_flow',
        topStyle: 'jacket',
        topColor: Color(0xFFDC2626),
        bottomStyle: 'jeans',
      ),
      gender: _selectedGender,
    )..addListener(_onAvatarChanged);

    _updateRoomPreview();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _avatarEditor.dispose();
    super.dispose();
  }

  /// The skip hint hides once the avatar is touched.
  void _onAvatarChanged() => setState(() {});

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

  Future<void> _completeRegistration() async {
    setState(() {
      _isLoading = true;
    });

    final starterRoom = PreferenceCatalog.generateStarterRoomConfig(
      baseTheme: _selectedRoomTheme,
      selectedTastes: _selectedTastes.toList(),
      avatarConfig: _avatarConfig,
    );

    final resolvedCommune = _communeTextController.text.trim().isNotEmpty
        ? _communeTextController.text.trim()
        : _selectedCommune;

    final result = await AuthService.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      age: _selectedAge,
      commune: resolvedCommune,
      avatarConfig: _avatarConfig,
      tastes: _selectedTastes.toList(),
      roomConfig: starterRoom,
      gender: _selectedGender,
      seekingGender: _selectedSeeking,
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
      // Validar que los 4 ejes obligatorios estén seleccionados
      final missingRequired = PreferenceCatalog.categories
          .where((cat) => cat.isRequired && !cat.items.any((it) => _selectedTastes.contains(it.id)))
          .toList();

      if (missingRequired.isNotEmpty) {
        final missingTitles = missingRequired.map((c) => '${c.emoji} ${c.title}').join('\n• ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor completa los ejes obligatorios para conectar en sintonía:\n• $missingTitles'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }
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

            // Identidad & Preferencia
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C27),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Soy:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('👨 Hombre'),
                        selected: _selectedGender == 'MAN',
                        selectedColor: const Color(0xFFFFB300).withOpacity(0.3),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: _selectedGender == 'MAN' ? const Color(0xFFFFB300) : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (!val) return;
                          setState(() => _selectedGender = 'MAN');
                          _avatarEditor.gender = 'MAN';
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('👩 Mujer'),
                        selected: _selectedGender == 'WOMAN',
                        selectedColor: const Color(0xFFFF4081).withOpacity(0.3),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: _selectedGender == 'WOMAN' ? const Color(0xFFFF4081) : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (!val) return;
                          setState(() => _selectedGender = 'WOMAN');
                          _avatarEditor.gender = 'WOMAN';
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('✨ No binario'),
                        selected: _selectedGender == 'NON_BINARY',
                        selectedColor: const Color(0xFF38BDF8).withOpacity(0.3),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: _selectedGender == 'NON_BINARY' ? const Color(0xFF38BDF8) : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (!val) return;
                          setState(() => _selectedGender = 'NON_BINARY');
                          _avatarEditor.gender = 'NON_BINARY';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Busco conocer:', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('👩 Mujeres'),
                        selected: _selectedSeeking == 'WOMAN',
                        selectedColor: const Color(0xFFFF4081).withOpacity(0.3),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: _selectedSeeking == 'WOMAN' ? const Color(0xFFFF4081) : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedSeeking = 'WOMAN');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('👨 Hombres'),
                        selected: _selectedSeeking == 'MAN',
                        selectedColor: const Color(0xFFFFB300).withOpacity(0.3),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: _selectedSeeking == 'MAN' ? const Color(0xFFFFB300) : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedSeeking = 'MAN');
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('💫 Todos'),
                        selected: _selectedSeeking == 'ANY',
                        selectedColor: const Color(0xFF38BDF8).withOpacity(0.3),
                        backgroundColor: const Color(0xFF0F172A),
                        labelStyle: TextStyle(
                          color: _selectedSeeking == 'ANY' ? const Color(0xFF38BDF8) : Colors.white70,
                          fontSize: 12,
                        ),
                        onSelected: (val) {
                          if (val) setState(() => _selectedSeeking = 'ANY');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Ciudad / Comuna libre
            TextFormField(
              controller: _communeTextController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Tu Ciudad o Comuna',
                hintText: 'Ej. Santiago, Valdivia, Concepción...',
                prefixIcon: const Icon(Icons.location_city, color: Color(0xFFFFB300)),
                filled: true,
                fillColor: const Color(0xFF1E1C27),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ubicación aproximada (~2 km) para emparejar por cercanía. Tu calle o dirección nunca se revelan.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
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

  // -------------------------------------------------------------
  // STEP 2: AVATAR (the shared editor)
  // -------------------------------------------------------------
  Widget _buildStep2Avatar() {
    return Column(
      key: const ValueKey('step_1'),
      children: [
        Expanded(child: AvatarEditor(controller: _avatarEditor, thumbnails: _avatarThumbnails)),
        // Until the avatar is touched the default look can be kept as is; it can be changed later
        // from the room.
        if (!_avatarEditor.isDirty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextButton(
              onPressed: _nextStep,
              child: const Text(
                'Saltar por ahora: puedes cambiarlo después desde tu sala',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ),
      ],
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
                    if (cat.isRequired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Obligatorio', style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else if (cat.isSingleSelect)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('1 Favorito', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.bold)),
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
