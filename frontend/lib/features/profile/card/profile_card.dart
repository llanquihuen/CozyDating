import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/models/profile_card_style.dart';
import '../../../core/models/user_profile.dart';
import '../../avatar/widgets/avatar_still_image.dart';
import 'card_frame_painter.dart';
import 'card_themes.dart';

/// A player's two-sided profile card. The character face (avatar, phrase, featured tastes; a game
/// look with the theme's ornamented frame) is what others see before the campfire; [showReal]
/// flips it to the real face (photos, age, place, bio; a dating-app look in the same colours).
///
/// It is laid out at a fixed design size and scaled to the space it gets, so it looks the same on
/// every screen; system text scaling is capped inside the card.
class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.profile,
    this.style,
    this.showReal = false,
    this.distanceKm,
    this.flipDuration = const Duration(milliseconds: 650),
  });

  final UserProfile profile;

  /// Overrides the profile's own style (live previews while editing it).
  final ProfileCardStyle? style;
  final bool showReal;

  /// Shown next to the commune on the real face when known.
  final double? distanceKm;
  final Duration flipDuration;

  static const Size designSize = Size(300, 454);
  static const double aspectRatio = 300 / 454;

  @override
  Widget build(BuildContext context) {
    final cardStyle = (style ?? profile.effectiveCardStyle).normalizedFor(profile.tastes);
    final theme = cardThemeOf(cardStyle.themeId);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: FittedBox(
        child: SizedBox.fromSize(
          size: designSize,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.15,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: showReal ? 1 : 0),
              duration: flipDuration,
              curve: Curves.easeInOutCubic,
              builder: (context, t, _) {
                final angle = t * math.pi;
                final realSide = angle > math.pi / 2;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012)
                    ..rotateY(angle),
                  child: realSide
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.rotationY(math.pi),
                          child: _RealFace(profile: profile, style: cardStyle, theme: theme, distanceKm: distanceKm),
                        )
                      : _CharacterFace(profile: profile, style: cardStyle, theme: theme),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A taste chip: emoji and short title.
class _TasteChip extends StatelessWidget {
  const _TasteChip({required this.tasteId, required this.fill, required this.textColor, this.border});

  final String tasteId;
  final Color fill;
  final Color textColor;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final item = PreferenceCatalog.getItem(tasteId);
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        border: border == null ? null : Border.all(color: border!, width: 1.2),
      ),
      child: Text(
        '${item?.emoji ?? '✨'} ${PreferenceCatalog.shortTitle(tasteId)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// The verified-identity seal: a tick in a filled circle.
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.color, required this.tick, this.size = 20});

  final Color color;
  final Color tick;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Identidad certificada',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(Icons.check, size: size * 0.72, color: tick),
      ),
    );
  }
}

class _CharacterFace extends StatelessWidget {
  const _CharacterFace({required this.profile, required this.style, required this.theme});

  final UserProfile profile;
  final ProfileCardStyle style;
  final ProfileCardTheme theme;

