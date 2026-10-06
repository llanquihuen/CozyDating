/// Every selectable avatar style in one place: which slot it fills, who it is aimed at and which
/// bodies have art for it. Adding an item = one entry in [AvatarCatalog.items] plus its sprites
/// under OCTOPLAYER/Avatar/; AvatarConfig validation, both editors and the gender filter read it.
enum AvatarAudience { feminine, masculine, neutral }

class AvatarItem {
  final String slot;
  final String id;
  final String label;
  final AvatarAudience audience;

  /// Body types with art for this item (fitted or generic).
  final List<String> fits;

  /// Hair drawn in two layers (behind and in front of the body).
  final bool hasBack;

  /// Body marks (tattoos) drawn on the skin under the clothes, fitted per body type, instead of over
  /// the head like face marks.
  final bool underClothes;

  /// Name under the editor thumbnail; null derives it from [label] (see [displayLabel]).
  final String? shortLabel;

  const AvatarItem(
    this.slot,
    this.id,
    this.label, {
    this.audience = AvatarAudience.neutral,
    this.fits = AvatarCatalog.bodyTypes,
    this.hasBack = false,
    this.underClothes = false,
    this.shortLabel,
  });

  /// Words a thumbnail label can drop: the grid already says which part it is.
  static const _slotWords = ['Ojos de ', 'Ojos ', 'Nariz ', 'Boca ', 'Labial ', 'Sombra ', 'Rubor '];

  /// [shortLabel], else [label] without emoji, without the English name after " / " and without a
  /// leading slot word ("Ojos Felinos 🐱" -> "Felinos", "Flequillo / Bangs" -> "Flequillo").
  String get displayLabel {
    if (shortLabel != null) return shortLabel!;
    var text = label.split(' / ').first.replaceAll(RegExp(r' \(.*\)'), '');
    text = text.runes
        .where((r) => r < 0x2190 || (r >= 0x2C00 && r < 0xFE00) || (r > 0xFE0F && r < 0x1F000))
        .map(String.fromCharCode)
        .join()
        .replaceAll('///', '')
        .trim();
    for (final word in _slotWords) {
      if (text.startsWith(word) && text.length > word.length) {
        text = text.substring(word.length);
        break;
      }
    }
    return text.isEmpty ? label : text[0].toUpperCase() + text.substring(1);
  }
}

class AvatarCatalog {
  static const List<String> bodyTypes = ['female', 'male'];

  static const String eyes = 'eyes';
  static const String nose = 'nose';
  static const String mouth = 'mouth';
  static const String hair = 'hair';
  static const String top = 'top';
  static const String bottom = 'bottom';
  static const String shoes = 'shoes';

  /// One-piece outfits (dresses): worn over both halves, hiding the top and bottom while on.
  static const String dress = 'dress';

  /// Body marks (freckles, moles, tattoos, scars): stackable, see AvatarConfig.marks.
  static const String mark = 'mark';

  /// Accessory slots in draw order (later slots are drawn on top); one style per slot.
  static const List<String> accessorySlots = ['bag', 'glasses', 'headband', 'hat'];

  /// Makeup slots in draw order; one style per slot, each with its own colour (AvatarConfig.makeup).
  /// Blush ships sprites; eyeshadow and lipstick are painted at load time around the worn eyes and
  /// mouth, so they fit every eye and mouth style.
  static const String blush = 'blush';
  static const String eyeshadow = 'eyeshadow';
  static const String lipstick = 'lipstick';

  /// The eye sprites' blue-coded pixels (the liner drawn over the lid): invisible unless an eyeliner
  /// is worn, then painted in its colour.
  static const String eyeliner = 'eyeliner';
  static const List<String> makeupSlots = [blush, eyeshadow, eyeliner, lipstick];

  /// Slots that can be left empty ('none').
  static const Set<String> _optionalSlots = {
    hair, top, bottom, shoes, dress, 'bag', 'glasses', 'headband', 'hat', blush, eyeshadow, eyeliner, lipstick,
  };

