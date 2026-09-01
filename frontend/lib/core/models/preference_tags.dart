import 'avatar_config.dart';
import 'room_config.dart';

class PreferenceItem {
  final String id;
  final String title;
  final String emoji;
  final String? subtitle;
  final String category;

  const PreferenceItem({
    required this.id,
    required this.title,
    required this.emoji,
    this.subtitle,
    required this.category,
  });
}

class PreferenceCategory {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final List<PreferenceItem> items;
  final bool isSingleSelect;

  const PreferenceCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.items,
    this.isSingleSelect = false,
  });
}

class PreferenceCatalog {
  static const List<PreferenceCategory> categories = [
    // 1. Intención de Cita (Selección única o principal)
    PreferenceCategory(
      id: 'dating_intentions',
      title: '¿Qué buscas en Cozy Dating?',
      emoji: '🎯',
      description: 'Elige tu intención para encontrar gente en la misma sintonía',
      isSingleSelect: true,
      items: [
        PreferenceItem(id: 'intent_serious', title: 'Relación seria & bonita', emoji: '💍', category: 'dating_intentions'),
        PreferenceItem(id: 'intent_slow', title: 'Conocer gente sin prisa (Slow Dating)', emoji: '🌱', category: 'dating_intentions'),
        PreferenceItem(id: 'intent_gaming_duo', title: 'Dúo gamer & nuevas amistades', emoji: '🎮', category: 'dating_intentions'),
        PreferenceItem(id: 'intent_cozy_chats', title: 'Charlas de café y buena compañía', emoji: '☕', category: 'dating_intentions'),
      ],
    ),

    // 2. Personalidad & Vibes
    PreferenceCategory(
      id: 'personality',
      title: 'Tu Energía & Batería Social',
      emoji: '🧠',
      description: 'Tu ritmo diario y forma de compartir',
      items: [
        PreferenceItem(id: 'vibe_introvert', title: 'Introvertido(a) reflexivo', emoji: '🔋', category: 'personality'),
        PreferenceItem(id: 'vibe_extrovert', title: 'Extrovertido(a) sociable', emoji: '⚡', category: 'personality'),
        PreferenceItem(id: 'vibe_ambivert', title: 'Ambivertido(a) adaptable', emoji: '⚖️', category: 'personality'),
        PreferenceItem(id: 'vibe_night_owl', title: 'Criatura nocturna', emoji: '🌙', category: 'personality'),
        PreferenceItem(id: 'vibe_early_bird', title: 'Madrugador(a) activo', emoji: '☀️', category: 'personality'),
        PreferenceItem(id: 'vibe_homebody', title: 'Modo Casa & Mantita', emoji: '🛋️', category: 'personality'),
        PreferenceItem(id: 'vibe_adventurer', title: 'Modo Mochila & Explorar', emoji: '🎒', category: 'personality'),
      ],
    ),

    // 3. Tipos de Videojuegos
    PreferenceCategory(
      id: 'gaming',
      title: 'Tus Videojuegos Favoritos',
      emoji: '🎮',
      description: '¿Qué te gusta jugar en tu tiempo libre?',
      items: [
        PreferenceItem(id: 'game_cozy', title: 'Cozy & Farming Sims', emoji: '🌾', subtitle: 'Stardew Valley, Animal Crossing', category: 'gaming'),
        PreferenceItem(id: 'game_coop', title: 'Cooperativos en Pareja', emoji: '🤝', subtitle: 'It Takes Two, Overcooked', category: 'gaming'),
        PreferenceItem(id: 'game_roguelike', title: 'Roguelikes & Acción', emoji: '⚔️', subtitle: 'Hades, Dead Cells, Spelunky', category: 'gaming'),
        PreferenceItem(id: 'game_rpg', title: 'RPGs & JRPGs de Historia', emoji: '📜', subtitle: 'Final Fantasy, Persona, Baldur’s Gate', category: 'gaming'),
        PreferenceItem(id: 'game_souls', title: 'Soulslikes & Desafíos', emoji: '🛡️', subtitle: 'Elden Ring, Hollow Knight', category: 'gaming'),
        PreferenceItem(id: 'game_tabletop', title: 'Juegos de Mesa & Rol D&D', emoji: '🎲', subtitle: 'Catan, Dungeons & Dragons', category: 'gaming'),
        PreferenceItem(id: 'game_mmo', title: 'MMORPGs & Aventuras Online', emoji: '🌐', subtitle: 'FFXIV, WoW, Guild Wars', category: 'gaming'),
        PreferenceItem(id: 'game_strategy', title: 'Estrategia & City Builders', emoji: '🏰', subtitle: 'Civilization, Cities Skylines', category: 'gaming'),
      ],
    ),

    // 4. Tecnología & Geek
    PreferenceCategory(
      id: 'tech',
      title: 'Tecnología & Espacio Geek',
      emoji: '💻',
      description: 'Herramientas, setups y aficiones digitales',
      items: [
        PreferenceItem(id: 'tech_pc_gamer', title: 'PC Gaming & Setup RGB', emoji: '🖥️', category: 'tech'),
        PreferenceItem(id: 'tech_programming', title: 'Programación & Desarrollo', emoji: '🧑‍💻', category: 'tech'),
        PreferenceItem(id: 'tech_retro', title: 'Consolas Retro & Emuladores', emoji: '🕹️', category: 'tech'),
        PreferenceItem(id: 'tech_gadgets', title: 'Gadgets & Domótica', emoji: '⚙️', category: 'tech'),
      ],
    ),

    // 5. Música & Sonido
    PreferenceCategory(
      id: 'music',
      title: 'Música & Paisajes Sonoros',
      emoji: '🎧',
      description: 'La banda sonora de tus días',
      items: [
        PreferenceItem(id: 'music_lofi', title: 'Lo-Fi & Chillhop', emoji: '☕', category: 'music'),
        PreferenceItem(id: 'music_ost', title: 'OSTs de Juegos & Anime', emoji: '🎼', category: 'music'),
        PreferenceItem(id: 'music_synthwave', title: 'Synthwave & Retro 80s', emoji: '🌆', category: 'music'),
        PreferenceItem(id: 'music_indie', title: 'Indie Rock / Indie Pop', emoji: '🎸', category: 'music'),
        PreferenceItem(id: 'music_jpop', title: 'J-Pop, K-Pop & City Pop', emoji: '🌸', category: 'music'),
        PreferenceItem(id: 'music_rock_metal', title: 'Rock Clásico & Metal', emoji: '🤘', category: 'music'),
        PreferenceItem(id: 'music_jazz', title: 'Jazz, Bossa Nova & Vinilos', emoji: '🎷', category: 'music'),
        PreferenceItem(id: 'music_instruments', title: 'Toco un Instrumento', emoji: '🎹', category: 'music'),
      ],
    ),

    // 6. Cine & Series
    PreferenceCategory(
      id: 'cinema',
      title: 'Cine, Series & Animación',
      emoji: '🎬',
      description: 'Tus géneros y estilos audiovisuales',
      items: [
        PreferenceItem(id: 'cinema_ghibli', title: 'Studio Ghibli & Animación', emoji: '🍃', category: 'cinema'),
        PreferenceItem(id: 'cinema_scifi', title: 'Sci-Fi & Cyberpunk', emoji: '🚀', category: 'cinema'),
        PreferenceItem(id: 'cinema_fantasy', title: 'Fantasía Épica (LOTR, GoT)', emoji: '🐉', category: 'cinema'),
        PreferenceItem(id: 'cinema_horror', title: 'Terror & Misterio Psicológico', emoji: '👻', category: 'cinema'),
        PreferenceItem(id: 'cinema_sitcoms', title: 'Sitcoms & Comedias Confort', emoji: '🍿', category: 'cinema'),
        PreferenceItem(id: 'cinema_cult', title: 'Cine de Culto & Clásicos', emoji: '📽️', category: 'cinema'),
      ],
    ),

    // 7. Anime & Manga
    PreferenceCategory(
      id: 'anime',
      title: 'Anime & Manga',
      emoji: '🍙',
      description: 'Tus historias favoritas',
      items: [
        PreferenceItem(id: 'anime_romance', title: 'Romance & Slice of Life', emoji: '💖', category: 'anime'),
        PreferenceItem(id: 'anime_shonen', title: 'Shonen & Aventuras Épicas', emoji: '🔥', category: 'anime'),
        PreferenceItem(id: 'anime_isekai', title: 'Isekai & Fantasía de Otro Mundo', emoji: '✨', category: 'anime'),
        PreferenceItem(id: 'anime_classics', title: 'Clásicos 90s/2000s (Evangelion, Bebop)', emoji: '📼', category: 'anime'),
        PreferenceItem(id: 'anime_seinen', title: 'Seinen & Thrillers Psicológicos', emoji: '♟️', category: 'anime'),
      ],
    ),

    // 8. Hobbies & Estilo de Vida
    PreferenceCategory(
      id: 'lifestyle',
      title: 'Pasatiempos & Estilo de Vida',
      emoji: '🌿',
      description: 'Actividades que disfrutas fuera de la pantalla',
      items: [
        PreferenceItem(id: 'life_coffee_tea', title: 'Café de Especialidad & Té', emoji: '🫖', category: 'lifestyle'),
        PreferenceItem(id: 'life_plants', title: 'Plantas & Botánica (Plant Lover)', emoji: '🪴', category: 'lifestyle'),
        PreferenceItem(id: 'life_photography', title: 'Fotografía Polaroid & Analógica', emoji: '📷', category: 'lifestyle'),
        PreferenceItem(id: 'life_travel', title: 'Viajes, Mochilazo & Trekking', emoji: '🏕️', category: 'lifestyle'),
        PreferenceItem(id: 'life_fitness', title: 'Yoga, Gym & Deporte', emoji: '🧘', category: 'lifestyle'),
        PreferenceItem(id: 'life_books', title: 'Lectura & Novelas Fantásticas', emoji: '📚', category: 'lifestyle'),
        PreferenceItem(id: 'life_art', title: 'Dibujo, Pintura & Manualidades', emoji: '🎨', category: 'lifestyle'),
        PreferenceItem(id: 'life_cooking', title: 'Cocina & Repostería Casera', emoji: '🍰', category: 'lifestyle'),
      ],
    ),

    // 9. Mascotas
    PreferenceCategory(
      id: 'pets',
      title: 'Mascotas & Animales',
      emoji: '🐾',
      description: 'Tus compañeros peludos',
      items: [
        PreferenceItem(id: 'pet_cat', title: 'Team Gatos 🐱', emoji: '🐱', category: 'pets'),
        PreferenceItem(id: 'pet_dog', title: 'Team Perros 🐶', emoji: '🐶', category: 'pets'),
        PreferenceItem(id: 'pet_all', title: 'Amante de todos los animales', emoji: '🐾', category: 'pets'),
      ],
    ),
  ];

