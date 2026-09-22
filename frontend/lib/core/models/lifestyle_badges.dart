import 'dart:convert';

/// Represents a single display-ready badge for profile cards and previews.
class BadgeDisplayItem {
  final String key;
  final String categoryTitle;
  final String label;
  final String icon;

  const BadgeDisplayItem({
    required this.key,
    required this.categoryTitle,
    required this.label,
    required this.icon,
  });

  @override
  String toString() => '$icon $label';
}

/// Model holding the 12 optional lifestyle badges for a user profile.
class LifestyleBadges {
  final String? smoking;
  final String? drinking;
  final String? diet;
  final int? heightCm;
  final String? kids;
  final String? pets;
  final String? zodiac;
  final String? education;
  final String? occupation;
  final List<String> languages;
  final String? religion;
  final String? exercise;

  const LifestyleBadges({
    this.smoking,
    this.drinking,
    this.diet,
    this.heightCm,
    this.kids,
    this.pets,
    this.zodiac,
    this.education,
    this.occupation,
    this.languages = const [],
    this.religion,
    this.exercise,
  });

  /// Count of currently active (non-empty) badges
  int get activeCount => activeBadges.length;

  /// Returns whether any badge has been configured
  bool get hasAnyBadge => activeCount > 0;

  LifestyleBadges copyWith({
    String? smoking,
    String? drinking,
    String? diet,
    int? heightCm,
    String? kids,
    String? pets,
    String? zodiac,
    String? education,
    String? occupation,
    List<String>? languages,
    String? religion,
    String? exercise,
    bool clearSmoking = false,
    bool clearDrinking = false,
    bool clearDiet = false,
    bool clearHeight = false,
    bool clearKids = false,
    bool clearPets = false,
    bool clearZodiac = false,
    bool clearEducation = false,
    bool clearOccupation = false,
    bool clearLanguages = false,
    bool clearReligion = false,
    bool clearExercise = false,
  }) {
    return LifestyleBadges(
      smoking: clearSmoking ? null : (smoking ?? this.smoking),
      drinking: clearDrinking ? null : (drinking ?? this.drinking),
      diet: clearDiet ? null : (diet ?? this.diet),
      heightCm: clearHeight ? null : (heightCm ?? this.heightCm),
      kids: clearKids ? null : (kids ?? this.kids),
      pets: clearPets ? null : (pets ?? this.pets),
      zodiac: clearZodiac ? null : (zodiac ?? this.zodiac),
      education: clearEducation ? null : (education ?? this.education),
      occupation: clearOccupation ? null : (occupation ?? this.occupation),
      languages: clearLanguages ? const [] : (languages ?? this.languages),
      religion: clearReligion ? null : (religion ?? this.religion),
      exercise: clearExercise ? null : (exercise ?? this.exercise),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (smoking != null && smoking!.isNotEmpty) 'smoking': smoking,
      if (drinking != null && drinking!.isNotEmpty) 'drinking': drinking,
      if (diet != null && diet!.isNotEmpty) 'diet': diet,
      if (heightCm != null && heightCm! > 0) 'heightCm': heightCm,
      if (kids != null && kids!.isNotEmpty) 'kids': kids,
      if (pets != null && pets!.isNotEmpty) 'pets': pets,
      if (zodiac != null && zodiac!.isNotEmpty) 'zodiac': zodiac,
      if (education != null && education!.isNotEmpty) 'education': education,
      if (occupation != null && occupation!.trim().isNotEmpty) 'occupation': occupation!.trim(),
      if (languages.isNotEmpty) 'languages': languages,
      if (religion != null && religion!.isNotEmpty) 'religion': religion,
      if (exercise != null && exercise!.isNotEmpty) 'exercise': exercise,
    };
  }

  factory LifestyleBadges.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LifestyleBadges();

