import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../components/modular_avatar_component.dart';
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

  // 0: Rostro & Cabello (Zoom Facial), 1: Vestimenta & Estilo (Cuerpo Completo)
  int _mainSectionIndex = 0;

  late TabController _faceTabController;
  late TabController _clothesTabController;
  bool _syncBrowsWithHair = true;
  double _dragDeltaAccumulator = 0.0;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.initialConfig ?? AvatarStorageService.loadConfig();
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

    _updateConfig(newConfig);
  }

  void _saveAndClose() {
    AvatarStorageService.saveConfig(_currentConfig);
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
        child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
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
                'Armario & Creador de Avatar',
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

    final controlsWidget = Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rotation & Swipe Interactive Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1120),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.swipe, size: 14, color: Color(0xFF38BDF8)),
                  SizedBox(width: 5),
                  Text(
                    'Desliza para girar',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildQuickRotateBtn(Icons.rotate_left, () {
                    setState(() {
                      _previewGame.rotateLeft();
                    });
                  }),
                  const SizedBox(width: 6),
                  _buildQuickRotateBtn(Icons.rotate_right, () {
                    setState(() {
                      _previewGame.rotateRight();
                    });
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Walk toggle button
        InkWell(
          onTap: () {
            setState(() {
              _previewGame.toggleWalk();
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _previewGame.isWalking
                  ? const Color(0xFFDC2626).withOpacity(0.2)
                  : const Color(0xFF16A34A).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _previewGame.isWalking
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF22C55E),
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _previewGame.isWalking ? Icons.pause : Icons.directions_walk,
                  size: 15,
                  color: _previewGame.isWalking
                      ? const Color(0xFFFCA5A5)
                      : const Color(0xFF86EFAC),
                ),
                const SizedBox(width: 6),
                Text(
                  _previewGame.isWalking ? 'Pausar Movimiento' : 'Caminar (Animación)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _previewGame.isWalking
                        ? const Color(0xFFFCA5A5)
                        : const Color(0xFF86EFAC),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

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
                Expanded(child: canvasWidget),
                const SizedBox(height: 8),
                controlsWidget,
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

  // -------------------------------------------------------------
  // MAIN CUSTOMIZATION WORKSPACE (2 SECTIONS)
  // -------------------------------------------------------------
  Widget _buildCustomizationWorkspace() {
    return Column(
      children: [
        // Top 2-Section Switcher Header
        _buildMainSectionSwitcher(),
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

  Widget _buildMainSectionSwitcher() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFF131A2A),
      child: Row(
        children: [
          // Section 1: Rostro & Cabello
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
          const SizedBox(width: 10),
          // Section 2: Vestimenta & Estilo
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