  @override
  Widget build(BuildContext context) {
    final accent = theme.accentOf(style);
    return Container(
      decoration: BoxDecoration(color: theme.base, borderRadius: BorderRadius.circular(18)),
      child: CustomPaint(
        foregroundPainter: CardFramePainter(frame: theme.frame, accent: accent, second: theme.frameSecond(accent)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      profile.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.text, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (profile.isVerified) ...[
                    const SizedBox(width: 8),
                    _VerifiedBadge(color: accent, tick: theme.onAccent(accent)),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(color: _panelColor, borderRadius: BorderRadius.circular(14)),
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Positioned(
                        bottom: 10,
                        child: Container(
                          width: 120,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: const BorderRadius.all(Radius.elliptical(60, 7)),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 14),
                          child: AvatarStillImage(
                            config: profile.avatarConfig,
                            crop: const Rect.fromLTRB(4, 6, 60, 124),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (style.phrase.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '“${style.phrase}”',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.mutedText, fontSize: 14, fontStyle: FontStyle.italic, height: 1.25),
                ),
              ],
              if (style.featuredTastes.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in style.featuredTastes)
                      _TasteChip(tasteId: t, fill: theme.chipFill(accent), textColor: theme.chipText(accent)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The avatar panel stands out from the base even when the theme's panel colour is close to it.
  Color get _panelColor {
    final diff = (theme.panel.computeLuminance() - theme.base.computeLuminance()).abs();
    return diff > 0.03 ? theme.panel : Color.lerp(theme.base, theme.accentOf(style), 0.18)!;
  }
}

class _RealFace extends StatefulWidget {
  const _RealFace({required this.profile, required this.style, required this.theme, this.distanceKm});

  final UserProfile profile;
  final ProfileCardStyle style;
  final ProfileCardTheme theme;
  final double? distanceKm;

  @override
  State<_RealFace> createState() => _RealFaceState();
}

class _RealFaceState extends State<_RealFace> {
  int _photo = 0;

  List<String> get _photos => widget.profile.allPhotos;

  void _step(int delta) {
    final n = _photos.length;
    if (n < 2) return;
    setState(() => _photo = (_photo + delta).clamp(0, n - 1));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final theme = widget.theme;
    final accent = theme.accentOf(widget.style);
    final photos = _photos;
    final index = photos.isEmpty ? 0 : _photo.clamp(0, photos.length - 1);
    const white = Colors.white;
    final place = [
      if (p.commune.isNotEmpty) p.commune,
      if (widget.distanceKm != null) '${widget.distanceKm!.round()} km',
    ].join(' · ');
    final badges = p.lifestyle.activeBadges.take(3).map((b) => '${b.icon} ${b.label}').join('  ·  ');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.base,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accent.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            _NoPhoto(theme: theme)
          else
            _ProfilePhoto(url: photos[index], key: ValueKey(photos[index])),
          // The theme's base colour rises behind the text, like a dating app's photo shade.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.38, 0.72, 1],
                colors: [theme.base.withValues(alpha: 0), theme.base.withValues(alpha: 0.82), theme.base],
              ),
            ),
          ),
          // Tap the left or right half to change photo.
          if (photos.length > 1)
            Row(
              children: [
                Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _step(-1))),
                Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => _step(1))),
              ],
            ),
          if (photos.length > 1)
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  for (var i = 0; i < photos.length; i++)
                    Expanded(
                      child: Container(
                        height: 3.5,
                        margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                        decoration: BoxDecoration(
                          color: white.withValues(alpha: i == index ? 0.95 : 0.38),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          // The avatar as a small seal: the same person as on the other face.
          Positioned(
            top: 24,
            right: 14,
            child: Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              child: ClipOval(
                child: ColoredBox(
                  color: Color.lerp(theme.base, Colors.white, 0.15)!,
                  child: AvatarStillImage(config: p.avatarConfig, crop: const Rect.fromLTRB(12, 6, 52, 46)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${p.username}, ${p.age}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: white, fontSize: 27, fontWeight: FontWeight.w700, height: 1.1),
                        ),
                      ),
                      if (p.isVerified) ...[
                        const SizedBox(width: 8),
                        const _VerifiedBadge(color: Color(0xFF3B82F6), tick: white, size: 22),
                      ],
                    ],
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 15, color: white.withValues(alpha: 0.78)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: white.withValues(alpha: 0.78), fontSize: 13.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (p.bio.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      p.bio.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: white.withValues(alpha: 0.92), fontSize: 14, height: 1.3),
                    ),
                  ],
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      badges,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: white.withValues(alpha: 0.75), fontSize: 12),
                    ),
                  ],
                  if (widget.style.featuredTastes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in widget.style.featuredTastes.take(3))
                          _TasteChip(
                            tasteId: t,
                            fill: white.withValues(alpha: 0.14),
                            textColor: white,
                            border: accent.withValues(alpha: 0.9),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto({required this.theme});

  final ProfileCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(theme.base, Colors.white, 0.25)!, theme.base],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.6),
        child: Icon(Icons.person_rounded, size: 96, color: Colors.white.withValues(alpha: 0.22)),
      ),
    );
  }
}

/// A profile photo from the server (or a bundled asset), covering its box.
class _ProfilePhoto extends StatelessWidget {
  const _ProfilePhoto({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.resolveMediaUrl(url);
    Widget fallback(BuildContext _, Object __, StackTrace? ___) =>
        const ColoredBox(color: Color(0xFF1E293B), child: Center(child: Icon(Icons.person_outline, size: 60, color: Colors.white30)));
    if (resolved.startsWith('assets/')) {
      return Image.asset(resolved, fit: BoxFit.cover, errorBuilder: fallback);
    }
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(resolved, fit: BoxFit.cover, errorBuilder: fallback);
    }
    return fallback(context, '', null);
  }
}
