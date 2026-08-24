import 'package:equatable/equatable.dart';

enum FurniturePlacementType {
  floor,
  surface,
  wallNorth,
  wallWest,
}

class FurnitureRotationMeta extends Equatable {
  final String id;
  final String name;
  final String footprint;
  final int rot;
  final List<int> canvasSize;
  final List<int> spriteOffset;
  final int surfaceHeight;
  final bool supportsSurface;
  final List<int> surfaceOffset;

  const FurnitureRotationMeta({
    required this.id,
    required this.name,
    required this.footprint,
    required this.rot,
    required this.canvasSize,
    required this.spriteOffset,
    this.surfaceHeight = 0,
    this.supportsSurface = false,
    this.surfaceOffset = const [0, 0],
  });

  factory FurnitureRotationMeta.fromJson(Map<String, dynamic> json) {
    final sH = (json['surface_height'] as num?)?.toInt() ?? 0;
    final supSurf = (json['supports_surface'] as bool?) ?? (sH > 0);
    return FurnitureRotationMeta(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      footprint: json['footprint'] as String? ?? '1x1',
      rot: (json['rot'] as num?)?.toInt() ?? 0,
      canvasSize: (json['canvas_size'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [64, 64],
      spriteOffset: (json['sprite_offset'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [-32, -48],
      surfaceHeight: sH,
      supportsSurface: supSurf,
      surfaceOffset: (json['surface_offset'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'footprint': footprint,
      'rot': rot,
      'canvas_size': canvasSize,
      'sprite_offset': spriteOffset,
      'surface_height': surfaceHeight,
      'supports_surface': supportsSurface,
      'surface_offset': surfaceOffset,
    };
  }

  @override
  List<Object?> get props => [id, name, footprint, rot, canvasSize, spriteOffset, surfaceHeight, supportsSurface, surfaceOffset];
}

class FurnitureCatalogItem extends Equatable {
  final String id;
  final String name;
  final String zone; // 'living', 'bedroom', 'kitchen', 'bathroom', 'patio', 'decor', 'guide'
  final String footprint; // '1x1', '1x2', '2x1', '2x2', 'surface', 'wall_n', 'wall_w'
  final int surfaceHeight;
  final bool supportsSurface;
  final List<int> surfaceOffset;
  final List<int> canvasSize;
  final List<int> spriteOffset;
  final Map<int, FurnitureRotationMeta> rotations;

  const FurnitureCatalogItem({
    required this.id,
    required this.name,
    required this.zone,
    required this.footprint,
    this.surfaceHeight = 0,
    this.supportsSurface = false,
    this.surfaceOffset = const [0, 0],
    this.canvasSize = const [64, 64],
    this.spriteOffset = const [-32, -48],
    this.rotations = const {},
  });

  FurniturePlacementType get placementType {
    if (footprint == 'surface' || id == 'table_lamp' || id == 'coffee_mug' || id == 'open_book' || id == 'soap_bottles' || id == 'cooking_pot' || id == 'cutting_board' || id == 'plush_teddy') {
      return FurniturePlacementType.surface;
    }
    if (footprint == 'wall_w' || id.endsWith('_wall_w') || id.endsWith('_w')) {
      return FurniturePlacementType.wallWest;
    }
    if (footprint == 'wall_n' || footprint == 'wall' || id.endsWith('_wall_n') || id.endsWith('_n') || id.contains('wall') || id == 'window_yellow' || id == 'art_painting' || id == 'wall_clock') {
      return FurniturePlacementType.wallNorth;
    }
    return FurniturePlacementType.floor;
  }

  bool get isSurfaceItem => placementType == FurniturePlacementType.surface;
  bool get isWallNorth => placementType == FurniturePlacementType.wallNorth;
  bool get isWallWest => placementType == FurniturePlacementType.wallWest;
  bool get isWallItem => isWallNorth || isWallWest;
  bool get isSurfaceSupporting {
    if (supportsSurface) return true;
    if (surfaceHeight > 0) return true;
    if (id.startsWith('cube_') && !id.contains('wall')) return true;
    return id.contains('table') ||
        id.contains('counter') ||
        id.contains('stove') ||
        id.contains('sink') ||
        id.contains('bed') ||
        id.contains('nightstand') ||
        id.contains('drawer') ||
        id.contains('vanity');
  }

  int get effectiveSurfaceHeight {
    if (surfaceHeight > 0) return surfaceHeight;
    if (rotations.isNotEmpty) {
      final r0 = rotations[0];
      if (r0 != null && r0.surfaceHeight > 0) return r0.surfaceHeight;
    }
    if (id.startsWith('cube_')) {
      if (id == 'cube_1x1') return 24;
      if (id == 'cube_1x2' || id == 'cube_2x1') return 20;
      if (id == 'cube_2x2') return 28;
      return 20;
    }
    switch (id) {
      case 'dining_table_2x2': return 22;
      case 'table': return 18;
      case 'side_table': return 18;
      case 'kitchen_counter': return 20;
      case 'kitchen_stove': return 22;
      case 'kitchen_sink': return 20;
      case 'nightstand_drawer': return 16;
      case 'vanity_table': return 18;
      case 'single_bed': return 14;
      case 'king_bed': return 16;
      default: return 0;
    }
  }

  double get gridWidth {
    if (footprint == '0.5x0.5') return 0.5;
    if (footprint == '2x1' || footprint == '2x2') return 2.0;
    return 1.0;
  }

  double get gridHeight {
    if (footprint == '0.5x0.5') return 0.5;
    if (footprint == '1x2' || footprint == '2x2') return 2.0;
    return 1.0;
  }

  static String getWallVariantFor(String rawId, bool isNorth) {
    String baseId = rawId;
    if (baseId.endsWith('_wall_w')) {
      baseId = '${baseId.substring(0, baseId.length - 7)}_wall';
    } else if (baseId.endsWith('_wall_n')) {
      baseId = '${baseId.substring(0, baseId.length - 7)}_wall';
    } else if (baseId.endsWith('_w')) {
      baseId = baseId.substring(0, baseId.length - 2);
    } else if (baseId.endsWith('_n')) {
      baseId = baseId.substring(0, baseId.length - 2);
    }

    return isNorth ? '${baseId}_n' : '${baseId}_w';
  }

  factory FurnitureCatalogItem.fromJson(String id, Map<String, dynamic> json) {
    final name = json['name'] as String? ?? id;
    final zone = json['zone'] as String? ?? 'decor';
    final footprint = json['footprint'] as String? ?? '1x1';
    final surfaceH = (json['surface_height'] as num?)?.toInt() ?? 0;
    final supSurf = (json['supports_surface'] as bool?) ?? (surfaceH > 0);
    final surfOff = (json['surface_offset'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0];
    final canvasS = (json['canvas_size'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [64, 64];
    final spriteOff = (json['sprite_offset'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [-32, -48];

    final rots = <int, FurnitureRotationMeta>{};
    if (json['rotations'] != null && json['rotations'] is Map) {
      final rotMap = json['rotations'] as Map<String, dynamic>;
      rotMap.forEach((k, v) {
        final rotIdx = int.tryParse(k) ?? 0;
        final meta = FurnitureRotationMeta.fromJson(v as Map<String, dynamic>);
        final effMetaSurfaceH = (surfaceH > 0) ? surfaceH : meta.surfaceHeight;
        final effMetaSupports = meta.supportsSurface || supSurf;
        final effMetaSurfaceOff = (meta.surfaceOffset != const [0, 0]) ? meta.surfaceOffset : surfOff;
        rots[rotIdx] = FurnitureRotationMeta(
          id: meta.id,
          name: meta.name,
          footprint: meta.footprint,
          rot: meta.rot,
          canvasSize: meta.canvasSize,
          spriteOffset: meta.spriteOffset,
          surfaceHeight: effMetaSurfaceH,
          supportsSurface: effMetaSupports,
          surfaceOffset: effMetaSurfaceOff,
        );
      });
    }

    return FurnitureCatalogItem(
      id: id,
      name: name,
      zone: zone,
      footprint: footprint,
      surfaceHeight: surfaceH,
      supportsSurface: supSurf,
      surfaceOffset: surfOff,
      canvasSize: canvasS,
      spriteOffset: spriteOff,
      rotations: rots,
    );
  }

  @override
  List<Object?> get props => [id, name, zone, footprint, surfaceHeight, supportsSurface, surfaceOffset, canvasSize, spriteOffset, rotations];
}

class PlacedFurniture extends Equatable {
  final String id;
  final double gx;
  final double gy;
  final int rot; // 0, 1, 2, 3
  final String? parentId; // ID of the supporting surface furniture (e.g. side_table)
  final String wallHeightLevel; // 'mid' or 'high'
  final double nudgeX;
  final double nudgeY;

  const PlacedFurniture({
    required this.id,
    required this.gx,
    required this.gy,
    this.rot = 0,
    this.parentId,
    this.wallHeightLevel = 'mid',
    this.nudgeX = 0.0,
    this.nudgeY = 0.0,
  });

  PlacedFurniture copyWith({
    String? id,
    double? gx,
    double? gy,
    int? rot,
    String? parentId,
    bool clearParent = false,
    String? wallHeightLevel,
    double? nudgeX,
    double? nudgeY,
  }) {
    return PlacedFurniture(
      id: id ?? this.id,
      gx: gx ?? this.gx,
      gy: gy ?? this.gy,
      rot: rot ?? this.rot,
      parentId: clearParent ? null : (parentId ?? this.parentId),
      wallHeightLevel: wallHeightLevel ?? this.wallHeightLevel,
      nudgeX: nudgeX ?? this.nudgeX,
      nudgeY: nudgeY ?? this.nudgeY,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gx': gx,
      'gy': gy,
      'rot': rot,
      if (parentId != null) 'parent_id': parentId,
      if (wallHeightLevel != 'mid') 'wall_height_level': wallHeightLevel,
      if (nudgeX != 0.0) 'nudge_x': nudgeX,
      if (nudgeY != 0.0) 'nudge_y': nudgeY,
    };
  }

  factory PlacedFurniture.fromJson(Map<String, dynamic> json) {
    return PlacedFurniture(
      id: json['id'] as String? ?? 'side_table',
      gx: (json['gx'] as num?)?.toDouble() ?? 0.0,
      gy: (json['gy'] as num?)?.toDouble() ?? 0.0,
      rot: json['rot'] as int? ?? 0,
      parentId: json['parent_id'] as String?,
      wallHeightLevel: json['wall_height_level'] as String? ?? 'mid',
      nudgeX: (json['nudge_x'] as num?)?.toDouble() ?? 0.0,
      nudgeY: (json['nudge_y'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  List<Object?> get props => [id, gx, gy, rot, parentId, wallHeightLevel, nudgeX, nudgeY];
}
