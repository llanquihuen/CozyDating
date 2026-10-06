import 'dart:math';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_catalog.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/editor/avatar_editor_controller.dart';
import 'package:frontend/features/avatar/editor/editor_tabs.dart';

EditorSection _section(AvatarEditorController c, String id) =>
    c.tabs.expand((t) => t.sections).firstWhere((s) => s.id == id);

Iterable<String> _sectionIds(AvatarEditorController c) => c.tabs.expand((t) => t.sections).map((s) => s.id);

void main() {
  test('every catalog slot has a section, and the six tabs come in order', () {
    final slots = editorTabs.expand((t) => t.sections).map((s) => s.slot).toSet();
    for (final item in AvatarCatalog.items) {
      expect(slots, contains(item.slot), reason: item.slot);
    }
    expect(editorTabs.map((t) => t.label), ['Cuerpo', 'Cara', 'Maquillaje', 'Pelo', 'Ropa', 'Accesorios']);
  });

  test('sections without a choice for the player are hidden', () {
    final man = AvatarEditorController(initial: const AvatarConfig(), gender: 'MAN');
    final other = AvatarEditorController(initial: const AvatarConfig(), gender: 'NON_BINARY');
    expect(_sectionIds(man), isNot(contains('build')), reason: 'body locked for men');
    expect(_sectionIds(other), contains('build'));
    expect(_sectionIds(other), isNot(contains('face_shape')), reason: 'one face shape so far');
    expect(_sectionIds(man), isNot(contains('dress')), reason: 'no dress for men yet');
    expect(_sectionIds(other), contains('dress'));
    expect(_sectionIds(other), containsAll(['skin', 'eyes', 'marks', 'glasses']));
    expect(_sectionIds(other), isNot(contains('hat')), reason: 'no hats in the catalog yet');
  });

  test('changes are fitted to the gender, undoable and tracked as unsaved', () {
    final c = AvatarEditorController(initial: const AvatarConfig(), gender: 'MAN');
    expect(c.config.bodyType, 'male');
    expect(c.isDirty, isFalse);

    c.select(_section(c, 'hair'), 'messy');
    expect(c.config.hairStyle, 'messy');
    expect(c.isSelected(_section(c, 'hair'), 'messy'), isTrue);
    expect(c.isDirty, isTrue);

    c.select(_section(c, 'hair'), 'braids'); // feminine: not offered to men, swapped for an allowed one
    expect(AvatarCatalog.isAllowedId(AvatarCatalog.hair, c.config.hairStyle, gender: 'MAN', bodyType: 'male'), isTrue);
    c.undo();
    c.undo();
    expect(c.isDirty, isFalse);
    expect(c.canUndo, isFalse);

    c.setColor(_section(c, 'hair').colors.single, const Color(0xFF7F77DD));
    c.markSaved();
    expect(c.isDirty, isFalse);
    expect(c.canUndo, isTrue, reason: 'saving keeps the history');
  });

  test('undo keeps the last maxUndo steps and a no-op change is not a step', () {
    final c = AvatarEditorController(initial: const AvatarConfig(), gender: 'WOMAN');
    final skin = _section(c, 'skin').colors.single;
    for (var i = 0; i < AvatarEditorController.maxUndo + 5; i++) {
      c.setColor(skin, AvatarConfig.skinTones[i % 2]);
    }
    c.setColor(skin, c.colorOf(skin));
    var steps = 0;
    while (c.canUndo) {
      c.undo();
      steps++;
    }
    expect(steps, AvatarEditorController.maxUndo);
  });

  test('marks toggle, and none takes them all off', () {
    final c = AvatarEditorController(initial: const AvatarConfig(), gender: 'WOMAN');
    final marks = _section(c, 'marks');
    c.select(marks, 'freckles');
    c.select(marks, 'mole_eye');
    expect(c.config.marks, ['freckles', 'mole_eye']);
    expect(c.isSelected(marks, 'none'), isFalse);
    c.select(marks, 'freckles');
    expect(c.config.marks, ['mole_eye']);
    c.select(marks, 'none');
    expect(c.config.marks, isEmpty);
    expect(c.isSelected(marks, 'none'), isTrue);
  });

  test('every colour row reads back what it writes', () {
    final c = AvatarEditorController(initial: const AvatarConfig(), gender: 'NON_BINARY');
    for (final target in c.tabs.expand((t) => t.sections).expand((s) => s.colors)) {
      final colour = target.palette.last;
      c.setColor(target, colour);
      expect(c.colorOf(target), colour, reason: target.label);
    }
  });

  test('a gender change re-fits the config and clears the history', () {
    final c = AvatarEditorController(initial: const AvatarConfig(), gender: 'NON_BINARY');
    c.select(_section(c, 'build'), 'female');
    c.select(_section(c, 'dress'), 'lolita');
    c.gender = 'MAN';
    expect(c.config.bodyType, 'male');
    expect(c.config.dressStyle, 'none');
    expect(c.canUndo, isFalse);
  });

  test('randomize stays within what the gender allows and always dresses the avatar', () {
    for (final gender in ['MAN', 'WOMAN', 'NON_BINARY']) {
      for (var seed = 0; seed < 40; seed++) {
        final c = AvatarEditorController(initial: const AvatarConfig(), gender: gender, random: Random(seed));
        c.randomize();
        expect(c.config.restrictedTo(gender), c.config, reason: '$gender seed $seed');
        expect(c.config.topStyle, isNot('none'));
        expect(c.config.bottomStyle, isNot('none'));
        if (gender == 'MAN') expect(c.config.bodyType, 'male');
        if (gender == 'WOMAN') expect(c.config.bodyType, 'female');
      }
    }
  });

  test('men see the hairstyles aimed at them first, Undercut leading, and get it by default', () {
    final men = AvatarCatalog.options(AvatarCatalog.hair, gender: 'MAN', bodyType: 'male');
    expect(men.take(2), ['none', 'undercut']);
    final masculine = men.skip(1).takeWhile((id) => AvatarCatalog.find(AvatarCatalog.hair, id)!.audience == AvatarAudience.masculine);
    expect(masculine.length, AvatarCatalog.items.where((i) => i.audience == AvatarAudience.masculine).length,
        reason: 'every masculine style comes before the neutral ones');
    expect(AvatarEditorController(initial: const AvatarConfig(), gender: 'MAN').config.hairStyle, 'undercut',
        reason: 'the default long hair is swapped for the first style offered');

    final women = AvatarCatalog.options(AvatarCatalog.hair, gender: 'WOMAN', bodyType: 'female');
    expect(women, [
      'none',
      for (final i in AvatarCatalog.items)
        if (i.slot == AvatarCatalog.hair && i.audience != AvatarAudience.masculine) i.id,
    ], reason: 'catalog order for everyone else');
  });

  test('eyes and brows share one section: the eye styles with an iris and a brow colour row', () {
    final c = AvatarEditorController(initial: const AvatarConfig(), gender: 'WOMAN');
    final face = c.tabs.firstWhere((t) => t.id == 'face');
    expect(face.sections.map((s) => s.label), ['Ojos y cejas', 'Nariz', 'Boca']);
    final eyes = _section(c, 'eyes');
    expect(eyes.colors.map((t) => t.label), ['Color de ojos', 'Color de cejas']);
    c.setColor(eyes.colors.last, const Color(0xFF123456));
    expect(c.config.eyebrowColor, const Color(0xFF123456));
    expect(c.config.eyeColor, isNot(const Color(0xFF123456)));
  });
}
