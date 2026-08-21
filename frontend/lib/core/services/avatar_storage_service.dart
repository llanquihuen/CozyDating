import 'dart:ui';
import '../models/avatar_config.dart';
import '../models/room_config.dart';

class AvatarStorageService {
  static String _activeUserId = 'alice';

  // In-memory multi-user profiles with rich distinctive looks based on CreateSprites
  static final Map<String, AvatarConfig> _userConfigs = {
    'alice': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFFCD5B5),
      eyeStyle: 'stardew_cute',
      eyeColor: Color(0xFF059669), // Emerald Green
      eyebrowStyle: 'normal',
      eyebrowColor: Color(0xFFC85A2A),
      noseStyle: 'subtle',
      mouthStyle: 'smile',
      faceDetail: 'blush',
      faceDetailColor: Color(0xFFFF7777),
      hairStyle: 'farm_braids',
      hairColor: Color(0xFFC85A2A), // Ginger/Auburn
      topStyle: 'flannel_shirt',
      topColor: Color(0xFFDC2626), // Ruby Red
      bottomStyle: 'farmer_overalls',
      bottomColor: Color(0xFF2563EB), // Denim Blue
      shoeStyle: 'farmer_boots',
      shoeColor: Color(0xFF78350F), // Leather Brown
      accessoryStyle: 'straw_hat',
      accessoryColor: Color(0xFFEAB308), // Gold/Straw
    ),
    'bob': const AvatarConfig(
      faceShape: 'round',
      skinColor: Color(0xFFFFDFD3),
      eyeStyle: 'sleepy_calm',
      eyeColor: Color(0xFF2563EB), // Sapphire Blue
      eyebrowStyle: 'normal',
      eyebrowColor: Color(0xFFD97706),
      noseStyle: 'button',
      mouthStyle: 'neutral',
      faceDetail: 'freckles',
      faceDetailColor: Color(0xFFA56635),
      hairStyle: 'long_flowing',
      hairColor: Color(0xFFD97706), // Wheat Blonde
      topStyle: 'hoodie',
      topColor: Color(0xFF0284C7), // Sky Blue
      bottomStyle: 'adventurer_pants',
      bottomColor: Color(0xFF1E293B), // Navy Slate
      shoeStyle: 'sneakers',
      shoeColor: Color(0xFFF8FAFC),
      accessoryStyle: 'neck_bandana',
      accessoryColor: Color(0xFFDC2626),
    ),
    'charlie': const AvatarConfig(
      faceShape: 'sharp_v',
      skinColor: Color(0xFFE8AB7A),
      eyeStyle: 'jrpg_classic',
      eyeColor: Color(0xFF7C3AED), // Mystic Purple
      eyebrowStyle: 'serious',
      eyebrowColor: Color(0xFF1E293B),
      noseStyle: 'pointed',
      mouthStyle: 'smirk',
      faceDetail: 'scar',
      faceDetailColor: Color(0xFF8B0000),
      hairStyle: 'adventurer_spiky',
      hairColor: Color(0xFF1E293B), // Midnight Black
      topStyle: 'traveler_tunic',
      topColor: Color(0xFF059669), // Emerald
      bottomStyle: 'adventurer_pants',
      bottomColor: Color(0xFF78350F), // Leather
      shoeStyle: 'adventurer_boots',
      shoeColor: Color(0xFF451A03),
      accessoryStyle: 'scholar_glasses',
      accessoryColor: Color(0xFFEAB308),
    ),
    'david': const AvatarConfig(
      faceShape: 'square_jaw',
      skinColor: Color(0xFFD4915C),
      eyeStyle: 'adventurer_serious',
      eyeColor: Color(0xFF78350F), // Amber Brown
      eyebrowStyle: 'thick',
      eyebrowColor: Color(0xFF451A03),
      noseStyle: 'subtle',
      mouthStyle: 'open_smile',
      faceDetail: 'none',
      faceDetailColor: Color(0xFFFF7777),
      hairStyle: 'messy_wanderer',
      hairColor: Color(0xFF451A03), // Dark Brown
      topStyle: 'adventurer_coat',
      topColor: Color(0xFF16A34A), // Forest Green
      bottomStyle: 'shorts',
      bottomColor: Color(0xFF64748B),
      shoeStyle: 'farmer_boots',
      shoeColor: Color(0xFF451A03),
      accessoryStyle: 'traveler_hood',
      accessoryColor: Color(0xFF16A34A),
    ),
    'userA': const AvatarConfig(
      faceShape: 'oval',
      skinColor: Color(0xFFFCD5B5),
      eyeStyle: 'stardew_cute',
      hairStyle: 'farm_braids',
      topStyle: 'flannel_shirt',
      topColor: Color(0xFFDC2626),
    ),
    'userB': const AvatarConfig(
      faceShape: 'round',
      skinColor: Color(0xFFFFDFD3),
      eyeStyle: 'sleepy_calm',
      hairStyle: 'long_flowing',
      topStyle: 'hoodie',
      topColor: Color(0xFF0284C7),
    ),
    'userC': const AvatarConfig(
      faceShape: 'sharp_v',
      skinColor: Color(0xFFE8AB7A),
      eyeStyle: 'jrpg_classic',
      hairStyle: 'adventurer_spiky',
      topStyle: 'traveler_tunic',
      topColor: Color(0xFF059669),
    ),
    'userD': const AvatarConfig(
      faceShape: 'square_jaw',
      skinColor: Color(0xFFD4915C),
      eyeStyle: 'adventurer_serious',
      hairStyle: 'messy_wanderer',
      topStyle: 'adventurer_coat',
      topColor: Color(0xFF16A34A),
    ),
  };

  // In-memory multi-user room wallpaper and floor configurations.
  // Each dummy room ships with a fully enclosed 3x3 bedroom in the northeast corner
  // (gridX 5-7, gridY 0-2) — the north side is free (it's the room's own perimeter
  // wall), so it only needs a west wall (gx=5, gy=0..2, with a door at gy=1 to walk in)
  // and a south wall (gy=3, gx=5..7) to close it off. The default `single_bed` furniture
  // position (see room_config.dart) sits at gridX=7, gridY=0 — the far corner from the
  // door. Styled to match that user's wallpaper/floor theme.
  static final Map<String, RoomConfig> _userRoomConfigs = {
    'alice': const RoomConfig(
      wallpaper: 'solid_white_plaster',
      floor: 'solid_blush_pink',
      interiorWalls: [
        InteriorWallConfig(id: 'alice_bedroom_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bedroom_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'solid_white_plaster', hasDoorway: true),
        InteriorWallConfig(id: 'alice_bedroom_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bedroom_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bedroom_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'solid_white_plaster'),
        InteriorWallConfig(id: 'alice_bedroom_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'solid_white_plaster'),
      ],
    ),
    'bob': const RoomConfig(
      wallpaper: 'cozy_stripes',
      floor: 'dark_walnut',
      interiorWalls: [
        InteriorWallConfig(id: 'bob_bedroom_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bedroom_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'wood_slats', hasDoorway: true),
        InteriorWallConfig(id: 'bob_bedroom_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bedroom_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bedroom_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'wood_slats'),
        InteriorWallConfig(id: 'bob_bedroom_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'wood_slats'),
      ],
    ),
    'charlie': const RoomConfig(
      wallpaper: 'brick_stone',
      floor: 'terracotta_tiles',
      interiorWalls: [
        InteriorWallConfig(id: 'charlie_bedroom_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bedroom_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'rustic_brick', hasDoorway: true),
        InteriorWallConfig(id: 'charlie_bedroom_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bedroom_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bedroom_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'rustic_brick'),
        InteriorWallConfig(id: 'charlie_bedroom_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'rustic_brick'),
      ],
    ),
    'david': const RoomConfig(
      wallpaper: 'starry_night',
      floor: 'checker_marble',
      interiorWalls: [
        InteriorWallConfig(id: 'david_bedroom_w0', gridX: 5, gridY: 0, orientation: 'west', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bedroom_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'solid_navy_blue', hasDoorway: true),
        InteriorWallConfig(id: 'david_bedroom_w2', gridX: 5, gridY: 2, orientation: 'west', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bedroom_s0', gridX: 5, gridY: 3, orientation: 'north', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bedroom_s1', gridX: 6, gridY: 3, orientation: 'north', style: 'solid_navy_blue'),
        InteriorWallConfig(id: 'david_bedroom_s2', gridX: 7, gridY: 3, orientation: 'north', style: 'solid_navy_blue'),
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
    return _userConfigs[userId] ?? const AvatarConfig();
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
    return _userRoomConfigs[userId] ?? const RoomConfig();
  }

  static void saveUserRoomConfig(String userId, RoomConfig config) {
    _userRoomConfigs[userId] = config;
  }

  static void saveRoomConfig(RoomConfig config) {
    saveUserRoomConfig(_activeUserId, config);
  }
}
