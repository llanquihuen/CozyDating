import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import '../../../core/models/avatar_catalog.dart';
import '../../../core/models/avatar_config.dart';
import '../components/avatar_layers.dart';

/// Part of the 64x128 sprite canvas a thumbnail shows. Each crop only covers some layers, so
/// [AvatarThumbnailService] can ignore the fields of the others (see [AvatarThumbnailService.relevant]).
///
/// Rows used by the art (canvas pixels): hair 0-124, head 8-49, eyes 26-37, nose 35-41,
/// mouth 38-46, face marks 24-42, tops 42-88, dresses 46-101, body tattoos 47-100,
/// bottoms 71-122, shoes 94-127.
enum ThumbCrop {
  /// Eyes, nose, mouth, makeup.
  face(ui.Rect.fromLTRB(12, 12, 52, 52)),

  /// Hairstyles and head accessories: the head with long hair falling to the shoulders.
  head(ui.Rect.fromLTRB(2, 0, 62, 60)),

  /// Tops, dresses, body marks.
  torso(ui.Rect.fromLTRB(6, 38, 58, 90)),

  /// Bottoms.
  legs(ui.Rect.fromLTRB(4, 68, 60, 124)),

  /// Shoes.
  feet(ui.Rect.fromLTRB(8, 92, 56, 128)),

  /// The whole avatar (body type).
  full(AvatarLayers.canvasRect);

  const ThumbCrop(this.rect);
  final ui.Rect rect;
}

typedef ThumbRenderer = Future<ui.Image> Function(AvatarConfig config, ui.Rect crop);

/// Editor thumbnails: the player's own avatar wearing one catalog item, cropped to the part that
/// item changes ([ThumbCrop]). Renders are cached (least recently used dropped first) and at most
/// [maxConcurrent] run at once, so a grid can ask for every visible tile without stalling.
class AvatarThumbnailService {
  AvatarThumbnailService({this.capacity = 200, this.maxConcurrent = 3, ThumbRenderer? render})
      : _render = render ?? ((config, crop) => AvatarLayers.renderStill(config, crop: crop));

  final int capacity;
  final int maxConcurrent;
  final ThumbRenderer _render;

  final LinkedHashMap<_Key, Future<ui.Image>> _cache = LinkedHashMap();
  final Map<_Key, ui.Image> _done = {};
  final Queue<Completer<void>> _waiting = Queue();
  int _running = 0;

  /// [base] wearing [itemId] in [slot], cropped to [crop]. A top or bottom is shown without the
  /// worn dress, which would hide it.
  Future<ui.Image> thumbnail(AvatarConfig base, String slot, String itemId, ThumbCrop crop) {
    final key = _keyFor(base, slot, itemId, crop);
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit; // most recently used
      return hit;
    }
    final future = _schedule(() => _render(key.config, crop.rect));
    _cache[key] = future;
    future.then((image) {
      if (_cache.containsKey(key)) _done[key] = image;
    }, onError: (Object _) {
      _cache.remove(key);
    });
    while (_cache.length > capacity) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _done.remove(oldest);
    }
    return future;
  }

  /// The finished thumbnail, if it is already cached (lets a tile paint at once, without a
  /// loading frame).
  ui.Image? cached(AvatarConfig base, String slot, String itemId, ThumbCrop crop) =>
      _done[_keyFor(base, slot, itemId, crop)];

  void clear() {
    _cache.clear();
    _done.clear();
  }

  _Key _keyFor(AvatarConfig base, String slot, String itemId, ThumbCrop crop) {
    var config = base.withItem(slot, itemId);
    if (slot == AvatarCatalog.top || slot == AvatarCatalog.bottom) {
      config = config.copyWith(dressStyle: 'none');
    }
    return _Key(relevant(config, crop), crop);
  }

  /// [config] with the fields drawn only outside [crop] reset to their defaults. Rendering it gives
  /// the same pixels inside [crop], and thumbnails that differ only there share a cache entry: a
  /// new shoe colour does not repaint the hairstyles, a new top does not repaint the shoes.
  static AvatarConfig relevant(AvatarConfig config, ThumbCrop crop) {
    const d = AvatarConfig();
    final bottom = crop.rect.bottom;
    final top = crop.rect.top;
    var c = config;
    if (bottom <= 71) {
      c = c.copyWith(bottomStyle: d.bottomStyle, bottomColor: d.bottomColor);
    }
    if (bottom <= 94) {
      c = c.copyWith(shoeStyle: d.shoeStyle, shoeColor: d.shoeColor);
    }
    if (top >= 38) {
      // Below the eyes: their style and colours, the brows and eye makeup are not drawn.
      c = c.copyWith(eyeStyle: d.eyeStyle, eyeColor: d.eyeColor, eyebrowColor: d.eyebrowColor)
          .withMakeup(AvatarCatalog.eyeshadow, 'none')
          .withMakeup(AvatarCatalog.eyeliner, 'none');
    }
    if (top >= 52) {
      // Below the chin: no face at all, only body tattoos among the marks.
      c = c.copyWith(
        faceShape: d.faceShape,
        noseStyle: d.noseStyle,
        mouthStyle: d.mouthStyle,
        marks: [for (final m in c.marks) if (AvatarLayers.isBodyArt(m)) m],
        makeup: const {},
        makeupColors: const {},
        accessories: {
          for (final e in c.accessories.entries)
            if (e.key == 'bag') e.key: e.value,
        },
      );
    }
    if (top >= 88) {
      c = c.copyWith(topStyle: d.topStyle, topColor: d.topColor);
    }
    // Nothing that reloads no sprite (see ModularAvatarComponent.updateConfig) is drawn.
    return c.copyWith(eyebrowStyle: d.eyebrowStyle, faceDetail: d.faceDetail, faceDetailColor: d.faceDetailColor);
  }

  Future<ui.Image> _schedule(Future<ui.Image> Function() job) async {
    if (_running >= maxConcurrent) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future; // a finishing job hands its slot over, _running unchanged
    } else {
      _running++;
    }
    try {
      return await job();
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeFirst().complete();
      } else {
        _running--;
      }
    }
  }
}

class _Key {
  const _Key(this.config, this.crop);
  final AvatarConfig config;
  final ThumbCrop crop;

  @override
  bool operator ==(Object other) => other is _Key && other.crop == crop && other.config == config;

  @override
  int get hashCode => Object.hash(config, crop);
}
