import 'package:flutter/material.dart';

import '../../../core/models/profile_card_style.dart';

/// Ornaments drawn on the character face's frame (the real face only gets a thin accent rim).
enum CardFrame { studs, wood, bows, plain, neon, stars, stripes, thin, rope }

/// A profile card theme: the colours both faces share and the character face's frame.
class ProfileCardTheme {
  const ProfileCardTheme({
    required this.id,
    required this.name,
    required this.base,
    required this.panel,
    required this.accents,
    required this.frame,
    this.secondFrameColor,
  });

  final String id;
  final String name;

  /// Card background (character face) and the gradient under the text (real face).
  final Color base;

  /// Panel behind the avatar on the character face.
  final Color panel;

  /// Suggested accent colours; the first is the default.
  final List<Color> accents;
  final CardFrame frame;

  /// Second ornament colour (studs, stripes...); defaults to the second accent.
  final Color? secondFrameColor;

  static const Color _dark = Color(0xFF231914);
  static const Color _light = Color(0xFFF5F2EC);

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return la > lb ? (la + 0.05) / (lb + 0.05) : (lb + 0.05) / (la + 0.05);
  }

  /// Whichever of the dark and light text colours reads better on [background].
  static Color textOn(Color background) =>
      _contrast(_dark, background) >= _contrast(_light, background) ? _dark : _light;

  /// Text on [base].
  Color get text => textOn(base);

  /// Secondary text on [base] (phrase, captions).
  Color get mutedText => Color.lerp(text, base, 0.3)!;

  /// An accent-tinted chip: 30% accent over the base, less when that mid tone would leave the
  /// text below 4.5:1 contrast.
  Color chipFill(Color accent) {
    for (final t in const [0.30, 0.22, 0.15, 0.08]) {
      final fill = Color.lerp(base, accent, t)!;
      if (_contrast(textOn(fill), fill) >= 4.5) return fill;
    }
    return base;
  }

  Color chipText(Color accent) => textOn(chipFill(accent));

  /// The tick drawn on a filled [accent] (the verified badge): the base colour or white, whichever
  /// reads better.
  Color onAccent(Color accent) => _contrast(base, accent) >= _contrast(Colors.white, accent) ? base : Colors.white;

  Color frameSecond(Color accent) => secondFrameColor ?? (accents.length > 1 ? accents[1] : accent);

  /// [style]'s accent, or this theme's default.
  Color accentOf(ProfileCardStyle style) => style.accent ?? accents.first;
}

/// The ten themes, in [ProfileCardStyle.themeIds] order.
const List<ProfileCardTheme> cardThemes = [
  ProfileCardTheme(
    id: 'metal',
    name: 'Metal / Goth',
    base: Color(0xFF141016),
    panel: Color(0xFF3B1F4F),
    accents: [Color(0xFFB3122E), Color(0xFFC0C0C8)],
    frame: CardFrame.studs,
  ),
  ProfileCardTheme(
    id: 'forest',
    name: 'Rústico / Forest',
    base: Color(0xFF3F4F22),
    panel: Color(0xFF5C3D2E),
    accents: [Color(0xFFCC8B2C), Color(0xFFB5651D)],
    frame: CardFrame.wood,
  ),
  ProfileCardTheme(
    id: 'coquette',
    name: 'Pink Lady / Coquette',
    base: Color(0xFF6E3B5C),
    panel: Color(0xFFE8B4C8),
    accents: [Color(0xFFFF6FAE), Color(0xFFE6C68A)],
    frame: CardFrame.bows,
  ),
  ProfileCardTheme(
    id: 'cafe',
    name: 'Café de Especialidad',
    base: Color(0xFF3B2416),
    panel: Color(0xFFE7DCC8),
    accents: [Color(0xFFA0663A), Color(0xFFC68B3E)],
    frame: CardFrame.plain,
  ),
  ProfileCardTheme(
    id: 'arcade',
    name: 'Arcade / Cyberpunk',
    base: Color(0xFF0B0F2A),
    panel: Color(0xFF1A1F4A),
    accents: [Color(0xFF00F0FF), Color(0xFFFF2BD6)],
    frame: CardFrame.neon,
  ),
  ProfileCardTheme(
    id: 'mystic',
    name: 'Místico / Brujita',
    base: Color(0xFF1B1D4A),
    panel: Color(0xFF2C2F6B),
    accents: [Color(0xFFE3C567), Color(0xFFB9A3E3)],
    frame: CardFrame.stars,
  ),
  ProfileCardTheme(
    id: 'matcha',
    name: 'Matcha / Zen',
    base: Color(0xFF59744D),
    panel: Color(0xFFC5E1A5),
    accents: [Color(0xFFF3E9A2), Color(0xFFC5E1A5)],
    frame: CardFrame.plain,
  ),
  ProfileCardTheme(
    id: 'retro70s',
    name: 'Retro 70s / Vinyl',
    base: Color(0xFF8E4428),
    panel: Color(0xFFD9A520),
    accents: [Color(0xFFD9A520), Color(0xFFCC5500)],
    frame: CardFrame.stripes,
  ),
  ProfileCardTheme(
    id: 'mono',
    name: 'Monocromo Elegante',
    base: Color(0xFF0E0E0E),
    panel: Color(0xFF2A2A2A),
    accents: [Color(0xFFC9CCD1), Color(0xFFFFFFFF)],
    frame: CardFrame.thin,
  ),
  ProfileCardTheme(
    id: 'coast',
    name: 'Costa / Marino',
    base: Color(0xFF0F4C5C),
    panel: Color(0xFF1D6F80),
    accents: [Color(0xFF87CEEB), Color(0xFFF7D046)],
    frame: CardFrame.rope,
  ),
];

/// Extra accents offered with every theme, after its own.
const List<Color> sharedCardAccents = [
  Color(0xFFFFFFFF),
  Color(0xFFF4C542),
  Color(0xFFFF7A59),
  Color(0xFFE11D48),
  Color(0xFF34D399),
  Color(0xFF60A5FA),
  Color(0xFFA78BFA),
];

ProfileCardTheme cardThemeOf(String id) =>
    cardThemes.firstWhere((t) => t.id == id, orElse: () => cardThemeOf(ProfileCardStyle.defaultTheme));
