import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/furniture_item.dart';

class FurnitureCatalogService {
  static final Map<String, FurnitureCatalogItem> _catalog = {};
  static bool _isLoaded = false;

  static bool get isLoaded => _isLoaded;
  static Map<String, FurnitureCatalogItem> get items => Map.unmodifiable(_catalog);

  /// Initializes the catalog from JSON asset (or fallback definitions)
  static Future<void> initialize({bool forceReload = false}) async {
    if (!forceReload && _isLoaded && _catalog.isNotEmpty) return;

    try {
      final jsonStr = await rootBundle.loadString('assets/images/furniture/furniture_catalog.json');
      final Map<String, dynamic> rawMap = json.decode(jsonStr) as Map<String, dynamic>;
      _catalog.clear();
      rawMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          _catalog[key] = FurnitureCatalogItem.fromJson(key, value);
        }
      });
      _mergeFallbackCatalog();
      _isLoaded = true;
    } catch (e) {
      if (_catalog.isEmpty) {
        _loadFallbackCatalog();
      }
      _isLoaded = true;
    }
  }

  static Future<void> reload() async {
    _isLoaded = false;
    _catalog.clear();
    await initialize(forceReload: true);
  }

  static FurnitureCatalogItem? getItem(String id) {
    if (_catalog.isEmpty) {
      _loadFallbackCatalog();
    }
    if (_catalog.containsKey(id)) return _catalog[id];
    // If querying variant e.g. art_painting_n or art_painting_w, resolve to base item
    final baseId = id.endsWith('_wall_n') || id.endsWith('_wall_w')
        ? '${id.substring(0, id.length - 7)}_wall'
        : (id.endsWith('_n') || id.endsWith('_w') ? id.substring(0, id.length - 2) : id);
    if (_catalog.containsKey(baseId)) return _catalog[baseId];
    return null;
  }

  static List<FurnitureCatalogItem> getByCategory(String category) {
    if (_catalog.isEmpty) {
      _loadFallbackCatalog();
    }
    switch (category) {
      case 'living':
        return _catalog.values.where((i) => (i.zone == 'living' || i.id == 'table' || i.id == 'bookshelf' || i.id == 'tall_bookshelf' || i.id == 'dining_table_2x2' || i.id == 'side_table' || i.id == 'plush_armchair' || i.id == 'wooden_chair' || i.id == 'potted_plant') && !i.isSurfaceItem && !i.isWallItem).toList();
      case 'bedroom':
        return _catalog.values.where((i) => (i.zone == 'bedroom' || i.id == 'single_bed' || i.id == 'closet' || i.id == 'king_bed') && !i.isSurfaceItem && !i.isWallItem).toList();
      case 'kitchen_bath':
        return _catalog.values.where((i) => (i.zone == 'kitchen_bath' || i.zone == 'kitchen' || i.zone == 'bathroom' || i.id == 'kitchen_fridge_sm' || i.id == 'kitchen_stove' || i.id == 'kitchen_sink' || i.id == 'kitchen_counter' || i.id == 'bathtub_1x2' || i.id == 'bathtub_regular_1x2' || i.id == 'bathroom_toilet') && !i.isSurfaceItem && !i.isWallItem).toList();
      case 'surface':
        return _catalog.values.where((i) => i.isSurfaceItem).toList();
      case 'walls':
        return _catalog.values.where((i) => i.isWallItem).toList();
      case 'patio':
        return _catalog.values.where((i) => (i.zone == 'patio' || i.id == 'bbq_grill' || i.id == 'stone_fountain') && !i.isSurfaceItem && !i.isWallItem).toList();
      case 'guide':
        return _catalog.values.where((i) => (i.zone == 'guide' || i.id.startsWith('cube_')) && !i.isSurfaceItem && !i.isWallItem).toList();
      default:
        return _catalog.values.toList();
    }
  }

  static void _mergeFallbackCatalog() {
    _loadFallbackCatalog(overwriteExisting: false);
  }

  static void _loadFallbackCatalog({bool overwriteExisting = true}) {
    final fallbackList = [
      // Muebles Nuevos (New Added)
      const FurnitureCatalogItem(id: 'table', name: 'Mesa Rústica', zone: 'living', footprint: '1x1', surfaceHeight: 18, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'bookshelf', name: 'Estantería de Libros', zone: 'living', footprint: '1x1', surfaceHeight: 14, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'tall_bookshelf', name: 'Estantería Alta', zone: 'living', footprint: '1x1', surfaceHeight: 14, spriteOffset: [-32, -73]),
      const FurnitureCatalogItem(id: 'single_bed', name: 'Cama Individual (1x2)', zone: 'bedroom', footprint: '1x2', surfaceHeight: 14, spriteOffset: [-64, -36]),
      const FurnitureCatalogItem(id: 'closet', name: 'Armario Ropero Alto', zone: 'bedroom', footprint: '1x1', spriteOffset: [-32, -73]),

      // Guías & Paralelepípedos (Surface Supporting)
      const FurnitureCatalogItem(id: 'cube_1x1', name: 'Paralelepípedo 1x1', zone: 'guide', footprint: '1x1', surfaceHeight: 24, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'cube_1x2', name: 'Paralelepípedo 1x2', zone: 'guide', footprint: '1x2', surfaceHeight: 20, spriteOffset: [-64, -36]),
      const FurnitureCatalogItem(id: 'cube_2x1', name: 'Paralelepípedo 2x1', zone: 'guide', footprint: '2x1', surfaceHeight: 20, spriteOffset: [-32, -36]),
      const FurnitureCatalogItem(id: 'cube_2x2', name: 'Paralelepípedo 2x2', zone: 'guide', footprint: '2x2', surfaceHeight: 28, spriteOffset: [-64, -44]),
      const FurnitureCatalogItem(id: 'cube_wall', name: 'Guía de Pared', zone: 'guide', footprint: 'wall_n', spriteOffset: [-32, -48]),

      // Surface items (Tabletop)
      const FurnitureCatalogItem(id: 'table_lamp', name: 'Lámpara de Noche', zone: 'decor', footprint: 'surface', spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'coffee_mug', name: 'Taza de Café Caliente', zone: 'decor', footprint: 'surface', spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'open_book', name: 'Libro Abierto', zone: 'decor', footprint: 'surface', spriteOffset: [-32, -48]),

      // Living & Tables (Surface Supporting)
      const FurnitureCatalogItem(id: 'dining_table_2x2', name: 'Mesa de Comedor Roble (2x2)', zone: 'living', footprint: '2x2', surfaceHeight: 22, spriteOffset: [-64, -44]),
      const FurnitureCatalogItem(id: 'side_table', name: 'Mesa de Noche / Velador', zone: 'living', footprint: '1x1', surfaceHeight: 18, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'wooden_chair', name: 'Silla de Madera', zone: 'living', footprint: '1x1', surfaceHeight: 14, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'plush_armchair', name: 'Sillón Acolchado', zone: 'living', footprint: '1x1', surfaceHeight: 16, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'potted_plant', name: 'Planta en Maceta', zone: 'living', footprint: '1x1', spriteOffset: [-32, -48]),

      // Bedroom (Surface Supporting)
      const FurnitureCatalogItem(id: 'king_bed', name: 'Cama King Size (2x2)', zone: 'bedroom', footprint: '2x2', surfaceHeight: 16, spriteOffset: [-64, -44]),

      // Kitchen & Bath
      const FurnitureCatalogItem(id: 'kitchen_counter', name: 'Encimera de Cocina', zone: 'kitchen', footprint: '1x1', surfaceHeight: 20, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'kitchen_stove', name: 'Cocina con Fogones', zone: 'kitchen', footprint: '1x1', surfaceHeight: 22, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'kitchen_sink', name: 'Fregadero Inox', zone: 'kitchen', footprint: '1x1', surfaceHeight: 20, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'kitchen_fridge_sm', name: 'Refrigerador Compacto', zone: 'kitchen', footprint: '0.5x0.5', spriteOffset: [-64, -136]),
      const FurnitureCatalogItem(id: 'bathtub_1x2', name: 'Bañera Clásica (1x2)', zone: 'bathroom', footprint: '1x2', spriteOffset: [-64, -36]),
      const FurnitureCatalogItem(id: 'bathroom_toilet', name: 'Inodoro Cerámica', zone: 'bathroom', footprint: '1x1', spriteOffset: [-32, -48]),

      // Walls (Unified single entry per wall item)
      const FurnitureCatalogItem(id: 'window_yellow', name: 'Window Yellow', zone: 'decor', footprint: 'wall_n', spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'art_painting', name: 'Cuadro de Paisaje', zone: 'decor', footprint: 'wall_n', spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'hanging_shelf_wall', name: 'Repisa Colgante', zone: 'decor', footprint: 'wall_n', surfaceHeight: 12, spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'wall_clock', name: 'Reloj de Pared', zone: 'decor', footprint: 'wall_n', spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'pan_rack_wall', name: 'Colgador de Sartenes', zone: 'kitchen', footprint: 'wall_n', spriteOffset: [-32, -48]),
      const FurnitureCatalogItem(id: 'towel_rack_wall', name: 'Toallero', zone: 'bathroom', footprint: 'wall_n', spriteOffset: [-32, -48]),

      // Patio
      const FurnitureCatalogItem(id: 'stone_fountain', name: 'Fuente de Piedra (2x2)', zone: 'patio', footprint: '2x2', spriteOffset: [-64, -44]),
      const FurnitureCatalogItem(id: 'bbq_grill', name: 'Parrilla Asador', zone: 'patio', footprint: '1x1', surfaceHeight: 16, spriteOffset: [-32, -48]),
    ];

    for (final item in fallbackList) {
      if (overwriteExisting || !_catalog.containsKey(item.id)) {
        _catalog[item.id] = item;
      }
    }
  }
}
