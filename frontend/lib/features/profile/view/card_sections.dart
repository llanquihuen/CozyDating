import 'package:flutter/material.dart';

import '../../../core/models/lifestyle_badges.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/models/profile_card_style.dart';
import '../card/card_parts.dart';
import '../card/card_themes.dart';

/// The blocks a fullscreen profile card scrolls through, in the card theme's colours.

/// A titled block on a surface slightly lighter than the theme's base.
class CardSection extends StatelessWidget {
  const CardSection({super.key, required this.theme, required this.title, required this.child});

  final ProfileCardTheme theme;
  final String title;
  final Widget child;

  /// A shade lighter than the base; on mid-tone bases (Matcha) a darker one, so text reads at 4.5:1.
  static Color surfaceOf(ProfileCardTheme theme) {
    double contrast(Color c) {
      final a = ProfileCardTheme.textOn(c).computeLuminance(), b = c.computeLuminance();
      return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
    }

    final lighter = Color.lerp(theme.base, Colors.white, 0.08)!;
    if (contrast(lighter) >= 4.5) return lighter;
    for (var t = 0.1; t < 0.5; t += 0.05) {
      final darker = Color.lerp(theme.base, Colors.black, t)!;
      if (contrast(darker) >= 4.5) return darker;
    }
    return Color.lerp(theme.base, Colors.black, 0.5)!;
  }

  @override
  Widget build(BuildContext context) {
    final surface = surfaceOf(theme);
    final text = ProfileCardTheme.textOn(surface);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: text),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: TextStyle(
                color: text.withValues(alpha: 0.62),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

/// Tastes grouped by their catalog category; the featured ones come first in each group, filled
/// with the accent. The dating intent is left out (as on the character face).
class TastesByCategory extends StatelessWidget {
  const TastesByCategory({
    super.key,
    required this.tastes,
    required this.featured,
    required this.theme,
    required this.accent,
  });

  final List<String> tastes;
  final List<String> featured;
  final ProfileCardTheme theme;
  final Color accent;

  /// Category titles as a third person reads them (the catalog's speak to the player: "Tu ...").
  static const Map<String, String> _titles = {
    'social_battery': 'Batería social',
    'life_rhythm': 'Ritmo diario',
    'weekend_vibe': 'Fin de semana',
    'gaming_platform': 'Plataformas',
    'daily_fuel': 'Combustible diario',
    'pets_dilemma': 'Mascotas',
    'dream_vacation': 'Escapada soñada',
    'gaming': 'Juegos',
    'music': 'Música',
    'cinema': 'Cine y series',
    'anime': 'Anime y manga',
    'lifestyle': 'Pasatiempos',
  };

  /// [tastes] grouped by category, in catalog order: (category, its tastes, featured first).
  static List<(PreferenceCategory, List<String>)> groups(List<String> tastes, List<String> featured) {
    final owned = tastes.where(ProfileCardStyle.canFeature).toSet();
    return [
      for (final category in PreferenceCatalog.categories)
        if (category.items.any((i) => owned.contains(i.id)))
          (
            category,
            [
              ...category.items.map((i) => i.id).where((id) => owned.contains(id) && featured.contains(id)),
              ...category.items.map((i) => i.id).where((id) => owned.contains(id) && !featured.contains(id)),
            ],
          ),
    ];
  }

  /// A taste chip on [surface]: up to 22% [accent], less when its text would read below 4.5:1.
  static Color chipFill(Color surface, Color accent) {
    for (final t in const [0.22, 0.15, 0.08]) {
      final fill = Color.lerp(surface, accent, t)!;
      final a = ProfileCardTheme.textOn(fill).computeLuminance(), b = fill.computeLuminance();
      if ((a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05) >= 4.5) return fill;
    }
    return surface;
  }

  /// [color], darkened or lightened just enough for its text to read at 4.5:1.
  static Color readableFill(Color color) {
    double contrast(Color c) {
      final a = ProfileCardTheme.textOn(c).computeLuminance(), b = c.computeLuminance();
      return (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
    }

    // Light text reads better on a darker fill, dark text on a lighter one.
    final toward = ProfileCardTheme.textOn(color).computeLuminance() > 0.5 ? Colors.black : Colors.white;
    for (var t = 0.0; t <= 0.6; t += 0.05) {
      final c = Color.lerp(color, toward, t)!;
      if (contrast(c) >= 4.5) return c;
    }
    return Color.lerp(color, toward, 0.6)!;
  }

  @override
  Widget build(BuildContext context) {
    final surface = CardSection.surfaceOf(theme);
    final text = ProfileCardTheme.textOn(surface);
    final featuredFill = readableFill(accent);
    final onFeatured = ProfileCardTheme.textOn(featuredFill);
    final chip = chipFill(surface, accent);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (category, ids)) in groups(tastes, featured).indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          Text(
            '${category.emoji} ${_titles[category.id] ?? category.title}',
            style: TextStyle(color: text.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final id in ids)
                featured.contains(id)
                    ? TasteChip(tasteId: id, fill: featuredFill, textColor: onFeatured, fontSize: 13)
                    : TasteChip(tasteId: id, fill: chip, textColor: ProfileCardTheme.textOn(chip), fontSize: 13),
            ],
          ),
        ],
      ],
    );
  }
}

/// The lifestyle badges in two columns.
class LifestyleGrid extends StatelessWidget {
  const LifestyleGrid({super.key, required this.badges, required this.theme});

  final List<BadgeDisplayItem> badges;
  final ProfileCardTheme theme;

  @override
  Widget build(BuildContext context) {
    final surface = CardSection.surfaceOf(theme);
    final tile = Color.lerp(surface, Colors.white, 0.07)!;
    final text = ProfileCardTheme.textOn(tile);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final b in badges)
              Container(
                width: width,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(color: tile, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${b.icon} ${b.label}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A large photo between the blocks of the real face.
class FeedPhoto extends StatelessWidget {
  const FeedPhoto({super.key, required this.url, required this.onTap});

  final String url;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(aspectRatio: 4 / 5, child: ProfilePhoto(url: url)),
        ),
      ),
    );
  }
}

/// "Desliza para ver más" with a down arrow, under the first screen of a face.
class ScrollHint extends StatelessWidget {
  const ScrollHint({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: color),
      ],
    );
  }
}
