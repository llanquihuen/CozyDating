import 'package:flutter/material.dart';

import '../../../core/models/avatar_catalog.dart';
import '../../../core/models/avatar_config.dart';
import '../components/avatar_layers.dart';
import '../services/avatar_thumbnail_service.dart';

/// The colour a section's colour row edits.
class ColorTarget {
  const ColorTarget(this.label, this.palette, this.read, this.write);

  final String label;
  final List<Color> palette;
  final Color Function(AvatarConfig config) read;
  final AvatarConfig Function(AvatarConfig config, Color color) write;
}

/// One sub-category (pill) of an editor tab: a grid of choices for [slot] and/or colour rows.
class EditorSection {
  const EditorSection({
    required this.id,
    required this.label,
    this.slot,
    this.crop = ThumbCrop.full,
    this.cropOf,
    this.colors = const [],
  });

  final String id;
  final String label;

  /// Catalog slot, or [AvatarConfig.bodySlot] / [AvatarConfig.faceShapeSlot]. Null for a
  /// colour-only section (skin).
  final String? slot;

  /// Thumbnail crop for the section's items; [cropOf] overrides it per item.
  final ThumbCrop crop;
  final ThumbCrop Function(String id)? cropOf;

  /// Colour rows shown with the section, in order (eyes: iris, then brows).
  final List<ColorTarget> colors;

  /// Several worn at once (marks): tapping toggles instead of replacing.
  bool get multi => slot == AvatarCatalog.mark;

  ThumbCrop cropFor(String id) => cropOf?.call(id) ?? crop;
}

class EditorTab {
  const EditorTab({required this.id, required this.label, required this.icon, required this.faceFocus, required this.sections});

  final String id;
  final String label;
  final IconData icon;

  /// The preview zooms on the face while this tab is open.
  final bool faceFocus;
  final List<EditorSection> sections;

  EditorTab withSections(List<EditorSection> visible) =>
      EditorTab(id: id, label: label, icon: icon, faceFocus: faceFocus, sections: visible);
}

ColorTarget _makeupColor(String slot) => ColorTarget(
      'Color',
      AvatarConfig.makeupPalette,
      (c) => c.makeupColor(slot),
      (c, color) => c.withMakeupColor(slot, color),
    );

ColorTarget _clothesColor(Color Function(AvatarConfig) read, AvatarConfig Function(AvatarConfig, Color) write) =>
    ColorTarget('Color de la prenda', AvatarConfig.clothingColors, read, write);

const _accessoryLabels = {'bag': 'Bolso', 'glasses': 'Lentes', 'headband': 'Cintillo', 'hat': 'Sombrero'};

