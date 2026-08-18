import 'dart:ui';
import 'package:equatable/equatable.dart';

class AvatarConfig extends Equatable {
  final String spriteResolution; // '64x128' (Detailed) or '32x64' (Pixel Chibi)
  final String faceShape;
  final Color skinColor;
  final String eyeStyle;
  final Color eyeColor;
  final String eyebrowStyle;
  final Color eyebrowColor;
  final String noseStyle;
  final String mouthStyle;
  final String faceDetail;
  final Color faceDetailColor;
  final String hairStyle;
  final Color hairColor;
  final String topStyle;
  final Color topColor;
  final String bottomStyle;
  final Color bottomColor;
  final String shoeStyle;
  final Color shoeColor;
  final String accessoryStyle;
  final Color accessoryColor;

  const AvatarConfig({
    this.spriteResolution = '64x128',
    this.faceShape = 'oval',
    this.skinColor = const Color(0xFFFCD5B5),
    this.eyeStyle = 'jrpg_classic',
    this.eyeColor = const Color(0xFF059669),
    this.eyebrowStyle = 'normal',
    this.eyebrowColor = const Color(0xFFC85A2A),
    this.noseStyle = 'subtle',
    this.mouthStyle = 'smile',
    this.faceDetail = 'none',
    this.faceDetailColor = const Color(0xFFFF7777),
    this.hairStyle = 'farm_braids',
    this.hairColor = const Color(0xFFC85A2A),
    this.topStyle = 'flannel_shirt',
    this.topColor = const Color(0xFFDC2626),
    this.bottomStyle = 'farmer_overalls',
    this.bottomColor = const Color(0xFF2563EB),
    this.shoeStyle = 'farmer_boots',
    this.shoeColor = const Color(0xFF78350F),
    this.accessoryStyle = 'none',
    this.accessoryColor = const Color(0xFFEAB308),
  });

  // Retro Palettes (SNES / 16-Bit style)
  static const List<Color> skinTones = [
    Color(0xFFFFDFD3), // Pálido Nórdico
    Color(0xFFFCD5B5), // Melocotón Claro
    Color(0xFFF5C49F), // Beige Cálido
    Color(0xFFE8AB7A), // Bronceado Suave
    Color(0xFFD4915C), // Caramelo / Canela
    Color(0xFFA56635), // Moreno Cálido
    Color(0xFF7A4522), // Ébano Profundo
    Color(0xFF532B13), // Chocolate Oscuro
  ];

  static const List<Color> eyeColors = [
    Color(0xFF059669), // Esmeralda JRPG
    Color(0xFF2563EB), // Azul Zafiro
    Color(0xFF0284C7), // Celeste Cielo
    Color(0xFF7C3AED), // Violeta Místico
    Color(0xFF9333EA), // Amatista Profundo
    Color(0xFF78350F), // Ámbar / Miel
    Color(0xFF451A03), // Marrón Avellana
    Color(0xFFDC2626), // Rubí Carmesí
    Color(0xFF334155), // Gris Acero
    Color(0xFF0F172A), // Negro Obsidiana
    Color(0xFF0D9488), // Turquesa
    Color(0xFFE11D48), // Rosa Anime
  ];

  static const List<Color> hairColors = [
    Color(0xFF1E293B), // Negro Noche
    Color(0xFF451A03), // Castaño Oscuro
    Color(0xFF78350F), // Castaño Chocolate
    Color(0xFFC85A2A), // Pelirrojo / Cobrizo
    Color(0xFFD97706), // Rubio Trigo
    Color(0xFFFDE047), // Rubio Dorado
    Color(0xFF94A3B8), // Plateado / Canoso
    Color(0xFFE2E8F0), // Blanco Puro
    Color(0xFFDC2626), // Carmesí Intenso
    Color(0xFFDB2777), // Rosa Chicle
    Color(0xFF7C3AED), // Púrpura Fantasía
    Color(0xFF0284C7), // Azul Cielo
    Color(0xFF059669), // Verde Menta
    Color(0xFF0D9488), // Verde Esmeralda
  ];

