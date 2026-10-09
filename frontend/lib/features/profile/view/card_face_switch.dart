import 'package:flutter/material.dart';

/// The floating Personaje / Real pill that picks which face of a profile card shows. While the
/// real face is [realLocked] (before the campfire) its option shows a lock and only calls
/// [onLockedTap].
class CardFaceSwitch extends StatelessWidget {
  const CardFaceSwitch({
    super.key,
    required this.real,
    required this.onChanged,
    required this.accent,
    required this.onAccent,
    this.realLocked = false,
    this.onLockedTap,
  });

  final bool real;
  final ValueChanged<bool> onChanged;
  final Color accent;
  final Color onAccent;
  final bool realLocked;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final selected = real == value;
      final locked = value && realLocked;
      return Semantics(
        button: true,
        selected: selected,
        label: locked ? 'Real, se revela en la fogata' : null,
        excludeSemantics: locked,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: locked ? onLockedTap : () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (locked) ...[
                  Icon(Icons.lock_rounded, size: 13, color: Colors.white.withValues(alpha: 0.55)),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? onAccent : Colors.white.withValues(alpha: locked ? 0.55 : 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0E).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [option('Personaje', false), option('Real', true)]),
    );
  }
}
