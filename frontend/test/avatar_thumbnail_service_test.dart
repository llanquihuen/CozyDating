import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/avatar_catalog.dart';
import 'package:frontend/core/models/avatar_config.dart';
import 'package:frontend/features/avatar/components/avatar_layers.dart';
import 'package:frontend/features/avatar/services/avatar_thumbnail_service.dart';

Future<Uint8List> _pixels(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

/// A 1x1 image per render, recording what was asked for.
class _FakeRenderer {
  final requests = <AvatarConfig>[];
  final pending = <Completer<void>>[];
  bool hold = false;
  int running = 0;
  int maxRunning = 0;

  Future<ui.Image> call(AvatarConfig config, ui.Rect crop) async {
    requests.add(config);
    running++;
    if (running > maxRunning) maxRunning = running;
    if (hold) {
      final gate = Completer<void>();
      pending.add(gate);
      await gate.future;
    }
    running--;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    return recorder.endRecording().toImage(1, 1);
  }
}

void main() {
  // Everything worn, so each crop has fields it must ignore and fields it must keep.
  final dressed = const AvatarConfig(
    hairStyle: 'ponytail',
    hairColor: Color(0xFF7F77DD),
    topStyle: 'tank',
    topColor: Color(0xFF10B981),
    bottomStyle: 'sweatpants',
    bottomColor: Color(0xFF334155),
    shoeStyle: 'sneakers',
    shoeColor: Color(0xFFF1F5F9),
    marks: ['freckles', 'tattoo_sleeves'],
    accessories: {'glasses': 'nice_lenses'},
  ).withMakeup('blush', 'blush_soft').withMakeup('eyeshadow', 'shadow_soft').withMakeup('lipstick', 'lip_bold');

  testWidgets('a thumbnail keeps every pixel of its crop: dropped fields are never drawn there', (tester) async {
    await tester.runAsync(() async {
      for (final config in [dressed, dressed.copyWith(bodyType: 'male', hairStyle: 'undercut')]) {
        for (final crop in ThumbCrop.values) {
          final original = await AvatarLayers.renderStill(config, crop: crop.rect);
          final reduced = await AvatarLayers.renderStill(AvatarThumbnailService.relevant(config, crop), crop: crop.rect);
          expect(original.width, crop.rect.width.round());
          final pixels = await _pixels(original);
          expect(pixels.any((b) => b != 0), isTrue, reason: '$crop is blank');
          expect(await _pixels(reduced), equals(pixels), reason: '${config.bodyType} $crop');
        }
      }
    });
  });

  testWidgets('no catalog item draws outside the rows its crops assume', (tester) async {
    await tester.runAsync(() async {
      for (final item in AvatarCatalog.items) {
        for (final body in item.fits) {
          final config = dressed.copyWith(bodyType: body).withItem(item.slot, item.id);
          for (final crop in ThumbCrop.values) {
            final original = await _pixels(await AvatarLayers.renderStill(config, crop: crop.rect));
            final reduced = await _pixels(
                await AvatarLayers.renderStill(AvatarThumbnailService.relevant(config, crop), crop: crop.rect));
            expect(reduced, equals(original), reason: '${item.slot}/${item.id} on $body, $crop');
          }
        }
      }
    });
  });

  testWidgets('real thumbnails show the item and are served from the cache', (tester) async {
    await tester.runAsync(() async {
      final service = AvatarThumbnailService();
      final bob = await service.thumbnail(dressed, AvatarCatalog.hair, 'bob', ThumbCrop.head);
      final pixie = await service.thumbnail(dressed, AvatarCatalog.hair, 'pixie', ThumbCrop.head);
      expect(await _pixels(bob), isNot(equals(await _pixels(pixie))));
      expect(service.cached(dressed, AvatarCatalog.hair, 'bob', ThumbCrop.head), same(bob));
      expect(await service.thumbnail(dressed, AvatarCatalog.hair, 'bob', ThumbCrop.head), same(bob));
    });
  });

  test('only changes visible in the crop render again', () async {
    final render = _FakeRenderer();
    final service = AvatarThumbnailService(render: render.call);
    Future<void> hairThumbs(AvatarConfig c) => Future.wait([
          for (final id in ['bob', 'pixie', 'braids']) service.thumbnail(c, AvatarCatalog.hair, id, ThumbCrop.head),
        ]);

    await hairThumbs(dressed);
    expect(render.requests, hasLength(3));
    await hairThumbs(dressed);
    expect(render.requests, hasLength(3), reason: 'cached');
    await hairThumbs(dressed.copyWith(shoeColor: const Color(0xFFDC2626), bottomStyle: 'shorts'));
    expect(render.requests, hasLength(3), reason: 'shoes and bottoms are below the head crop');
    await hairThumbs(dressed.copyWith(skinColor: const Color(0xFF7A4522)));
    expect(render.requests, hasLength(6), reason: 'the skin shows in every crop');

    await service.thumbnail(dressed, AvatarCatalog.shoes, 'sandals', ThumbCrop.feet);
    await service.thumbnail(dressed.copyWith(hairColor: const Color(0xFFDC2626)), AvatarCatalog.shoes, 'sandals',
        ThumbCrop.feet);
    expect(render.requests, hasLength(8), reason: 'long hair can reach the feet crop');
    await service.thumbnail(dressed.copyWith(eyeColor: const Color(0xFFDC2626), topColor: const Color(0xFF000000)),
        AvatarCatalog.shoes, 'sandals', ThumbCrop.feet);
    expect(render.requests, hasLength(8), reason: 'eyes and tops are above the feet crop');
  });

  test('a top or bottom is shown without the worn dress', () async {
    final render = _FakeRenderer();
    final service = AvatarThumbnailService(render: render.call);
    final inDress = dressed.copyWith(dressStyle: 'lolita');
    await service.thumbnail(inDress, AvatarCatalog.top, 'tshirt', ThumbCrop.torso);
    await service.thumbnail(inDress, AvatarCatalog.dress, 'lolita', ThumbCrop.torso);
    expect(render.requests[0].dressStyle, 'none');
    expect(render.requests[0].topStyle, 'tshirt');
    expect(render.requests[1].dressStyle, 'lolita');
  });

  test('at most maxConcurrent renders run at once, and the oldest entries are dropped', () async {
    final render = _FakeRenderer()..hold = true;
    final service = AvatarThumbnailService(render: render.call, maxConcurrent: 3, capacity: 4);
    final ids = AvatarCatalog.options(AvatarCatalog.hair, gender: 'NON_BINARY', bodyType: 'female')
        .where((id) => id != 'none')
        .take(6)
        .toList();
    final all = Future.wait([for (final id in ids) service.thumbnail(dressed, AvatarCatalog.hair, id, ThumbCrop.head)]);
    while (render.requests.length < ids.length) {
      await Future<void>.delayed(Duration.zero);
      for (final gate in List.of(render.pending)) {
        render.pending.remove(gate);
        gate.complete();
      }
    }
    await all;
    expect(render.maxRunning, 3);

    render.hold = false;
    await service.thumbnail(dressed, AvatarCatalog.hair, ids.last, ThumbCrop.head);
    expect(render.requests, hasLength(6), reason: 'recent entry kept');
    await service.thumbnail(dressed, AvatarCatalog.hair, ids.first, ThumbCrop.head);
    expect(render.requests, hasLength(7), reason: 'oldest entry dropped (capacity 4)');
  });

  test('withItem wears any catalog slot', () {
    const base = AvatarConfig();
    for (final item in AvatarCatalog.items) {
      final other = AvatarCatalog.items.firstWhere((i) => i.slot == item.slot && i.id != item.id, orElse: () => item);
      if (other == item) continue; // single-item slot
      final before = base.withItem(item.slot, other.id);
      expect(before.withItem(item.slot, item.id), isNot(equals(before)), reason: '${item.slot}/${item.id}');
    }
    expect(base.withItem(AvatarCatalog.mark, 'freckles').withItem(AvatarCatalog.mark, 'none').marks, isEmpty);
    expect(base.withItem('glasses', 'nice_lenses').withItem('glasses', 'none').accessories, isEmpty);
  });
}