  static const List<AvatarItem> items = [
    // Eyes
    AvatarItem(eyes, 'cateyes', 'Ojos Felinos 🐱'),
    AvatarItem(eyes, 'closedeyes', 'Ojos Cerrados 😌'),
    AvatarItem(eyes, 'relax', 'Ojos Relajados 🍃'),
    AvatarItem(eyes, 'sparkle', 'Ojos Kawaii ✨'),
    AvatarItem(eyes, 'anime', 'Ojos Anime 🌟'),
    AvatarItem(eyes, 'serious', 'Ojos Serios 😐'),
    AvatarItem(eyes, 'sleepy', 'Ojos Somnolientos 😪'),
    AvatarItem(eyes, 'winged', 'Ojos Delineados 💅'),
    AvatarItem(eyes, 'puppy', 'Ojos de Cachorrito 🥺'),
    AvatarItem(eyes, 'hearts', 'Ojos Enamorados 😍'),
    AvatarItem(eyes, 'wink', 'Guiño 😉'),

    // Nose
    AvatarItem(nose, 'small', 'Nariz Pequeña'),
    AvatarItem(nose, 'standard', 'Nariz Estándar'),

    // Mouth
    AvatarItem(mouth, 'biglips', 'Labios Grandes 💋'),
    AvatarItem(mouth, 'catmouth', 'Boca Gatito 🐱'),
    AvatarItem(mouth, 'smile', 'Sonrisa Dulce 😊'),
    AvatarItem(mouth, 'smirk', 'Sonrisa Pícara 😏'),
    AvatarItem(mouth, 'grin', 'Sonrisa Abierta 😄'),
    AvatarItem(mouth, 'neutral', 'Boca Neutral 😐'),
    AvatarItem(mouth, 'fang', 'Sonrisa con Colmillo 😺', shortLabel: 'Colmillo'),
    AvatarItem(mouth, 'pout', 'Boquita de Beso 😗'),

    // Hair
    AvatarItem(hair, 'bangs', 'Flequillo / Bangs'),
    AvatarItem(hair, 'braids', 'Trenzas / Braids', audience: AvatarAudience.feminine),
    AvatarItem(hair, 'undercut', 'Undercut', audience: AvatarAudience.masculine),
    AvatarItem(hair, 'comb_over', 'Raya al Lado / Comb Over', audience: AvatarAudience.masculine),
    AvatarItem(hair, 'flow', 'Cabello Flow', hasBack: true),
    AvatarItem(hair, 'long_flow', 'Melena Fluida', audience: AvatarAudience.feminine, hasBack: true),
    AvatarItem(hair, 'twintails', 'Dos Coletas / Twintails 👧', audience: AvatarAudience.feminine, hasBack: true),
    AvatarItem(hair, 'buzz', 'Rapado'),
    AvatarItem(hair, 'afro', 'Afro'),
    AvatarItem(hair, 'messy', 'Despeinado', audience: AvatarAudience.masculine),
    AvatarItem(hair, 'curly_short', 'Rizos Cortos', audience: AvatarAudience.masculine),
    AvatarItem(hair, 'spiky', 'Puntas Anime', audience: AvatarAudience.masculine),
    AvatarItem(hair, 'man_bun', 'Moño Masculino', audience: AvatarAudience.masculine),
    AvatarItem(hair, 'bob', 'Bob', audience: AvatarAudience.feminine),
    AvatarItem(hair, 'pixie', 'Pixie', audience: AvatarAudience.feminine),
    AvatarItem(hair, 'space_buns', 'Moños Dobles', audience: AvatarAudience.feminine),
    AvatarItem(hair, 'ponytail', 'Cola de Caballo', audience: AvatarAudience.feminine, hasBack: true),
    AvatarItem(hair, 'wavy_long', 'Ondas Largas', audience: AvatarAudience.feminine, hasBack: true),

    // Clothing
    AvatarItem(top, 'jacket', 'Chaqueta'),
    AvatarItem(top, 'tshirt', 'Polera'),
    AvatarItem(top, 'tank', 'Musculosa'),
    AvatarItem(top, 'longsleeve', 'Manga Larga'),
    AvatarItem(top, 'dress_shirt', 'Camisa'),
    AvatarItem(top, 'hoodie', 'Polerón con Capucha', shortLabel: 'Polerón'),
    AvatarItem(top, 'bikini_top', 'Bikini (Arriba) 👙', audience: AvatarAudience.feminine, fits: ['female']),
    AvatarItem(bottom, 'jeans', 'Jeans Clásicos'),
    AvatarItem(bottom, 'sweatpants', 'Pantalón de Buzo'),
    AvatarItem(bottom, 'leggings', 'Calzas'),
    AvatarItem(bottom, 'shorts', 'Shorts'),
    AvatarItem(bottom, 'skirt_short', 'Falda Corta', audience: AvatarAudience.feminine, fits: ['female']),
    AvatarItem(bottom, 'skirt_long', 'Falda Larga', audience: AvatarAudience.feminine, fits: ['female']),
    AvatarItem(bottom, 'bikini_bottom', 'Bikini (Abajo) 👙', audience: AvatarAudience.feminine, fits: ['female']),
    AvatarItem(dress, 'lolita', 'Vestido Lolita 🎀', audience: AvatarAudience.feminine, fits: ['female']),
    AvatarItem(shoes, 'boots', 'Botas de Cuero 🥾'),
    AvatarItem(shoes, 'sneakers', 'Zapatillas 👟'),
    AvatarItem(shoes, 'sandals', 'Sandalias 🩴'),

    // Marks
    AvatarItem(mark, 'freckles', 'Pecas ✨'),
    AvatarItem(mark, 'scar_eye', 'Cicatriz en el Ojo ⚔️', shortLabel: 'Cicatriz'),
    AvatarItem(mark, 'mole_mouth', 'Lunar junto a la Boca', shortLabel: 'Lunar boca'),
    AvatarItem(mark, 'mole_eye', 'Lunar bajo el Ojo', shortLabel: 'Lunar ojo'),
    AvatarItem(mark, 'tattoo_tear', 'Lágrima Tatuada 💧'),
    AvatarItem(mark, 'tattoo_star', 'Estrella en la Mejilla ⭐', shortLabel: 'Estrella'),
    AvatarItem(mark, 'tattoo_heart', 'Corazón en la Mejilla ❤️', shortLabel: 'Corazón'),
    AvatarItem(mark, 'tattoo_sleeves', 'Brazos Tatuados', underClothes: true),
    AvatarItem(mark, 'tattoo_bands', 'Brazaletes Tatuados', underClothes: true),
    AvatarItem(mark, 'tattoo_roses', 'Rosas en los Hombros 🌹', underClothes: true, shortLabel: 'Rosas'),

    // Makeup (blush sprites in OCTOPLAYER/Avatar/makeup/blush/)
    AvatarItem(blush, 'blush_soft', 'Rubor Suave'),
    AvatarItem(blush, 'blush_anime', 'Rubor Anime ///'),
    AvatarItem(blush, 'blush_strong', 'Rubor Intenso'),
    AvatarItem(eyeshadow, 'shadow_soft', 'Sombra Suave'),
    AvatarItem(eyeshadow, 'shadow_smoky', 'Sombra Ahumada'),
    AvatarItem(eyeliner, 'liner', 'Delineado'),
    AvatarItem(lipstick, 'lip_natural', 'Labial Natural'),
    AvatarItem(lipstick, 'lip_bold', 'Labial Intenso'),

    // Accessories (assets in OCTOPLAYER/Avatar/accessories/<slot>/)
    AvatarItem('glasses', 'nice_lenses', 'Gafas Modernas 🕶️'),
    AvatarItem('glasses', 'normal_lenses', 'Lentes Clásicos 👓'),
  ];

