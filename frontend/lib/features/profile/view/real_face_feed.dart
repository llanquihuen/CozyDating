import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/profile_card_style.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/widgets/fullscreen_photo_viewer.dart';
import '../../avatar/widgets/avatar_still_image.dart';
import '../card/card_parts.dart';
import '../card/card_themes.dart';
import 'card_sections.dart';

/// The real face at full screen, as a vertical feed (like Hinge): the main photo with name, age,
/// place and featured tastes, then the bio, lifestyle and tastes with the other photos in between.
/// Empty blocks are left out.
class RealFaceFeed extends StatelessWidget {
  const RealFaceFeed({
    super.key,
    required this.profile,
    required this.style,
    required this.theme,
    this.distanceKm,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final UserProfile profile;
  final ProfileCardStyle style;
  final ProfileCardTheme theme;
  final double? distanceKm;
  final double topInset;
  final double bottomInset;

  /// The feed's blocks after the main photo, in order: 'bio', 'lifestyle', 'tastes' (the ones the
  /// profile has) with 'photo:<index>' between them and the leftover photos at the end.
  static List<String> layout(UserProfile profile) {
    final blocks = [
      if (profile.bio.trim().isNotEmpty) 'bio',
      if (profile.lifestyle.activeBadges.isNotEmpty) 'lifestyle',
      if (profile.tastes.any(ProfileCardStyle.canFeature)) 'tastes',
    ];
    final photos = profile.allPhotos.length;
    var next = 1;
    final out = <String>[];
    for (final b in blocks) {
      out.add(b);
      if (next < photos) out.add('photo:${next++}');
    }
    while (next < photos) {
      out.add('photo:${next++}');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final accent = theme.accentOf(style);
    final photos = profile.allPhotos;
    void openPhoto(int index) =>
        FullScreenPhotoViewer.open(context, photos: photos, initialIndex: index, title: profile.username);

    Widget block(String id) {
      if (id.startsWith('photo:')) {
        final i = int.parse(id.substring(6));
        return FeedPhoto(url: photos[i], onTap: () => openPhoto(i));
      }
      switch (id) {
        case 'bio':
          return CardSection(
            theme: theme,
            title: 'Sobre mí',
            child: Text(profile.bio.trim(), style: const TextStyle(fontSize: 15, height: 1.45)),
          );
        case 'lifestyle':
          return CardSection(
            theme: theme,
            title: 'Estilo de vida',
            child: LifestyleGrid(badges: profile.lifestyle.activeBadges, theme: theme),
          );
        default:
          return CardSection(
            theme: theme,
            title: 'Gustos',
            child:
                TastesByCategory(tastes: profile.tastes, featured: style.featuredTastes, theme: theme, accent: accent),
          );
      }
    }

    final rest = layout(profile);
    return LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: math.max(constraints.maxHeight * (rest.isEmpty ? 1 : 0.86), 440),
              child: RealFaceCover(
                profile: profile,
                style: style,
                theme: theme,
                accent: accent,
                distanceKm: distanceKm,
                topInset: topInset,
                showHint: rest.isNotEmpty,
                onTap: photos.isEmpty ? null : () => openPhoto(0),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverList.list(children: [for (final id in rest) block(id)]),
          SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),
        ],
      ),
    );
  }
}

/// The real face's first screen: the main photo with name, age, place and featured tastes.
class RealFaceCover extends StatelessWidget {
  const RealFaceCover({
    super.key,
    required this.profile,
    required this.style,
    required this.theme,
    required this.accent,
    required this.topInset,
    required this.showHint,
    this.distanceKm,
    this.onTap,
  });

  final UserProfile profile;
  final ProfileCardStyle style;
  final ProfileCardTheme theme;
  final Color accent;
  final double topInset;
  final bool showHint;
  final double? distanceKm;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    const white = Colors.white;
    final place = [
      if (p.commune.isNotEmpty) p.commune,
      if (distanceKm != null) 'a ${distanceKm!.round()} km',
    ].join(' · ');
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: onTap,
            child: p.allPhotos.isEmpty ? NoPhoto(theme: theme) : ProfilePhoto(url: p.allPhotos.first),
          ),
          // The theme's base colour rises behind the text, like a dating app's photo shade.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.16, 0.5, 0.78, 1],
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0),
                    theme.base.withValues(alpha: 0),
                    theme.base.withValues(alpha: 0.85),
                    theme.base,
                  ],
                ),
              ),
            ),
          ),
          // The avatar as a small seal: the same person as on the other face.
          Positioned(
            top: topInset + 8,
            left: 16,
            child: Container(
              width: 52,
              height: 52,
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
                          style: const TextStyle(color: white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
                        ),
                      ),
                      if (p.isVerified) ...[
                        const SizedBox(width: 8),
                        const VerifiedBadge(color: Color(0xFF3B82F6), tick: white, size: 24),
                      ],
                    ],
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.place_outlined, size: 16, color: white.withValues(alpha: 0.8)),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (style.featuredTastes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in style.featuredTastes)
                          TasteChip(
                            tasteId: t,
                            fill: white.withValues(alpha: 0.14),
                            textColor: white,
                            border: accent.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                      ],
                    ),
                  ],
                  if (showHint) ...[
                    const SizedBox(height: 14),
                    Center(child: ScrollHint(label: 'Desliza para ver más', color: white.withValues(alpha: 0.8))),
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
