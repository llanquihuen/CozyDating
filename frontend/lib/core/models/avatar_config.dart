import 'dart:ui';
import 'package:equatable/equatable.dart';

class AvatarConfig extends Equatable {
  final String bodyType; // 'female' or 'male'
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
    this.bodyType = 'female',
    this.spriteResolution = '64x128',
    this.faceShape = 'oval',
    this.skinColor = const Color(0xFFFCD5B5),
    this.eyeStyle = 'cateyes',
    this.eyeColor = const Color(0xFF059669),
    this.eyebrowStyle = 'none',
    this.eyebrowColor = const Color(0xFFC85A2A),
    this.noseStyle = 'standard',
    this.mouthStyle = 'catmouth',
    this.faceDetail = 'none',
    this.faceDetailColor = const Color(0xFFFF7777),
    this.hairStyle = 'long_flow',
    this.hairColor = const Color(0xFFC85A2A),
    this.topStyle = 'jacket',
    this.topColor = const Color(0xFFDC2626),
    this.bottomStyle = 'jeans',
    this.bottomColor = const Color(0xFF2563EB),
    this.shoeStyle = 'none',
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

  static const List<String> availableBodyTypes = [
    'female',
    'male',
  ];

  static const List<String> availableResolutions = [
    '64x128',
  ];

  static const List<String> availableFaceShapes = [
    'oval',
  ];

  static const List<String> availableEyeStyles = [
    'cateyes',
    'relax',
  ];

  static const List<String> availableEyebrowStyles = [
    'none',
  ];

  static const List<String> availableNoseStyles = [
    'standard',
    'small',
  ];

  static const List<String> availableMouthStyles = [
    'catmouth',
    'smile',
    'smirk',
  ];

  static const List<String> availableFaceDetails = [
    'none',
  ];

  static const List<String> availableHairStyles = [
    'long_flow',
    'flow',
    'comb_over',
    'bangs',
    'braids',
    'none',
  ];

  static const List<String> availableTopStyles = [
    'jacket',
    'none',
  ];

  static const List<String> availableBottomStyles = [
    'jeans',
    'none',
  ];

  static const List<String> availableShoeStyles = [
    'none',
    'boots',
  ];

  static const List<String> availableAccessoryStyles = [
    'none',
    'nice_lenses',
    'normal_lenses',
  ];

  static String formatName(String id) {
    switch (id) {
      // Body Type / Gender
      case 'female': return 'Femenino ♀';
      case 'male': return 'Masculino ♂';

      // Resolutions
      case '64x128': return '64x128 (OCTOPLAYER 8-Dir)';
      case '32x64': return '32x64 (Pixel Chibi)';

      // Face Shapes
      case 'oval': return 'Ovalada';
      case 'round': return 'Redonda Tierna';
      case 'sharp_v': return 'Afilada en V';
      case 'square_jaw': return 'Mandíbula Firme';
      case 'heart': return 'Forma de Corazón';

      // Eyes
      case 'cateyes': return 'Ojos Felinos 🐱';
      case 'relax': return 'Ojos Relajados 🍃';

      // Brows
      case 'normal': return 'Normales';
      case 'none': return 'Ninguno';

      // Nose
      case 'standard': return 'Nariz Estándar';
      case 'small': return 'Nariz Pequeña';
      case 'subtle': return 'Sutil';

      // Mouth
      case 'catmouth': return 'Boca Gatito 🐱';
      case 'smile': return 'Sonrisa Dulce 😊';
      case 'smirk': return 'Sonrisa Pícara 😏';

      // Face Details
      case 'blush': return 'Rubor Suave';
      case 'freckles': return 'Pecas';
      case 'scar': return 'Cicatriz';

      // Hair
      case 'long_flow': return 'Melena Fluida';
      case 'flow': return 'Cabello Flow';
      case 'comb_over': return 'Raya al Lado / Comb Over';
      case 'bangs': return 'Flequillo / Bangs';
      case 'braids': return 'Trenzas / Braids';

      // Tops
      case 'jacket': return 'Chaqueta';

      // Bottoms
      case 'jeans': return 'Jeans Clásicos';

      // Calzado
      case 'boots': return 'Botas de Cuero 🥾';
      case 'farmer_boots': return 'Botas';

      // Accesorios
      case 'nice_lenses': return 'Gafas Modernas 🕶️';
      case 'normal_lenses': return 'Lentes Clásicos 👓';
      case 'straw_hat': return 'Sombrero';
      case 'none': return 'Ninguno';

      default:
        return id.replaceAll('_', ' ');
    }
  }

  AvatarConfig copyWith({
    String? bodyType,
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
      bodyType: bodyType ?? this.bodyType,
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
      'bodyType': bodyType,
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
      if (h == 'flow') return 'flow';
      if (h == 'comb_over') return 'comb_over';
      if (h == 'bangs') return 'bangs';
      if (h == 'braids') return 'braids';
      if (h == 'none') return 'none';
      return 'long_flow';
    }

    String mapTop(String? t) {
      if (t == 'none') return 'none';
      return 'jacket';
    }

    String mapBottom(String? b) {
      if (b == 'none') return 'none';
      return 'jeans';
    }

    String mapEyes(String? e) {
      if (e == 'relax') return 'relax';
      return 'cateyes';
    }

    String mapNose(String? n) {
      if (n == 'small') return 'small';
      return 'standard';
    }

    String mapMouth(String? m) {
      if (m == 'smile') return 'smile';
      if (m == 'smirk') return 'smirk';
      return 'catmouth';
    }

    return AvatarConfig(
      bodyType: (json['bodyType'] == 'male') ? 'male' : 'female',
      spriteResolution: '64x128',
      faceShape: 'oval',
      skinColor: json['skinColor'] != null ? Color(json['skinColor'] as int) : const Color(0xFFFCD5B5),
      eyeStyle: mapEyes(json['eyeStyle'] as String?),
      eyeColor: json['eyeColor'] != null ? Color(json['eyeColor'] as int) : const Color(0xFF059669),
      eyebrowStyle: 'none',
      eyebrowColor: json['eyebrowColor'] != null ? Color(json['eyebrowColor'] as int) : const Color(0xFFC85A2A),
      noseStyle: mapNose(json['noseStyle'] as String?),
      mouthStyle: mapMouth(json['mouthStyle'] as String?),
      faceDetail: 'none',
      faceDetailColor: json['faceDetailColor'] != null ? Color(json['faceDetailColor'] as int) : const Color(0xFFFF7777),
      hairStyle: mapHair(json['hairStyle'] as String?),
      hairColor: json['hairColor'] != null ? Color(json['hairColor'] as int) : const Color(0xFFC85A2A),
      topStyle: mapTop(json['topStyle'] as String?),
      topColor: json['topColor'] != null ? Color(json['topColor'] as int) : const Color(0xFFDC2626),
      bottomStyle: mapBottom(json['bottomStyle'] as String?),
      bottomColor: json['bottomColor'] != null ? Color(json['bottomColor'] as int) : const Color(0xFF2563EB),
      shoeStyle: 'none',
      shoeColor: json['shoeColor'] != null ? Color(json['shoeColor'] as int) : const Color(0xFF78350F),
      accessoryStyle: 'none',
      accessoryColor: json['accessoryColor'] != null ? Color(json['accessoryColor'] as int) : const Color(0xFFEAB308),
    );
  }

  @override
  List<Object?> get props => [
        bodyType,
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