  static const List<Color> clothingColors = [
    Color(0xFFDC2626), // Rojo Rubí
    Color(0xFFEA580C), // Naranja Fuego
    Color(0xFFEAB308), // Amarillo Mostaza
    Color(0xFF16A34A), // Verde Pradera
    Color(0xFF059669), // Verde Esmeralda
    Color(0xFF0D9488), // Verde Azulado
    Color(0xFF0284C7), // Azul Cielo
    Color(0xFF2563EB), // Azul Cobalto
    Color(0xFF4F46E5), // Azul Índigo
    Color(0xFF7C3AED), // Púrpura Real
    Color(0xFFDB2777), // Rosa Vibrante
    Color(0xFF78350F), // Cuero Rústico
    Color(0xFF64748B), // Gris Pizarra
    Color(0xFF1E293B), // Azul Marino Oscuro
    Color(0xFF0F172A), // Negro Noche
    Color(0xFFF8FAFC), // Blanco Marfil
  ];

  static const List<String> availableResolutions = [
    '64x128',
    '32x64',
  ];

  static const List<String> availableFaceShapes = [
    'oval',
    'round',
    'sharp_v',
    'square_jaw',
    'heart',
  ];

  static const List<String> availableEyeStyles = [
    'shoujo_sparkle',
    'stardew_cute',
    'jrpg_classic',
    'adventurer_serious',
    'sleepy_calm',
    'cateye_sly',
    'mystic_glow',
    'happy_closed',
    'dot_chibi',
    'wink',
  ];

  static const List<String> availableEyebrowStyles = [
    'normal',
    'thick',
    'serious',
    'arched',
  ];

  static const List<String> availableNoseStyles = [
    'subtle',
    'pointed',
    'button',
  ];

  static const List<String> availableMouthStyles = [
    'smile',
    'neutral',
    'open_smile',
    'smirk',
    'lipstick',
  ];

  static const List<String> availableFaceDetails = [
    'none',
    'blush',
    'freckles',
    'scar',
  ];

  static const List<String> availableHairStyles = [
    'farm_braids',
    'adventurer_spiky',
    'long_flowing',
    'bob_bangs',
    'curly_locks',
    'high_ponytail',
    'twintails',
    'messy_wanderer',
    'none',
  ];

  static const List<String> availableTopStyles = [
    'flannel_shirt',
    'overalls_bib',
    'traveler_tunic',
    'adventurer_coat',
    'tshirt',
    'hoodie',
    'crop_top',
    'bikini',
    'none',
  ];

  static const List<String> availableBottomStyles = [
    'farmer_overalls',
    'adventurer_pants',
    'rustic_skirt',
    'skirt_pleated',
    'shorts',
    'underwear',
    'bikini',
    'none',
  ];

  static const List<String> availableShoeStyles = [
    'farmer_boots',
    'adventurer_boots',
    'sneakers',
    'sandals',
    'none',
  ];

  static const List<String> availableAccessoryStyles = [
    'straw_hat',
    'traveler_hood',
    'hair_flower',
    'scholar_glasses',
    'neck_bandana',
    'satchel_bag',
    'headphones',
    'sunglasses_cool',
    'none',
  ];

