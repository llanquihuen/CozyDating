import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'isometric_furniture_component.dart';

class FurniturePreviewGame extends FlameGame {
  final FurnitureType type;
  final int gw;
  final int gh;
  final bool isDragged;
  final Sprite? sprite;

  FurniturePreviewGame({
    required this.type, 
    this.gw = 1, 
    this.gh = 1, 
    this.isDragged = false,
    this.sprite,
  });

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    camera.viewfinder.anchor = Anchor.center;
    
    final furniture = IsometricFurnitureComponent(
      gridX: 0,
      gridY: 0,
      gridWidth: gw,
      gridHeight: gh,
      type: type,
      sprite: sprite,
    )..updateGridPosition(0, 0);

    if (isDragged) {
      furniture.isSelected = true;
      furniture.isBeingDragged = true;
    }

    world.add(furniture);
  }
}

@Preview(name: 'Furniture: Wardrobe')
Widget previewWardrobe() {
  return GameWidget(
    game: FurniturePreviewGame(
      type: FurnitureType.wardrobe,
    ),
  );
}

@Preview(name: 'Furniture: Portal')
Widget previewPortal() {
  return GameWidget(
    game: FurniturePreviewGame(
      type: FurnitureType.portal,
    ),
  );
}

@Preview(name: 'Furniture: Bed (1x2)')
Widget previewBed() {
  return GameWidget(
    game: FurniturePreviewGame(
      type: FurnitureType.bed,
      gw: 1,
      gh: 2,
    ),
  );
}

@Preview(name: 'Furniture: Bed (2x1)')
Widget previewBedRotated() {
  return GameWidget(
    game: FurniturePreviewGame(
      type: FurnitureType.bed,
      gw: 2,
      gh: 1,
    ),
  );
}

@Preview(name: 'Furniture: Bed (Dragged)')
Widget previewBedDragged() {
  return GameWidget(
    game: FurniturePreviewGame(
      type: FurnitureType.bed,
      gw: 1,
      gh: 2,
      isDragged: true,
    ),
  );
}

@Preview(name: 'Furniture: Plant')
Widget previewPlant() {
  return GameWidget(
    game: FurniturePreviewGame(
      type: FurnitureType.plant,
    ),
  );
}

@Preview(name: 'Furniture: Table')
Widget previewTable() {
  return GameWidget(
    game: FurniturePreviewGame(
      type: FurnitureType.table,
    ),
  );
}
