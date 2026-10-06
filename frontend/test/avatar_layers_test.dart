import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/avatar_layers.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';

Future<Uint8List> _pixels(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

Future<Uint8List> _componentRender(AvatarConfig config, AvatarDirection direction) async {
  final avatar = ModularAvatarComponent(config: config, direction: direction);
  await avatar.onLoad();
  final recorder = ui.PictureRecorder();
  avatar.render(ui.Canvas(recorder));
  return _pixels(await recorder.endRecording().toImage(64, 128));
}

void main() {
  const configs = {
    'default': AvatarConfig(),
    'dressed': AvatarConfig(
      bodyType: 'male',
      hairStyle: 'undercut',
      topStyle: 'tank',
      topColor: Color(0xFF10B981),
      bottomStyle: 'sweatpants',
      shoeStyle: 'sneakers',
      marks: ['freckles', 'tattoo_sleeves'],
      accessories: {'glasses': 'nice_lenses'},
    ),
    'dress and makeup': AvatarConfig(
      dressStyle: 'lolita',
      makeup: {'blush': 'blush_soft', 'lipstick': 'lip_bold', 'eyeshadow': 'shadow_soft'},
    ),
  };

  testWidgets('a still render is pixel-identical to the component standing still', (tester) async {
    await tester.runAsync(() async {
      for (final entry in configs.entries) {
        for (final direction in [AvatarDirection.south, AvatarDirection.east, AvatarDirection.north]) {
          final still = await _pixels(await AvatarLayers.renderStill(entry.value, direction: direction.dirNumber));
          final full = await _componentRender(entry.value, direction);
          expect(still.any((b) => b != 0), isTrue, reason: '${entry.key} $direction is blank');
          expect(still, equals(full), reason: '${entry.key} $direction');
        }
      }
    });
  });

  testWidgets('loadStill loads one frame only', (tester) async {
    await tester.runAsync(() async {
      final still = AvatarLayers(configs['dressed']!);
      await still.loadStill();
      expect(still.images.keys.map((k) => k.split(':').last).toSet(), {'1'});

      final all = AvatarLayers(configs['dressed']!);
      await all.loadAll();
      expect(all.images.length, greaterThan(still.images.length * 10));
    });
  });
}
