import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class WallRoofComponent extends PositionComponent {
  final Sprite sprite;

  WallRoofComponent({
    required Vector2 position,
    required Vector2 size,
    required this.sprite,
  }) : super(position: position, size: size) {
    priority = 4; // Priority 4 ensures the roof covers sprites, entities, and particles behind it
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    sprite.render(canvas, size: size);
  }
}

class WallComponent extends PositionComponent with CollisionCallbacks {
  final Sprite? faceSprite;
  final Sprite? topSprite;

  WallComponent({
    required Vector2 position,
    required Vector2 size,
    this.faceSprite,
    this.topSprite,
  }) : super(position: position, size: size) {
    // Priority 1 ensures the front wall face draws over the floor (Priority -1)
    // but stays behind entities (Priority 3) standing on the cell in front
    priority = 1;
    add(RectangleHitbox());
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // If this wall has a roof (-up sprite), add it as an independent high-priority component
    // situated on the tile above, so it properly covers sprites passing behind it.
    if (topSprite != null && parent != null) {
      parent!.add(WallRoofComponent(
        position: Vector2(position.x, position.y - size.y),
        size: size,
        sprite: topSprite!,
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    // Render the wall face (current tile)
    if (faceSprite != null) {
      faceSprite!.render(canvas, size: size);
    } else {
      canvas.drawRect(size.toRect(), Paint()..color = const Color(0xFF2C3E50));
    }
  }
}