    List<String> parsedLanguages = [];
    final rawLang = map['languages'];
    if (rawLang is List) {
      parsedLanguages = rawLang.map((e) => e.toString()).toList();
    } else if (rawLang is String && rawLang.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawLang);
        if (decoded is List) {
          parsedLanguages = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        parsedLanguages = [rawLang];
      }
    }

    int? parsedHeight;
    if (map['heightCm'] != null) {
      parsedHeight = (map['heightCm'] as num?)?.toInt();
    } else if (map['height'] != null) {
      parsedHeight = (map['height'] as num?)?.toInt();
    }

    return LifestyleBadges(
      smoking: map['smoking']?.toString(),
      drinking: map['drinking']?.toString(),
      diet: map['diet']?.toString(),
      heightCm: parsedHeight,
      kids: map['kids']?.toString(),
      pets: map['pets']?.toString(),
      zodiac: map['zodiac']?.toString(),
      education: map['education']?.toString(),
      occupation: map['occupation']?.toString(),
      languages: parsedLanguages,
      religion: map['religion']?.toString(),
      exercise: map['exercise']?.toString(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory LifestyleBadges.fromJson(String? source) {
    if (source == null || source.trim().isEmpty || source == '{}') {
      return const LifestyleBadges();
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return LifestyleBadges.fromMap(decoded);
      }
    } catch (_) {}
    return const LifestyleBadges();
  }

  /// Formatted list of active badges ready to render in the presentation card.
  List<BadgeDisplayItem> get activeBadges {
    final list = <BadgeDisplayItem>[];

    // 1. Altura
    if (heightCm != null && heightCm! > 0) {
      list.add(BadgeDisplayItem(
        key: 'height',
        categoryTitle: 'Altura',
        label: '$heightCm cm',
        icon: '📏',
      ));
    }

    // 2. Fumar
    if (_isValid(smoking)) {
      list.add(BadgeDisplayItem(
        key: 'smoking',
        categoryTitle: 'Fuma',
        label: _formatSmoking(smoking!),
        icon: _iconSmoking(smoking!),
      ));
    }

    // 3. Tomar
    if (_isValid(drinking)) {
      list.add(BadgeDisplayItem(
        key: 'drinking',
        categoryTitle: 'Toma',
        label: _formatDrinking(drinking!),
        icon: _iconDrinking(drinking!),
      ));
    }

    // 4. Hijos
    if (_isValid(kids)) {
      list.add(BadgeDisplayItem(
        key: 'kids',
        categoryTitle: 'Hijos',
        label: _formatKids(kids!),
        icon: _iconKids(kids!),
      ));
    }

    // 5. Mascotas
    if (_isValid(pets)) {
      list.add(BadgeDisplayItem(
        key: 'pets',
        categoryTitle: 'Mascotas',
        label: _formatPets(pets!),
        icon: _iconPets(pets!),
      ));
    }

    // 6. Dieta
    if (_isValid(diet)) {
      list.add(BadgeDisplayItem(
        key: 'diet',
        categoryTitle: 'Dieta',
        label: _formatDiet(diet!),
        icon: _iconDiet(diet!),
      ));
    }

    // 7. Ejercicio
    if (_isValid(exercise)) {
      list.add(BadgeDisplayItem(
        key: 'exercise',
        categoryTitle: 'Ejercicio',
        label: _formatExercise(exercise!),
        icon: _iconExercise(exercise!),
      ));
    }

    // 8. Zodiaco
    if (_isValid(zodiac)) {
      list.add(BadgeDisplayItem(
        key: 'zodiac',
        categoryTitle: 'Zodiaco',
        label: _formatZodiac(zodiac!),
        icon: _iconZodiac(zodiac!),
      ));
    }

    // 9. Ocupación
    if (_isValid(occupation)) {
      list.add(BadgeDisplayItem(
        key: 'occupation',
        categoryTitle: 'Ocupación',
        label: occupation!.trim(),
        icon: '💼',
      ));
    }

    // 10. Educación
    if (_isValid(education)) {
      list.add(BadgeDisplayItem(
        key: 'education',
        categoryTitle: 'Educación',
        label: _formatEducation(education!),
        icon: '🎓',
      ));
    }

    // 11. Idiomas
    if (languages.isNotEmpty) {
      list.add(BadgeDisplayItem(
        key: 'languages',
        categoryTitle: 'Idiomas',
        label: languages.join(', '),
        icon: '🗣️',
      ));
    }

    // 12. Religión
    if (_isValid(religion)) {
      list.add(BadgeDisplayItem(
        key: 'religion',
        categoryTitle: 'Creencias',
        label: _formatReligion(religion!),
        icon: _iconReligion(religion!),
      ));
    }

    return list;
  }

  static bool _isValid(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    return trimmed.isNotEmpty && trimmed != 'prefer_not_say' && trimmed != 'none' && trimmed != 'hidden';
  }

  // Formatting helpers
  static String _formatSmoking(String val) {
    switch (val.toLowerCase()) {
      case 'no_smoke': return 'No fumo';
      case 'social': return 'Fumo social';
      case 'tobacco': return 'Fumo tabaco';
      case 'vape': return 'Vapeo';
      default: return val;
    }
  }

  static String _iconSmoking(String val) {
    switch (val.toLowerCase()) {
      case 'no_smoke': return '🚭';
      case 'vape': return '💨';
      default: return '🚬';
    }
  }

  static String _formatDrinking(String val) {
    switch (val.toLowerCase()) {
      case 'no_drink': return 'No bebo';
      case 'social': return 'Bebo social';
      case 'frequent': return 'Bebo frecuente';
      case 'sober': return 'Sobrio(a)';
      default: return val;
    }
  }

  static String _iconDrinking(String val) {
    switch (val.toLowerCase()) {
      case 'no_drink': return '🚫';
      case 'sober': return '✨';
      default: return '🍷';
    }
  }

  static String _formatKids(String val) {
    switch (val.toLowerCase()) {
      case 'no_kids': return 'Sin hijos';
      case 'have_kids': return 'Tengo hijos';
      case 'want_kids': return 'Quiero hijos';
      case 'dont_want_kids': return 'No quiero hijos';
      case 'open_to_kids': return 'Abierto(a) a tener';
      default: return val;
    }
  }

  static String _iconKids(String val) {
    switch (val.toLowerCase()) {
      case 'have_kids': return '👶';
      case 'want_kids': return '🍼';
      case 'dont_want_kids': return '🚫';
      default: return '🧸';
    }
  }

  static String _formatPets(String val) {
    switch (val.toLowerCase()) {
      case 'dog': return 'Tengo perro';
      case 'cat': return 'Tengo gato';
      case 'both': return 'Perros y gatos';
      case 'other': return 'Otras mascotas';
      case 'no_pets': return 'Sin mascotas';
      case 'allergic': return 'Alérgico(a) a animales';
      default: return val;
    }
  }

  static String _iconPets(String val) {
    switch (val.toLowerCase()) {
      case 'dog': return '🐶';
      case 'cat': return '🐱';
      case 'both': return '🐾';
      case 'other': return '🐰';
      case 'no_pets': return '🪴';
      case 'allergic': return '🤧';
      default: return '🐾';
    }
  }

  static String _formatDiet(String val) {
    switch (val.toLowerCase()) {
      case 'omnivore': return 'Omnívoro(a)';
      case 'vegetarian': return 'Vegetariano(a)';
      case 'vegan': return 'Vegano(a)';
      case 'pescatarian': return 'Pesquetariano(a)';
      case 'gluten_free': return 'Sin gluten';
      default: return val;
    }
  }

  static String _iconDiet(String val) {
    switch (val.toLowerCase()) {
      case 'vegetarian': return '🥗';
      case 'vegan': return '🌱';
      case 'pescatarian': return '🐟';
      case 'gluten_free': return '🌾';
      default: return '🍖';
    }
  }

  static String _formatExercise(String val) {
    switch (val.toLowerCase()) {
      case 'daily': return 'Activo(a) a diario';
      case 'often': return 'Ejercicio frecuente';
      case 'sometimes': return 'Ejercicio a veces';
      case 'rarely': return 'Modo relax';
      default: return val;
    }
  }

  static String _iconExercise(String val) {
    switch (val.toLowerCase()) {
      case 'daily': return '🏋️';
      case 'often': return '🏃';
      case 'sometimes': return '🚶';
      default: return '🛋️';
    }
  }

  static String _formatZodiac(String val) {
    switch (val.toLowerCase()) {
      case 'aries': return 'Aries';
      case 'taurus': return 'Tauro';
      case 'gemini': return 'Géminis';
      case 'cancer': return 'Cáncer';
      case 'leo': return 'Leo';
      case 'virgo': return 'Virgo';
      case 'libra': return 'Libra';
      case 'scorpio': return 'Escorpio';
      case 'sagittarius': return 'Sagitario';
      case 'capricorn': return 'Capricornio';
      case 'aquarius': return 'Acuario';
      case 'pisces': return 'Piscis';
      default: return val;
    }
  }

  static String _iconZodiac(String val) {
    switch (val.toLowerCase()) {
      case 'aries': return '♈';
      case 'taurus': return '♉';
      case 'gemini': return '♊';
      case 'cancer': return '♋';
      case 'leo': return '♌';
      case 'virgo': return '♍';
      case 'libra': return '♎';
      case 'scorpio': return '♏';
      case 'sagittarius': return '♐';
      case 'capricorn': return '♑';
      case 'aquarius': return '♒';
      case 'pisces': return '♓';
      default: return '⭐';
    }
  }

  static String _formatEducation(String val) {
    switch (val.toLowerCase()) {
      case 'university': return 'Universitario(a)';
      case 'in_university': return 'En la Universidad';
      case 'postgraduate': return 'Postgrado / Máster';
      case 'technical': return 'Técnico(a)';
      case 'high_school': return 'Secundaria';
      default: return val;
    }
  }

  static String _formatReligion(String val) {
    switch (val.toLowerCase()) {
      case 'agnostic': return 'Agnóstico(a)';
      case 'atheist': return 'Ateo(a)';
      case 'spiritual': return 'Espiritual';
      case 'christian': return 'Cristiano / Católico';
      case 'buddhist': return 'Budista';
      default: return val;
    }
  }

  static String _iconReligion(String val) {
    switch (val.toLowerCase()) {
      case 'agnostic': return '✨';
      case 'atheist': return '⚛️';
      case 'spiritual': return '🧘';
      case 'christian': return '⛪';
      case 'buddhist': return '🪷';
      default: return '🕊️';
    }
  }
}
