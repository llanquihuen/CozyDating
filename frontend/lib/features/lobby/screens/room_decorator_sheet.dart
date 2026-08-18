import 'package:flutter/material.dart';
import '../../../core/models/room_config.dart';
import '../components/isometric_furniture_component.dart';

class RoomDecoratorSheet extends StatefulWidget {
  final RoomConfig initialConfig;
  final ValueChanged<RoomConfig> onConfigChanged;
  final ValueChanged<RoomConfig> onSave;
  final Function(FurnitureType type, int gw, int gh, String? assetPath)? onAddFurniture;

  const RoomDecoratorSheet({
    super.key,
    required this.initialConfig,
    required this.onConfigChanged,
    required this.onSave,
    this.onAddFurniture,
  });

  static Future<void> show(
    BuildContext context, {
    required RoomConfig initialConfig,
    required ValueChanged<RoomConfig> onConfigChanged,
    required ValueChanged<RoomConfig> onSave,
    Function(FurnitureType type, int gw, int gh, String? assetPath)? onAddFurniture,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomDecoratorSheet(
        initialConfig: initialConfig,
        onConfigChanged: onConfigChanged,
        onSave: onSave,
        onAddFurniture: onAddFurniture,
      ),
    );
  }

  @override
  State<RoomDecoratorSheet> createState() => _RoomDecoratorSheetState();
}

class _RoomDecoratorSheetState extends State<RoomDecoratorSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late RoomConfig _currentConfig;

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.initialConfig;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectWallpaper(String wallpaperId) {
    setState(() {
      _currentConfig = _currentConfig.copyWith(wallpaper: wallpaperId);
    });
    widget.onConfigChanged(_currentConfig);
  }

  void _selectFloor(String floorId) {
    setState(() {
      _currentConfig = _currentConfig.copyWith(floor: floorId);
    });
    widget.onConfigChanged(_currentConfig);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: 440 + bottomPadding,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1C27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF453F58), width: 2)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🎨', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 8),
                    Text(
                      'Decorar Habitación',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6D00),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  onPressed: () {
                    widget.onSave(_currentConfig);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),

          // Tabs (Papel Tapiz / Pisos / Muebles)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF282531),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFFFD54F),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(text: '🧱 Papel Tapiz (PNG)'),
                Tab(text: '🪵 Pisos (PNG)'),
                Tab(text: '🛋️ Muebles'),
              ],
            ),
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWallpaperList(),
                _buildFloorList(),
                _buildFurnitureCatalogList(),
              ],
            ),
          ),
          SizedBox(height: bottomPadding),
        ],
      ),
    );
  }

  Widget _buildWallpaperList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: RoomThemes.wallpapers.length,
      itemBuilder: (context, index) {
        final item = RoomThemes.wallpapers[index];
        final isSelected = _currentConfig.wallpaper == item.id;
        final previewAsset = 'assets/images/wallpaper/wallpaper_${item.id}.png';

        return _buildCard(
          emoji: item.emoji,
          name: item.name,
          description: item.description,
          previewAsset: previewAsset,
          isSelected: isSelected,
          onTap: () => _selectWallpaper(item.id),
        );
      },
    );
  }

  Widget _buildFloorList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: RoomThemes.floors.length,
      itemBuilder: (context, index) {
        final item = RoomThemes.floors[index];
        final isSelected = _currentConfig.floor == item.id;
        final floorFilename = (item.id == 'terracotta_tiles')
            ? 'floor_terracotta.png'
            : ((item.id == 'tatami_mat') ? 'floor_tatami.png' : 'floor_${item.id}.png');
        final previewAsset = 'assets/images/floors/$floorFilename';

        return _buildCard(
          emoji: item.emoji,
          name: item.name,
          description: item.description,
          previewAsset: previewAsset,
          isSelected: isSelected,
          onTap: () => _selectFloor(item.id),
        );
      },
    );
  }

  Widget _buildFurnitureCatalogList() {
    final furnitureItems = [
      {
        'name': 'Cama Rústica',
        'emoji': '🛏️',
        'desc': '1x2 Roble cálido',
        'asset': 'furniture/bed_single_rustic.png',
        'gw': 1,
        'gh': 2,
        'type': FurnitureType.bed,
      },
      {
        'name': 'Cama Nórdica',
        'emoji': '🛏️',
        'desc': '1x2 Verde salvia',
        'asset': 'furniture/bed_single_modern.png',
        'gw': 1,
        'gh': 2,
        'type': FurnitureType.bed,
      },
      {
        'name': 'Cama King Size',
        'emoji': '👑',
        'desc': '2x2 Caoba noble',
        'asset': 'furniture/bed_double_king.png',
        'gw': 2,
        'gh': 2,
        'type': FurnitureType.bed,
      },
      {
        'name': 'Sofá Acogedor',
        'emoji': '🛋️',
        'desc': '2x1 Terciopelo rojo',
        'asset': 'furniture/sofa_cozy.png',
        'gw': 2,
        'gh': 1,
        'type': FurnitureType.table,
      },
      {
        'name': 'Estantería',
        'emoji': '📚',
        'desc': '1x1 Con libros',
        'asset': 'furniture/bookshelf_wooden.png',
        'gw': 1,
        'gh': 1,
        'type': FurnitureType.wardrobe,
      },
      {
        'name': 'Planta Monstera',
        'emoji': '🪴',
        'desc': '1x1 Cerámica viva',
        'asset': 'furniture/plant_monstera.png',
        'gw': 1,
        'gh': 1,
        'type': FurnitureType.plant,
      },
      {
        'name': 'Mesa de Té',
        'emoji': '☕',
        'desc': '1x1 Con vela y té',
        'asset': 'furniture/table_tea.png',
        'gw': 1,
        'gh': 1,
        'type': FurnitureType.table,
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      scrollDirection: Axis.horizontal,
      itemCount: furnitureItems.length,
      itemBuilder: (context, index) {
        final item = furnitureItems[index];

        return GestureDetector(
          onTap: () {
            widget.onAddFurniture?.call(
              item['type'] as FurnitureType,
              item['gw'] as int,
              item['gh'] as int,
              item['asset'] as String?,
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('¡${item['name']} agregado! Mantén clic para moverlo a su lugar.'),
                backgroundColor: const Color(0xFF282531),
                duration: const Duration(seconds: 3),
              ),
            );
          },
          child: Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12, bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF282531),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Text(item['emoji'] as String, style: const TextStyle(fontSize: 20)),
                    ),
                    const Icon(Icons.add_circle, color: Color(0xFF00E5FF), size: 22),
                  ],
                ),
                const Spacer(),
                Text(
                  item['name'] as String,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF00E5FF),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item['desc'] as String,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white60,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required String emoji,
    required String name,
    required String description,
    required String previewAsset,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 140,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF383247) : const Color(0xFF282531),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFF453F58),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD54F).withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle, color: Color(0xFFFFD54F), size: 20)
                else
                  const SizedBox(width: 20, height: 20),
              ],
            ),
            const Spacer(),
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white60,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
