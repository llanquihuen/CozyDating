import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class PlacedFurnitureConfig extends Equatable {
  final String id;
  final String typeName;
  final int gridX;
  final int gridY;
  final int gridWidth;
  final int gridHeight;
  final int rotation;
  final String? assetPath;
  final String? parentId;
  final String wallHeightLevel; // 'mid' or 'high'
  final double nudgeX;
  final double nudgeY;

  const PlacedFurnitureConfig({
    required this.id,
    required this.typeName,
    required this.gridX,
    required this.gridY,
    this.gridWidth = 1,
    this.gridHeight = 1,
    this.rotation = 0,
    this.assetPath,
    this.parentId,
    this.wallHeightLevel = 'high',
    this.nudgeX = 0.0,
    this.nudgeY = 0.0,
  });

  PlacedFurnitureConfig copyWith({
    String? id,
    String? typeName,
    int? gridX,
    int? gridY,
    int? gridWidth,
    int? gridHeight,
    int? rotation,
    String? assetPath,
    String? parentId,
    bool clearParent = false,
    String? wallHeightLevel,
    double? nudgeX,
    double? nudgeY,
  }) {
    return PlacedFurnitureConfig(
      id: id ?? this.id,
      typeName: typeName ?? this.typeName,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      rotation: rotation ?? this.rotation,
      assetPath: assetPath ?? this.assetPath,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      wallHeightLevel: wallHeightLevel ?? this.wallHeightLevel,
      nudgeX: nudgeX ?? this.nudgeX,
      nudgeY: nudgeY ?? this.nudgeY,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'typeName': typeName,
      'gridX': gridX,
      'gridY': gridY,
      'gridWidth': gridWidth,
      'gridHeight': gridHeight,
      'rotation': rotation,
      if (assetPath != null) 'assetPath': assetPath,
      if (parentId != null) 'parentId': parentId,
      if (wallHeightLevel != 'high') 'wallHeightLevel': wallHeightLevel,
      if (nudgeX != 0.0) 'nudgeX': nudgeX,
      if (nudgeY != 0.0) 'nudgeY': nudgeY,
    };
  }

  factory PlacedFurnitureConfig.fromMap(Map<String, dynamic> map) {
    return PlacedFurnitureConfig(
      id: map['id'] ?? '',
      typeName: map['typeName'] ?? 'table',
      gridX: map['gridX'] ?? 0,
      gridY: map['gridY'] ?? 0,
      gridWidth: map['gridWidth'] ?? 1,
      gridHeight: map['gridHeight'] ?? 1,
      rotation: map['rotation'] ?? 0,
      assetPath: map['assetPath'],
      parentId: map['parentId'] ?? map['parent_id'],
      wallHeightLevel: map['wallHeightLevel'] ?? map['wall_height_level'] ?? 'high',
      nudgeX: (map['nudgeX'] ?? map['nudge_x'] as num?)?.toDouble() ?? 0.0,
      nudgeY: (map['nudgeY'] ?? map['nudge_y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [id, typeName, gridX, gridY, gridWidth, gridHeight, rotation, assetPath, parentId, wallHeightLevel, nudgeX, nudgeY];
}

class RoomConfig extends Equatable {
  final String wallpaper;
  final String floor;
  final String resolution; // '64x128' or '32x64'
  final List<PlacedFurnitureConfig> furniture;
  final List<InteriorWallConfig> interiorWalls;

  const RoomConfig({
    this.wallpaper = 'rustic_wood',
    this.floor = 'oak_parquet',
    this.resolution = '64x128',
    this.interiorWalls = const [],
    this.furniture = const [
      PlacedFurnitureConfig(
        id: 'window_yellow_n',
        typeName: 'window_yellow_n',
        gridX: 3,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
        wallHeightLevel: 'high',
      ),
      PlacedFurnitureConfig(
        id: 'art_painting_w',
        typeName: 'art_painting_w',
        gridX: 0,
        gridY: 2,
        gridWidth: 1,
        gridHeight: 1,
        wallHeightLevel: 'high',
      ),
      PlacedFurnitureConfig(
        id: 'tall_bookshelf',
        typeName: 'tall_bookshelf',
        gridX: 1,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
      ),
      PlacedFurnitureConfig(
        id: 'bookshelf',
        typeName: 'bookshelf',
        gridX: 6,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
      ),
      PlacedFurnitureConfig(
        id: 'single_bed',
        typeName: 'single_bed',
        // Tucked into the far corner of the east bedroom nook (gridX 5-7, gridY 0-2).
        gridX: 7,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 2,
      ),
      PlacedFurnitureConfig(
        id: 'closet',
        typeName: 'closet',
        gridX: 0,
        gridY: 6,
        gridWidth: 1,
        gridHeight: 1,
      ),
      PlacedFurnitureConfig(
        id: 'table',
        typeName: 'table',
        gridX: 3,
        gridY: 3,
        gridWidth: 1,
        gridHeight: 1,
      ),
      PlacedFurnitureConfig(
        id: 'coffee_mug',
        typeName: 'coffee_mug',
        gridX: 3,
        gridY: 3,
        gridWidth: 1,
        gridHeight: 1,
        parentId: 'table',
      ),
    ],
  });

  RoomConfig copyWith({
    String? wallpaper,
    String? floor,
    String? resolution,
    List<PlacedFurnitureConfig>? furniture,
    List<InteriorWallConfig>? interiorWalls,
  }) {
    return RoomConfig(
      wallpaper: wallpaper ?? this.wallpaper,
      floor: floor ?? this.floor,
      resolution: resolution ?? this.resolution,
      furniture: furniture ?? this.furniture,
      interiorWalls: interiorWalls ?? this.interiorWalls,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wallpaper': wallpaper,
      'floor': floor,
      'resolution': resolution,
      'furniture': furniture.map((f) => f.toMap()).toList(),
      if (interiorWalls.isNotEmpty)
        'interiorWalls': interiorWalls.map((w) => w.toMap()).toList(),
    };
  }

  factory RoomConfig.fromMap(Map<String, dynamic> map) {
    return RoomConfig(
      wallpaper: map['wallpaper'] ?? 'rustic_wood',
      floor: map['floor'] ?? 'oak_parquet',
      resolution: map['resolution'] ?? '64x128',
      interiorWalls: map['interiorWalls'] != null
          ? List<InteriorWallConfig>.from(
              (map['interiorWalls'] as List).map((x) => InteriorWallConfig.fromMap(x)))
          : const [],
      furniture: map['furniture'] != null
          ? List<PlacedFurnitureConfig>.from(
              (map['furniture'] as List).map((x) => PlacedFurnitureConfig.fromMap(x)))
          : const [
              PlacedFurnitureConfig(
                id: 'window_yellow_n',
                typeName: 'window_yellow_n',
                gridX: 3,
                gridY: 0,
                gridWidth: 1,
                gridHeight: 1,
                wallHeightLevel: 'high',
              ),
              PlacedFurnitureConfig(
                id: 'art_painting_w',
                typeName: 'art_painting_w',
                gridX: 0,
                gridY: 2,
                gridWidth: 1,
                gridHeight: 1,
              ),
              PlacedFurnitureConfig(
                id: 'tall_bookshelf',
                typeName: 'tall_bookshelf',
                gridX: 1,
                gridY: 0,
                gridWidth: 1,
                gridHeight: 1,
              ),
              PlacedFurnitureConfig(
                id: 'bookshelf',
                typeName: 'bookshelf',
                gridX: 6,
                gridY: 0,
                gridWidth: 1,
                gridHeight: 1,
              ),
              PlacedFurnitureConfig(
                id: 'single_bed',
                typeName: 'single_bed',
                gridX: 7,
                gridY: 0,
                gridWidth: 1,
                gridHeight: 2,
              ),
              PlacedFurnitureConfig(
                id: 'closet',
                typeName: 'closet',
                gridX: 0,
                gridY: 6,
                gridWidth: 1,
                gridHeight: 1,
              ),
              PlacedFurnitureConfig(
                id: 'table',
                typeName: 'table',
                gridX: 3,
                gridY: 3,
                gridWidth: 1,
                gridHeight: 1,
              ),
              PlacedFurnitureConfig(
                id: 'coffee_mug',
                typeName: 'coffee_mug',
                gridX: 3,
                gridY: 3,
                gridWidth: 1,
                gridHeight: 1,
                parentId: 'table',
              ),
            ],
    );
  }

  String toJson() => json.encode(toMap());

  factory RoomConfig.fromJson(String source) => RoomConfig.fromMap(json.decode(source));

  @override
  List<Object?> get props => [wallpaper, floor, resolution, furniture, interiorWalls];
}

class InteriorWallConfig extends Equatable {
  final String id;
  final int gridX;
  final int gridY;
  final String orientation; // 'north' (top edge) or 'west' (left edge)
  final String style; // 'wood_slats', 'bathroom_glass', 'rustic_brick', 'modern_white', 'japanese_shoji', 'doorway_frame'
  final bool hasDoorway;

  const InteriorWallConfig({
    required this.id,
    required this.gridX,
    required this.gridY,
    this.orientation = 'north',
    this.style = 'wood_slats',
    this.hasDoorway = false,
  });

  InteriorWallConfig copyWith({
    String? id,
    int? gridX,
    int? gridY,
    String? orientation,
    String? style,
    bool? hasDoorway,
  }) {
    return InteriorWallConfig(
      id: id ?? this.id,
      gridX: gridX ?? this.gridX,
      gridY: gridY ?? this.gridY,
      orientation: orientation ?? this.orientation,
      style: style ?? this.style,
      hasDoorway: hasDoorway ?? this.hasDoorway,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gridX': gridX,
      'gridY': gridY,
      'orientation': orientation,
      'style': style,
      if (hasDoorway) 'hasDoorway': hasDoorway,
    };
  }

  factory InteriorWallConfig.fromMap(Map<String, dynamic> map) {
    return InteriorWallConfig(
      id: map['id'] ?? '',
      gridX: map['gridX'] ?? 0,
      gridY: map['gridY'] ?? 0,
      orientation: map['orientation'] ?? 'north',
      style: map['style'] ?? 'wood_slats',
      hasDoorway: map['hasDoorway'] ?? false,
    );
  }

  @override
  List<Object?> get props => [id, gridX, gridY, orientation, style, hasDoorway];
}

class InteriorWallStyleOption {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final bool isDoorway;
  final Color? color;

  const InteriorWallStyleOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.isDoorway = false,
    this.color,
  });
}

class InteriorWallStyles {
  static const List<InteriorWallStyleOption> all = [
    // Structural Architectural Styles
    InteriorWallStyleOption(
      id: 'wood_slats',
      name: 'Tabique de Madera',
      emoji: '🪵',
      description: 'Paneles de madera cálida para separar cocina o dormitorio.',
    ),
    InteriorWallStyleOption(
      id: 'bathroom_glass',
      name: 'Mampara de Cristal',
      emoji: '🚿',
      description: 'Cristal translúcido con perfil metálico para el baño.',
    ),
    InteriorWallStyleOption(
      id: 'rustic_brick',
      name: 'Muro de Ladrillo',
      emoji: '🧱',
      description: 'Pared divisoria rústica de ladrillo visto.',
    ),
    InteriorWallStyleOption(
      id: 'japanese_shoji',
      name: 'Biombo Shoji',
      emoji: '🎋',
      description: 'Elegante mampara japonesa de madera y papel de arroz.',
    ),
    InteriorWallStyleOption(
      id: 'doorway_frame',
      name: 'Marco de Puerta Abierto',
      emoji: '🚪',
      description: 'Paso libre entre ambientes sin bloquear el paso.',
      isDoorway: true,
    ),

    // Solid Color Textured Plaster Walls (Paredes de color a juego con la habitación)
    InteriorWallStyleOption(
      id: 'solid_white_plaster',
      name: 'Muro Blanco Lino',
      emoji: '🤍',
      description: 'Tabique liso de yeso blanco lino con zócalo.',
      color: Color(0xFFF9F9F8),
    ),
    InteriorWallStyleOption(
      id: 'solid_sage_green',
      name: 'Muro Verde Salvia',
      emoji: '🍃',
      description: 'Pared divisoria verde salvia relajante.',
      color: Color(0xFF8DA399),
    ),
    InteriorWallStyleOption(
      id: 'solid_warm_beige',
      name: 'Muro Beige Arena',
      emoji: '🌾',
      description: 'Tabique cálido color arena tostada.',
      color: Color(0xFFE8DCCB),
    ),
    InteriorWallStyleOption(
      id: 'solid_dusty_rose',
      name: 'Muro Rosa Pastel',
      emoji: '🩰',
      description: 'Pared divisoria rosa empolvado cálido.',
      color: Color(0xFFE5B2B7),
    ),
    InteriorWallStyleOption(
      id: 'solid_navy_blue',
      name: 'Muro Azul Índigo',
      emoji: '🌌',
      description: 'Tabique azul noche aterciopelado.',
      color: Color(0xFF2C3E50),
    ),
    InteriorWallStyleOption(
      id: 'solid_charcoal',
      name: 'Muro Gris Pizarra',
      emoji: '🌑',
      description: 'Pared moderna gris grafito contemporáneo.',
      color: Color(0xFF4A4E5A),
    ),
    InteriorWallStyleOption(
      id: 'solid_mustard',
      name: 'Muro Mostaza Cálido',
      emoji: '🌻',
      description: 'Tabique ocre soleado y acogedor.',
      color: Color(0xFFE5A65D),
    ),
    InteriorWallStyleOption(
      id: 'solid_lavender',
      name: 'Muro Lavanda Suave',
      emoji: '🪻',
      description: 'Pared violeta pastel suave.',
      color: Color(0xFFC3B1E1),
    ),
    InteriorWallStyleOption(
      id: 'modern_white',
      name: 'Panel Blanco Minimalista',
      emoji: '◻️',
      description: 'Separador minimalista con perfil gris y base negra.',
      color: Color(0xFFECEFF1),
    ),
  ];
}

class WallpaperOption {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color? color;

  const WallpaperOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.color,
  });
}

