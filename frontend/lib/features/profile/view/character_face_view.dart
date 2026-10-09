import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/profile_card_style.dart';
import '../../../core/models/user_profile.dart';
import '../../avatar/widgets/avatar_still_image.dart';
import '../card/card_frame_painter.dart';
import '../card/card_parts.dart';
import '../card/card_scene.dart';
import '../card/card_themes.dart';
import 'card_sections.dart';
import 'pixel_motion.dart';

/// The character face at full screen: the avatar on its stage, the phrase in a speech bubble and
/// the featured tastes on pixel plaques; scrolling down shows all the tastes. Nothing here reveals
/// age, place, bio or photos.
class CharacterFaceView extends StatelessWidget {
  const CharacterFaceView({
    super.key,
    required this.profile,
    required this.style,
    required this.theme,
    this.avatarHeroTag,
    this.topInset = 0,
    this.bottomInset = 0,
  });

  final UserProfile profile;
  final ProfileCardStyle style;
  final ProfileCardTheme theme;
  final Object? avatarHeroTag;

  /// Space covered by the floating top bar and the bottom action.
  final double topInset;
  final double bottomInset;

  /// The part of the 64x128 sprite canvas shown, the same as on the compact card (so the avatar
  /// lands where it flew from).
  static const Rect avatarCrop = Rect.fromLTRB(4, 6, 60, 124);

  @override
  Widget build(BuildContext context) {
    final accent = theme.accentOf(style);
    final groups = TastesByCategory.groups(profile.tastes, style.featuredTastes);
    final hasMore = profile.tastes.where(ProfileCardStyle.canFeature).length > style.featuredTastes.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stageHeight = math.max(constraints.maxHeight - (hasMore ? 44 : 0), 420.0);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: stageHeight,
                child: CharacterStage(
                  profile: profile,
                  style: style,
                  theme: theme,
                  accent: accent,
                  avatarHeroTag: avatarHeroTag,
                  topInset: topInset,
                  hint: hasMore ? 'Desliza para ver sus gustos' : null,
                ),
              ),
            ),
            if (groups.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: CardSection(
                    theme: theme,
                    title: 'Gustos',
                    child: TastesByCategory(
                      tastes: profile.tastes,
                      featured: style.featuredTastes,
                      theme: theme,
                      accent: accent,
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(child: SizedBox(height: bottomInset + 24)),
          ],
        );
      },
    );
  }
}

/// The character on its theme's scene: name plate, speech bubble, plaques and corner ornaments.
/// Fills the screen on the fullscreen card; [fixedScale] draws a smaller preview (the editor).
class CharacterStage extends StatelessWidget {
  const CharacterStage({
    super.key,
    required this.profile,
    required this.style,
    required this.theme,
    required this.accent,
    this.topInset = 0,
    this.avatarHeroTag,
    this.hint,
    this.fixedScale,
  });

  final UserProfile profile;
  final ProfileCardStyle style;
  final ProfileCardTheme theme;
  final Color accent;
  final double topInset;
  final Object? avatarHeroTag;
  final String? hint;
  final int? fixedScale;

