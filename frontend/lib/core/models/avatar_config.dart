import 'dart:ui';
import 'package:equatable/equatable.dart';

import 'avatar_catalog.dart';

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
  /// Body marks (freckles, moles, tattoos, scars): any number at once, drawn on the skin.
  /// They stay visible when worn accessories are taken off (e.g. sleeping under the covers).
  final List<String> marks;

  /// Worn accessories, slot -> style (see [AvatarCatalog.accessorySlots]): at most one per slot.
  final Map<String, String> accessories;
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
    this.marks = const [],
    this.accessories = const {},
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

  static const List<String> availableEyebrowStyles = [
    'none',
  ];

  static const List<String> availableFaceDetails = [
    'none',
  ];

  /// Accessory slot holding [accessoryStyle], or 'none'.
  static String slotOf(String accessoryStyle) {
    for (final slot in AvatarCatalog.accessorySlots) {
      if (AvatarCatalog.find(slot, accessoryStyle) != null) return slot;
    }
    return 'none';
  }

  static String formatSlotName(String slot) {
    switch (slot) {
      case 'hat': return 'Sombrero';
      case 'glasses': return 'Lentes';
      case 'bag': return 'Bolso';
      case 'headband': return 'Cintillo';
      default: return slot.replaceAll('_', ' ');
    }
  }

  /// Equipped style for [slot], or 'none'.
  String accessoryIn(String slot) => accessories[slot] ?? 'none';

  /// Equips [style] in [slot] ('none' empties the slot).
  AvatarConfig withAccessory(String slot, String style) {
    final next = Map<String, String>.of(accessories);
    if (style == 'none') {
      next.remove(slot);
    } else {
      next[slot] = style;
    }
    return copyWith(accessories: next);
  }

  /// Adds or removes a body mark.
  AvatarConfig toggleMark(String mark) {
    final next = List<String>.of(marks);
    if (!next.remove(mark)) next.add(mark);
    return copyWith(marks: next);
  }

  /// This config made valid for a profile [gender] ('MAN', 'WOMAN', 'NON_BINARY'...): the body is
  /// locked for men and women, and items aimed at another audience or without art for the body are
  /// swapped for the first allowed style of their slot (or emptied).
  AvatarConfig restrictedTo(String gender) {
    final body = AvatarCatalog.lockedBodyFor(gender) ?? bodyType;
    bool allowed(String slot, String id) => AvatarCatalog.isAllowedId(slot, id, gender: gender, bodyType: body);
    String pick(String slot, String current) {
      if (allowed(slot, current)) return current;
      final options = AvatarCatalog.options(slot, gender: gender, bodyType: body);
      return options.firstWhere((id) => id != 'none', orElse: () => options.isEmpty ? current : options.first);
    }

    return copyWith(
      bodyType: body,
      eyeStyle: pick(AvatarCatalog.eyes, eyeStyle),
      noseStyle: pick(AvatarCatalog.nose, noseStyle),
      mouthStyle: pick(AvatarCatalog.mouth, mouthStyle),
      hairStyle: pick(AvatarCatalog.hair, hairStyle),
      topStyle: pick(AvatarCatalog.top, topStyle),
      bottomStyle: pick(AvatarCatalog.bottom, bottomStyle),
      shoeStyle: pick(AvatarCatalog.shoes, shoeStyle),
      marks: [for (final m in marks) if (allowed(AvatarCatalog.mark, m)) m],
      accessories: {
        for (final e in accessories.entries) if (allowed(e.key, e.value)) e.key: e.value,
      },
    );
  }

  static String formatName(String id) {
    final label = AvatarCatalog.labelOf(id);
    if (label != null) return label;
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
    List<String>? marks,
    Map<String, String>? accessories,
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
      marks: marks ?? this.marks,
      accessories: accessories ?? this.accessories,
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
      'marks': marks,
      'accessories': accessories,
      'accessoryColor': accessoryColor.value,
    };
  }

  factory AvatarConfig.fromJson(Map<String, dynamic> json) {
    // Unknown or missing styles (removed items, older/newer clients) fall back to a default.
    String known(String slot, Object? value, String fallback) =>
        value is String && AvatarCatalog.isKnown(slot, value) ? value : fallback;

    final marks = <String>[];
    final accessories = <String, String>{};
    final rawMarks = json['marks'];
    if (rawMarks is List) {
      for (final m in rawMarks) {
        if (m is String && AvatarCatalog.isKnown(AvatarCatalog.mark, m) && !marks.contains(m)) marks.add(m);
      }
    }
    final rawAccessories = json['accessories'];
    if (rawAccessories is Map) {
      rawAccessories.forEach((slot, style) {
        if (slot is String && style is String && style != 'none' && AvatarCatalog.isKnown(slot, style)) {
          accessories[slot] = style;
        }
      });
    }
    // Legacy configs had a single 'accessoryStyle' mixing marks and worn accessories.
    final legacy = json['accessoryStyle'];
    if (rawMarks == null && rawAccessories == null && legacy is String) {
      if (AvatarCatalog.isKnown(AvatarCatalog.mark, legacy)) {
        marks.add(legacy);
      } else if (slotOf(legacy) != 'none') {
        accessories[slotOf(legacy)] = legacy;
      }
    }

    return AvatarConfig(
      bodyType: (json['bodyType'] == 'male') ? 'male' : 'female',
      spriteResolution: '64x128',
      faceShape: 'oval',
      skinColor: json['skinColor'] != null ? Color(json['skinColor'] as int) : const Color(0xFFFCD5B5),
      eyeStyle: known(AvatarCatalog.eyes, json['eyeStyle'], 'cateyes'),
      eyeColor: json['eyeColor'] != null ? Color(json['eyeColor'] as int) : const Color(0xFF059669),
      eyebrowStyle: 'none',
      eyebrowColor: json['eyebrowColor'] != null ? Color(json['eyebrowColor'] as int) : const Color(0xFFC85A2A),
      noseStyle: known(AvatarCatalog.nose, json['noseStyle'], 'standard'),
      mouthStyle: known(AvatarCatalog.mouth, json['mouthStyle'], 'catmouth'),
      faceDetail: 'none',
      faceDetailColor: json['faceDetailColor'] != null ? Color(json['faceDetailColor'] as int) : const Color(0xFFFF7777),
      hairStyle: known(AvatarCatalog.hair, json['hairStyle'], 'long_flow'),
      hairColor: json['hairColor'] != null ? Color(json['hairColor'] as int) : const Color(0xFFC85A2A),
      topStyle: known(AvatarCatalog.top, json['topStyle'], 'jacket'),
      topColor: json['topColor'] != null ? Color(json['topColor'] as int) : const Color(0xFFDC2626),
      bottomStyle: known(AvatarCatalog.bottom, json['bottomStyle'], 'jeans'),
      bottomColor: json['bottomColor'] != null ? Color(json['bottomColor'] as int) : const Color(0xFF2563EB),
      shoeStyle: known(AvatarCatalog.shoes, json['shoeStyle'], 'none'),
      shoeColor: json['shoeColor'] != null ? Color(json['shoeColor'] as int) : const Color(0xFF78350F),
      marks: marks,
      accessories: accessories,
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
        marks,
        accessories,
        accessoryColor,
      ];
}