  static String formatName(String id) {
    switch (id) {
      // Resolutions
      case '64x128': return '64x128 (Detallado)';
      case '32x64': return '32x64 (Pixel Chibi)';

      // Face Shapes
      case 'oval': return 'Ovalada Clásica';
      case 'round': return 'Redonda Tierna';
      case 'sharp_v': return 'Afilada en V';
      case 'square_jaw': return 'Mandíbula Firme';
      case 'heart': return 'Forma de Corazón';

      // Eyes
      case 'shoujo_sparkle': return 'Shoujo Brillante ✨';
      case 'stardew_cute': return 'Stardew Cute 🌾';
      case 'jrpg_classic': return 'JRPG Clásico ⚔️';
      case 'adventurer_serious': return 'Aventurero Decidido 🛡️';
      case 'sleepy_calm': return 'Calmado / Serena 🍃';
      case 'cateye_sly': return 'Pícaro Kitsune 😸';
      case 'mystic_glow': return 'Místico Hechicero 🔮';
      case 'happy_closed': return 'Feliz Cerrado 😊';
      case 'dot_chibi': return 'Dot Chibi ⚫';
      case 'wink': return 'Guiño Pícaro 😉';

      // Brows
      case 'normal': return 'Normales';
      case 'thick': return 'Gruesas';
      case 'serious': return 'Serias';
      case 'arched': return 'Arqueadas';

      // Nose
      case 'subtle': return 'Sutil (1-Pixel)';
      case 'pointed': return 'Perfilada';
      case 'button': return 'Botón Redonda';

      // Mouth
      case 'smile': return 'Sonrisa Dulce';
      case 'neutral': return 'Neutra';
      case 'open_smile': return 'Sonrisa Alegre';
      case 'smirk': return 'Sonrisa Pícara';
      case 'lipstick': return 'Labial Elegante';

      // Face Details
      case 'none': return 'Ninguno';
      case 'blush': return 'Rubor Suave';
      case 'freckles': return 'Pecas Campestres';
      case 'scar': return 'Cicatriz de Batalla';

      // Hair
      case 'farm_braids': return 'Trenzas Leah';
      case 'adventurer_spiky': return 'Corto Puntiagudo';
      case 'long_flowing': return 'Melena Larga';
      case 'bob_bangs': return 'Corte Bob';
      case 'curly_locks': return 'Rizos Campestres';
      case 'high_ponytail': return 'Coleta Alta';
      case 'twintails': return 'Coletas Dobles';
      case 'messy_wanderer': return 'Trotamundos';

      // Tops
      case 'flannel_shirt': return 'Camisa Franela';
      case 'overalls_bib': return 'Peto Overalls';
      case 'traveler_tunic': return 'Túnica de Viajero';
      case 'adventurer_coat': return 'Abrigo Aventurero';
      case 'tshirt': return 'Polera Algodón';
      case 'hoodie': return 'Sudadera / Hoodie';
      case 'crop_top': return 'Crop Top';
      case 'bikini': return 'Bikini Top';

      // Bottoms
      case 'farmer_overalls': return 'Overalls Granjero';
      case 'adventurer_pants': return 'Pantalón Cuero';
      case 'rustic_skirt': return 'Falda Rústica';
      case 'skirt_pleated': return 'Falda Plisada';
      case 'shorts': return 'Shorts Explorador';
      case 'underwear': return 'Ropa Interior';

      // Shoes
      case 'farmer_boots': return 'Botas de Trabajo';
      case 'adventurer_boots': return 'Botas de Cuero';
      case 'sneakers': return 'Zapatillas Urbanas';
      case 'sandals': return 'Sandalias';

      // Accessories
      case 'straw_hat': return 'Sombrero de Paja';
      case 'traveler_hood': return 'Capucha Viajero';
      case 'hair_flower': return 'Flor Silvestre';
      case 'scholar_glasses': return 'Gafas de Erudito';
      case 'neck_bandana': return 'Bandana / Pañuelo';
      case 'satchel_bag': return 'Bolso Cruzado';
      case 'headphones': return 'Audífonos';
      case 'sunglasses_cool': return 'Gafas de Sol';

      // Fallbacks for legacy ids
      case 'short': return 'Corto';
      case 'long': return 'Largo';
      case 'curly': return 'Rizado';
      case 'cap': return 'Gorra';
      case 'jacket': return 'Chaqueta';
      case 'shirt': return 'Camisa';
      case 'cargo': return 'Cargo';
      case 'jeans': return 'Jeans';
      case 'goggles': return 'Gafas';
      case 'scarf': return 'Bufanda';

      default:
        return id.replaceAll('_', ' ');
    }
  }

  AvatarConfig copyWith({
    String? spriteResolution,
    String? faceShape,
    Color? skinColor,
    String? eyeStyle,
    Color? eyeColor,
    String? eyebrowStyle,
    Color? eyebrowColor,
    String? noseStyle,
    String? mouthStyle,
    String? faceDetail,
    Color? faceDetailColor,
    String? hairStyle,
    Color? hairColor,
    String? topStyle,
    Color? topColor,
    String? bottomStyle,
    Color? bottomColor,
    String? shoeStyle,
    Color? shoeColor,
    String? accessoryStyle,
    Color? accessoryColor,
  }) {
    return AvatarConfig(
      spriteResolution: spriteResolution ?? this.spriteResolution,
      faceShape: faceShape ?? this.faceShape,
      skinColor: skinColor ?? this.skinColor,
      eyeStyle: eyeStyle ?? this.eyeStyle,
      eyeColor: eyeColor ?? this.eyeColor,
      eyebrowStyle: eyebrowStyle ?? this.eyebrowStyle,
      eyebrowColor: eyebrowColor ?? this.eyebrowColor,
      noseStyle: noseStyle ?? this.noseStyle,
      mouthStyle: mouthStyle ?? this.mouthStyle,
      faceDetail: faceDetail ?? this.faceDetail,
      faceDetailColor: faceDetailColor ?? this.faceDetailColor,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      topStyle: topStyle ?? this.topStyle,
      topColor: topColor ?? this.topColor,
      bottomStyle: bottomStyle ?? this.bottomStyle,
      bottomColor: bottomColor ?? this.bottomColor,
      shoeStyle: shoeStyle ?? this.shoeStyle,
      shoeColor: shoeColor ?? this.shoeColor,
      accessoryStyle: accessoryStyle ?? this.accessoryStyle,
      accessoryColor: accessoryColor ?? this.accessoryColor,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'spriteResolution': spriteResolution,
      'faceShape': faceShape,
      'skinColor': skinColor.value,
      'eyeStyle': eyeStyle,
      'eyeColor': eyeColor.value,
      'eyebrowStyle': eyebrowStyle,
      'eyebrowColor': eyebrowColor.value,
      'noseStyle': noseStyle,
      'mouthStyle': mouthStyle,
      'faceDetail': faceDetail,
      'faceDetailColor': faceDetailColor.value,
      'hairStyle': hairStyle,
      'hairColor': hairColor.value,
      'topStyle': topStyle,
      'topColor': topColor.value,
      'bottomStyle': bottomStyle,
      'bottomColor': bottomColor.value,
      'shoeStyle': shoeStyle,
      'shoeColor': shoeColor.value,
      'accessoryStyle': accessoryStyle,
      'accessoryColor': accessoryColor.value,
    };
  }

  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    String mapHair(String? h) {
      if (h == 'short') return 'adventurer_spiky';
      if (h == 'long') return 'long_flowing';
      if (h == 'curly') return 'curly_locks';
      if (h == 'cap') return 'bob_bangs';
      return h ?? 'farm_braids';
    }

