import 'dart:typed_data';
import 'dart:ui';

/// Eyeshadow and lipstick painted onto the loaded eye and mouth layers, so they fit every eye and
/// mouth style, standing or lying. Buffers are premultiplied RGBA, as returned by
/// `Image.toByteData(format: ImageByteFormat.rawRgba)` and read back by `decodeImageFromPixels`.
///
/// "Up" is the direction of the forehead in the sprite: (0, -1) standing; the lying views draw the
/// face rotated, see [lyingUp].
class FaceMakeup {
  static const List<int> standingUp = [0, -1];
  static const Map<String, List<int>> lyingUp = {
    'A': [1, -1],
    'B': [-1, 1],
  };

  /// Pixels just above the eye outline (index -> alpha), found on the raw colour-coded eye layer:
  /// every opaque pixel except brows (green) casts shadow on the pixels above it while they are
  /// transparent; smoky shadow goes one pixel further. Where a brow sits right on the lid, the shadow
  /// goes over the brow's bottom row instead (see [paint]).
  static Map<int, int> eyeshadowTargets(Uint8List rgba, int width, int height,
      {required List<int> up, required bool smoky}) {
    final targets = <int, int>{};
    final levels = smoky ? const [200, 110] : const [130];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (rgba[i + 3] == 0 || _isBrow(rgba, i)) continue;
        for (int step = 1; step <= levels.length; step++) {
          final tx = x + up[0] * step, ty = y + up[1] * step;
          if (tx < 0 || ty < 0 || tx >= width || ty >= height) break;
          final t = (ty * width + tx) * 4;
          final alpha = levels[step - 1];
          if (rgba[t + 3] != 0) {
            if (step == 1 && _isBrow(rgba, t) && (targets[t] ?? 0) < alpha) targets[t] = alpha;
            break;
          }
          if ((targets[t] ?? 0) < alpha) targets[t] = alpha;
        }
      }
    }
    return targets;
  }

  /// Composites [color] at [targets] (index -> alpha) over what is there (premultiplied source-over).
  static void paint(Uint8List rgba, Map<int, int> targets, Color color) {
    targets.forEach((i, alpha) {
      final keep = 1 - alpha / 255;
      rgba[i] = (color.red * alpha / 255 + rgba[i] * keep).round();
      rgba[i + 1] = (color.green * alpha / 255 + rgba[i + 1] * keep).round();
      rgba[i + 2] = (color.blue * alpha / 255 + rgba[i + 2] * keep).round();
      rgba[i + 3] = (alpha + rgba[i + 3] * keep).round();
    });
  }

  /// Colours the lips of a mouth layer: its dark outline (or every pixel, for mouths drawn with
  /// coloured lips and no outline). Bold lipstick also fills a lower lip below the outline.
  /// Teeth, tongue and the inside of open mouths are left alone.
  static void paintLipstick(Uint8List rgba, int width, int height,
      {required List<int> up, required Color color, required bool bold}) {
    final lips = <int>[];
    final opaque = <int>[];
    for (int i = 0; i < rgba.length; i += 4) {
      final a = rgba[i + 3];
      if (a == 0) continue;
      opaque.add(i);
      final r = rgba[i] * 255 ~/ a, g = rgba[i + 1] * 255 ~/ a, b = rgba[i + 2] * 255 ~/ a;
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final spread = [r, g, b].reduce((m, v) => v > m ? v : m) - [r, g, b].reduce((m, v) => v < m ? v : m);
      if (lum < 95 && spread < 35) lips.add(i);
    }
    final targets = lips.isEmpty ? opaque : lips;
    final mix = bold ? 0.85 : 0.6;
    final lower = <int>[];
    for (final i in targets) {
      final a = rgba[i + 3];
      final shade = bold && lips.isNotEmpty ? 0.75 : 1.0;
      for (int c = 0; c < 3; c++) {
        final orig = rgba[i + c] * 255 / a;
        final tint = [color.red, color.green, color.blue][c] * shade;
        rgba[i + c] = ((orig * (1 - mix) + tint * mix) * a / 255).round().clamp(0, 255);
      }
      if (bold) {
        final p = i ~/ 4, x = p % width, y = p ~/ width;
        final tx = x - up[0], ty = y - up[1];
        if (tx >= 0 && ty >= 0 && tx < width && ty < height) {
          final t = (ty * width + tx) * 4;
          if (rgba[t + 3] == 0) lower.add(t);
        }
      }
    }
    for (final t in lower) {
      rgba[t] = color.red;
      rgba[t + 1] = color.green;
      rgba[t + 2] = color.blue;
      rgba[t + 3] = 255;
    }
  }

  static bool _isBrow(Uint8List rgba, int i) {
    final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
    return g > r + 15 && g > b + 15;
  }
}
