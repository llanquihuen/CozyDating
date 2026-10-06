import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';

/// Renders the avatar lying (view A, 160x128 canvas at 1:1) with the real assets and returns its pixels.
Future<Uint8List> _renderLying(AvatarConfig config, {required bool under, required bool barefoot}) async {
  final avatar = ModularAvatarComponent(config: config);
  await avatar.onLoad();
  avatar.lieDown(LyingPose(
    view: 'A',
    mirror: false,
    under: under,
    barefoot: barefoot,
    canvasOrigin: ui.Offset.zero,
    bedWidth: 160,
    scale: 1,
  ));
  final recorder = ui.PictureRecorder();
  avatar.render(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(160, 128);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

void main() {
  const base = AvatarConfig(shoeStyle: 'boots', marks: ['freckles']);
  final withGlasses = base.withAccessory('glasses', 'normal_lenses');

  testWidgets('lying on a bed takes the shoes off; lying elsewhere keeps them', (tester) async {
    await tester.runAsync(() async {
      final onBed = await _renderLying(base, under: false, barefoot: true);
      final elsewhere = await _renderLying(base, under: false, barefoot: false);
      final shod = await _renderLying(base.copyWith(shoeStyle: 'none'), under: false, barefoot: false);
      expect(onBed, isNot(equals(elsewhere)), reason: 'boots are drawn when not barefoot');
      expect(onBed, equals(shod), reason: 'barefoot looks exactly like wearing no shoes');
    });
  });

  testWidgets('glasses stay on lying awake and come off asleep under the covers', (tester) async {
    await tester.runAsync(() async {
      final awake = await _renderLying(withGlasses, under: false, barefoot: true);
      final awakeNoGlasses = await _renderLying(base, under: false, barefoot: true);
      expect(awake, isNot(equals(awakeNoGlasses)), reason: 'glasses are drawn while awake');

      final asleep = await _renderLying(withGlasses, under: true, barefoot: true);
      final asleepNoGlasses = await _renderLying(base, under: true, barefoot: true);
      expect(asleep, equals(asleepNoGlasses), reason: 'glasses are taken off to sleep');
    });
  });

  testWidgets('body marks stay on while asleep', (tester) async {
    await tester.runAsync(() async {
      final asleep = await _renderLying(base, under: true, barefoot: true);
      final noMarks = await _renderLying(base.copyWith(marks: const []), under: true, barefoot: true);
      expect(asleep, isNot(equals(noMarks)));
    });
  });
}
