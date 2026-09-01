import 'dart:ui';
import '../models/avatar_config.dart';
import '../models/room_config.dart';

class AvatarStorageService {
  static String _activeUserId = 'alice';

  // In-memory multi-user profiles using OCTOPLAYER assets
  static final Map<String, AvatarConfig> _userConfigs = {
    'alice': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFFCD5B5),
      eyeStyle: 'cateyes',
      eyeColor: Color(0xFF059669), // Emerald Green
      eyebrowStyle: 'none',
      eyebrowColor: Color(0xFFC85A2A),
      noseStyle: 'standard',
      mouthStyle: 'catmouth',
      faceDetail: 'none',
      faceDetailColor: Color(0xFFFF7777),
      hairStyle: 'long_flow',
      hairColor: Color(0xFFC85A2A), // Ginger/Auburn
      topStyle: 'jacket',
      topColor: Color(0xFFDC2626), // Ruby Red
      bottomStyle: 'jeans',
      bottomColor: Color(0xFF2563EB), // Denim Blue
      shoeStyle: 'none',
      shoeColor: Color(0xFF78350F),
      accessoryStyle: 'none',
      accessoryColor: Color(0xFFEAB308),
    ),
    'bob': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFFFDFD3),
      eyeStyle: 'relax',
      eyeColor: Color(0xFF2563EB), // Sapphire Blue
      eyebrowStyle: 'none',
      eyebrowColor: Color(0xFFD97706),
      noseStyle: 'small',
      mouthStyle: 'smile',
      faceDetail: 'none',
      faceDetailColor: Color(0xFFA56635),
      hairStyle: 'long_flow',
      hairColor: Color(0xFFD97706), // Wheat Blonde
      topStyle: 'jacket',
      topColor: Color(0xFF0284C7), // Sky Blue
      bottomStyle: 'jeans',
      bottomColor: Color(0xFF1E293B), // Navy Slate
      shoeStyle: 'none',
      shoeColor: Color(0xFFF8FAFC),
      accessoryStyle: 'none',
      accessoryColor: Color(0xFFDC2626),
    ),
    'charlie': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFE8AB7A),
      eyeStyle: 'cateyes',
      eyeColor: Color(0xFF7C3AED), // Mystic Purple
      eyebrowStyle: 'none',
      eyebrowColor: Color(0xFF1E293B),
      noseStyle: 'standard',
      mouthStyle: 'smirk',
      faceDetail: 'none',
      faceDetailColor: Color(0xFF8B0000),
      hairStyle: 'long_flow',
      hairColor: Color(0xFF1E293B), // Midnight Black
      topStyle: 'jacket',
      topColor: Color(0xFF059669), // Emerald
      bottomStyle: 'jeans',
      bottomColor: Color(0xFF78350F), // Leather
      shoeStyle: 'none',
      shoeColor: Color(0xFF451A03),
      accessoryStyle: 'none',
      accessoryColor: Color(0xFFEAB308),
    ),
    'david': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFD4915C),
      eyeStyle: 'relax',
      eyeColor: Color(0xFF78350F), // Amber Brown
      eyebrowStyle: 'none',
      eyebrowColor: Color(0xFF451A03),
      noseStyle: 'small',
      mouthStyle: 'smile',
      faceDetail: 'none',
      faceDetailColor: Color(0xFFFF7777),
      hairStyle: 'long_flow',
      hairColor: Color(0xFF451A03), // Dark Brown
      topStyle: 'jacket',
      topColor: Color(0xFF16A34A), // Forest Green
      bottomStyle: 'jeans',
      bottomColor: Color(0xFF64748B),
      shoeStyle: 'none',
      shoeColor: Color(0xFF451A03),
      accessoryStyle: 'none',
      accessoryColor: Color(0xFF16A34A),
    ),
    'userA': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFFCD5B5),
      eyeStyle: 'cateyes',
      hairStyle: 'long_flow',
      topStyle: 'jacket',
      topColor: Color(0xFFDC2626),
      bottomStyle: 'jeans',
    ),
    'userB': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFFFDFD3),
      eyeStyle: 'relax',
      hairStyle: 'long_flow',
      topStyle: 'jacket',
      topColor: Color(0xFF0284C7),
      bottomStyle: 'jeans',
    ),
    'userC': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFE8AB7A),
      eyeStyle: 'cateyes',
      hairStyle: 'long_flow',
      topStyle: 'jacket',
      topColor: Color(0xFF059669),
      bottomStyle: 'jeans',
    ),
    'userD': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFD4915C),
      eyeStyle: 'relax',
      hairStyle: 'long_flow',
      topStyle: 'jacket',
      topColor: Color(0xFF16A34A),
      bottomStyle: 'jeans',
    ),
  };

  // In-memory multi-user room wallpaper, floor and room structure configurations.
  // Each default room ships with:
  // - Cuarto de Baño (NW corner: gridX 0..2, gridY 0..2) with glass walls, tub, toilet, towel rack
  // - Dormitorio (NE corner: gridX 5..7, gridY 0..2) with bed, closet, side table, lamp
  // - Cocina (SW corner: gridX 0..2, gridY 4..6) with fridge, stove, sink, counter, pan rack
  // - Salón central abierto con mesa, sillas, estantería y portal.
  static final Map<String, RoomConfig> _userRoomConfigs = {
    'alice': const RoomConfig(
      wallpaper: 'solid_white_plaster',
      floor: 'solid_blush_pink',
      floorOverrides: {
        '0,0': 'solid_white_tiles', '1,0': 'solid_white_tiles', '2,0': 'solid_white_tiles',
        '0,1': 'solid_white_tiles', '1,1': 'solid_white_tiles', '2,1': 'solid_white_tiles',
        '0,2': 'solid_white_tiles', '1,2': 'solid_white_tiles', '2,2': 'solid_white_tiles',
        '5,0': 'solid_carpet_blush_pink', '6,0': 'solid_carpet_blush_pink', '7,0': 'solid_carpet_blush_pink',
        '5,1': 'solid_carpet_blush_pink', '6,1': 'solid_carpet_blush_pink', '7,1': 'solid_carpet_blush_pink',
        '5,2': 'solid_carpet_blush_pink', '6,2': 'solid_carpet_blush_pink', '7,2': 'solid_carpet_blush_pink',
        '0,4': 'solid_white_tiles', '1,4': 'solid_white_tiles', '2,4': 'solid_white_tiles',
        '0,5': 'solid_white_tiles', '1,5': 'solid_white_tiles', '2,5': 'solid_white_tiles',
        '0,6': 'solid_white_tiles', '1,6': 'solid_white_tiles', '2,6': 'solid_white_tiles',
      },
      wallOverrides: {
        'n,0': 'solid_tiles_white', 'n,1': 'solid_tiles_white', 'n,2': 'solid_tiles_white',
        'w,0': 'solid_tiles_white', 'w,1': 'solid_tiles_white', 'w,2': 'solid_tiles_white',
      },
      interiorWalls: [
        // Baño (NW)
        InteriorWallConfig(id: 'alice_bath_e0', gridX: 3, gridY: 0, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'alice_bath_e1', gridX: 3, gridY: 1, orientation: 'west', style: 'bathroom_glass', hasDoorway: true),
        InteriorWallConfig(id: 'alice_bath_e2', gridX: 3, gridY: 2, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'alice_bath_s0', gridX: 0, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'alice_bath_s1', gridX: 1, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'alice_bath_s2', gridX: 2, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        // Dormitorio (NE)
        InteriorWallConfig(id: 'alice_bed_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bed_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'solid_white_plaster', hasDoorway: true),
        InteriorWallConfig(id: 'alice_bed_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bed_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bed_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bed_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'solid_white_plaster'),
        // Cocina (SW)
        InteriorWallConfig(id: 'alice_kitchen_n0', gridX: 0, gridY: 4, orientation: 'north', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_kitchen_n1', gridX: 1, gridY: 4, orientation: 'north', style: 'solid_white_plaster', hasDoorway: true),
        InteriorWallConfig(id: 'alice_kitchen_n2', gridX: 2, gridY: 4, orientation: 'north', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_kitchen_e0', gridX: 3, gridY: 4, orientation: 'west', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_kitchen_e1', gridX: 3, gridY: 5, orientation: 'west', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_kitchen_e2', gridX: 3, gridY: 6, orientation: 'west', style: 'solid_white_plaster', hasDoorway: true),
      ],
    ),
    'bob': const RoomConfig(
      wallpaper: 'cozy_stripes',
      floor: 'dark_walnut',
      floorOverrides: {
        '0,0': 'solid_white_tiles', '1,0': 'solid_white_tiles', '2,0': 'solid_white_tiles',
        '0,1': 'solid_white_tiles', '1,1': 'solid_white_tiles', '2,1': 'solid_white_tiles',
        '0,2': 'solid_white_tiles', '1,2': 'solid_white_tiles', '2,2': 'solid_white_tiles',
        '5,0': 'solid_carpet_warm_sand', '6,0': 'solid_carpet_warm_sand', '7,0': 'solid_carpet_warm_sand',
        '5,1': 'solid_carpet_warm_sand', '6,1': 'solid_carpet_warm_sand', '7,1': 'solid_carpet_warm_sand',
        '5,2': 'solid_carpet_warm_sand', '6,2': 'solid_carpet_warm_sand', '7,2': 'solid_carpet_warm_sand',
        '0,4': 'solid_slate_gray', '1,4': 'solid_slate_gray', '2,4': 'solid_slate_gray',
        '0,5': 'solid_slate_gray', '1,5': 'solid_slate_gray', '2,5': 'solid_slate_gray',
        '0,6': 'solid_slate_gray', '1,6': 'solid_slate_gray', '2,6': 'solid_slate_gray',
      },
      wallOverrides: {
        'n,0': 'solid_tiles_white', 'n,1': 'solid_tiles_white', 'n,2': 'solid_tiles_white',
        'w,0': 'solid_tiles_white', 'w,1': 'solid_tiles_white', 'w,2': 'solid_tiles_white',
      },
      interiorWalls: [
        // Baño (NW)
        InteriorWallConfig(id: 'bob_bath_e0', gridX: 3, gridY: 0, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'bob_bath_e1', gridX: 3, gridY: 1, orientation: 'west', style: 'bathroom_glass', hasDoorway: true),
        InteriorWallConfig(id: 'bob_bath_e2', gridX: 3, gridY: 2, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'bob_bath_s0', gridX: 0, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'bob_bath_s1', gridX: 1, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'bob_bath_s2', gridX: 2, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        // Dormitorio (NE)
        InteriorWallConfig(id: 'bob_bed_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bed_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'wood_slats', hasDoorway: true),
        InteriorWallConfig(id: 'bob_bed_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bed_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bed_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bed_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'wood_slats'),
        // Cocina (SW)
        InteriorWallConfig(id: 'bob_kitchen_n0', gridX: 0, gridY: 4, orientation: 'north', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_kitchen_n1', gridX: 1, gridY: 4, orientation: 'north', style: 'wood_slats', hasDoorway: true),
        InteriorWallConfig(id: 'bob_kitchen_n2', gridX: 2, gridY: 4, orientation: 'north', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_kitchen_e0', gridX: 3, gridY: 4, orientation: 'west', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_kitchen_e1', gridX: 3, gridY: 5, orientation: 'west', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_kitchen_e2', gridX: 3, gridY: 6, orientation: 'west', style: 'wood_slats', hasDoorway: true),
      ],
    ),
    'charlie': const RoomConfig(
      wallpaper: 'brick_stone',
      floor: 'terracotta_tiles',
      floorOverrides: {
        '0,0': 'solid_white_tiles', '1,0': 'solid_white_tiles', '2,0': 'solid_white_tiles',
        '0,1': 'solid_white_tiles', '1,1': 'solid_white_tiles', '2,1': 'solid_white_tiles',
        '0,2': 'solid_white_tiles', '1,2': 'solid_white_tiles', '2,2': 'solid_white_tiles',
        '5,0': 'solid_carpet_warm_sand', '6,0': 'solid_carpet_warm_sand', '7,0': 'solid_carpet_warm_sand',
        '5,1': 'solid_carpet_warm_sand', '6,1': 'solid_carpet_warm_sand', '7,1': 'solid_carpet_warm_sand',
        '5,2': 'solid_carpet_warm_sand', '6,2': 'solid_carpet_warm_sand', '7,2': 'solid_carpet_warm_sand',
        '0,4': 'terracotta_tiles', '1,4': 'terracotta_tiles', '2,4': 'terracotta_tiles',
        '0,5': 'terracotta_tiles', '1,5': 'terracotta_tiles', '2,5': 'terracotta_tiles',
        '0,6': 'terracotta_tiles', '1,6': 'terracotta_tiles', '2,6': 'terracotta_tiles',
      },
      wallOverrides: {
        'n,0': 'solid_tiles_white', 'n,1': 'solid_tiles_white', 'n,2': 'solid_tiles_white',
        'w,0': 'solid_tiles_white', 'w,1': 'solid_tiles_white', 'w,2': 'solid_tiles_white',
      },
      interiorWalls: [
        // Baño (NW)
        InteriorWallConfig(id: 'charlie_bath_e0', gridX: 3, gridY: 0, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'charlie_bath_e1', gridX: 3, gridY: 1, orientation: 'west', style: 'bathroom_glass', hasDoorway: true),
        InteriorWallConfig(id: 'charlie_bath_e2', gridX: 3, gridY: 2, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'charlie_bath_s0', gridX: 0, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'charlie_bath_s1', gridX: 1, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'charlie_bath_s2', gridX: 2, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        // Dormitorio (NE)
        InteriorWallConfig(id: 'charlie_bed_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bed_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'rustic_brick', hasDoorway: true),
        InteriorWallConfig(id: 'charlie_bed_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bed_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bed_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bed_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'rustic_brick'),
        // Cocina (SW)
        InteriorWallConfig(id: 'charlie_kitchen_n0', gridX: 0, gridY: 4, orientation: 'north', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_kitchen_n1', gridX: 1, gridY: 4, orientation: 'north', style: 'rustic_brick', hasDoorway: true),
        InteriorWallConfig(id: 'charlie_kitchen_n2', gridX: 2, gridY: 4, orientation: 'north', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_kitchen_e0', gridX: 3, gridY: 4, orientation: 'west', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_kitchen_e1', gridX: 3, gridY: 5, orientation: 'west', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_kitchen_e2', gridX: 3, gridY: 6, orientation: 'west', style: 'rustic_brick', hasDoorway: true),
      ],
    ),
    'david': const RoomConfig(
      wallpaper: 'starry_night',
      floor: 'checker_marble',
      floorOverrides: {
        '0,0': 'solid_white_tiles', '1,0': 'solid_white_tiles', '2,0': 'solid_white_tiles',
        '0,1': 'solid_white_tiles', '1,1': 'solid_white_tiles', '2,1': 'solid_white_tiles',
        '0,2': 'solid_white_tiles', '1,2': 'solid_white_tiles', '2,2': 'solid_white_tiles',
        '5,0': 'solid_carpet_navy_blue', '6,0': 'solid_carpet_navy_blue', '7,0': 'solid_carpet_navy_blue',
        '5,1': 'solid_carpet_navy_blue', '6,1': 'solid_carpet_navy_blue', '7,1': 'solid_carpet_navy_blue',
        '5,2': 'solid_carpet_navy_blue', '6,2': 'solid_carpet_navy_blue', '7,2': 'solid_carpet_navy_blue',
        '0,4': 'solid_dark_graphite', '1,4': 'solid_dark_graphite', '2,4': 'solid_dark_graphite',
        '0,5': 'solid_dark_graphite', '1,5': 'solid_dark_graphite', '2,5': 'solid_dark_graphite',
        '0,6': 'solid_dark_graphite', '1,6': 'solid_dark_graphite', '2,6': 'solid_dark_graphite',
      },
      wallOverrides: {
        'n,0': 'solid_tiles_white', 'n,1': 'solid_tiles_white', 'n,2': 'solid_tiles_white',
        'w,0': 'solid_tiles_white', 'w,1': 'solid_tiles_white', 'w,2': 'solid_tiles_white',
      },
      interiorWalls: [
        // Baño (NW)
        InteriorWallConfig(id: 'david_bath_e0', gridX: 3, gridY: 0, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'david_bath_e1', gridX: 3, gridY: 1, orientation: 'west', style: 'bathroom_glass', hasDoorway: true),
        InteriorWallConfig(id: 'david_bath_e2', gridX: 3, gridY: 2, orientation: 'west', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'david_bath_s0', gridX: 0, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'david_bath_s1', gridX: 1, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        InteriorWallConfig(id: 'david_bath_s2', gridX: 2, gridY: 3, orientation: 'north', style: 'bathroom_glass'),
        // Dormitorio (NE)
        InteriorWallConfig(id: 'david_bed_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bed_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'solid_navy_blue', hasDoorway: true),
        InteriorWallConfig(id: 'david_bed_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bed_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bed_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bed_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'solid_navy_blue'),
        // Cocina (SW)
        InteriorWallConfig(id: 'david_kitchen_n0', gridX: 0, gridY: 4, orientation: 'north', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_kitchen_n1', gridX: 1, gridY: 4, orientation: 'north', style: 'solid_navy_blue', hasDoorway: true),
        InteriorWallConfig(id: 'david_kitchen_n2', gridX: 2, gridY: 4, orientation: 'north', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_kitchen_e0', gridX: 3, gridY: 4, orientation: 'west', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_kitchen_e1', gridX: 3, gridY: 5, orientation: 'west', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_kitchen_e2', gridX: 3, gridY: 6, orientation: 'west', style: 'solid_navy_blue', hasDoorway: true),
      ],
    ),
  };

  static String get activeUserId => _activeUserId;

  static void setActiveUser(String userId) {
    _activeUserId = userId;
  }

  // --- Avatar Config Methods ---
  static AvatarConfig get currentConfig => getUserConfig(_activeUserId);

  static AvatarConfig getUserConfig(String userId) {
    if (_userConfigs.containsKey(userId)) {
      return _userConfigs[userId]!;
    }
    if (userId.isEmpty) {
      return _userConfigs['bob'] ?? const AvatarConfig();
    }
    // Si no existe, mapear determinísticamente a uno de los perfiles para variedad visual
    const fallbackKeys = ['bob', 'charlie', 'david', 'alice'];
    final index = userId.hashCode.abs() % fallbackKeys.length;
    return _userConfigs[fallbackKeys[index]] ?? const AvatarConfig();
  }

  static void saveUserConfig(String userId, AvatarConfig config) {
    _userConfigs[userId] = config;
  }

  static void saveConfig(AvatarConfig config) {
    saveUserConfig(_activeUserId, config);
  }

  static AvatarConfig loadConfig() {
    return currentConfig;
  }

  // --- Room Config Methods ---
  static RoomConfig get currentRoomConfig => getUserRoomConfig(_activeUserId);

  static RoomConfig getUserRoomConfig(String userId) {
    if (_userRoomConfigs.containsKey(userId)) {
      return _userRoomConfigs[userId]!;
    }
    if (userId.isEmpty) {
      return _userRoomConfigs['bob'] ?? const RoomConfig();
    }
    const fallbackKeys = ['bob', 'charlie', 'david', 'alice'];
    final index = userId.hashCode.abs() % fallbackKeys.length;
    return _userRoomConfigs[fallbackKeys[index]] ?? const RoomConfig();
  }

  static void saveUserRoomConfig(String userId, RoomConfig config) {
    _userRoomConfigs[userId] = config;
  }

  static void saveRoomConfig(RoomConfig config) {
    saveUserRoomConfig(_activeUserId, config);
  }
}