class FloorOption {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color? color;

  const FloorOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.color,
  });
}

class RoomThemes {
  static const List<WallpaperOption> wallpapers = [
    // Patterns
    WallpaperOption(
      id: 'rustic_wood',
      name: 'Madera Rústica',
      emoji: '🪵',
      description: 'Paneles de madera de roble con zócalos cálidos.',
    ),
    WallpaperOption(
      id: 'brick_stone',
      name: 'Ladrillo Vintage',
      emoji: '🧱',
      description: 'Pared de ladrillo visto con mortero artesanal.',
    ),
    WallpaperOption(
      id: 'cozy_stripes',
      name: 'Rayas Salvia',
      emoji: '🌿',
      description: 'Rayas elegantes con moldura victoriana.',
    ),
    WallpaperOption(
      id: 'starry_night',
      name: 'Noche Estrellada',
      emoji: '✨',
      description: 'Fondo azul noche profundo con destellos dorados.',
    ),
    WallpaperOption(
      id: 'pastel_floral',
      name: 'Floral Romántico',
      emoji: '🌸',
      description: 'Papel tapiz rosa pastel con motivos florales.',
    ),

    // Solid Textured Colors (Paredes de color con textura de yeso y zócalo)
    WallpaperOption(
      id: 'solid_white_plaster',
      name: 'Blanco Lino',
      emoji: '🤍',
      description: 'Pared lisa blanco suave con textura de yeso.',
      color: Color(0xFFF9F9F8),
    ),
    WallpaperOption(
      id: 'solid_sage_green',
      name: 'Verde Salvia',
      emoji: '🍃',
      description: 'Pintura mate verde salvia relajante.',
      color: Color(0xFF8DA399),
    ),
    WallpaperOption(
      id: 'solid_warm_beige',
      name: 'Beige Arena',
      emoji: '🌾',
      description: 'Pared cálida tono arena tostada.',
      color: Color(0xFFE8DCCB),
    ),
    WallpaperOption(
      id: 'solid_dusty_rose',
      name: 'Rosa Pastel',
      emoji: '🩰',
      description: 'Pintura suave rosa empolvado cálido.',
      color: Color(0xFFE5B2B7),
    ),
    WallpaperOption(
      id: 'solid_navy_blue',
      name: 'Azul Índigo',
      emoji: '🌌',
      description: 'Pared azul profundo aterciopelada.',
      color: Color(0xFF2C3E50),
    ),
    WallpaperOption(
      id: 'solid_charcoal',
      name: 'Gris Pizarra',
      emoji: '🌑',
      description: 'Pintura gris grafito contemporánea.',
      color: Color(0xFF4A4E5A),
    ),
    WallpaperOption(
      id: 'solid_mustard',
      name: 'Mostaza Cálido',
      emoji: '🌻',
      description: 'Pintura ocre soleada y acogedora.',
      color: Color(0xFFE5A65D),
    ),
    WallpaperOption(
      id: 'solid_lavender',
      name: 'Lavanda Suave',
      emoji: '🪻',
      description: 'Pintura violeta pastel relajante.',
      color: Color(0xFFC3B1E1),
    ),
  ];

