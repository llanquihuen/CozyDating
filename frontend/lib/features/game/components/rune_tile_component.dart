import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'explorer_component.dart';
import '../dungeon_game.dart';

class RuneTileComponent extends PositionComponent with HasGameRef<DungeonGame>, CollisionCallbacks {
  final String runeType; // 'SOL', 'MOON', 'SNAKE', 'LIGHTNING'
  Sprite? spriteOff;
  Sprite? spriteOn;

  bool _isStepped = false;
  bool _isCorrectlyStepped = false;

  final Paint _platePaint = Paint()..color = const Color(0xFF2C3E50);
  final Paint _activePaint = Paint()..color = const Color(0xFF3498DB);
  final Paint _borderPaint = Paint()
    ..color = Colors.cyanAccent
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  RuneTileComponent({
    required Vector2 position,
    required Vector2 size,
    required this.runeType,
    this.spriteOff,
    this.spriteOn,
  }) : super(position: position, size: size) {
    priority = 2;
    add(RectangleHitbox(
      position: Vector2(4, 4),
      size: size - Vector2(8, 8),
    ));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (spriteOff == null || spriteOn == null) {
      try {
        final (offName, onName) = _getSpriteNames(runeType);
        spriteOff ??= await Sprite.load(offName);
        spriteOn ??= await Sprite.load(onName);
      } catch (_) {
        // Fallback for headless test environments
      }
    }
  }

  static (String, String) _getSpriteNames(String type) {
    switch (type.toUpperCase()) {
      case 'SOL':
      case 'SUN':
        return ('sun-off.png', 'sun-on.png');
      case 'MOON':
      case 'LUNA':
        return ('moon-off.png', 'moon-on.png');
      case 'SNAKE':
      case 'SERPIENTE':
        return ('snake-off.png', 'snake-on.png');
      case 'LIGHTNING':
      case 'LIGHTING':
      case 'RAYO':
        return ('lighting-off.png', 'lighting-on.png');
      default:
        return ('sun-off.png', 'sun-on.png');
    }
  }

  void reset() {
    _isCorrectlyStepped = false;
    // We do NOT reset _isStepped here. 
    // Flame's onCollisionEnd will handle that when the player leaves the tile.
    // This prevents the error message from repeating infinitely while standing on the wrong tile.
  }

  String get runeSymbol {
    switch (runeType) {
      case 'SOL':
        return '☀️';
      case 'MOON':
        return '🌙';
      case 'SNAKE':
        return '🐍';
      case 'LIGHTNING':
        return '⚡';
      default:
        return '🔮';
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    
    if (other is ExplorerComponent && !_isStepped && !_isCorrectlyStepped) {
      final feet = other.feetPosition;
      
      // Only trigger if the feet of the explorer are within the tile boundaries
      if (feet.x >= position.x && 
          feet.x < position.x + size.x &&
          feet.y >= position.y && 
          feet.y < position.y + size.y) {
        
        _isStepped = true;
        gameRef.stepOnRuneTile(runeType, position);

        // Check if this was the correct next step in the sequence
        final currentSeq = gameRef.currentSteppedSequence;
        if (currentSeq.isNotEmpty && currentSeq.last == runeType) {
          _isCorrectlyStepped = true;
        }
      }
    }
  }

  @override
  void onCollisionEnd(PositionComponent other) {
    super.onCollisionEnd(other);
    if (other is ExplorerComponent) {
      _isStepped = false;
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final isLit = _isStepped || _isCorrectlyStepped;
    final currentSprite = isLit ? spriteOn : spriteOff;

    if (currentSprite != null) {
      currentSprite.render(canvas, size: size);
      return;
    }

    // Fallback vector drawing if sprites are not loaded (e.g. headless tests)
    final rect = size.toRect();
    final center = (size / 2).toOffset();

    canvas.drawRect(rect, isLit ? _activePaint : _platePaint);
    canvas.drawRect(rect, _borderPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: runeSymbol,
        style: const TextStyle(fontSize: 16),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
}
