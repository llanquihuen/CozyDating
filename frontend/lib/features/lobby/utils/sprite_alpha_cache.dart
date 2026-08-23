import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart' show Sprite, Vector2;

/// Caches decoded alpha-channel bytes per source [ui.Image] so sprite hit-testing can check
/// whether a touch actually landed on a drawn (non-transparent) pixel, instead of an
/// approximate bounding box — the same "matches what you see" precision the interior walls
/// already get from their exact parallelogram shape.
///
/// Flutter's [ui.Image] has no synchronous pixel access, so decoding is async. Call [warm]
/// as soon as a sprite is loaded (well before any tap needs it) so the cache is almost
/// always ready by the time [isOpaqueAt] is actually called; callers should fall back to a
/// bounding-box check when it returns `null` (data not decoded yet).
class SpriteAlphaCache {
  SpriteAlphaCache._();

  static final Map<ui.Image, Uint8List> _cache = {};
  static final Set<ui.Image> _pending = {};

  /// Minimum alpha (0-255) to count as "drawn" — a couple of steps above zero so faint
  /// antialiased edge pixels don't register as solid.
  static const int _opaqueThreshold = 10;

  /// Kicks off (fire-and-forget) decoding of [image]'s pixels if not already cached/pending.
  static void warm(ui.Image image) {
    if (_cache.containsKey(image) || _pending.contains(image)) return;
    _pending.add(image);
    unawaited(
      image.toByteData(format: ui.ImageByteFormat.rawStraightRgba).then((data) {
        _pending.remove(image);
        if (data != null) {
          _cache[image] = data.buffer.asUint8List();
        }
      }).catchError((_) {
        _pending.remove(image);
      }),
    );
  }

  /// True/false once [sprite]'s pixel data is decoded, or null if it isn't ready yet (in
  /// which case decoding has also been (re-)queued via [warm]).
  ///
  /// [localPoint] is the touch point expressed in the sprite's own locally-drawn rect —
  /// (0,0) at its top-left corner, [drawSize] at its bottom-right — exactly the box passed
  /// as `size:` to `Sprite.render()`.
  static bool? isOpaqueAt(Sprite sprite, Vector2 localPoint, Vector2 drawSize) {
    if (drawSize.x <= 0 || drawSize.y <= 0) return false;
    if (localPoint.x < 0 || localPoint.y < 0 || localPoint.x >= drawSize.x || localPoint.y >= drawSize.y) {
      return false;
    }

    final image = sprite.image;
    final bytes = _cache[image];
    if (bytes == null) {
      warm(image);
      return null;
    }

    final srcX = (sprite.srcPosition.x + localPoint.x / drawSize.x * sprite.srcSize.x).floor();
    final srcY = (sprite.srcPosition.y + localPoint.y / drawSize.y * sprite.srcSize.y).floor();
    if (srcX < 0 || srcY < 0 || srcX >= image.width || srcY >= image.height) return false;

    final idx = (srcY * image.width + srcX) * 4 + 3;
    if (idx < 0 || idx >= bytes.length) return false;
    return bytes[idx] >= _opaqueThreshold;
  }
}
