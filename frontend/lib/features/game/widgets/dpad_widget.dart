import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../dungeon_game.dart';

class DPadWidget extends StatefulWidget {
  final DungeonGame game;

  const DPadWidget({super.key, required this.game});

  @override
  State<DPadWidget> createState() => _DPadWidgetState();
}

class _DPadWidgetState extends State<DPadWidget> {
  String? _activeDirection;

  Widget _buildDirectionButton({
    required String directionKey,
    required IconData icon,
    required Vector2 directionVector,
  }) {
    final isPressed = _activeDirection == directionKey;

    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _activeDirection = directionKey;
        });
        widget.game.moveExplorer(directionVector);
      },
      onTapUp: (_) {
        setState(() {
          _activeDirection = null;
        });
        widget.game.stopExplorer();
      },
      onTapCancel: () {
        setState(() {
          _activeDirection = null;
        });
        widget.game.stopExplorer();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isPressed ? Colors.deepOrange.withOpacity(0.8) : Colors.white.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: isPressed ? Colors.white : Colors.white24,
            width: 1.5,
          ),
          boxShadow: isPressed
              ? [
                  BoxShadow(
                    color: Colors.deepOrange.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          color: isPressed ? Colors.white : Colors.white54,
          size: 30,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDirectionButton(
            directionKey: 'UP',
            icon: Icons.keyboard_arrow_up,
            directionVector: Vector2(0, -1),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDirectionButton(
                directionKey: 'LEFT',
                icon: Icons.keyboard_arrow_left,
                directionVector: Vector2(-1, 0),
              ),
              const SizedBox(width: 48),
              _buildDirectionButton(
                directionKey: 'RIGHT',
                icon: Icons.keyboard_arrow_right,
                directionVector: Vector2(1, 0),
              ),
            ],
          ),
          _buildDirectionButton(
            directionKey: 'DOWN',
            icon: Icons.keyboard_arrow_down,
            directionVector: Vector2(0, 1),
          ),
        ],
      ),
    );
  }
}
