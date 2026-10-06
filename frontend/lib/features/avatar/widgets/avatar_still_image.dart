import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/avatar_config.dart';
import '../components/avatar_layers.dart';

/// [config] standing still and facing the viewer, as crisp pixel art: the whole 64x128 sprite
/// canvas, or only [crop] of it. Renders are shared through a small cache.
class AvatarStillImage extends StatefulWidget {
  const AvatarStillImage({super.key, required this.config, this.crop = AvatarLayers.canvasRect, this.fit = BoxFit.contain});

  final AvatarConfig config;
  final Rect crop;
  final BoxFit fit;

  static const int _capacity = 24;
  static final LinkedHashMap<(AvatarConfig, Rect), Future<ui.Image>> _cache = LinkedHashMap();

  static Future<ui.Image> _render(AvatarConfig config, Rect crop) {
    final key = (config, crop);
    final hit = _cache.remove(key);
    final future = hit ?? AvatarLayers.renderStill(config, crop: crop);
    _cache[key] = future;
    if (_cache.length > _capacity) _cache.remove(_cache.keys.first);
    return future;
  }

  @override
  State<AvatarStillImage> createState() => _AvatarStillImageState();
}

class _AvatarStillImageState extends State<AvatarStillImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AvatarStillImage old) {
    super.didUpdateWidget(old);
    if (old.config != widget.config || old.crop != widget.crop) _load();
  }

  void _load() {
    final config = widget.config;
    final crop = widget.crop;
    AvatarStillImage._render(config, crop).then((image) {
      // Keep showing the previous look until the new one is ready.
      if (mounted && widget.config == config && widget.crop == crop) setState(() => _image = image);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.expand();
    return RawImage(image: image, filterQuality: FilterQuality.none, fit: widget.fit);
  }
}
