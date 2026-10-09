import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/models/preference_tags.dart';
import 'card_themes.dart';

/// A taste chip: emoji and short title.
class TasteChip extends StatelessWidget {
  const TasteChip({
    super.key,
    required this.tasteId,
    required this.fill,
    required this.textColor,
    this.border,
    this.fontSize = 12,
    this.radius = 14,
  });

  final String tasteId;
  final Color fill;
  final Color textColor;
  final Color? border;
  final double fontSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final item = PreferenceCatalog.getItem(tasteId);
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(radius),
        border: border == null ? null : Border.all(color: border!, width: 1.2),
      ),
      child: Text(
        '${item?.emoji ?? '✨'} ${PreferenceCatalog.shortTitle(tasteId)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// The verified-identity seal: a tick in a filled circle.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, required this.color, required this.tick, this.size = 20});

  final Color color;
  final Color tick;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Identidad certificada',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(Icons.check, size: size * 0.72, color: tick),
      ),
    );
  }
}

/// Stands in for the photos of a profile that has none.
class NoPhoto extends StatelessWidget {
  const NoPhoto({super.key, required this.theme});

  final ProfileCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(theme.base, Colors.white, 0.25)!, theme.base],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.6),
        child: Icon(Icons.person_rounded, size: 96, color: Colors.white.withValues(alpha: 0.22)),
      ),
    );
  }
}

/// A profile photo from the server (or a bundled asset), covering its box.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.resolveMediaUrl(url);
    Widget fallback(BuildContext _, Object __, StackTrace? ___) => const ColoredBox(
        color: Color(0xFF1E293B), child: Center(child: Icon(Icons.person_outline, size: 60, color: Colors.white30)));
    if (resolved.startsWith('assets/')) {
      return Image.asset(resolved, fit: BoxFit.cover, errorBuilder: fallback);
    }
    if (resolved.startsWith('http://') || resolved.startsWith('https://')) {
      return Image.network(resolved, fit: BoxFit.cover, errorBuilder: fallback);
    }
    return fallback(context, '', null);
  }
}
