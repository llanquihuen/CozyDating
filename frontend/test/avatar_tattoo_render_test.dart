import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_catalog.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/modular_avatar_component.dart';

/// Set to a folder (--dart-define=AVATAR_RENDER_DIR=...) to also save the renders as PNGs.
const _dumpDir = String.fromEnvironment('AVATAR_RENDER_DIR');

Future<Uint8List> _render(AvatarConfig config, String name,
    {AvatarDirection direction = AvatarDirection.south, bool sitting = false, String? lyingView}) async {
  final avatar = ModularAvatarComponent(config: config, direction: direction, isSitting: sitting);
  await avatar.onLoad();
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
  final image = await recorder.endRecording().toImage(lyingView == null ? 64 : 160, 128);
  if (_dumpDir.isNotEmpty) {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_dumpDir/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  }
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return bytes!.buffer.asUint8List();
}

int _diff(Uint8List a, Uint8List b) {
  var n = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] || a[i + 1] != b[i + 1] || a[i + 2] != b[i + 2] || a[i + 3] != b[i + 3]) n++;
  }
  return n;
}

void main() {
  final tattoos = [
    for (final item in AvatarCatalog.items)
      if (item.slot == AvatarCatalog.mark && item.underClothes) item.id,
  ];

  test('body tattoos are marks drawn under the clothes', () {
    expect(tattoos, isNotEmpty);
  });

  testWidgets('a body tattoo shows on bare arms, is covered by long sleeves, and is drawn sitting and lying',
      (tester) async {
    await tester.runAsync(() async {
      for (final body in AvatarCatalog.bodyTypes) {
        final tank = AvatarConfig(bodyType: body, hairStyle: 'none', topStyle: 'tank', bottomStyle: 'shorts');
        final sleeves = tank.copyWith(topStyle: 'longsleeve');
        for (final id in tattoos) {
          final inkTank = await _render(tank.copyWith(marks: [id]), '${body}_${id}_tank');
          final plainTank = await _render(tank, '${body}_plain_tank');
          final shown = _diff(inkTank, plainTank);
          expect(shown, greaterThan(0), reason: '$id shows with a tank top ($body)');

          final hidden = _diff(await _render(sleeves.copyWith(marks: [id]), '${body}_${id}_sleeves'),
              await _render(sleeves, '${body}_plain_sleeves'));
          expect(hidden, lessThan(shown ~/ 3), reason: '$id mostly covered by long sleeves ($body)');

          for (final pose in ['sit', 'lie']) {
            final ink = pose == 'sit'
                ? await _render(tank.copyWith(marks: [id]), '${body}_${id}_sit',
                    direction: AvatarDirection.southEast, sitting: true)
                : await _render(tank.copyWith(marks: [id]), '${body}_${id}_lieA', lyingView: 'A');
            final plain = pose == 'sit'
                ? await _render(tank, '${body}_plain_sit', direction: AvatarDirection.southEast, sitting: true)
                : await _render(tank, '${body}_plain_lieA', lyingView: 'A');
            expect(_diff(ink, plain), greaterThan(0), reason: '$id drawn $pose ($body)');
          }
        }
      }
    });
  });
}
