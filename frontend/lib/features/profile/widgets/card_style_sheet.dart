import 'package:flutter/material.dart';

import '../../../core/models/preference_tags.dart';
import '../../../core/models/profile_card_style.dart';
import '../../../core/models/user_profile.dart';
import '../card/card_themes.dart';
import '../card/profile_card.dart';

/// "Estilo de la tarjeta": theme, accent, short phrase and featured tastes, with a live preview of
/// the character face. Returns the chosen style, or null when closed without saving.
Future<ProfileCardStyle?> showCardStyleSheet(BuildContext context, UserProfile profile) {
  return showModalBottomSheet<ProfileCardStyle>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF16141F),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: CardStyleSheet(profile: profile)),
  );
}

class CardStyleSheet extends StatefulWidget {
  const CardStyleSheet({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<CardStyleSheet> createState() => _CardStyleSheetState();
}

class _CardStyleSheetState extends State<CardStyleSheet> {
  late ProfileCardStyle _style = widget.profile.effectiveCardStyle;
  late final TextEditingController _phrase = TextEditingController(text: _style.phrase);

  static const _text = Color(0xFFF1EFE8);
  static const _muted = Color(0xFFA8A49B);

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  ProfileCardTheme get _theme => cardThemeOf(_style.themeId);
  Color get _accent => _theme.accentOf(_style);
  List<String> get _featurable => widget.profile.tastes.where(ProfileCardStyle.canFeature).toList();

  void _toggleTaste(String id) {
    final current = List<String>.of(_style.featuredTastes);
    if (current.contains(id)) {
      if (current.length == 1) return; // at least one stays
      current.remove(id);
    } else {
      if (current.length >= ProfileCardStyle.maxFeaturedTastes) return;
      current.add(id);
    }
    setState(() => _style = _style.copyWith(featuredTastes: current));
  }

  Widget _title(String text, {String? trailing}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Row(
          children: [
            Text(text, style: const TextStyle(color: _text, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            if (trailing != null)
              Expanded(
                child: Text(
                  trailing,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final preview = widget.profile.copyWith(cardStyle: _style);
    final accents = [..._theme.accents, ...sharedCardAccents.where((c) => !_theme.accents.contains(c))];
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Estilo de la tarjeta', style: TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_style.copyWith(phrase: _phrase.text)),
                style: FilledButton.styleFrom(backgroundColor: _accent, foregroundColor: _theme.onAccent(_accent)),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              const SizedBox(height: 14),
              Center(
                child: SizedBox(width: 170, child: ProfileCard(profile: preview, style: _style, flipDuration: Duration.zero)),
              ),
              _title('Tema', trailing: _theme.name),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: cardThemes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final theme = cardThemes[i];
                    final selected = theme.id == _style.themeId;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: theme.name,
                      child: GestureDetector(
                        // A new theme starts from its own accent.
                        onTap: () => setState(() => _style = _style.copyWith(themeId: theme.id, clearAccent: true)),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 87,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selected ? theme.accents.first : Colors.transparent, width: 2),
                          ),
                          child: ProfileCard(
                            profile: preview,
                            style: _style.copyWith(themeId: theme.id, clearAccent: true),
                            flipDuration: Duration.zero,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _title('Color de acento'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final c in accents)
                      Semantics(
                        button: true,
                        selected: c == _accent,
                        label: 'Acento #${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
                        child: GestureDetector(
                          onTap: () => setState(() => _style = _style.copyWith(accent: c)),
                          child: Container(
                            width: 34,
                            height: 34,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: c == _accent ? _text : Colors.transparent, width: 2),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _title('Frase', trailing: 'se ve antes de la revelación'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _phrase,
                  maxLength: ProfileCardStyle.maxPhraseLength,
                  onChanged: (v) => setState(() => _style = _style.copyWith(phrase: v)),
                  style: const TextStyle(color: _text),
                  cursorColor: _accent,
                  decoration: InputDecoration(
                    hintText: 'Speedruns y ramen a las 3 AM',
                    hintStyle: const TextStyle(color: Colors.white30),
                    counterStyle: const TextStyle(color: _muted),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              _title(
                'Gustos destacados',
                trailing: '${_style.featuredTastes.length} de ${ProfileCardStyle.maxFeaturedTastes}',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _featurable.isEmpty
                    ? const Text(
                        'Elige tus gustos en tu perfil y podrás destacar hasta 5 aquí.',
                        style: TextStyle(color: _muted, fontSize: 13),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in _featurable)
                            FilterChip(
                              label: Text(
                                '${PreferenceCatalog.getItem(id)?.emoji ?? '✨'} ${PreferenceCatalog.shortTitle(id)}',
                              ),
                              selected: _style.featuredTastes.contains(id),
                              onSelected: (_) => _toggleTaste(id),
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: _style.featuredTastes.contains(id) ? _theme.chipText(_accent) : _muted,
                                fontSize: 13,
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.05),
                              selectedColor: _theme.chipFill(_accent),
                              side: BorderSide(
                                color: _style.featuredTastes.contains(id) ? _accent : Colors.white24,
                              ),
                              shape: const StadiumBorder(),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
