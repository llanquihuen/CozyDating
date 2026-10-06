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

  const AvatarItem(
    this.slot,
    this.id,
    this.label, {
    this.audience = AvatarAudience.neutral,
    this.fits = AvatarCatalog.bodyTypes,
    this.hasBack = false,
  });
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

  /// Body marks (freckles, moles, tattoos, scars): stackable, see AvatarConfig.marks.
  static const String mark = 'mark';

  /// Accessory slots in draw order (later slots are drawn on top); one style per slot.
  static const List<String> accessorySlots = ['bag', 'glasses', 'headband', 'hat'];

  /// Slots that can be left empty ('none').
  static const Set<String> _optionalSlots = {hair, top, bottom, shoes, 'bag', 'glasses', 'headband', 'hat'};

  static const List<AvatarItem> items = [
    // Eyes
    AvatarItem(eyes, 'cateyes', 'Ojos Felinos 🐱'),
    AvatarItem(eyes, 'closedeyes', 'Ojos Cerrados 😌'),
    AvatarItem(eyes, 'relax', 'Ojos Relajados 🍃'),

    // Nose
    AvatarItem(nose, 'small', 'Nariz Pequeña'),
    AvatarItem(nose, 'standard', 'Nariz Estándar'),

    // Mouth
    AvatarItem(mouth, 'biglips', 'Labios Grandes 💋'),
    AvatarItem(mouth, 'catmouth', 'Boca Gatito 🐱'),
    AvatarItem(mouth, 'smile', 'Sonrisa Dulce 😊'),
    AvatarItem(mouth, 'smirk', 'Sonrisa Pícara 😏'),

    // Hair
    AvatarItem(hair, 'bangs', 'Flequillo / Bangs'),
    AvatarItem(hair, 'braids', 'Trenzas / Braids', audience: AvatarAudience.feminine),
    AvatarItem(hair, 'comb_over', 'Raya al Lado / Comb Over', audience: AvatarAudience.masculine),
    AvatarItem(hair, 'flow', 'Cabello Flow', hasBack: true),
    AvatarItem(hair, 'long_flow', 'Melena Fluida', audience: AvatarAudience.feminine, hasBack: true),
    AvatarItem(hair, 'twintails', 'Dos Coletas / Twintails 👧', audience: AvatarAudience.feminine, hasBack: true),

    // Clothing
    AvatarItem(top, 'jacket', 'Chaqueta'),
    AvatarItem(bottom, 'jeans', 'Jeans Clásicos'),
    AvatarItem(shoes, 'boots', 'Botas de Cuero 🥾'),

    // Marks
    AvatarItem(mark, 'freckles', 'Pecas ✨'),

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

  /// Ids offered for [slot], with 'none' first where the slot can be empty.
  static List<String> options(String slot, {required String gender, required String bodyType}) {
    return [
      if (allowsNone(slot)) 'none',
      for (final item in items)
        if (item.slot == slot && isAllowed(item, gender: gender, bodyType: bodyType)) item.id,
    ];
  }

  /// Whether [id] may be worn in [slot] by this gender and body.
  static bool isAllowedId(String slot, String id, {required String gender, required String bodyType}) {
    if (id == 'none') return allowsNone(slot);
    final item = find(slot, id);
    return item != null && isAllowed(item, gender: gender, bodyType: bodyType);
  }
}