    String mapTop(String? t) {
      if (t == 'jacket') return 'adventurer_coat';
      if (t == 'shirt') return 'flannel_shirt';
      if (t == 'hoodie') return 'hoodie';
      return t ?? 'flannel_shirt';
    }

    String mapBottom(String? b) {
      if (b == 'cargo') return 'adventurer_pants';
      if (b == 'jeans') return 'farmer_overalls';
      return b ?? 'farmer_overalls';
    }

    String mapAcc(String? a) {
      if (a == 'goggles') return 'scholar_glasses';
      if (a == 'scarf') return 'neck_bandana';
      return a ?? 'none';
    }

    return AvatarConfig(
      spriteResolution: json['spriteResolution'] as String? ?? '64x128',
      faceShape: json['faceShape'] as String? ?? 'oval',
      skinColor: json['skinColor'] != null ? Color(json['skinColor'] as int) : const Color(0xFFFCD5B5),
      eyeStyle: json['eyeStyle'] as String? ?? 'jrpg_classic',
      eyeColor: json['eyeColor'] != null ? Color(json['eyeColor'] as int) : const Color(0xFF059669),
      eyebrowStyle: json['eyebrowStyle'] as String? ?? 'normal',
      eyebrowColor: json['eyebrowColor'] != null ? Color(json['eyebrowColor'] as int) : const Color(0xFFC85A2A),
      noseStyle: json['noseStyle'] as String? ?? 'subtle',
      mouthStyle: json['mouthStyle'] as String? ?? 'smile',
      faceDetail: json['faceDetail'] as String? ?? 'none',
      faceDetailColor: json['faceDetailColor'] != null ? Color(json['faceDetailColor'] as int) : const Color(0xFFFF7777),
      hairStyle: mapHair(json['hairStyle'] as String?),
      hairColor: json['hairColor'] != null ? Color(json['hairColor'] as int) : const Color(0xFFC85A2A),
      topStyle: mapTop(json['topStyle'] as String?),
      topColor: json['topColor'] != null ? Color(json['topColor'] as int) : const Color(0xFFDC2626),
      bottomStyle: mapBottom(json['bottomStyle'] as String?),
      bottomColor: json['bottomColor'] != null ? Color(json['bottomColor'] as int) : const Color(0xFF2563EB),
      shoeStyle: json['shoeStyle'] as String? ?? 'farmer_boots',
      shoeColor: json['shoeColor'] != null ? Color(json['shoeColor'] as int) : const Color(0xFF78350F),
      accessoryStyle: mapAcc(json['accessoryStyle'] as String?),
      accessoryColor: json['accessoryColor'] != null ? Color(json['accessoryColor'] as int) : const Color(0xFFEAB308),
    );
  }

  @override
  List<Object?> get props => [
        spriteResolution,
        faceShape,
        skinColor,
        eyeStyle,
        eyeColor,
        eyebrowStyle,
        eyebrowColor,
        noseStyle,
        mouthStyle,
        faceDetail,
        faceDetailColor,
        hairStyle,
        hairColor,
        topStyle,
        topColor,
        bottomStyle,
        bottomColor,
        shoeStyle,
        shoeColor,
        accessoryStyle,
        accessoryColor,
      ];
}
