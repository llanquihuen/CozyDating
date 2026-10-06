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
    {String? lyingView, AvatarDirection direction = AvatarDirection.south}) async {
  final avatar = ModularAvatarComponent(config: config, direction: direction);
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
  final hairstyles = [
    for (final item in AvatarCatalog.items)
      if (item.slot == AvatarCatalog.hair) item.id,
  ];

  testWidgets('every hairstyle is drawn standing (front and back) and lying', (tester) async {
    await tester.runAsync(() async {
      const bald = AvatarConfig(hairStyle: 'none');
      final baldFront = await _render(bald, 'bald_S');
      final baldBack = await _render(bald, 'bald_N', direction: AvatarDirection.north);
      final baldLying = await _render(bald, 'bald_lieA', lyingView: 'A');
      for (final style in hairstyles) {
        final config = bald.copyWith(hairStyle: style);
        expect(await _render(config, '${style}_S'), isNot(equals(baldFront)), reason: '$style front');
        expect(await _render(config, '${style}_N', direction: AvatarDirection.north), isNot(equals(baldBack)),
            reason: '$style back');
        expect(await _render(config, '${style}_lieA', lyingView: 'A'), isNot(equals(baldLying)),
            reason: '$style lying');
      }
    });
  });
}
