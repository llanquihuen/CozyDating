import 'package:flutter/material.dart';

class EmoteWheelWidget extends StatefulWidget {
  final void Function(String emote) onEmoteSelected;

  const EmoteWheelWidget({
    super.key,
    required this.onEmoteSelected,
  });

  @override
  State<EmoteWheelWidget> createState() => _EmoteWheelWidgetState();
}

class _EmoteWheelWidgetState extends State<EmoteWheelWidget> with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  static const List<Map<String, String>> emotes = [
    {'emoji': '❤️', 'label': 'Cariño'},
    {'emoji': '👏', 'label': '¡Genial!'},
    {'emoji': '💡', 'label': '¡Por aquí!'},
    {'emoji': '😱', 'label': '¡Ups!'},
    {'emoji': '⏳', 'label': 'Espera'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleMenu() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _selectEmote(String emoji) {
    widget.onEmoteSelected(emoji);
    _toggleMenu();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Expanded Emote Palette
        ScaleTransition(
          scale: _scaleAnimation,
          alignment: Alignment.bottomRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.amberAccent.withOpacity(0.8), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.amberAccent.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: emotes.map((item) {
                final emoji = item['emoji']!;
                return GestureDetector(
                  onTap: () => _selectEmote(emoji),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Floating Trigger Button
        GestureDetector(
          onTap: _toggleMenu,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE67E22), Color(0xFFD35400)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.amberAccent, width: 1.8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: AnimatedRotation(
                turns: _isOpen ? 0.25 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  _isOpen ? Icons.close : Icons.sentiment_satisfied_alt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
