import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

class PlacedFurnitureConfig extends Equatable {
  final String id;
  final String typeName;
  final double gridX;
  final double gridY;
  final double gridWidth;
  final double gridHeight;
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
    this.gridWidth = 1.0,
    this.gridHeight = 1.0,
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
    double? gridX,
    double? gridY,
    double? gridWidth,
    double? gridHeight,
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
      gridX: (map['gridX'] as num?)?.toDouble() ?? 0.0,
      gridY: (map['gridY'] as num?)?.toDouble() ?? 0.0,
      gridWidth: (map['gridWidth'] as num?)?.toDouble() ?? 1.0,
      gridHeight: (map['gridHeight'] as num?)?.toDouble() ?? 1.0,
      rotation: (map['rotation'] as num?)?.toInt() ?? 0,
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
  final Map<String, String> floorOverrides; // 'x,y' -> floorId
  final Map<String, String> wallOverrides; // 'n,x' or 'w,y' -> wallpaperId
  final String resolution; // '64x128' or '32x64'
  final List<PlacedFurnitureConfig> furniture;
  final List<InteriorWallConfig> interiorWalls;

  static const List<PlacedFurnitureConfig> defaultFurniture = [
    // --- Salón / Común ---
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
      id: 'bookshelf',
      typeName: 'bookshelf',
      gridX: 4,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 1,
    ),
    PlacedFurnitureConfig(
      id: 'table',
      typeName: 'table',
      gridX: 3,
      gridY: 4,
      gridWidth: 1,
      gridHeight: 1,
    ),
    PlacedFurnitureConfig(
      id: 'coffee_mug',
      typeName: 'coffee_mug',
      gridX: 3,
      gridY: 4,
      gridWidth: 1,
      gridHeight: 1,
      parentId: 'table',
    ),
    PlacedFurnitureConfig(
      id: 'wooden_chair',
      typeName: 'wooden_chair',
      gridX: 4,
      gridY: 4,
      gridWidth: 1,
      gridHeight: 1,
    ),
    PlacedFurnitureConfig(
      id: 'potted_plant',
      typeName: 'potted_plant',
      gridX: 4,
      gridY: 3,
      gridWidth: 1,
      gridHeight: 1,
    ),

    // --- Dormitorio (NE: gridX 5..7, gridY 0..2) ---
    PlacedFurnitureConfig(
      id: 'single_bed',
      typeName: 'single_bed',
      gridX: 7,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 2,
    ),
    PlacedFurnitureConfig(
      id: 'side_table',
      typeName: 'side_table',
      gridX: 6,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 1,
    ),
    PlacedFurnitureConfig(
      id: 'table_lamp',
      typeName: 'table_lamp',
      gridX: 6,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 1,
      parentId: 'side_table',
    ),
    PlacedFurnitureConfig(
      id: 'closet',
      typeName: 'closet',
      gridX: 5,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 1,
    ),

    // --- Baño (NW: gridX 0..2, gridY 0..2) ---
    PlacedFurnitureConfig(
      id: 'bathtub_1x2',
      typeName: 'bathtub_1x2',
      gridX: 0,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 2,
    ),
    PlacedFurnitureConfig(
      id: 'bathroom_toilet',
      typeName: 'bathroom_toilet',
      gridX: 2,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 1,
    ),
    PlacedFurnitureConfig(
      id: 'towel_rack_wall',
      typeName: 'towel_rack_wall',
      gridX: 1,
      gridY: 0,
      gridWidth: 1,
      gridHeight: 1,
      wallHeightLevel: 'high',
    ),

