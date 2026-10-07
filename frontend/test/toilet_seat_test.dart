import 'dart:io';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/lobby/components/isometric_avatar_component.dart';
import 'package:frontend/features/lobby/components/isometric_furniture_component.dart';
import 'package:frontend/features/lobby/data/chair_seat_config.dart';

Future<Sprite> _blankSprite() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 128, 128), ui.Paint());
  return Sprite(await recorder.endRecording().toImage(128, 128));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the toilet is a seat with a spot in every rotation', () {
    final toilet = IsometricFurnitureComponent(
      id: 'bathroom_toilet', typeName: 'bathroom_toilet', gridX: 3, gridY: 3, gridWidth: 1, gridHeight: 1, footprint: '1x1');
    expect(toilet.isChair, isTrue);
    expect(IsometricFurnitureComponent.isSeatName('toilet'), isTrue);
    expect(IsometricFurnitureComponent.isSeatName('bathtub_classic'), isFalse);
    for (var rot = 0; rot < 4; rot++) {
      final spot = ChairSeatConfig.getSpots(toilet, rot).single;
      // Mirrored rotations mirror the horizontal offset, give or take a pixel: the offsets were
      // calibrated by eye on the real render (back views: 3 / -4), not computed.
      final mirror = ChairSeatConfig.getSpots(toilet, rot ^ 1).single;
      expect(spot.visualOffset.x, closeTo(-mirror.visualOffset.x, 1.0), reason: 'rot$rot');
      expect(spot.visualOffset.y, mirror.visualOffset.y, reason: 'rot$rot');
    }
  });

  test('sitting raises the lid (seated layers) and standing up lowers it again', () async {
    final down = await _blankSprite(), up = await _blankSprite(), tank = await _blankSprite(), tankLidUp = await _blankSprite();
    final toilet = IsometricFurnitureComponent(
      id: 'bathroom_toilet',
      typeName: 'bathroom_toilet',
      gridX: 3,
      gridY: 3,
      gridWidth: 1,
      gridHeight: 1,
      rotation: 2,
      footprint: '1x1',
      sprite: down,
      chairBaseSprites: {2: down},
      chairFrontSprites: {2: tank},
      chairSeatedBaseSprites: {2: up},
      chairSeatedFrontSprites: {2: tankLidUp},
    );
    final avatar = IsometricAvatarComponent(gridX: 0, gridY: 0, config: const AvatarConfig());

    expect(toilet.isOccupied, isFalse);
    expect(toilet.currentChairBaseSprite, same(down));
    expect(toilet.currentChairFrontSprite, same(tank));

    avatar.sitOnChair(toilet);
    expect(toilet.isOccupied, isTrue);
    expect(toilet.currentChairBaseSprite, same(up));
    expect(toilet.currentChairFrontSprite, same(tankLidUp));

    avatar.standUp(obstacles: toilet.occupiedSubCells.toSet(), blockedEdges: const {});
    expect(toilet.isOccupied, isFalse);
    expect(toilet.currentChairBaseSprite, same(down));
    expect(toilet.currentChairFrontSprite, same(tank));
  });

  test('switching seats frees the previous one', () async {
    IsometricFurnitureComponent seat(String id, double gx) => IsometricFurnitureComponent(
        id: id, typeName: 'bathroom_toilet', gridX: gx, gridY: 3, gridWidth: 1, gridHeight: 1, footprint: '1x1');
    final a = seat('toilet_a', 3), b = seat('toilet_b', 6);
    final avatar = IsometricAvatarComponent(gridX: 0, gridY: 0, config: const AvatarConfig());
    avatar.sitOnChair(a);
    avatar.sitOnChair(b);
    expect(a.isOccupied, isFalse);
    expect(b.isOccupied, isTrue);
  });

  test('toilet sprites: back views for rotations 2/3 and lid-up layers exist', () {
    const dir = 'assets/images/furniture/established_furniture';
    final files = [
      for (var rot = 0; rot < 4; rot++) ...['$dir/bathroom_toilet_rot$rot.png', '$dir/bathroom_toilet_rot${rot}_seated.png'],
      for (final rot in [2, 3]) ...['$dir/bathroom_toilet_rot${rot}_front.png', '$dir/bathroom_toilet_rot${rot}_seated_front.png'],
    ];
    for (final f in files) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    // The back views are their own art, not copies of the front views.
    expect(File('$dir/bathroom_toilet_rot2.png').readAsBytesSync(), isNot(File('$dir/bathroom_toilet_rot0.png').readAsBytesSync()));
  });
}
