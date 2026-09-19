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
  final bool isRequired;

  const PreferenceCategory({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    required this.items,
    this.isSingleSelect = false,
    this.isRequired = false,
  });
}

class PreferenceCatalog {
  static PreferenceItem? findById(String id) {
    for (final category in categories) {
      for (final item in category.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  static const List<PreferenceCategory> categories = [
    // =========================================================================
    // 🌟 LOS 4 EJES OBLIGATORIOS (Selección Única - Universales)
    // =========================================================================

    // 1. Intención de Cita
    PreferenceCategory(
      id: 'dating_intentions',
      title: '¿Qué buscas en Cozy Dating?',
      emoji: '🎯',
      description: 'Define tu intención para conectar en la misma sintonía',
      isSingleSelect: true,
      isRequired: true,
      items: [
        PreferenceItem(id: 'intent_serious', title: 'Relación seria & bonita', emoji: '💍', category: 'dating_intentions'),
        PreferenceItem(id: 'intent_slow', title: 'Conocer sin prisa (Slow Dating)', emoji: '🌱', category: 'dating_intentions'),
        PreferenceItem(id: 'intent_gaming_duo', title: 'Dúo gamer & complicidad', emoji: '🎮', category: 'dating_intentions'),
        PreferenceItem(id: 'intent_cozy_chats', title: 'Charlas de café y amistad', emoji: '☕', category: 'dating_intentions'),
      ],
    ),

    // 2. Batería Social
    PreferenceCategory(
      id: 'social_battery',
      title: 'Tu Batería Social',
      emoji: '🧠',
      description: '¿Cómo recargas tu energía al compartir con otros?',
      isSingleSelect: true,
      isRequired: true,
      items: [
        PreferenceItem(id: 'vibe_introvert', title: 'Introvertido(a) reflexivo', emoji: '🔋', category: 'social_battery'),
        PreferenceItem(id: 'vibe_extrovert', title: 'Extrovertido(a) sociable', emoji: '⚡', category: 'social_battery'),
        PreferenceItem(id: 'vibe_ambivert', title: 'Ambivertido(a) adaptable', emoji: '⚖️', category: 'social_battery'),
      ],
    ),

    // 3. Ritmo de Vida / Cronotipo
    PreferenceCategory(
      id: 'life_rhythm',
      title: 'Tu Ritmo Diario',
      emoji: '⏰',
      description: '¿En qué momento del día funciona mejor tu mundo?',
      isSingleSelect: true,
      isRequired: true,
      items: [
        PreferenceItem(id: 'vibe_night_owl', title: 'Criatura nocturna (Búho)', emoji: '🌙', category: 'life_rhythm'),
        PreferenceItem(id: 'vibe_early_bird', title: 'Madrugador(a) activo (Alondra)', emoji: '☀️', category: 'life_rhythm'),
        PreferenceItem(id: 'vibe_flexible_rhythm', title: 'Ritmo flexible / Tarde activa (Colibrí)', emoji: '☕', category: 'life_rhythm'),
        PreferenceItem(id: 'vibe_chaotic_rhythm', title: 'Caótico / Según el día y humor', emoji: '🎲', category: 'life_rhythm'),
      ],
    ),

    // 4. Fin de Semana Ideal
    PreferenceCategory(
      id: 'weekend_vibe',
      title: 'Tu Fin de Semana Ideal',
      emoji: '🛋️',
      description: 'Tu plan perfecto para desconectar',
      isSingleSelect: true,
      isRequired: true,
      items: [
        PreferenceItem(id: 'vibe_homebody', title: 'Modo Casa & Mantita (Chill)', emoji: '🛋️', category: 'weekend_vibe'),
        PreferenceItem(id: 'vibe_adventurer', title: 'Modo Mochila & Salir (Naturaleza)', emoji: '🎒', category: 'weekend_vibe'),
        PreferenceItem(id: 'vibe_urban_walks', title: 'Modo Cafeterías, Museos & Ciudad', emoji: '🏛️', category: 'weekend_vibe'),
        PreferenceItem(id: 'vibe_balanced_weekend', title: 'Equilibrio 50/50 (Un día afuera, un día chill)', emoji: '⚖️', category: 'weekend_vibe'),
      ],
    ),

    // =========================================================================
    // ⚔️ DILEMAS DE UN SOLO BANDO (Selección Única - Elige tu Favorito)
    // =========================================================================

    // 5. Ecosistema Gamer Principal
    PreferenceCategory(
      id: 'gaming_platform',
      title: 'Tu Ecosistema Gamer',
      emoji: '🕹️',
      description: '¿Cuál es tu templo de juego principal?',
      isSingleSelect: true,
      items: [
        PreferenceItem(id: 'plat_pc', title: 'PC Master Race / Steam Deck', emoji: '🖥️', category: 'gaming_platform'),
        PreferenceItem(id: 'plat_playstation', title: 'PlayStation', emoji: '🟦', category: 'gaming_platform'),
        PreferenceItem(id: 'plat_xbox', title: 'Xbox & Game Pass', emoji: '🟩', category: 'gaming_platform'),
        PreferenceItem(id: 'plat_nintendo', title: 'Nintendo Switch', emoji: '🍄', category: 'gaming_platform'),
        PreferenceItem(id: 'plat_mobile', title: 'Mobile Gamer', emoji: '📱', category: 'gaming_platform'),
      ],
    ),

    // 6. Combustible Diario
    PreferenceCategory(
      id: 'daily_fuel',
      title: 'Tu Combustible Diario',
      emoji: '☕',
      description: 'La bebida que activa tus días y tardes',
      isSingleSelect: true,
      items: [
        PreferenceItem(id: 'fuel_coffee', title: 'Café de especialidad / Espresso', emoji: '☕', category: 'daily_fuel'),
        PreferenceItem(id: 'fuel_tea', title: 'Té caliente / Matcha / Infusión', emoji: '🍵', category: 'daily_fuel'),
        PreferenceItem(id: 'fuel_energy', title: 'Bebidas Energéticas (Monster/RedBull)', emoji: '⚡', category: 'daily_fuel'),
        PreferenceItem(id: 'fuel_mate', title: 'Mate tradicional o tereré', emoji: '🧉', category: 'daily_fuel'),
        PreferenceItem(id: 'fuel_water', title: 'Solo Agua pura bien fresca', emoji: '💧', category: 'daily_fuel'),
      ],
    ),

    // 7. Mascotas & Convivencia
    PreferenceCategory(
      id: 'pets_dilemma',
      title: 'Mascotas & Convivencia',
      emoji: '🐾',
      description: '¿Quién manda en tu corazón animal?',
      isSingleSelect: true,
      items: [
        PreferenceItem(id: 'pet_cat', title: 'Team Gatos (Misterio y ronroneo)', emoji: '🐱', category: 'pets_dilemma'),
        PreferenceItem(id: 'pet_dog', title: 'Team Perros (Alegría incondicional)', emoji: '🐶', category: 'pets_dilemma'),
        PreferenceItem(id: 'pet_exotic', title: 'Team Mascotas No Tradicionales (Conejos, erizos, hurones, otros)', emoji: '🐰', category: 'pets_dilemma'),
        PreferenceItem(id: 'pet_all', title: 'Amo a todos los animales por igual', emoji: '🐾', category: 'pets_dilemma'),
        PreferenceItem(id: 'pet_plants', title: 'Prefiero plantas / Sin mascotas', emoji: '🪴', category: 'pets_dilemma'),
      ],
    ),

    // 8. Vacaciones Soñadas
    PreferenceCategory(
      id: 'dream_vacation',
      title: 'Tu Escapada Soñada',
      emoji: '✈️',
      description: '¿Hacia qué paisaje apunta tu brújula?',
      isSingleSelect: true,
      items: [
        PreferenceItem(id: 'vacation_cabin', title: 'Cabaña en bosque / Montaña fría', emoji: '🌲', category: 'dream_vacation'),
        PreferenceItem(id: 'vacation_beach', title: 'Playa cálida, mar y atardeceres', emoji: '🏖️', category: 'dream_vacation'),
        PreferenceItem(id: 'vacation_city', title: 'Metrópolis, museos & cafés urbanos', emoji: '🏙️', category: 'dream_vacation'),
        PreferenceItem(id: 'vacation_home', title: 'Vacaciones en casa jugando y descansando', emoji: '🏡', category: 'dream_vacation'),
      ],
    ),

    // =========================================================================
    // 🎨 GUSTOS LIBRES & PASIONES (Multi-Selección)
    // =========================================================================

    // 9. Géneros de Videojuegos
    PreferenceCategory(
      id: 'gaming',
      title: 'Tus Géneros de Juegos Favoritos',
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

    // 10. Música
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

    // 11. Cine & Series
    PreferenceCategory(
      id: 'cinema',
      title: 'Cine, Series & Animación',
      emoji: '🎬',
      description: 'Tus estilos audiovisuales favoritos',
      items: [
        PreferenceItem(id: 'cinema_ghibli', title: 'Studio Ghibli & Animación', emoji: '🍃', category: 'cinema'),
        PreferenceItem(id: 'cinema_scifi', title: 'Sci-Fi & Cyberpunk', emoji: '🚀', category: 'cinema'),
        PreferenceItem(id: 'cinema_fantasy', title: 'Fantasía Épica (LOTR, GoT)', emoji: '🐉', category: 'cinema'),
        PreferenceItem(id: 'cinema_horror', title: 'Terror & Misterio Psicológico', emoji: '👻', category: 'cinema'),
        PreferenceItem(id: 'cinema_sitcoms', title: 'Sitcoms & Comedias Confort', emoji: '🍿', category: 'cinema'),
        PreferenceItem(id: 'cinema_cult', title: 'Cine de Culto & Clásicos', emoji: '📽️', category: 'cinema'),
      ],
    ),

    // 12. Anime & Manga
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

    // 13. Hobbies & Estilo de Vida
    PreferenceCategory(
      id: 'lifestyle',
      title: 'Pasatiempos & Estilo de Vida',
      emoji: '🌿',
      description: 'Actividades que disfrutas fuera de la pantalla',
      items: [
        PreferenceItem(id: 'life_coffee_tea', title: 'Cafeterías & Probar Comida', emoji: '🥐', category: 'lifestyle'),
        PreferenceItem(id: 'life_plants', title: 'Plantas & Botánica (Plant Lover)', emoji: '🪴', category: 'lifestyle'),
        PreferenceItem(id: 'life_photography', title: 'Fotografía Polaroid & Analógica', emoji: '📷', category: 'lifestyle'),
        PreferenceItem(id: 'life_travel', title: 'Viajes, Mochilazo & Trekking', emoji: '🏕️', category: 'lifestyle'),
        PreferenceItem(id: 'life_fitness', title: 'Yoga, Gym & Deporte', emoji: '🧘', category: 'lifestyle'),
        PreferenceItem(id: 'life_books', title: 'Lectura & Novelas Fantásticas', emoji: '📚', category: 'lifestyle'),
        PreferenceItem(id: 'life_art', title: 'Dibujo, Pintura & Manualidades', emoji: '🎨', category: 'lifestyle'),
        PreferenceItem(id: 'life_cooking', title: 'Cocina & Repostería Casera', emoji: '🍰', category: 'lifestyle'),
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

  static PreferenceItem? getItem(String id) {
    for (final cat in categories) {
      for (final item in cat.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  static String formatTaste(String id) {
    final item = getItem(id);
    if (item != null) {
      return '${item.emoji} ${item.title}';
    }
    // Fallback format
    final clean = id.replaceAll(RegExp(r'^(game_|cinema_|music_|food_|pet_|life_|tech_|vibe_|intent_|plat_|fuel_|vacation_)'), '');
    return '✨ ${clean.replaceAll('_', ' ')}';
  }
}
