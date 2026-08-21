import 'dart:convert';
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

  const RoomConfig({
    this.wallpaper = 'rustic_wood',
    this.floor = 'oak_parquet',
    this.resolution = '64x128',
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
        gridX: 0,
        gridY: 4,
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
  }) {
    return RoomConfig(
      wallpaper: wallpaper ?? this.wallpaper,
      floor: floor ?? this.floor,
      resolution: resolution ?? this.resolution,
      furniture: furniture ?? this.furniture,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'wallpaper': wallpaper,
      'floor': floor,
      'resolution': resolution,
      'furniture': furniture.map((f) => f.toMap()).toList(),
    };
  }

  factory RoomConfig.fromMap(Map<String, dynamic> map) {
    return RoomConfig(
      wallpaper: map['wallpaper'] ?? 'rustic_wood',
      floor: map['floor'] ?? 'oak_parquet',
      resolution: map['resolution'] ?? '64x128',
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
                gridX: 0,
                gridY: 4,
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
  List<Object?> get props => [wallpaper, floor, resolution, furniture];
}

class WallpaperOption {
  final String id;
  final String name;
  final String emoji;
  final String description;

  const WallpaperOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
  });
}

class FloorOption {
  final String id;
  final String name;
  final String emoji;
  final String description;

  const FloorOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
  });
}

class RoomThemes {
  static const List<WallpaperOption> wallpapers = [
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
      name: 'Rayas Verde Salvia',
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
  ];

  static const List<FloorOption> floors = [
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
  ];
}
