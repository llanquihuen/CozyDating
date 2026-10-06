import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';

/// Set to a folder (--dart-define=AVATAR_RENDER_DIR=...) to also save the renders as PNGs.
const _dumpDir = String.fromEnvironment('AVATAR_RENDER_DIR');

Future<Uint8List> _render(AvatarConfig config, String name, {String? lyingView}) async {
  final avatar = ModularAvatarComponent(config: config);
  await avatar.onLoad();
  final w = lyingView == null ? 64 : 160;
  if (lyingView != null) {
    avatar.lieDown(LyingPose(
      view: lyingView,
      mirror: false,
      under: false,
      barefoot: true,
      canvasOrigin: ui.Offset.zero,
      bedWidth: 160,
      scale: 1,
    ));
  }
  final recorder = ui.PictureRecorder();
  avatar.render(ui.Canvas(recorder));
  final image = await recorder.endRecording().toImage(w, 128);
  if (_dumpDir.isNotEmpty) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dumpDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  }
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

void main() {
  const base = AvatarConfig(hairStyle: 'bangs', mouthStyle: 'smile', eyeStyle: 'sparkle');
  final madeUp = base
      .withMakeup('blush', 'blush_anime')
      .withMakeup('eyeshadow', 'shadow_smoky')
      .withMakeup('lipstick', 'lip_bold')
      .copyWith(marks: const ['scar_eye', 'mole_mouth']);

  testWidgets('each makeup piece changes the standing avatar', (tester) async {
    await tester.runAsync(() async {
      final plain = await _render(base, 'plain');
      for (final slot in ['blush', 'eyeshadow', 'lipstick']) {
        final style = madeUp.makeup[slot]!;
        final withOne = await _render(base.withMakeup(slot, style), slot);
        expect(withOne, isNot(equals(plain)), reason: '$slot $style is drawn');
      }
      await _render(madeUp, 'full_makeup');
    });
  });

  testWidgets('makeup colours are applied', (tester) async {
    await tester.runAsync(() async {
      final pink = await _render(madeUp, 'pink');
      final blue = await _render(madeUp.withMakeupColor('lipstick', const ui.Color(0xFF5B8FD9)), 'blue_lips');
      expect(pink, isNot(equals(blue)));
    });
  });

  testWidgets('makeup and new marks are drawn lying down', (tester) async {
    await tester.runAsync(() async {
      for (final view in ['A', 'B']) {
        final plain = await _render(base, 'lie${view}_plain', lyingView: view);
        final full = await _render(madeUp, 'lie${view}_full', lyingView: view);
        expect(full, isNot(equals(plain)), reason: 'lying view $view');
      }
    });
  });
}