  static const List<FloorOption> floors = [
    // Patterns
    FloorOption(
      id: 'oak_parquet',
      name: 'Parquet de Roble',
      emoji: '🪵',
      description: 'Madera de roble natural pulida en espiga.',
    ),
    FloorOption(
      id: 'dark_walnut',
      name: 'Nogal Oscuro',
      emoji: '🍂',
      description: 'Tablones oscuros de nogal noble.',
    ),
    FloorOption(
      id: 'checker_marble',
      name: 'Mármol Ajedrezado',
      emoji: '🏁',
      description: 'Baldosas de mármol blanco y pizarra gris.',
    ),
    FloorOption(
      id: 'terracotta_tiles',
      name: 'Terracota Rústica',
      emoji: '🏺',
      description: 'Barro cocido mediterráneo artesanal.',
    ),
    FloorOption(
      id: 'tatami_mat',
      name: 'Tatami Japonés',
      emoji: '🎋',
      description: 'Esteras de bambú y paja natural relajante.',
    ),

    // Solid Textured Colors (Suelos cerámicos de color con textura)
    FloorOption(
      id: 'solid_white_tiles',
      name: 'Cerámica Blanca',
      emoji: '⚪',
      description: 'Baldosas lisas blancas con juntas finas.',
      color: Color(0xFFF5F6F8),
    ),
    FloorOption(
      id: 'solid_slate_gray',
      name: 'Microcemento Gris',
      emoji: '🏢',
      description: 'Suelo gris moderno estilo cemento pulido.',
      color: Color(0xFF7F8C8D),
    ),
    FloorOption(
      id: 'solid_mint_green',
      name: 'Menta Pastel',
      emoji: '🌿',
      description: 'Baldosas cerámicas verde menta suave.',
      color: Color(0xFFA8D8B9),
    ),
    FloorOption(
      id: 'solid_blush_pink',
      name: 'Rosa Cuarzo',
      emoji: '🌸',
      description: 'Baldosas lisas rosa pastel.',
      color: Color(0xFFEBBFC2),
    ),
    FloorOption(
      id: 'solid_warm_sand',
      name: 'Arena Cálida',
      emoji: '🏖️',
      description: 'Suelo continuo color arena mediterránea.',
      color: Color(0xFFD8C3A5),
    ),
    FloorOption(
      id: 'solid_dark_graphite',
      name: 'Grafito Mate',
      emoji: '🖤',
      description: 'Baldosas oscuras de pizarra moderna.',
      color: Color(0xFF34495E),
    ),
    FloorOption(
      id: 'solid_ocean_teal',
      name: 'Turquesa Suave',
      emoji: '🌊',
      description: 'Baldosas cerámicas azul verdoso.',
      color: Color(0xFF5C9496),
    ),
  ];
}
