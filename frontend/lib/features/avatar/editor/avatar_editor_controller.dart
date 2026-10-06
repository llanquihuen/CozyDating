import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;

import '../../../core/models/avatar_catalog.dart';
import '../../../core/models/avatar_config.dart';
import 'editor_tabs.dart';

/// State of the avatar editor, shared by registration and the room: the config being edited
/// (always valid for [gender]), undo history, unsaved changes, and which tabs and choices the
/// player gets.
class AvatarEditorController extends ChangeNotifier {
  AvatarEditorController({required AvatarConfig initial, required String gender, Random? random})
      : _gender = gender,
        _random = random ?? Random() {
    _config = initial.restrictedTo(gender);
    _saved = _config;
  }

  static const int maxUndo = 30;

  final Random _random;
  String _gender;
  late AvatarConfig _config;
  late AvatarConfig _saved;
  final List<AvatarConfig> _history = [];

  AvatarConfig get config => _config;
  String get gender => _gender;

  /// Changed since it was opened or last [markSaved].
  bool get isDirty => _config != _saved;
  bool get canUndo => _history.isNotEmpty;

  /// A new gender (registration step 1 changed) re-fits the config, and is not undoable.
  set gender(String value) {
    if (value == _gender) return;
    _gender = value;
    _config = _config.restrictedTo(value);
    _history.clear();
    notifyListeners();
  }

  /// Applies [next] made valid for [gender]; the previous config can be restored with [undo].
  void apply(AvatarConfig next) {
    final fitted = next.restrictedTo(_gender);
    if (fitted == _config) return;
    _history.add(_config);
    if (_history.length > maxUndo) _history.removeAt(0);
    _config = fitted;
    notifyListeners();
  }

  void undo() {
    if (_history.isEmpty) return;
    _config = _history.removeLast();
    notifyListeners();
  }

  void markSaved() {
    _saved = _config;
    notifyListeners();
  }

  /// Tabs with only the sections that offer the player a choice (a locked body, one face shape or
  /// an accessory slot without items are hidden); tabs left empty are dropped.
  List<EditorTab> get tabs => [
        for (final tab in editorTabs)
          if (tab.sections.where(_isVisible).toList() case final visible when visible.isNotEmpty)
            tab.withSections(visible),
      ];

  bool _isVisible(EditorSection section) {
    if (section.slot == null) return section.color != null;
    final choices = options(section).where((id) => id != 'none').length;
    // An optional slot with one item is still a choice (wear it or not).
    return choices > 1 || (choices == 1 && AvatarCatalog.allowsNone(section.slot!));
  }

  /// Ids offered in [section] ('none' first where the slot can be empty).
  List<String> options(EditorSection section) {
    final slot = section.slot;
    if (slot == null) return const [];
    switch (slot) {
      case AvatarConfig.bodySlot:
        return AvatarCatalog.lockedBodyFor(_gender) == null ? AvatarConfig.availableBodyTypes : const [];
      case AvatarConfig.faceShapeSlot:
        return AvatarConfig.availableFaceShapes;
      default:
        return AvatarCatalog.options(slot, gender: _gender, bodyType: _config.bodyType);
    }
  }

  bool isSelected(EditorSection section, String id) {
    final slot = section.slot;
    if (slot == null) return false;
    if (section.multi) return id == 'none' ? _config.marks.isEmpty : _config.marks.contains(id);
    return _config.itemIn(slot) == id;
  }

  /// Picks [id] in [section]: replaces the worn item, or toggles a mark.
  void select(EditorSection section, String id) {
    final slot = section.slot;
    if (slot == null) return;
    if (section.multi && id != 'none') {
      apply(_config.toggleMark(id));
    } else {
      apply(_config.withItem(slot, id));
    }
  }

  Color colorOf(EditorSection section) => section.color!.read(_config);

  void setColor(EditorSection section, Color color) => apply(section.color!.write(_config, color));

  /// A random look allowed for [gender]: body (when not locked), styles and colours, always with
  /// a top and a bottom. Marks, makeup, accessories and dresses are left off.
  void randomize() {
    T pick<T>(List<T> from) => from[_random.nextInt(from.length)];
    final body = AvatarCatalog.lockedBodyFor(_gender) ?? pick<String>(AvatarConfig.availableBodyTypes);
    String style(String slot, {bool allowNone = true}) => pick([
          for (final id in AvatarCatalog.options(slot, gender: _gender, bodyType: body))
            if (allowNone || id != 'none') id,
        ]);
    final hairColor = pick(AvatarConfig.hairColors);
    apply(AvatarConfig(
      bodyType: body,
      faceShape: pick(AvatarConfig.availableFaceShapes),
      skinColor: pick(AvatarConfig.skinTones),
      eyeStyle: style(AvatarCatalog.eyes),
      eyeColor: pick(AvatarConfig.eyeColors),
      eyebrowColor: hairColor,
      noseStyle: style(AvatarCatalog.nose),
      mouthStyle: style(AvatarCatalog.mouth),
      hairStyle: style(AvatarCatalog.hair),
      hairColor: hairColor,
      topStyle: style(AvatarCatalog.top, allowNone: false),
      topColor: pick(AvatarConfig.clothingColors),
      bottomStyle: style(AvatarCatalog.bottom, allowNone: false),
      bottomColor: pick(AvatarConfig.clothingColors),
      shoeStyle: style(AvatarCatalog.shoes),
      shoeColor: pick(AvatarConfig.clothingColors),
      accessoryColor: _config.accessoryColor,
    ));
  }
}
