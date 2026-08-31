import 'package:flutter/material.dart';
import '../../../core/models/furniture_item.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/furniture_catalog_service.dart';

class RoomDecoratorSheet extends StatefulWidget {
  final RoomConfig initialConfig;
  final String initialCategory;
  final ValueChanged<RoomConfig> onConfigChanged;
  final ValueChanged<RoomConfig> onSave;
  final Function(FurnitureCatalogItem catalogItem)? onAddFurniture;
  final Function(InteriorWallStyleOption styleOption)? onAddInteriorWall;
  final ValueChanged<String>? onNotification;

  const RoomDecoratorSheet({
    super.key,
    required this.initialConfig,
    this.initialCategory = 'living',
    required this.onConfigChanged,
    required this.onSave,
    this.onAddFurniture,
    this.onAddInteriorWall,
    this.onNotification,
  });

  static Future<void> show(
    BuildContext context, {
    required RoomConfig initialConfig,
    String initialCategory = 'living',
    required ValueChanged<RoomConfig> onConfigChanged,
    required ValueChanged<RoomConfig> onSave,
    Function(FurnitureCatalogItem catalogItem)? onAddFurniture,
    Function(InteriorWallStyleOption styleOption)? onAddInteriorWall,
    ValueChanged<String>? onNotification,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => RoomDecoratorSheet(
        initialConfig: initialConfig,
        initialCategory: initialCategory,
        onConfigChanged: onConfigChanged,
        onSave: onSave,
        onAddFurniture: onAddFurniture,
        onAddInteriorWall: onAddInteriorWall,
        onNotification: onNotification,
      ),
    );
  }

  @override
  State<RoomDecoratorSheet> createState() => _RoomDecoratorSheetState();
}

class _RoomDecoratorSheetState extends State<RoomDecoratorSheet> {
  late RoomConfig _currentConfig;
  late String _selectedCategory;

  // Drag handle also resizes the sheet now: drag up for more screen, drag down to
  // shrink it back or — past the close threshold — dismiss the sheet entirely.
  static const double _defaultHeightFraction = 0.46;
  static const double _minHeightFraction = 0.30;
  static const double _maxHeightFraction = 0.88;
  static const double _closeHeightFraction = 0.26;
  double _heightFraction = _defaultHeightFraction;

  final List<Map<String, String>> _categories = const [
    {'id': 'living', 'name': '🛋️ Salón y Mesas'},
    {'id': 'bedroom', 'name': '🛏️ Dormitorio'},
    {'id': 'kitchen_bath', 'name': '🍳 Cocina y Baño'},
    {'id': 'patio', 'name': '🪴 Patio y Jardín'},
    {'id': 'guide', 'name': '📦 Cubos Guías'},
    {'id': 'surface', 'name': '🕯️ Sobremesa'},
    {'id': 'walls', 'name': '🖼️ Paredes'},
  ];

