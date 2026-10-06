import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/core/models/furniture_item.dart';
import 'package:frontend/features/lobby/components/isometric_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/data/bed_sleep_config.dart';
import 'package:frontend/features/lobby/games/cozy_room_game.dart';

Future<Sprite> _blankSprite(int w, int h) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint());
  return Sprite(await recorder.endRecording().toImage(w, h));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<IsometricFurnitureComponent> kingBed(int rotation, {String id = 'king_bed'}) async => IsometricFurnitureComponent(
        id: id,
        typeName: 'king_bed',
        gridX: 4.0,
        gridY: 4.0,
        gridWidth: 2.0,
        gridHeight: 2.0,
        rotation: rotation,
        footprint: '2x2',
        type: FurnitureType.bed,
        sprite: await _blankSprite(256, 192),
      );

  /// World point on [side]'s pillow of [bed] (as drawn, mirrored rotations included).
  Vector2 tapOnSide(IsometricFurnitureComponent bed, int side) {
    final spot = BedSleepConfig.spotFor(bed.id, bed.typeName, bed.rotation, side: side)!;
    final px = spot.mirror ? Vector2(256 - spot.baseHead.dx, spot.baseHead.dy) : Vector2(spot.baseHead.dx, spot.baseHead.dy);
    return bed.position + bed.spriteOffset + px * 0.5;
  }

  test('tapping a half of the king bed lies on that half; a half taken by the partner gives the other', () async {
    for (var rot = 0; rot < 4; rot++) {
      final game = CozyRoomGame(avatarConfig: const AvatarConfig());
      final bed = await kingBed(rot);
      game.world.add(bed);
      expect(game.sideToLieOn(bed, tapOnSide(bed, 0)), 0, reason: 'rot$rot');
      expect(game.sideToLieOn(bed, tapOnSide(bed, 1)), 1, reason: 'rot$rot');

      final partner = IsometricAvatarComponent(gridX: 2, gridY: 2, config: const AvatarConfig());
      game.partnerAvatar = partner;
      partner.lieOnBed(bed, side: 1);
      expect(game.sideToLieOn(bed, tapOnSide(bed, 1)), 0, reason: 'rot$rot: partner already on side 1');
      expect(game.sideToLieOn(bed, tapOnSide(bed, 0)), 0, reason: 'rot$rot');
    }
  });

  test('a single bed taken by the partner is full', () async {
    final game = CozyRoomGame(avatarConfig: const AvatarConfig());
    final bed = IsometricFurnitureComponent(
      id: 'single_bed',
      typeName: 'single_bed',
      gridX: 4.0,
      gridY: 4.0,
      gridWidth: 1.0,
      gridHeight: 2.0,
      rotation: 0,
      footprint: '1x2',
      type: FurnitureType.bed,
      sprite: await _blankSprite(192, 144),
    );
    game.world.add(bed);
    final tap = bed.position + bed.spriteOffset + Vector2(78, 18);
    expect(game.sideToLieOn(bed, tap), 0);

    final partner = IsometricAvatarComponent(gridX: 2, gridY: 2, config: const AvatarConfig());
    game.partnerAvatar = partner;
    partner.lieOnBed(bed);
    expect(game.sideToLieOn(bed, tap), isNull);
  });
}
