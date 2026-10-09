import 'package:flutter/material.dart';

/// The pixel-art stage behind the avatar on the fullscreen character face: one scene per card
/// theme, made by `CreateSprites/card_scenes/make_scenes.py` at the avatar's pixel scale.
class CardScene {
  const CardScene._();

  /// Scene size in pixels (the same pixels as the 64x128 avatar sprite).
  static const Size size = Size(160, 288);

  /// Row of the scene where the avatar's feet stand (on the floor, a little below its far edge).
  static const double floorY = 214;

  static String assetFor(String themeId) => 'assets/images/card_scenes/$themeId.png';
}

/// [CardScene] for [themeId] drawn at an integer [scale] so its pixels match the avatar's, placed
/// so its floor row lands on [feetY] and centred horizontally. Where it does not reach (a very
/// tall or wide screen) the [fallback] colour shows; without the asset, only the fallback.
class CardSceneView extends StatelessWidget {
  const CardSceneView({
    super.key,
    required this.themeId,
    required this.scale,
    required this.feetY,
    required this.fallback,
  });

  final String themeId;
  final int scale;
  final double feetY;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    final w = CardScene.size.width * scale, h = CardScene.size.height * scale;
    return LayoutBuilder(
      builder: (context, c) => ColoredBox(
        color: fallback,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: ((c.maxWidth - w) / 2).roundToDouble(),
              top: (feetY - CardScene.floorY * scale).roundToDouble(),
              width: w,
              height: h,
              child: Image.asset(
                CardScene.assetFor(themeId),
                width: w,
                height: h,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
