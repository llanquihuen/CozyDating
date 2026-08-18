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
    with SingleTickerProviderStateMixin {
  late AvatarConfig _currentConfig;
  late CharacterPreviewGame _previewGame;
  late TabController _tabController;
  bool _syncBrowsWithHair = true;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.initialConfig ?? AvatarStorageService.loadConfig();
    _previewGame = CharacterPreviewGame(config: _currentConfig);
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    final randomShoeColor = AvatarConfig.clothingColors[rand.nextInt(AvatarConfig.clothingColors.length)];
    final randomAccColor = AvatarConfig.clothingColors[rand.nextInt(AvatarConfig.clothingColors.length)];

    final newConfig = AvatarConfig(
      faceShape: AvatarConfig.availableFaceShapes[rand.nextInt(AvatarConfig.availableFaceShapes.length)],
      skinColor: randomSkin,
      eyeStyle: AvatarConfig.availableEyeStyles[rand.nextInt(AvatarConfig.availableEyeStyles.length)],
      eyeColor: randomEyeColor,
      eyebrowStyle: AvatarConfig.availableEyebrowStyles[rand.nextInt(AvatarConfig.availableEyebrowStyles.length)],
      eyebrowColor: _syncBrowsWithHair ? randomHairColor : randomHairColor,
      noseStyle: AvatarConfig.availableNoseStyles[rand.nextInt(AvatarConfig.availableNoseStyles.length)],
      mouthStyle: AvatarConfig.availableMouthStyles[rand.nextInt(AvatarConfig.availableMouthStyles.length)],
      faceDetail: AvatarConfig.availableFaceDetails[rand.nextInt(AvatarConfig.availableFaceDetails.length)],
      faceDetailColor: const Color(0xFFFF7777),
      hairStyle: AvatarConfig.availableHairStyles[rand.nextInt(AvatarConfig.availableHairStyles.length)],
      hairColor: randomHairColor,
      topStyle: AvatarConfig.availableTopStyles[rand.nextInt(AvatarConfig.availableTopStyles.length)],
      topColor: randomTopColor,
      bottomStyle: AvatarConfig.availableBottomStyles[rand.nextInt(AvatarConfig.availableBottomStyles.length)],
      bottomColor: randomBottomColor,
      shoeStyle: AvatarConfig.availableShoeStyles[rand.nextInt(AvatarConfig.availableShoeStyles.length)],
      shoeColor: randomShoeColor,
      accessoryStyle: AvatarConfig.availableAccessoryStyles[rand.nextInt(AvatarConfig.availableAccessoryStyles.length)],
      accessoryColor: randomAccColor,
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
    final isWide = MediaQuery.of(context).size.width >= 760;

    return Scaffold(
      backgroundColor: const Color(0xFF13141C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181924),
        elevation: 0,
        title: const Row(
          children: [
            Text('🚶 ', style: TextStyle(fontSize: 20)),
            Text(
              'Avatar Studio 16-Bit',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF38BDF8),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Aleatorio',
            icon: const Icon(Icons.casino, color: Color(0xFFA78BFA)),
            onPressed: _randomizeAvatar,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: _saveAndClose,
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: isWide ? _buildWideLayout() : _buildNarrowLayout(),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left Column: Avatar Preview and Animation Controls
        SizedBox(
          width: 340,
          child: _buildPreviewPanel(),
        ),
        const VerticalDivider(width: 1, color: Color(0xFF2D3250)),
        // Right Column: Customization Tabs
        Expanded(
          child: _buildCustomizationTabs(),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        SizedBox(
          height: 250,
          child: _buildPreviewPanel(),
        ),
        const Divider(height: 1, color: Color(0xFF2D3250)),
        Expanded(
          child: _buildCustomizationTabs(),
        ),
      ],
    );
  }

  Widget _buildPreviewPanel() {
    return Container(
      color: const Color(0xFF181924),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Flame Canvas Preview with SNES gradient frame
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D3250), width: 2),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF182044), Color(0xFF365482)],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: GameWidget(game: _previewGame),
            ),
          ),
          // Resolution Toggle (64x128 / 32x64 Pixelated)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF13141C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2D3250)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _updateConfig(_currentConfig.copyWith(spriteResolution: '64x128')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentConfig.spriteResolution == '64x128' ? const Color(0xFF2563EB) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '64x128 (Detalle)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _currentConfig.spriteResolution == '64x128' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _updateConfig(_currentConfig.copyWith(spriteResolution: '32x64')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: _currentConfig.spriteResolution == '32x64' ? const Color(0xFF8B5CF6) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '32x64 (Pixel Chibi)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _currentConfig.spriteResolution == '32x64' ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Direction Controls
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildDirButton('⬇️ Frente', AvatarDirection.down),
              _buildDirButton('⬅️ Izq', AvatarDirection.left),
              _buildDirButton('➡️ Der', AvatarDirection.right),
              _buildDirButton('⬆️ Espalda', AvatarDirection.up),
            ],
          ),
          const SizedBox(height: 10),
          // Animation toggle & Randomize buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _previewGame.isWalking ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  setState(() {
                    _previewGame.toggleWalk();
                  });
                },
                icon: Icon(_previewGame.isWalking ? Icons.pause : Icons.directions_walk, size: 16),
                label: Text(_previewGame.isWalking ? 'Pausar' : 'Caminar', style: const TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFA78BFA),
                  side: const BorderSide(color: Color(0xFF8B5CF6)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _randomizeAvatar,
                icon: const Icon(Icons.casino, size: 16),
                label: const Text('Aleatorio', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirButton(String label, AvatarDirection dir) {
    final isSelected = _previewGame.currentDirection == dir;
    return GestureDetector(
      onTap: () {
        setState(() {
          _previewGame.currentDirection = dir;
          _previewGame.avatar.direction = dir;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF2D3250),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomizationTabs() {
    return Column(
      children: [
        Container(
          color: const Color(0xFF181924),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: const Color(0xFF38BDF8),
            labelColor: const Color(0xFF38BDF8),
            unselectedLabelColor: const Color(0xFF94A3B8),
            tabs: const [
              Tab(icon: Icon(Icons.face, size: 18), text: 'Cara & Piel'),
              Tab(icon: Icon(Icons.visibility, size: 18), text: 'Expresión & Ojos'),
              Tab(icon: Icon(Icons.content_cut, size: 18), text: 'Peinado'),
              Tab(icon: Icon(Icons.checkroom, size: 18), text: 'Vestimenta'),
              Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'Accesorios'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFaceShapeAndSkinTab(),
              _buildEyesAndExpressionTab(),
              _buildHairTab(),
              _buildClothingTab(),
              _buildAccessoriesTab(),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 1: CARA & PIEL
  // -------------------------------------------------------------
  Widget _buildFaceShapeAndSkinTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Resolución & Estilo de Pixel Art'),
        _buildOptionList(
          options: AvatarConfig.availableResolutions,
          selected: _currentConfig.spriteResolution,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(spriteResolution: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Forma del Rostro / Mandíbula'),
        _buildOptionList(
          options: AvatarConfig.availableFaceShapes,
          selected: _currentConfig.faceShape,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(faceShape: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Tono de Piel'),
        _buildColorPalette(
          colors: AvatarConfig.skinTones,
          selectedColor: _currentConfig.skinColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(skinColor: color)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 2: EXPRESIÓN & OJOS
  // -------------------------------------------------------------
  Widget _buildEyesAndExpressionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Estilo de Ojos (10 Diseños Expresivos)'),
        _buildOptionList(
          options: AvatarConfig.availableEyeStyles,
          selected: _currentConfig.eyeStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(eyeStyle: val)),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Color del Iris'),
        _buildColorPalette(
          colors: AvatarConfig.eyeColors,
          selectedColor: _currentConfig.eyeColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(eyeColor: color)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Cejas'),
        _buildOptionList(
          options: AvatarConfig.availableEyebrowStyles,
          selected: _currentConfig.eyebrowStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(eyebrowStyle: val)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Sincronizar color de cejas con el cabello', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13)),
          value: _syncBrowsWithHair,
          onChanged: (val) {
            setState(() {
              _syncBrowsWithHair = val ?? true;
              if (_syncBrowsWithHair) {
                _updateConfig(_currentConfig.copyWith(eyebrowColor: _currentConfig.hairColor));
              }
            });
          },
        ),
        if (!_syncBrowsWithHair) ...[
          const SizedBox(height: 8),
          _buildColorPalette(
            colors: AvatarConfig.hairColors,
            selectedColor: _currentConfig.eyebrowColor,
            onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(eyebrowColor: color)),
          ),
        ],
        const SizedBox(height: 20),
        _buildSectionHeader('Nariz'),
        _buildOptionList(
          options: AvatarConfig.availableNoseStyles,
          selected: _currentConfig.noseStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(noseStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Boca & Expresión'),
        _buildOptionList(
          options: AvatarConfig.availableMouthStyles,
          selected: _currentConfig.mouthStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(mouthStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Detalles Faciales'),
        _buildOptionList(
          options: AvatarConfig.availableFaceDetails,
          selected: _currentConfig.faceDetail,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(faceDetail: val)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: CABELLO
  // -------------------------------------------------------------
  Widget _buildHairTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Estilo de Cabello'),
        _buildOptionList(
          options: AvatarConfig.availableHairStyles,
          selected: _currentConfig.hairStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(hairStyle: val)),
        ),
        const SizedBox(height: 20),
        _buildSectionHeader('Color de Cabello'),
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
  // TAB 4: VESTIMENTA (TOPS, BOTTOMS, SHOES)
  // -------------------------------------------------------------
  Widget _buildClothingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Prenda Superior'),
        _buildOptionList(
          options: AvatarConfig.availableTopStyles,
          selected: _currentConfig.topStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(topStyle: val)),
        ),
        const SizedBox(height: 12),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.topColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(topColor: color)),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Prenda Inferior'),
        _buildOptionList(
          options: AvatarConfig.availableBottomStyles,
          selected: _currentConfig.bottomStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(bottomStyle: val)),
        ),
        const SizedBox(height: 12),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.bottomColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(bottomColor: color)),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Calzado'),
        _buildOptionList(
          options: AvatarConfig.availableShoeStyles,
          selected: _currentConfig.shoeStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(shoeStyle: val)),
        ),
        const SizedBox(height: 12),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.shoeColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(shoeColor: color)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 5: ACCESORIOS
  // -------------------------------------------------------------
  Widget _buildAccessoriesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Accesorio Temático'),
        _buildOptionList(
          options: AvatarConfig.availableAccessoryStyles,
          selected: _currentConfig.accessoryStyle,
          onSelected: (val) => _updateConfig(_currentConfig.copyWith(accessoryStyle: val)),
        ),
        const SizedBox(height: 16),
        _buildSectionHeader('Color de Accesorio'),
        _buildColorPalette(
          colors: AvatarConfig.clothingColors,
          selectedColor: _currentConfig.accessoryColor,
          onColorSelected: (color) => _updateConfig(_currentConfig.copyWith(accessoryColor: color)),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // HELPER WIDGETS
  // -------------------------------------------------------------
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF38BDF8),
        ),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF1E2030),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF2D3250),
                width: 1.5,
              ),
            ),
            child: Text(
              AvatarConfig.formatName(opt),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : const Color(0xFFE2E8F0),
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
      spacing: 8,
      runSpacing: 8,
      children: colors.map((color) {
        final isSelected = color.value == selectedColor.value;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : const Color(0xFF475569),
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : null,
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
