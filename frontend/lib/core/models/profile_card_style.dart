import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart' show Color, StringCharacters;

/// How a player's two-sided profile card looks: theme, accent colour, the short phrase and the
/// featured tastes on the character face. Stored as JSON in the user's `cardStyle`.
class ProfileCardStyle extends Equatable {
  const ProfileCardStyle({
    this.themeId = defaultTheme,
    this.accent,
    this.phrase = '',
    this.featuredTastes = const [],
  });

  static const int maxPhraseLength = 60;
  static const int maxFeaturedTastes = 5;
  static const int defaultFeaturedTastes = 3;

  /// Theme ids, in display order (their colours and frames come with the card widgets).
  static const String defaultTheme = 'cafe';
  static const List<String> themeIds = [
    'metal', 'forest', 'coquette', 'cafe', 'arcade', 'mystic', 'matcha', 'retro90s', 'mono', 'coast',
  ];

  /// Retired theme ids and the theme that replaced them, for styles saved before the change.
  static const Map<String, String> renamedThemes = {'retro70s': 'retro90s'};

  /// Tastes that suggest each theme, to pick a fitting default before the player chooses one.
  static const Map<String, List<String>> themeHints = {
    'metal': ['music_rock_metal', 'cinema_horror', 'game_souls'],
    'forest': ['vacation_cabin', 'vibe_adventurer', 'pet_dog', 'life_photography'],
    'coquette': ['anime_romance', 'life_art', 'cinema_sitcoms'],
    'cafe': ['fuel_coffee', 'life_coffee_tea', 'life_books', 'music_lofi', 'music_jazz'],
    'arcade': ['plat_pc', 'plat_playstation', 'plat_xbox', 'plat_nintendo', 'game_mmo', 'game_roguelike', 'music_synthwave', 'fuel_energy'],
    'mystic': ['cinema_fantasy', 'anime_isekai', 'game_rpg', 'game_tabletop'],
    'matcha': ['fuel_tea', 'pet_plants', 'life_plants', 'life_fitness', 'vibe_early_bird'],
    'retro90s': ['anime_classics', 'cinema_cult', 'music_indie', 'music_instruments'],
    'mono': ['vibe_urban_walks', 'vacation_city', 'intent_serious'],
    'coast': ['vacation_beach', 'fuel_water', 'pet_exotic'],
  };

  final String themeId;

  /// Accent colour; null uses the theme's first suggested accent.
  final Color? accent;

  /// One line on the character face (at most [maxPhraseLength] characters).
  final String phrase;

  /// Taste ids shown on the character face, in order (up to [maxFeaturedTastes]).
  final List<String> featuredTastes;

  /// Tastes that can be featured: everything but the dating intent, which the character face does
  /// not show.
  static bool canFeature(String tasteId) => !tasteId.startsWith('intent_');

  /// The theme whose hints match most of [tastes] ([defaultTheme] when none does; ties go to the
  /// earlier theme).
  static String suggestedTheme(List<String> tastes) {
    var best = defaultTheme;
    var bestScore = 0;
    for (final id in themeIds) {
      final score = themeHints[id]!.where(tastes.contains).length;
      if (score > bestScore) {
        best = id;
        bestScore = score;
      }
    }
    return best;
  }

  /// The style a player gets before choosing one: a theme suggested by their tastes and their
  /// first [defaultFeaturedTastes] featurable tastes.
  factory ProfileCardStyle.defaultFor(List<String> tastes) => ProfileCardStyle(
        themeId: suggestedTheme(tastes),
        featuredTastes: tastes.where(canFeature).take(defaultFeaturedTastes).toList(),
      );

  /// This style made valid for [tastes]: a known theme, a phrase within the limit, and featured
  /// tastes the player still has (at least one when they have any to feature).
  ProfileCardStyle normalizedFor(List<String> tastes) {
    final kept = <String>[
      for (final t in featuredTastes)
        if (tastes.contains(t) && canFeature(t)) t,
    ].toSet().take(maxFeaturedTastes).toList();
    final featurable = tastes.where(canFeature).toList();
    return ProfileCardStyle(
      themeId: themeIds.contains(themeId) ? themeId : suggestedTheme(tastes),
      accent: accent,
      phrase: _clip(phrase),
      featuredTastes: kept.isEmpty ? featurable.take(defaultFeaturedTastes).toList() : kept,
    );
  }

  static String _clip(String text) {
    final trimmed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final chars = trimmed.characters;
    return chars.length <= maxPhraseLength ? trimmed : chars.take(maxPhraseLength).toString().trimRight();
  }

  ProfileCardStyle copyWith({
    String? themeId,
    Color? accent,
    bool clearAccent = false,
    String? phrase,
    List<String>? featuredTastes,
  }) {
    return ProfileCardStyle(
      themeId: themeId ?? this.themeId,
      accent: clearAccent ? null : (accent ?? this.accent),
      phrase: phrase ?? this.phrase,
      featuredTastes: featuredTastes ?? this.featuredTastes,
    );
  }

  Map<String, dynamic> toMap() => {
        'themeId': themeId,
        if (accent != null) 'accent': '#${accent!.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
        if (phrase.isNotEmpty) 'phrase': phrase,
        'featuredTastes': featuredTastes,
      };

  String toJson() => jsonEncode(toMap());

  /// Tolerant of missing or malformed fields: anything unreadable falls back to the defaults.
  factory ProfileCardStyle.fromMap(Map<String, dynamic> map) {
    Color? accent;
    final rawAccent = map['accent'];
    if (rawAccent is String) {
      final hex = rawAccent.replaceFirst('#', '');
      final value = int.tryParse(hex, radix: 16);
      if (value != null && hex.length == 6) accent = Color(0xFF000000 | value);
    }
    final rawTastes = map['featuredTastes'];
    final rawTheme = map['themeId'] is String ? map['themeId'] as String : defaultTheme;
    return ProfileCardStyle(
      themeId: renamedThemes[rawTheme] ?? rawTheme,
      accent: accent,
      phrase: map['phrase'] is String ? _clip(map['phrase'] as String) : '',
      featuredTastes: rawTastes is List ? [for (final t in rawTastes) if (t is String) t] : const [],
    );
  }

  /// [source] as sent by the server: a JSON string (or an already decoded map); null when absent
  /// or unreadable.
  static ProfileCardStyle? tryParse(Object? source) {
    try {
      if (source is String && source.isNotEmpty && source != '{}') {
        final decoded = jsonDecode(source);
        if (decoded is Map<String, dynamic>) return ProfileCardStyle.fromMap(decoded);
      } else if (source is Map<String, dynamic>) {
        return ProfileCardStyle.fromMap(source);
      }
    } catch (_) {}
    return null;
  }

  @override
  List<Object?> get props => [themeId, accent, phrase, featuredTastes];
}