  @override
  void initState() {
    super.initState();
    _currentConfig = widget.initialConfig;
    _selectedCategory = widget.initialCategory;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final screenHeight = mediaQuery.size.height;
    // Starts at ~46% of the screen; the drag handle can grow it up to _maxHeightFraction
    // or shrink/close it — see _handleDragUpdate / _handleDragEnd below.
    final sheetHeight = (screenHeight * _heightFraction).clamp(220.0, screenHeight * _maxHeightFraction);

    final allItems = FurnitureCatalogService.items.values.toList();
    final filteredItems = allItems.where((item) {
      if (_selectedCategory == 'living') {
        return (item.zone == 'living' || item.id == 'table' || item.id == 'bookshelf' || item.id == 'tall_bookshelf' || item.id == 'dining_table_2x2' || item.id == 'side_table' || item.id == 'plush_armchair' || item.id == 'wooden_chair' || item.id == 'potted_plant') && !item.isSurfaceItem && !item.isWallItem;
      }
      if (_selectedCategory == 'bedroom') {
        return (item.zone == 'bedroom' || item.id == 'single_bed' || item.id == 'closet' || item.id == 'king_bed') && !item.isSurfaceItem && !item.isWallItem;
      }
      if (_selectedCategory == 'kitchen_bath') {
        return (item.zone == 'kitchen_bath' || item.zone == 'kitchen' || item.zone == 'bathroom' || item.id == 'kitchen_fridge_sm' || item.id == 'kitchen_stove' || item.id == 'kitchen_sink' || item.id == 'kitchen_counter' || item.id == 'bathtub_1x2' || item.id == 'bathtub_regular_1x2' || item.id == 'bathroom_toilet') && !item.isSurfaceItem && !item.isWallItem;
      }
      if (_selectedCategory == 'patio') {
        return (item.zone == 'patio' || item.id == 'bbq_grill' || item.id == 'stone_fountain') && !item.isSurfaceItem && !item.isWallItem;
      }
      if (_selectedCategory == 'guide') {
        return (item.zone == 'guide' || item.id.startsWith('cube_')) && !item.isSurfaceItem && !item.isWallItem;
      }
      if (_selectedCategory == 'surface') {
        return item.isSurfaceItem;
      }
      if (_selectedCategory == 'walls') {
        return item.isWallItem;
      }
      return true;
    }).toList();

    return Container(
      height: sheetHeight + bottomPadding,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1C27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF453F58), width: 2)),
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle — drag up to grow the sheet and see more of the catalog, drag
          // down to shrink it back, or drag it down further to close (same as before).
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              setState(() {
                _heightFraction = (_heightFraction - details.delta.dy / screenHeight).clamp(0.12, _maxHeightFraction);
              });
            },
            onVerticalDragEnd: (details) {
              if (_heightFraction < _closeHeightFraction) {
                Navigator.of(context).maybePop();
                return;
              }
              setState(() {
                _heightFraction = _heightFraction.clamp(_minHeightFraction, _maxHeightFraction);
              });
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 3.5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🛋️', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    const Text(
                      'Catálogo de Muebles',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
          ),

          const SizedBox(height: 3),

          // Horizontal Category Chips Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['id']!),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFF282531),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFF453F58),
                      ),
                    ),
                    child: Text(
                      cat['name']!,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.black : Colors.white70,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 4),

          // Slim 4-column GridView (mobile and tablet alike) showing at least 3 rows
          Expanded(
            child: filteredItems.isEmpty
                ? const Center(
                    child: Text('No hay muebles en esta categoría.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 0.80,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      return _buildFurnitureItemCard(filteredItems[index]);
                    },
                  ),
          ),
          SizedBox(height: bottomPadding + 4),
        ],
      ),
    );
  }

  Widget _buildPreviewImage(FurnitureCatalogItem item) {
    final assetName = item.isWallItem ? (item.id.endsWith('_n') || item.id.endsWith('_w') ? item.id : '${item.id}_n') : item.id;
    final r0Asset = item.rotations[0]?.assetPath;
    final primaryPath = (r0Asset != null && r0Asset.isNotEmpty)
        ? 'assets/$r0Asset'
        : 'assets/images/furniture/established_furniture/$assetName.png';

    return Image.asset(
      primaryPath,
      cacheWidth: 80,
      cacheHeight: 80,
      filterQuality: FilterQuality.medium,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/furniture/established_furniture/$assetName.png',
          cacheWidth: 80,
          cacheHeight: 80,
          filterQuality: FilterQuality.medium,
          fit: BoxFit.contain,
          errorBuilder: (context, err2, st2) => Icon(
            item.isSurfaceItem ? Icons.local_cafe : (item.isWallItem ? Icons.wallpaper : Icons.chair),
            color: Colors.white24,
            size: 22,
          ),
        );
      },
    );
  }

  Widget _buildFurnitureItemCard(FurnitureCatalogItem item) {
    String tagLabel = '1x1';
    Color tagColor = const Color(0xFF00E5FF);

    if (item.isSurfaceItem) {
      tagLabel = '✨ Mesa';
      tagColor = const Color(0xFFFFD54F);
    } else if (item.isWallItem) {
      tagLabel = '🧱 Pared';
      tagColor = const Color(0xFFA78BFA);
    } else if (item.isSurfaceSupporting) {
      tagLabel = '${item.footprint} (+M)';
      tagColor = const Color(0xFF10B981);
    } else {
      tagLabel = '${item.footprint}';
    }

    return GestureDetector(
      onTap: () {
        widget.onAddFurniture?.call(item);
        Navigator.pop(context);
        final msg = item.isSurfaceItem
            ? '¡${item.name} agregado! Arrástralo sobre un mueble.'
            : (item.isWallItem
                ? '¡${item.name} agregado! Arrástralo a la pared.'
                : '¡${item.name} agregado! Ubícalo en la habitación.');
        if (widget.onNotification != null) {
          widget.onNotification!(msg);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFF282531),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: const Color(0xFF282531),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tagColor.withOpacity(0.4), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badge & Add Icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: tagColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tagLabel,
                    style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: tagColor),
                  ),
                ),
                Icon(Icons.add_circle, color: tagColor, size: 13),
              ],
            ),
            const SizedBox(height: 2),
            // Centered Sprite Preview
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1C27),
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(2),
                child: _buildPreviewImage(item),
              ),
            ),
            const SizedBox(height: 2),
            // Item Name
            Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 9.5,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Extra info
            Text(
              item.isSurfaceSupporting ? 'Superficie (+${item.effectiveSurfaceHeight}px)' : (item.isSurfaceItem ? 'Sobre muebles' : 'Decoración'),
              style: const TextStyle(
                fontSize: 7.5,
                color: Colors.white54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
