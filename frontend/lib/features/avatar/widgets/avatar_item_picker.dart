import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/models/avatar_catalog.dart';
import '../../../core/models/avatar_config.dart';
import '../editor/avatar_editor_controller.dart';
import '../editor/editor_style.dart';
import '../editor/editor_tabs.dart';
import '../services/avatar_thumbnail_service.dart';

/// Grid of a section's choices, each shown as the player's own avatar wearing it ('none' as an
/// icon). Tapping one selects it, or toggles it in a multi section (marks).
class AvatarItemPicker extends StatelessWidget {
  const AvatarItemPicker({
    super.key,
    required this.controller,
    required this.section,
    required this.thumbnails,
    this.badgeBuilder,
  });

  final AvatarEditorController controller;
  final EditorSection section;
  final AvatarThumbnailService thumbnails;

  /// Optional corner badge per item (e.g. a lock later on); none by default.
  final Widget? Function(String id)? badgeBuilder;

  static String labelFor(EditorSection section, String id) {
    if (id == 'none') return 'Ninguno';
    switch (section.slot) {
      case AvatarConfig.bodySlot:
        return id == 'male' ? 'Masculino' : 'Femenino';
      case AvatarConfig.faceShapeSlot:
        return AvatarConfig.formatName(id);
    }
    return AvatarCatalog.find(section.slot!, id)?.displayLabel ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final options = controller.options(section);
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 8.0;
      final tileWidth = (constraints.maxWidth - spacing * 3) / 4;
      // Square thumbnail plus two lines of label, at the player's text size.
      final labelHeight = MediaQuery.textScalerOf(context).scale(_ItemTile.labelSize) * _ItemTile.labelLineHeight * 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: options.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          mainAxisExtent: tileWidth + _ItemTile.labelGap + labelHeight + 2,
        ),
        itemBuilder: (context, i) {
          final id = options[i];
          return _ItemTile(
            key: ValueKey('${section.id}/$id'),
            label: labelFor(section, id),
            selected: controller.isSelected(section, id),
            badge: badgeBuilder?.call(id),
            onTap: () => controller.select(section, id),
            thumbnail: id == 'none'
                ? null
                : _ThumbRequest(
                    thumbnails, controller.thumbnailBase(section, id), section.slot!, id, section.cropFor(id)),
          );
        },
      );
    });
  }
}

/// What a tile shows; equal requests reuse the image already on screen.
class _ThumbRequest {
  _ThumbRequest(this.service, this.base, this.slot, this.id, this.crop);

  final AvatarThumbnailService service;
  final AvatarConfig base;
  final String slot;
  final String id;
  final ThumbCrop crop;

  ui.Image? get cached => service.cached(base, slot, id, crop);
  Future<ui.Image> load() => service.thumbnail(base, slot, id, crop);

  @override
  bool operator ==(Object other) =>
      other is _ThumbRequest && other.base == base && other.slot == slot && other.id == id && other.crop == crop;

  @override
  int get hashCode => Object.hash(base, slot, id, crop);
}

class _ItemTile extends StatefulWidget {
  static const double labelSize = 11;
  static const double labelLineHeight = 1.2;
  static const double labelGap = 4;

  const _ItemTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.thumbnail,
    this.badge,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Null for the 'none' tile.
  final _ThumbRequest? thumbnail;
  final Widget? badge;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(_ItemTile old) {
    super.didUpdateWidget(old);
    if (old.thumbnail != widget.thumbnail) _request();
  }

  /// Shows the cached thumbnail at once; otherwise keeps the previous one until the new one is
  /// ready, so a colour change does not blink the whole grid.
  void _request() {
    final request = widget.thumbnail;
    if (request == null) {
      _image = null;
      return;
    }
    final cached = request.cached;
    if (cached != null) {
      _image = cached;
      return;
    }
    request.load().then((image) {
      if (mounted && widget.thumbnail == request) setState(() => _image = image);
    }, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return Semantics(
      button: true,
      selected: selected,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: EditorStyle.tile,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? EditorStyle.accent : EditorStyle.line,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: _content(),
                  ),
                  if (selected)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: CircleAvatar(
                        radius: 8,
                        backgroundColor: EditorStyle.accent,
                        child: Icon(Icons.check, size: 12, color: EditorStyle.background),
                      ),
                    ),
                  if (widget.badge != null) Positioned(top: 4, left: 4, child: widget.badge!),
                ],
              ),
            ),
            const SizedBox(height: _ItemTile.labelGap),
            Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _ItemTile.labelSize,
                height: _ItemTile.labelLineHeight,
                color: selected ? EditorStyle.text : EditorStyle.muted,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (widget.thumbnail == null) {
      return const Center(child: Icon(Icons.block, size: 28, color: EditorStyle.muted));
    }
    final image = _image;
    if (image == null) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: EditorStyle.strongLine),
        ),
      );
    }
    return RawImage(image: image, filterQuality: FilterQuality.none, fit: BoxFit.contain);
  }
}