  /// Generates a customized Starter RoomConfig based on user's theme and chosen preferences
  static RoomConfig generateStarterRoomConfig({
    required String baseTheme, // 'rustic', 'modern', 'mystic'
    required List<String> selectedTastes,
    required AvatarConfig avatarConfig,
  }) {
    String wallpaper;
    String floor;
    Map<String, String> wallOverrides = {};
    Map<String, String> floorOverrides = {};
    List<InteriorWallConfig> interiorWalls = [];

    if (baseTheme == 'modern') {
      wallpaper = 'solid_white_plaster';
      floor = 'solid_slate_gray';
      floorOverrides = {
        '0,0': 'solid_white_tiles', '1,0': 'solid_white_tiles', '2,0': 'solid_white_tiles',
        '0,1': 'solid_white_tiles', '1,1': 'solid_white_tiles', '2,1': 'solid_white_tiles',
        '0,2': 'solid_white_tiles', '1,2': 'solid_white_tiles', '2,2': 'solid_white_tiles',
        '5,0': 'solid_carpet_warm_sand', '6,0': 'solid_carpet_warm_sand', '7,0': 'solid_carpet_warm_sand',
        '5,1': 'solid_carpet_warm_sand', '6,1': 'solid_carpet_warm_sand', '7,1': 'solid_carpet_warm_sand',
        '5,2': 'solid_carpet_warm_sand', '6,2': 'solid_carpet_warm_sand', '7,2': 'solid_carpet_warm_sand',
      };
      interiorWalls = [
        const InteriorWallConfig(id: 'w_bath_e1', gridX: 3, gridY: 1, orientation: 'west', style: 'bathroom_glass', hasDoorway: true),
        const InteriorWallConfig(id: 'w_bed_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'modern_white', hasDoorway: true),
        const InteriorWallConfig(id: 'w_kitchen_e2', gridX: 3, gridY: 6, orientation: 'west', style: 'modern_white', hasDoorway: true),
      ];
    } else if (baseTheme == 'mystic') {
      wallpaper = 'starry_night';
      floor = 'solid_navy_blue';
      floorOverrides = {
        '0,0': 'solid_white_tiles', '1,0': 'solid_white_tiles', '2,0': 'solid_white_tiles',
        '0,1': 'solid_white_tiles', '1,1': 'solid_white_tiles', '2,1': 'solid_white_tiles',
        '0,2': 'solid_white_tiles', '1,2': 'solid_white_tiles', '2,2': 'solid_white_tiles',
        '5,0': 'solid_carpet_navy_blue', '6,0': 'solid_carpet_navy_blue', '7,0': 'solid_carpet_navy_blue',
        '5,1': 'solid_carpet_navy_blue', '6,1': 'solid_carpet_navy_blue', '7,1': 'solid_carpet_navy_blue',
        '5,2': 'solid_carpet_navy_blue', '6,2': 'solid_carpet_navy_blue', '7,2': 'solid_carpet_navy_blue',
      };
      interiorWalls = [
        const InteriorWallConfig(id: 'w_bath_e1', gridX: 3, gridY: 1, orientation: 'west', style: 'bathroom_glass', hasDoorway: true),
        const InteriorWallConfig(id: 'w_bed_w1', gridX: 5, gridY: 1, orientation: 'west', style: 'solid_navy_blue', hasDoorway: true),
        const InteriorWallConfig(id: 'w_kitchen_e2', gridX: 3, gridY: 6, orientation: 'west', style: 'solid_navy_blue', hasDoorway: true),
      ];
    } else {
      // Rustic Oak default
      wallpaper = 'rustic_wood';
      floor = 'oak_parquet';
      floorOverrides = Map<String, String>.from(RoomConfig.defaultFloorOverrides);
      wallOverrides = Map<String, String>.from(RoomConfig.defaultWallOverrides);
      interiorWalls = List<InteriorWallConfig>.from(RoomConfig.defaultInteriorWalls);
    }

    // Base Essential Furniture (Bed, Bath, Kitchen, Dining Table)
    List<PlacedFurnitureConfig> furnitureList = [
      // Bedroom
      const PlacedFurnitureConfig(id: 'single_bed', typeName: 'single_high_bed', gridX: 7, gridY: 0, gridWidth: 1, gridHeight: 2),
      const PlacedFurnitureConfig(id: 'side_table', typeName: 'side_table_sm', gridX: 6, gridY: 0, gridWidth: 0.5, gridHeight: 0.5),
      const PlacedFurnitureConfig(id: 'table_lamp', typeName: 'table_lamp', gridX: 6, gridY: 0, gridWidth: 1, gridHeight: 1, parentId: 'side_table'),
      const PlacedFurnitureConfig(id: 'closet', typeName: 'closet', gridX: 5, gridY: 0, gridWidth: 1, gridHeight: 1),

      // Bath
      const PlacedFurnitureConfig(id: 'bathtub', typeName: 'bathtub_classic', gridX: 0, gridY: 0, gridWidth: 1, gridHeight: 2),
      const PlacedFurnitureConfig(id: 'toilet', typeName: 'bathroom_toilet', gridX: 2, gridY: 0, gridWidth: 1, gridHeight: 1),

      // Kitchen
      const PlacedFurnitureConfig(id: 'fridge', typeName: 'kitchen_fridge_sm', gridX: 0, gridY: 4, gridWidth: 0.5, gridHeight: 0.5),
      const PlacedFurnitureConfig(id: 'stove', typeName: 'kitchen_stove', gridX: 0, gridY: 5, gridWidth: 1, gridHeight: 1, rotation: 1),
      const PlacedFurnitureConfig(id: 'sink', typeName: 'kitchen_sink', gridX: 0, gridY: 6, gridWidth: 1, gridHeight: 1, rotation: 1),

      // Living Center
      const PlacedFurnitureConfig(id: 'table', typeName: 'table', gridX: 4, gridY: 4, gridWidth: 1, gridHeight: 1),
      const PlacedFurnitureConfig(id: 'chair_1', typeName: 'simple_chair_sm', gridX: 4.25, gridY: 3.5, gridWidth: 0.5, gridHeight: 0.5, rotation: 0),
      const PlacedFurnitureConfig(id: 'chair_2', typeName: 'simple_chair_sm', gridX: 4.25, gridY: 5.0, gridWidth: 0.5, gridHeight: 0.5, rotation: 2),
      const PlacedFurnitureConfig(id: 'armchair', typeName: 'plush_armchair', gridX: 6, gridY: 4.5, gridWidth: 1, gridHeight: 1, rotation: 1),
    ];

    // INJECT THEMED STARTER FURNITURE ACCORDING TO SELECTED TASTES
    final tastes = Set<String>.from(selectedTastes);

    // 1. Tech / PC Gamer
    if (tastes.contains('tech_pc_gamer') || tastes.contains('tech_programming')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_pc_desk',
        typeName: 'gaming_pc_desk',
        gridX: 4,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
      ));
    } else if (tastes.contains('cinema_ghibli') || tastes.contains('cinema_scifi') || tastes.contains('cinema_cult')) {
      // 2. Cine & Series
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_tv',
        typeName: 'home_theater_tv',
        gridX: 4,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
      ));
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_poster_cinema',
        typeName: 'wall_poster_cinema',
        gridX: 3,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
        wallHeightLevel: 'high',
      ));
    } else {
      // Default tall bookshelf
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'tall_bookshelf',
        typeName: 'tall_bookshelf',
        gridX: 4,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
      ));
    }

    // 3. Anime & Manga
    if (tastes.contains('anime_romance') || tastes.contains('anime_shonen') || tastes.contains('anime_classics') || tastes.contains('anime_isekai')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_manga',
        typeName: 'manga_shelf',
        gridX: 3,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
      ));
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_poster_anime',
        typeName: 'wall_poster_anime',
        gridX: 2,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
        wallHeightLevel: 'high',
      ));
    }

    // 4. Music & Audio
    if (tastes.contains('music_jazz') || tastes.contains('music_lofi') || tastes.contains('music_synthwave') || tastes.contains('music_ost')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_vinyl',
        typeName: 'vinyl_record_player',
        gridX: 4,
        gridY: 4,
        gridWidth: 1,
        gridHeight: 1,
        parentId: 'table',
      ));
    } else if (tastes.contains('music_instruments') || tastes.contains('music_indie') || tastes.contains('music_rock_metal')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_guitar',
        typeName: 'acoustic_guitar_stand',
        gridX: 7,
        gridY: 3,
        gridWidth: 0.5,
        gridHeight: 0.5,
      ));
    }

    // 5. Café / Té
    if (tastes.contains('life_coffee_tea') || tastes.contains('intent_cozy_chats')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_espresso',
        typeName: 'espresso_machine',
        gridX: 1,
        gridY: 4,
        gridWidth: 1,
        gridHeight: 1,
      ));
    }

    // 6. Mascotas
    if (tastes.contains('pet_cat')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_cat_tree',
        typeName: 'cat_tree_tower',
        gridX: 7,
        gridY: 6,
        gridWidth: 1,
        gridHeight: 1,
      ));
    } else if (tastes.contains('pet_dog')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_dog_bed',
        typeName: 'pet_dog_bed',
        gridX: 7,
        gridY: 6,
        gridWidth: 1,
        gridHeight: 1,
      ));
    }

    // 7. Plant Lover
    if (tastes.contains('life_plants')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_monstera',
        typeName: 'monstera_plant_pot',
        gridX: 7,
        gridY: 5,
        gridWidth: 0.5,
        gridHeight: 0.5,
      ));
    }

    // 8. Boardgames / D&D
    if (tastes.contains('game_tabletop')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_dnd_box',
        typeName: 'boardgame_box_set',
        gridX: 4,
        gridY: 4,
        gridWidth: 1,
        gridHeight: 1,
        parentId: 'table',
      ));
    }

    // 9. Travel & Photography
    if (tastes.contains('life_photography') || tastes.contains('life_travel')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_polaroid',
        typeName: 'polaroid_camera_table',
        gridX: 6,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
        parentId: 'side_table',
      ));
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_map',
        typeName: 'wall_world_map',
        gridX: 1,
        gridY: 0,
        gridWidth: 1,
        gridHeight: 1,
        wallHeightLevel: 'high',
      ));
    }

    // 10. Fitness & Yoga
    if (tastes.contains('life_fitness')) {
      furnitureList.add(const PlacedFurnitureConfig(
        id: 'starter_yoga',
        typeName: 'yoga_mat_floor',
        gridX: 5,
        gridY: 6,
        gridWidth: 1,
        gridHeight: 1,
      ));
    }

    return RoomConfig(
      wallpaper: wallpaper,
      floor: floor,
      floorOverrides: floorOverrides,
      wallOverrides: wallOverrides,
      interiorWalls: interiorWalls,
      furniture: furnitureList,
    );
  }
}