    // --- Cocina (SW: gridX 0..2, gridY 4..6) ---
    PlacedFurnitureConfig(
      id: 'kitchen_fridge_sm',
      typeName: 'kitchen_fridge_sm',
      gridX: 0,
      gridY: 4,
      gridWidth: 0.5,
      gridHeight: 0.5,
      rotation: 0,
    ),
    PlacedFurnitureConfig(
      id: 'kitchen_stove',
      typeName: 'kitchen_stove',
      gridX: 0,
      gridY: 5,
      gridWidth: 1,
      gridHeight: 1,
      rotation: 1,
    ),
    PlacedFurnitureConfig(
      id: 'kitchen_sink',
      typeName: 'kitchen_sink',
      gridX: 0,
      gridY: 6,
      gridWidth: 1,
      gridHeight: 1,
      rotation: 1,
    ),
    PlacedFurnitureConfig(
      id: 'kitchen_counter',
      typeName: 'kitchen_counter',
      gridX: 0,
      gridY: 7,
      gridWidth: 1,
      gridHeight: 1,
      rotation: 1,
    ),
    PlacedFurnitureConfig(
      id: 'pan_rack_wall',
      typeName: 'pan_rack_wall',
      gridX: 0,
      gridY: 5,
      gridWidth: 1,
      gridHeight: 1,
      wallHeightLevel: 'high',
    ),
  ];

  static const List<InteriorWallConfig> defaultInteriorWalls = [
    // --- Baño (NW: gridX 0..2, gridY 0..2) con mampara de cristal ---
    InteriorWallConfig(id: 'bath_wall_e0', gridX: 3, gridY: 0, orientation: 'west', style: 'bathroom_glass'),
    InteriorWallConfig(id: 'bath_wall_e1', gridX: 3, gridY: 1, orientation: 'west', style: 'bathroom_glass', hasDoorway: true),
    InteriorWallConfig(id: 'bath_wall_e2', gridX: 3, gridY: 2, orientation: 'west', style: 'bathroom_glass'),
    InteriorWallConfig(id: 'bath_wall_s0', gridX: 0, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
    InteriorWallConfig(id: 'bath_wall_s1', gridX: 1, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
    InteriorWallConfig(id: 'bath_wall_s2', gridX: 2, gridY: 3, orientation: 'north', style: 'bathroom_glass'),

    // --- Dormitorio (NE: gridX 5..7, gridY 0..2) con tabiques de madera ---
    InteriorWallConfig(id: 'bed_wall_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'wood_slats'),
    InteriorWallConfig(id: 'bed_wall_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'wood_slats', hasDoorway: true),
    InteriorWallConfig(id: 'bed_wall_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'wood_slats'),
    InteriorWallConfig(id: 'bed_wall_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'wood_slats'),
    InteriorWallConfig(id: 'bed_wall_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'wood_slats'),
    InteriorWallConfig(id: 'bed_wall_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'wood_slats'),

    // --- Cocina (SW: gridX 0..2, gridY 4..6) con separador cálido ---
    InteriorWallConfig(id: 'kitchen_wall_n0', gridX: 0, gridY: 4, orientation: 'north', style: 'wood_slats'),
    InteriorWallConfig(id: 'kitchen_wall_n1', gridX: 1, gridY: 4, orientation: 'north', style: 'wood_slats', hasDoorway: true),
    InteriorWallConfig(id: 'kitchen_wall_n2', gridX: 2, gridY: 4, orientation: 'north', style: 'wood_slats'),
    InteriorWallConfig(id: 'kitchen_wall_e0', gridX: 3, gridY: 4, orientation: 'west', style: 'wood_slats'),
    InteriorWallConfig(id: 'kitchen_wall_e1', gridX: 3, gridY: 5, orientation: 'west', style: 'wood_slats'),
    InteriorWallConfig(id: 'kitchen_wall_e2', gridX: 3, gridY: 6, orientation: 'west', style: 'wood_slats', hasDoorway: true),
  ];

  static const Map<String, String> defaultFloorOverrides = {
    // Baño (azulejos cerámicos blancos)
    '0,0': 'solid_white_tiles',
    '1,0': 'solid_white_tiles',
    '2,0': 'solid_white_tiles',
    '0,1': 'solid_white_tiles',
    '1,1': 'solid_white_tiles',
    '2,1': 'solid_white_tiles',
    '0,2': 'solid_white_tiles',
    '1,2': 'solid_white_tiles',
    '2,2': 'solid_white_tiles',

    // Dormitorio (alfombra arena cálida)
    '5,0': 'solid_carpet_warm_sand',
    '6,0': 'solid_carpet_warm_sand',
    '7,0': 'solid_carpet_warm_sand',
    '5,1': 'solid_carpet_warm_sand',
    '6,1': 'solid_carpet_warm_sand',
    '7,1': 'solid_carpet_warm_sand',
    '5,2': 'solid_carpet_warm_sand',
    '6,2': 'solid_carpet_warm_sand',
    '7,2': 'solid_carpet_warm_sand',

    // Cocina (microcemento gris)
    '0,4': 'solid_slate_gray',
    '1,4': 'solid_slate_gray',
    '2,4': 'solid_slate_gray',
    '0,5': 'solid_slate_gray',
    '1,5': 'solid_slate_gray',
    '2,5': 'solid_slate_gray',
    '0,6': 'solid_slate_gray',
    '1,6': 'solid_slate_gray',
    '2,6': 'solid_slate_gray',
  };

  static const Map<String, String> defaultWallOverrides = {
    // Baño (azulejos cerámicos en las paredes)
    'n,0': 'solid_tiles_white',
    'n,1': 'solid_tiles_white',
    'n,2': 'solid_tiles_white',
    'w,0': 'solid_tiles_white',
    'w,1': 'solid_tiles_white',
    'w,2': 'solid_tiles_white',
  };

  const RoomConfig({
    this.wallpaper = 'rustic_wood',
    this.floor = 'oak_parquet',
    this.floorOverrides = defaultFloorOverrides,
    this.wallOverrides = defaultWallOverrides,
    this.resolution = '64x128',
    this.interiorWalls = defaultInteriorWalls,
    this.furniture = defaultFurniture,
    this.wallsCut = false,
  });

  final bool wallsCut;

  RoomConfig copyWith({
    String? wallpaper,
    String? floor,
    Map<String, String>? floorOverrides,
    Map<String, String>? wallOverrides,
    String? resolution,
    List<PlacedFurnitureConfig>? furniture,
    List<InteriorWallConfig>? interiorWalls,
    bool? wallsCut,
  }) {
    return RoomConfig(
      wallpaper: wallpaper ?? this.wallpaper,
      floor: floor ?? this.floor,
      floorOverrides: floorOverrides ?? this.floorOverrides,
      wallOverrides: wallOverrides ?? this.wallOverrides,
      resolution: resolution ?? this.resolution,
      furniture: furniture ?? this.furniture,
      interiorWalls: interiorWalls ?? this.interiorWalls,
      wallsCut: wallsCut ?? this.wallsCut,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wallpaper': wallpaper,
      'floor': floor,
      if (floorOverrides.isNotEmpty) 'floorOverrides': floorOverrides,
      if (wallOverrides.isNotEmpty) 'wallOverrides': wallOverrides,
      'resolution': resolution,
      'furniture': furniture.map((f) => f.toMap()).toList(),
      if (interiorWalls.isNotEmpty)
        'interiorWalls': interiorWalls.map((w) => w.toMap()).toList(),
      if (wallsCut) 'wallsCut': true,
    };
  }

  factory RoomConfig.fromMap(Map<String, dynamic> map) {
    return RoomConfig(
      wallpaper: map['wallpaper'] ?? 'rustic_wood',
      floor: map['floor'] ?? 'oak_parquet',
      floorOverrides: map['floorOverrides'] != null
          ? Map<String, String>.from(map['floorOverrides'] as Map)
          : defaultFloorOverrides,
      wallOverrides: map['wallOverrides'] != null
          ? Map<String, String>.from(map['wallOverrides'] as Map)
          : defaultWallOverrides,
      resolution: map['resolution'] ?? '64x128',
      interiorWalls: map['interiorWalls'] != null
          ? List<InteriorWallConfig>.from(
              (map['interiorWalls'] as List).map((x) => InteriorWallConfig.fromMap(x)))
          : defaultInteriorWalls,
      furniture: map['furniture'] != null
          ? List<PlacedFurnitureConfig>.from(
              (map['furniture'] as List).map((x) => PlacedFurnitureConfig.fromMap(x)))
          : defaultFurniture,
      wallsCut: map['wallsCut'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory RoomConfig.fromJson(String source) => RoomConfig.fromMap(json.decode(source));

  @override
  List<Object?> get props => [wallpaper, floor, floorOverrides, wallOverrides, resolution, furniture, interiorWalls, wallsCut];
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
  static const List<InteriorWallStyleOption> structural = [
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
    InteriorWallStyleOption(
      id: 'modern_white',
      name: 'Panel Blanco Minimalista',
      emoji: '◻️',
      description: 'Separador minimalista con perfil gris y base negra.',
      color: Color(0xFFECEFF1),
    ),
  ];

  static const List<InteriorWallStyleOption> all = [
    ...structural,

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
  ];

  static InteriorWallStyleOption getOption(String id) {
    for (final opt in all) {
      if (opt.id == id) return opt;
    }
    final wpOpt = RoomThemes.getWallpaperOption(id);
    if (wpOpt.color != null) {
      return InteriorWallStyleOption(
        id: id,
        name: wpOpt.name,
        emoji: wpOpt.emoji,
        description: wpOpt.description,
        color: wpOpt.color,
      );
    }
    return all.first;
  }
}

class WallpaperOption {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color? color;
  final String textureType; // 'pattern', 'plaster', 'tiles'

  const WallpaperOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.color,
    this.textureType = 'pattern',
  });
}

class WallpaperColorOption {
  final String key;
  final String name;
  final String emoji;
  final Color color;

  const WallpaperColorOption({
    required this.key,
    required this.name,
    required this.emoji,
    required this.color,
  });
}

class FloorOption {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final Color? color;
  final String textureType; // 'pattern', 'tiles', 'carpet'

  const FloorOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    this.color,
    this.textureType = 'pattern',
  });
}

class FloorColorOption {
  final String key;
  final String name;
  final String emoji;
  final Color color;

  const FloorColorOption({
    required this.key,
    required this.name,
    required this.emoji,
    required this.color,
  });
}

class RoomThemes {
  static const List<WallpaperColorOption> wallpaperColors = [
    WallpaperColorOption(key: 'white', name: 'Blanco Lino', emoji: '🤍', color: Color(0xFFF9F9F8)),
    WallpaperColorOption(key: 'sage_green', name: 'Verde Salvia', emoji: '🍃', color: Color(0xFF8DA399)),
    WallpaperColorOption(key: 'mint_green', name: 'Menta Pastel', emoji: '🌿', color: Color(0xFFA8D8B9)),
    WallpaperColorOption(key: 'warm_beige', name: 'Beige Arena', emoji: '🌾', color: Color(0xFFE8DCCB)),
    WallpaperColorOption(key: 'dusty_rose', name: 'Rosa Pastel', emoji: '🩰', color: Color(0xFFE5B2B7)),
    WallpaperColorOption(key: 'slate_gray', name: 'Microcemento Gris', emoji: '🏢', color: Color(0xFF7F8C8D)),
    WallpaperColorOption(key: 'lavender', name: 'Lavanda Suave', emoji: '🪻', color: Color(0xFFC3B1E1)),
    WallpaperColorOption(key: 'mustard', name: 'Mostaza Cálido', emoji: '🌻', color: Color(0xFFE5A65D)),
    WallpaperColorOption(key: 'ocean_teal', name: 'Turquesa Suave', emoji: '🌊', color: Color(0xFF5C9496)),
    WallpaperColorOption(key: 'navy_blue', name: 'Azul Índigo', emoji: '🌌', color: Color(0xFF2C3E50)),
    WallpaperColorOption(key: 'charcoal', name: 'Gris Pizarra', emoji: '🌑', color: Color(0xFF4A4E5A)),
  ];

  static const List<WallpaperOption> wallpaperPatterns = [
    WallpaperOption(
      id: 'rustic_wood',
      name: 'Madera Rústica',
      emoji: '🪵',
      description: 'Paneles de madera de roble con zócalos cálidos.',
      textureType: 'pattern',
    ),
    WallpaperOption(
      id: 'brick_stone',
      name: 'Ladrillo Vintage',
      emoji: '🧱',
      description: 'Pared de ladrillo visto con mortero artesanal.',
      textureType: 'pattern',
    ),
    WallpaperOption(
      id: 'cozy_stripes',
      name: 'Rayas Salvia',
      emoji: '🌿',
      description: 'Rayas elegantes con moldura victoriana.',
      textureType: 'pattern',
    ),
    WallpaperOption(
      id: 'starry_night',
      name: 'Noche Estrellada',
      emoji: '✨',
      description: 'Fondo azul noche profundo con destellos dorados.',
      textureType: 'pattern',
    ),
    WallpaperOption(
      id: 'pastel_floral',
      name: 'Floral Romántico',
      emoji: '🌸',
      description: 'Papel tapiz rosa pastel con motivos florales.',
      textureType: 'pattern',
    ),
  ];

  static const List<WallpaperOption> wallpapers = [
    // Patterns
    ...wallpaperPatterns,

    // Solid Textured Colors (Paredes de color con textura de yeso y zócalo)
    WallpaperOption(
      id: 'solid_white_plaster',
      name: 'Blanco Lino',
      emoji: '🤍',
      description: 'Pared lisa blanco suave con textura de yeso.',
      color: Color(0xFFF9F9F8),
      textureType: 'plaster',
    ),
    WallpaperOption(
      id: 'solid_sage_green',
      name: 'Verde Salvia',
      emoji: '🍃',
      description: 'Pintura mate verde salvia relajante.',
      color: Color(0xFF8DA399),
      textureType: 'plaster',
    ),
    WallpaperOption(
      id: 'solid_warm_beige',
      name: 'Beige Arena',
      emoji: '🌾',
      description: 'Pared cálida tono arena tostada.',
      color: Color(0xFFE8DCCB),
      textureType: 'plaster',
    ),
    WallpaperOption(
      id: 'solid_dusty_rose',
      name: 'Rosa Pastel',
      emoji: '🩰',
      description: 'Pintura suave rosa empolvado cálido.',
      color: Color(0xFFE5B2B7),
      textureType: 'plaster',
    ),
    WallpaperOption(
      id: 'solid_navy_blue',
      name: 'Azul Índigo',
      emoji: '🌌',
      description: 'Pared azul profundo aterciopelada.',
      color: Color(0xFF2C3E50),
      textureType: 'plaster',
    ),
    WallpaperOption(
      id: 'solid_charcoal',
      name: 'Gris Pizarra',
      emoji: '🌑',
      description: 'Pintura gris grafito contemporánea.',
      color: Color(0xFF4A4E5A),
      textureType: 'plaster',
    ),
    WallpaperOption(
      id: 'solid_mustard',
      name: 'Mostaza Cálido',
      emoji: '🌻',
      description: 'Pintura ocre soleada y acogedora.',
      color: Color(0xFFE5A65D),
      textureType: 'plaster',
    ),
    WallpaperOption(
      id: 'solid_lavender',
      name: 'Lavanda Suave',
      emoji: '🪻',
      description: 'Pintura violeta pastel relajante.',
      color: Color(0xFFC3B1E1),
      textureType: 'plaster',
    ),
  ];

  static WallpaperOption getWallpaperOption(String id) {
    for (final p in wallpaperPatterns) {
      if (p.id == id) return p;
    }
    for (final w in wallpapers) {
      if (w.id == id) return w;
    }

    final isTiles = id.contains('tiles');
    final String cleanKey = id
        .replaceAll('solid_tiles_', '')
        .replaceAll('solid_plaster_', '')
        .replaceAll('solid_', '')
        .replaceAll('tiles_', '')
        .replaceAll('_tiles', '')
        .replaceAll('_plaster', '');

    WallpaperColorOption? matchedColor;
    for (final c in wallpaperColors) {
      if (c.key == cleanKey || cleanKey == c.key || cleanKey.contains(c.key)) {
        matchedColor = c;
        break;
      }
    }

    if (matchedColor != null) {
      return WallpaperOption(
        id: id,
        name: isTiles ? 'Azulejos ${matchedColor.name}' : 'Muro ${matchedColor.name}',
        emoji: isTiles ? '🔲' : '🧱',
        description: isTiles
            ? 'Pared con azulejos cerámicos en color ${matchedColor.name.toLowerCase()}.'
            : 'Pared lisa con textura de yeso en color ${matchedColor.name.toLowerCase()}.',
        color: matchedColor.color,
        textureType: isTiles ? 'tiles' : 'plaster',
      );
    }

    return wallpaperPatterns.first;
  }

  static String getWallpaperId(String colorKey, String textureType) {
    if (textureType == 'tiles') {
      return 'solid_tiles_$colorKey';
    } else {
      return 'solid_plaster_$colorKey';
    }
  }

  static String changeWallpaperTexture(String currentWallpaperId, String newTextureType) {
    if (newTextureType == 'pattern') return currentWallpaperId;
    final opt = getWallpaperOption(currentWallpaperId);
    if (opt.color == null) {
      return getWallpaperId('white', newTextureType);
    }
    final isTiles = currentWallpaperId.contains('tiles');
    if ((isTiles && newTextureType == 'tiles') || (!isTiles && newTextureType == 'plaster')) {
      return currentWallpaperId;
    }
    final String cleanKey = currentWallpaperId
        .replaceAll('solid_tiles_', '')
        .replaceAll('solid_plaster_', '')
        .replaceAll('solid_', '')
        .replaceAll('tiles_', '')
        .replaceAll('_tiles', '')
        .replaceAll('_plaster', '');

    WallpaperColorOption? matchedColor;
    for (final c in wallpaperColors) {
      if (c.key == cleanKey || cleanKey == c.key || cleanKey.contains(c.key)) {
        matchedColor = c;
        break;
      }
    }
    final key = matchedColor?.key ?? cleanKey;
    return getWallpaperId(key, newTextureType);
  }

  static const List<FloorColorOption> floorColors = [
    FloorColorOption(key: 'white', name: 'Blanco Lino', emoji: '🤍', color: Color(0xFFF5F6F8)),
    FloorColorOption(key: 'sage_green', name: 'Verde Salvia', emoji: '🍃', color: Color(0xFF8DA399)),
    FloorColorOption(key: 'mint_green', name: 'Menta Pastel', emoji: '🌿', color: Color(0xFFA8D8B9)),
    FloorColorOption(key: 'blush_pink', name: 'Rosa Cuarzo', emoji: '🌸', color: Color(0xFFEBBFC2)),
    FloorColorOption(key: 'dusty_rose', name: 'Rosa Pastel', emoji: '🩰', color: Color(0xFFE5B2B7)),
    FloorColorOption(key: 'warm_sand', name: 'Arena Cálida', emoji: '🌾', color: Color(0xFFD8C3A5)),
    FloorColorOption(key: 'slate_gray', name: 'Microcemento Gris', emoji: '🏢', color: Color(0xFF7F8C8D)),
    FloorColorOption(key: 'lavender', name: 'Lavanda Suave', emoji: '🪻', color: Color(0xFFC3B1E1)),
    FloorColorOption(key: 'mustard', name: 'Mostaza Cálido', emoji: '🌻', color: Color(0xFFE5A65D)),
    FloorColorOption(key: 'ocean_teal', name: 'Turquesa Suave', emoji: '🌊', color: Color(0xFF5C9496)),
    FloorColorOption(key: 'navy_blue', name: 'Azul Índigo', emoji: '🌌', color: Color(0xFF2C3E50)),
    FloorColorOption(key: 'dark_graphite', name: 'Grafito Mate', emoji: '🖤', color: Color(0xFF34495E)),
  ];

  static const List<FloorOption> patterns = [
    FloorOption(
      id: 'oak_parquet',
      name: 'Parquet de Roble',
      emoji: '🪵',
      description: 'Madera de roble natural pulida en espiga.',
      textureType: 'pattern',
    ),
    FloorOption(
      id: 'dark_walnut',
      name: 'Nogal Oscuro',
      emoji: '🍂',
      description: 'Tablones oscuros de nogal noble.',
      textureType: 'pattern',
    ),
    FloorOption(
      id: 'checker_marble',
      name: 'Mármol Ajedrezado',
      emoji: '🏁',
      description: 'Baldosas de mármol blanco y pizarra gris.',
      textureType: 'pattern',
    ),
    FloorOption(
      id: 'terracotta_tiles',
      name: 'Terracota Rústica',
      emoji: '🏺',
      description: 'Barro cocido mediterráneo artesanal.',
      textureType: 'pattern',
    ),
    FloorOption(
      id: 'tatami_mat',
      name: 'Tatami Japonés',
      emoji: '🎋',
      description: 'Esteras de bambú y paja natural relajante.',
      textureType: 'pattern',
    ),
  ];

  static const List<FloorOption> floors = [
    // Patterns
    ...patterns,

    // Solid Textured Colors (Suelos cerámicos de color con textura de baldosas)
    FloorOption(
      id: 'solid_white_tiles',
      name: 'Cerámica Blanca',
      emoji: '⚪',
      description: 'Baldosas lisas blancas con juntas finas.',
      color: Color(0xFFF5F6F8),
      textureType: 'tiles',
    ),
    FloorOption(
      id: 'solid_slate_gray',
      name: 'Microcemento Gris',
      emoji: '🏢',
      description: 'Suelo gris moderno estilo cemento pulido.',
      color: Color(0xFF7F8C8D),
      textureType: 'tiles',
    ),
    FloorOption(
      id: 'solid_mint_green',
      name: 'Menta Pastel',
      emoji: '🌿',
      description: 'Baldosas cerámicas verde menta suave.',
      color: Color(0xFFA8D8B9),
      textureType: 'tiles',
    ),
    FloorOption(
      id: 'solid_blush_pink',
      name: 'Rosa Cuarzo',
      emoji: '🌸',
      description: 'Baldosas lisas rosa pastel.',
      color: Color(0xFFEBBFC2),
      textureType: 'tiles',
    ),
    FloorOption(
      id: 'solid_warm_sand',
      name: 'Arena Cálida',
      emoji: '🏖️',
      description: 'Suelo continuo color arena mediterránea.',
      color: Color(0xFFD8C3A5),
      textureType: 'tiles',
    ),
    FloorOption(
      id: 'solid_dark_graphite',
      name: 'Grafito Mate',
      emoji: '🖤',
      description: 'Baldosas oscuras de pizarra moderna.',
      color: Color(0xFF34495E),
      textureType: 'tiles',
    ),
    FloorOption(
      id: 'solid_ocean_teal',
      name: 'Turquesa Suave',
      emoji: '🌊',
      description: 'Baldosas cerámicas azul verdoso.',
      color: Color(0xFF5C9496),
      textureType: 'tiles',
    ),
  ];

  static FloorOption getFloorOption(String id) {
    for (final f in patterns) {
      if (f.id == id) return f;
    }
    for (final f in floors) {
      if (f.id == id) return f;
    }

    final isCarpet = id.contains('carpet');
    final String cleanKey = id
        .replaceAll('solid_carpet_', '')
        .replaceAll('carpet_', '')
        .replaceAll('solid_tiles_', '')
        .replaceAll('solid_', '')
        .replaceAll('tiles_', '')
        .replaceAll('_tiles', '');

    FloorColorOption? matchedColor;
    for (final c in floorColors) {
      if (c.key == cleanKey || cleanKey == c.key || cleanKey.contains(c.key)) {
        matchedColor = c;
        break;
      }
    }

    if (matchedColor != null) {
      return FloorOption(
        id: id,
        name: isCarpet ? 'Alfombra ${matchedColor.name}' : 'Baldosa ${matchedColor.name}',
        emoji: isCarpet ? '🧶' : '🔲',
        description: isCarpet
            ? 'Alfombra afelpada continua color ${matchedColor.name.toLowerCase()}.'
            : 'Baldosas cerámicas en cuadrícula color ${matchedColor.name.toLowerCase()}.',
        color: matchedColor.color,
        textureType: isCarpet ? 'carpet' : 'tiles',
      );
    }

    return patterns.first;
  }

  static String getFloorId(String colorKey, String textureType) {
    if (textureType == 'carpet') {
      return 'solid_carpet_$colorKey';
    } else {
      return 'solid_tiles_$colorKey';
    }
  }

  static String changeTexture(String currentFloorId, String newTextureType) {
    if (newTextureType == 'pattern') return currentFloorId;
    final opt = getFloorOption(currentFloorId);
    if (opt.color == null) {
      return getFloorId('warm_sand', newTextureType);
    }
    final isCarpet = currentFloorId.contains('carpet');
    if ((isCarpet && newTextureType == 'carpet') || (!isCarpet && newTextureType == 'tiles')) {
      return currentFloorId;
    }
    final String cleanKey = currentFloorId
        .replaceAll('solid_carpet_', '')
        .replaceAll('carpet_', '')
        .replaceAll('solid_tiles_', '')
        .replaceAll('solid_', '')
        .replaceAll('tiles_', '')
        .replaceAll('_tiles', '');

    FloorColorOption? matchedColor;
    for (final c in floorColors) {
      if (c.key == cleanKey || cleanKey == c.key || cleanKey.contains(c.key)) {
        matchedColor = c;
        break;
      }
    }
    final key = matchedColor?.key ?? cleanKey;
    return getFloorId(key, newTextureType);
  }
}