  /// The panel behind the avatar stands out from the base even when the theme's panel colour is
  /// close to it (as on the compact card).
  Color get _panel {
    final diff = (theme.panel.computeLuminance() - theme.base.computeLuminance()).abs();
    return diff > 0.03 ? theme.panel : Color.lerp(theme.base, accent, 0.18)!;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        // Whole pixels only: the sprite is drawn at an integer scale so pixel art stays crisp.
        const crop = CharacterFaceView.avatarCrop;
        // The smallest whole scale at which the scene covers the stage; the avatar shares it.
        final scale = fixedScale ??
            math.max(1, math.max((w / CardScene.size.width).ceil(), (h / CardScene.size.height).ceil()));
        final avatarW = crop.width * scale, avatarH = crop.height * scale;
        // Feet near 72% of the height, kept where the scene still reaches the top and bottom edges.
        final low = h - (CardScene.size.height - CardScene.floorY) * scale, high = CardScene.floorY * scale;
        final feetY = (low <= high ? (h * 0.72).clamp(low, high) : h * 0.72).roundToDouble();
        final avatarTop = feetY - avatarH;
        final roomAboveHead = avatarTop - topInset > 110;
        final avatarLeft = (w - avatarW) / 2;
        final avatar = SizedBox(
          width: avatarW,
          height: avatarH,
          child: AvatarStillImage(config: profile.avatarConfig, crop: crop, fit: BoxFit.fill),
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: CardSceneView(themeId: theme.id, scale: scale, feetY: feetY, fallback: _panel),
            ),
            Positioned.fill(
              child: SceneParticles(
                kind: SceneParticles.kindFor(theme.id),
                color: SceneParticles.kindFor(theme.id) == ParticleKind.hearts ? accent : const Color(0xFFFFE9A8),
                scale: scale,
              ),
            ),
            // Shades the top and bottom edges so the name and the plaques read over any scene.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.16, 0.74, 1],
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0),
                        theme.base.withValues(alpha: 0),
                        theme.base,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The avatar's shadow on the floor.
            Positioned(
              left: w / 2 - avatarW * 0.38,
              top: feetY - 7,
              child: Container(
                width: avatarW * 0.76,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.all(Radius.elliptical(avatarW * 0.38, 6)),
                ),
              ),
            ),
            Positioned(
              left: avatarLeft,
              top: avatarTop,
              child: StepBob(
                step: scale.toDouble(),
                period: const Duration(milliseconds: 900),
                child: avatarHeroTag == null ? avatar : Hero(tag: avatarHeroTag!, child: avatar),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              top: topInset + 10,
              child: Align(
                  alignment: Alignment.centerLeft, child: _NamePlate(profile: profile, theme: theme, accent: accent)),
            ),
            if (style.phrase.isNotEmpty)
              Positioned(
                // Above the head when there is room under the name plate; beside the face if not.
                left: roomAboveHead ? math.min(w / 2 + avatarW * 0.12, w - 190) : math.min(w / 2 + avatarW * 0.26, w - 140),
                right: 12,
                bottom: roomAboveHead ? h - avatarTop - avatarH * 0.08 : h - avatarTop - avatarH * 0.24,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: StepBob(
                    step: scale.toDouble(),
                    period: const Duration(milliseconds: 1300),
                    delay: const Duration(milliseconds: 400),
                    child: _SpeechBubble(text: style.phrase),
                  ),
                ),
              ),
            if (style.featuredTastes.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                top: feetY + 22,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (i, t) in style.featuredTastes.indexed)
                      StepBob(
                        step: scale.toDouble(),
                        period: const Duration(milliseconds: 1500),
                        delay: Duration(milliseconds: 500 * i),
                        child: _Plaque(tasteId: t, theme: theme, accent: accent),
                      ),
                  ],
                ),
              ),
            if (hint != null)
              Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: Center(child: ScrollHint(label: hint!, color: theme.mutedText))),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: CardFramePainter(
                    frame: theme.frame,
                    accent: accent,
                    second: theme.frameSecond(accent),
                    cornersOnly: true,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Name and seal on a framed plate with a hard pixel shadow.
class _NamePlate extends StatelessWidget {
  const _NamePlate({required this.profile, required this.theme, required this.accent});

  final UserProfile profile;
  final ProfileCardTheme theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 7),
      decoration: BoxDecoration(
        color: theme.base.withValues(alpha: 0.9),
        border: Border.all(color: accent, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x73000000), offset: Offset(3, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              profile.username,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.text, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1),
            ),
          ),
          if (profile.isVerified) ...[
            const SizedBox(width: 8),
            VerifiedBadge(color: accent, tick: theme.onAccent(accent)),
          ],
        ],
      ),
    );
  }
}

/// The card's phrase, said by the avatar: a pixel speech bubble with a hard outline.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});

  final String text;

  static const Color _paper = Color(0xFFFBF7EE);
  static const Color _ink = Color(0xFF2A1F18);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 190),
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
          decoration: BoxDecoration(
            color: _paper,
            border: Border.all(color: _ink, width: 3),
            boxShadow: const [BoxShadow(color: Color(0x40000000), offset: Offset(3, 3))],
          ),
          child:
              Text(text, style: const TextStyle(color: _ink, fontSize: 14, height: 1.2, fontWeight: FontWeight.w600)),
        ),
        // The tail, pointing down-left at the avatar's head; it overlaps the bubble's bottom border.
        Transform.translate(
          offset: const Offset(10, -3),
          child: const CustomPaint(size: Size(15, 12), painter: _TailPainter(paper: _paper, ink: _ink)),
        ),
      ],
    );
  }
}

/// A stepped pixel tail: three rows getting narrower, ink outlined.
class _TailPainter extends CustomPainter {
  const _TailPainter({required this.paper, required this.ink});

  final Color paper;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final inkPaint = Paint()..color = ink;
    final paperPaint = Paint()..color = paper;
    // Rows of 3 px: ink outline, then paper inside (the top row opens into the bubble).
    canvas.drawRect(const Rect.fromLTWH(0, 0, 15, 3), paperPaint);
    canvas.drawRect(const Rect.fromLTWH(0, 0, 3, 6), inkPaint);
    canvas.drawRect(const Rect.fromLTWH(12, 0, 3, 3), inkPaint);
    canvas.drawRect(const Rect.fromLTWH(3, 3, 6, 3), paperPaint);
    canvas.drawRect(const Rect.fromLTWH(9, 3, 3, 3), inkPaint);
    canvas.drawRect(const Rect.fromLTWH(0, 6, 9, 3), inkPaint);
    canvas.drawRect(const Rect.fromLTWH(3, 6, 3, 3), paperPaint);
    canvas.drawRect(const Rect.fromLTWH(0, 9, 6, 3), inkPaint);
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.paper != paper || old.ink != ink;
}

/// A featured taste on a square plate: accent border and a hard shadow, no blur.
class _Plaque extends StatelessWidget {
  const _Plaque({required this.tasteId, required this.theme, required this.accent});

  final String tasteId;
  final ProfileCardTheme theme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fill = theme.chipFill(accent);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: accent, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x73000000), offset: Offset(3, 3))],
      ),
      child: TasteChip(tasteId: tasteId, fill: fill, textColor: theme.chipText(accent), fontSize: 13.5, radius: 0),
    );
  }
}