  static AvatarItem? find(String slot, String id) {
    for (final item in items) {
      if (item.slot == slot && item.id == id) return item;
    }
    return null;
  }

  static bool allowsNone(String slot) => _optionalSlots.contains(slot);

  /// Whether [id] is a valid value for [slot] ('none' included where the slot can be empty).
  static bool isKnown(String slot, String id) => (id == 'none' && allowsNone(slot)) || find(slot, id) != null;

  /// Label of the first catalog item with [id], if any.
  static String? labelOf(String id) {
    for (final item in items) {
      if (item.id == id) return item.label;
    }
    return null;
  }

  /// Body a gender is locked to; null means free choice (non-binary, or gender not set yet).
  static String? lockedBodyFor(String gender) {
    switch (gender) {
      case 'MAN': return 'male';
      case 'WOMAN': return 'female';
      default: return null;
    }
  }

  /// Men see masculine + neutral, women feminine + neutral, everyone else all of it;
  /// in every case only items with art for [bodyType].
  static bool isAllowed(AvatarItem item, {required String gender, required String bodyType}) {
    if (!item.fits.contains(bodyType)) return false;
    switch (gender) {
      case 'MAN': return item.audience != AvatarAudience.feminine;
      case 'WOMAN': return item.audience != AvatarAudience.masculine;
      default: return true;
    }
  }

  /// Ids offered for [slot], with 'none' first where the slot can be empty. Men see the items aimed
  /// at men before the neutral ones (a neutral fringe is not what reads as masculine first), in
  /// catalog order; that first item is also their default (see AvatarConfig.restrictedTo).
  static List<String> options(String slot, {required String gender, required String bodyType}) {
    final allowed = [
      for (final item in items)
        if (item.slot == slot && isAllowed(item, gender: gender, bodyType: bodyType)) item,
    ];
    final menFirst = gender == 'MAN';
    bool leads(AvatarItem item) => menFirst && item.audience == AvatarAudience.masculine;
    return [
      if (allowsNone(slot)) 'none',
      for (final item in allowed) if (leads(item)) item.id,
      for (final item in allowed) if (!leads(item)) item.id,
    ];
  }

  /// Whether [id] may be worn in [slot] by this gender and body.
  static bool isAllowedId(String slot, String id, {required String gender, required String bodyType}) {
    if (id == 'none') return allowsNone(slot);
    final item = find(slot, id);
    return item != null && isAllowed(item, gender: gender, bodyType: bodyType);
  }
}