/// Every tab and section the editor can show, in order. [AvatarEditorController.tabs] hides the
/// sections with nothing to choose for the player (a locked body, slots without items yet).
/// A new catalog item shows up in its slot's section without touching this list.
final List<EditorTab> editorTabs = [
  EditorTab(id: 'body', label: 'Cuerpo', icon: Icons.accessibility_new, faceFocus: false, sections: [
    const EditorSection(id: 'build', label: 'Complexión', slot: AvatarConfig.bodySlot),
    EditorSection(
      id: 'skin',
      label: 'Piel',
      colors: [ColorTarget('Tono de piel', AvatarConfig.skinTones, (c) => c.skinColor, (c, v) => c.copyWith(skinColor: v))],
    ),
    EditorSection(
      id: 'marks',
      label: 'Marcas',
      slot: AvatarCatalog.mark,
      cropOf: (id) => AvatarLayers.isBodyArt(id) ? ThumbCrop.torso : ThumbCrop.face,
    ),
  ]),
  EditorTab(id: 'face', label: 'Cara', icon: Icons.face, faceFocus: true, sections: [
    const EditorSection(id: 'face_shape', label: 'Forma', slot: AvatarConfig.faceShapeSlot, crop: ThumbCrop.face),
    // Brows have no styles yet, only a colour (the hair colour by default), so they live with the eyes.
    EditorSection(
      id: 'eyes',
      label: 'Ojos y cejas',
      slot: AvatarCatalog.eyes,
      crop: ThumbCrop.face,
      colors: [
        ColorTarget('Color de ojos', AvatarConfig.eyeColors, (c) => c.eyeColor, (c, v) => c.copyWith(eyeColor: v)),
        ColorTarget(
            'Color de cejas', AvatarConfig.hairColors, (c) => c.eyebrowColor, (c, v) => c.copyWith(eyebrowColor: v)),
      ],
    ),
    const EditorSection(id: 'nose', label: 'Nariz', slot: AvatarCatalog.nose, crop: ThumbCrop.face),
    const EditorSection(id: 'mouth', label: 'Boca', slot: AvatarCatalog.mouth, crop: ThumbCrop.face),
  ]),
  EditorTab(id: 'makeup', label: 'Maquillaje', icon: Icons.brush, faceFocus: true, sections: [
    EditorSection(id: 'blush', label: 'Rubor', slot: AvatarCatalog.blush, crop: ThumbCrop.face, colors: [_makeupColor(AvatarCatalog.blush)]),
    EditorSection(
        id: 'eyeshadow', label: 'Sombra', slot: AvatarCatalog.eyeshadow, crop: ThumbCrop.face, colors: [_makeupColor(AvatarCatalog.eyeshadow)]),
    EditorSection(
        id: 'eyeliner', label: 'Delineado', slot: AvatarCatalog.eyeliner, crop: ThumbCrop.face, colors: [_makeupColor(AvatarCatalog.eyeliner)]),
    EditorSection(
        id: 'lipstick', label: 'Labial', slot: AvatarCatalog.lipstick, crop: ThumbCrop.face, colors: [_makeupColor(AvatarCatalog.lipstick)]),
  ]),
  EditorTab(id: 'hair', label: 'Pelo', icon: Icons.content_cut, faceFocus: true, sections: [
    EditorSection(
      id: 'hair',
      label: 'Peinado',
      slot: AvatarCatalog.hair,
      crop: ThumbCrop.head,
      // The brows follow a new hair colour, as in the original editors; Cara > Ojos y cejas sets them
      // apart.
      colors: [ColorTarget('Color del pelo', AvatarConfig.hairColors, (c) => c.hairColor,
          (c, v) => c.copyWith(hairColor: v, eyebrowColor: v))],
    ),
  ]),
  EditorTab(id: 'clothes', label: 'Ropa', icon: Icons.checkroom, faceFocus: false, sections: [
    EditorSection(
      id: 'top',
      label: 'Arriba',
      slot: AvatarCatalog.top,
      crop: ThumbCrop.torso,
      colors: [_clothesColor((c) => c.topColor, (c, v) => c.copyWith(topColor: v))],
    ),
    EditorSection(
      id: 'bottom',
      label: 'Abajo',
      slot: AvatarCatalog.bottom,
      crop: ThumbCrop.legs,
      colors: [_clothesColor((c) => c.bottomColor, (c, v) => c.copyWith(bottomColor: v))],
    ),
    EditorSection(
      id: 'dress',
      label: 'Vestido',
      slot: AvatarCatalog.dress,
      crop: ThumbCrop.torso,
      colors: [_clothesColor((c) => c.dressColor, (c, v) => c.copyWith(dressColor: v))],
    ),
    EditorSection(
      id: 'shoes',
      label: 'Calzado',
      slot: AvatarCatalog.shoes,
      crop: ThumbCrop.feet,
      colors: [_clothesColor((c) => c.shoeColor, (c, v) => c.copyWith(shoeColor: v))],
    ),
  ]),
  EditorTab(id: 'accessories', label: 'Accesorios', icon: Icons.auto_awesome, faceFocus: false, sections: [
    for (final slot in AvatarCatalog.accessorySlots)
      EditorSection(
        id: slot,
        label: _accessoryLabels[slot] ?? AvatarConfig.formatSlotName(slot),
        slot: slot,
        crop: slot == 'bag' ? ThumbCrop.torso : ThumbCrop.head,
        // One colour shared by every accessory.
        colors: [ColorTarget('Color del accesorio', AvatarConfig.clothingColors, (c) => c.accessoryColor,
            (c, v) => c.copyWith(accessoryColor: v))],
      ),
  ]),
];
