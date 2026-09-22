import 'package:flutter/material.dart';
import '../../../core/models/lifestyle_badges.dart';

/// Modal bottom sheet or dialog to manage the 12 optional lifestyle badges.
class LifestyleBadgesSheet extends StatefulWidget {
  final LifestyleBadges initialLifestyle;
  final ValueChanged<LifestyleBadges> onSaved;

  const LifestyleBadgesSheet({
    super.key,
    required this.initialLifestyle,
    required this.onSaved,
  });

  /// Static helper to open the sheet comfortably
  static Future<void> show(
    BuildContext context, {
    required LifestyleBadges initialLifestyle,
    required ValueChanged<LifestyleBadges> onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LifestyleBadgesSheet(
        initialLifestyle: initialLifestyle,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<LifestyleBadgesSheet> createState() => _LifestyleBadgesSheetState();
}

class _LifestyleBadgesSheetState extends State<LifestyleBadgesSheet> {
  late LifestyleBadges _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialLifestyle;
  }

  void _update(LifestyleBadges updated) {
    setState(() {
      _current = updated;
    });
    widget.onSaved(_current);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return Container(
      constraints: BoxConstraints(
        maxHeight: size.height * 0.90,
        maxWidth: 700,
      ),
      margin: EdgeInsets.symmetric(
        horizontal: isWide ? (size.width - 640) / 2 : 0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: const Color(0xFF0284C7).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Top Drag Handle & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.badge_rounded, color: Color(0xFF38BDF8), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¿Quién eres y cómo es tu realidad de vida actual?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Insignias de perfil para tu ficha de presentación',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Cerrar',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Friendly optional notice banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF0284C7).withOpacity(0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Todas estas opciones son 100% opcionales. Puedes completar las que quieras o dejarlas en blanco. Solo se mostrarán en tu ficha las que actives.',
                            style: TextStyle(color: Color(0xFFBAE6FD), fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white10, height: 1),

            // Scrollable 4 Blocks
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  // BLOQUE 1: HÁBITOS DE CONVIVENCIA
                  _buildSectionHeader('🌿', 'HÁBITOS DE CONVIVENCIA'),
                  _buildBadgeTile(
                    icon: '🚬',
                    title: 'Fumar',
                    currentValue: _current.smoking != null
                        ? _formatOption(_smokingOptions, _current.smoking!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Hábito de fumar',
                      icon: '🚬',
                      options: _smokingOptions,
                      currentValue: _current.smoking,
                      onSelected: (val) => _update(_current.copyWith(smoking: val, clearSmoking: val == null)),
                    ),
                  ),
                  _buildBadgeTile(
                    icon: '🍷',
                    title: 'Tomar',
                    currentValue: _current.drinking != null
                        ? _formatOption(_drinkingOptions, _current.drinking!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Hábito de tomar alcohol',
                      icon: '🍷',
                      options: _drinkingOptions,
                      currentValue: _current.drinking,
                      onSelected: (val) => _update(_current.copyWith(drinking: val, clearDrinking: val == null)),
                    ),
                  ),
                  _buildBadgeTile(
                    icon: '🥗',
                    title: 'Dieta',
                    currentValue: _current.diet != null
                        ? _formatOption(_dietOptions, _current.diet!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Estilo de alimentación',
                      icon: '🥗',
                      options: _dietOptions,
                      currentValue: _current.diet,
                      onSelected: (val) => _update(_current.copyWith(diet: val, clearDiet: val == null)),
                    ),
                  ),
                  _buildBadgeTile(
                    icon: '🏃',
                    title: 'Ejercicio',
                    currentValue: _current.exercise != null
                        ? _formatOption(_exerciseOptions, _current.exercise!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Actividad física',
                      icon: '🏃',
                      options: _exerciseOptions,
                      currentValue: _current.exercise,
                      onSelected: (val) => _update(_current.copyWith(exercise: val, clearExercise: val == null)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BLOQUE 2: HOGAR & PLANES
                  _buildSectionHeader('🏡', 'HOGAR & PLANES'),
                  _buildBadgeTile(
                    icon: '📏',
                    title: 'Altura',
                    currentValue: _current.heightCm != null && _current.heightCm! > 0
                        ? '${_current.heightCm} cm'
                        : null,
                    onTap: _showHeightDialog,
                  ),
                  _buildBadgeTile(
                    icon: '👶',
                    title: 'Hijos',
                    currentValue: _current.kids != null
                        ? _formatOption(_kidsOptions, _current.kids!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Planes familiares e hijos',
                      icon: '👶',
                      options: _kidsOptions,
                      currentValue: _current.kids,
                      onSelected: (val) => _update(_current.copyWith(kids: val, clearKids: val == null)),
                    ),
                  ),
                  _buildBadgeTile(
                    icon: '🐾',
                    title: 'Mascotas',
                    currentValue: _current.pets != null
                        ? _formatOption(_petsOptions, _current.pets!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Mascotas y convivencia',
                      icon: '🐾',
                      options: _petsOptions,
                      currentValue: _current.pets,
                      onSelected: (val) => _update(_current.copyWith(pets: val, clearPets: val == null)),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // BLOQUE 3: TRAYECTORIA & MUNDO
                  _buildSectionHeader('💼', 'TRAYECTORIA & MUNDO'),
                  _buildBadgeTile(
                    icon: '💼',
                    title: 'Ocupación',
                    currentValue: _current.occupation?.isNotEmpty == true ? _current.occupation : null,
                    onTap: _showOccupationDialog,
                  ),
                  _buildBadgeTile(
                    icon: '🎓',
                    title: 'Educación',
                    currentValue: _current.education != null
                        ? _formatOption(_educationOptions, _current.education!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Nivel educacional',
                      icon: '🎓',
                      options: _educationOptions,
                      currentValue: _current.education,
                      onSelected: (val) => _update(_current.copyWith(education: val, clearEducation: val == null)),
                    ),
                  ),
                  _buildBadgeTile(
                    icon: '🗣️',
                    title: 'Idiomas',
                    currentValue: _current.languages.isNotEmpty
                        ? _current.languages.join(', ')
                        : null,
                    onTap: _showLanguagesDialog,
                  ),

                  const SizedBox(height: 16),

                  // BLOQUE 4: CURIOSIDADES & CONVICCIONES
                  _buildSectionHeader('✨', 'CURIOSIDADES & CONVICCIONES'),
                  _buildBadgeTile(
                    icon: '♈',
                    title: 'Zodiaco',
                    currentValue: _current.zodiac != null
                        ? _formatOption(_zodiacOptions, _current.zodiac!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Signo zodiacal',
                      icon: '♈',
                      options: _zodiacOptions,
                      currentValue: _current.zodiac,
                      onSelected: (val) => _update(_current.copyWith(zodiac: val, clearZodiac: val == null)),
                    ),
                  ),
                  _buildBadgeTile(
                    icon: '🕊️',
                    title: 'Religión / Espiritualidad',
                    currentValue: _current.religion != null
                        ? _formatOption(_religionOptions, _current.religion!)
                        : null,
                    onTap: () => _showSingleChoiceSheet(
                      title: 'Creencias y espiritualidad',
                      icon: '🕊️',
                      options: _religionOptions,
                      currentValue: _current.religion,
                      onSelected: (val) => _update(_current.copyWith(religion: val, clearReligion: val == null)),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Confirm Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 3,
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Text(
                    'Listo (${_current.activeCount}/12 activas)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: () {
                    widget.onSaved(_current);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String emoji, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeTile({
    required String icon,
    required String title,
    required String? currentValue,
    required VoidCallback onTap,
  }) {
    final hasValue = currentValue != null && currentValue.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasValue ? const Color(0xFF0284C7).withOpacity(0.5) : Colors.white10,
          width: hasValue ? 1.2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                const Spacer(),
                if (hasValue)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF0284C7)),
                    ),
                    child: Text(
                      currentValue,
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+ Añadir',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right, size: 18, color: Colors.white.withOpacity(0.3)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Quick Single Choice Selector ---
  void _showSingleChoiceSheet({
    required String title,
    required String icon,
    required List<MapEntry<String, String>> options,
    required String? currentValue,
    required ValueChanged<String?> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B1120),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ...options.map((opt) {
                  final isSelected = opt.key == currentValue;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(
                      opt.value,
                      style: TextStyle(
                        color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 20)
                        : null,
                    onTap: () {
                      onSelected(opt.key);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
                const Divider(color: Colors.white10),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.visibility_off_outlined, color: Colors.redAccent, size: 20),
                  title: const Text(
                    'No mostrar en mi perfil (Ocultar)',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                  onTap: () {
                    onSelected(null);
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Height Dialog ---
  void _showHeightDialog() {
    int tempHeight = _current.heightCm ?? 170;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Text('📏', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Text('Tu Altura / Estatura', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$tempHeight cm',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(dialogCtx).copyWith(
                      activeTrackColor: const Color(0xFF0284C7),
                      inactiveTrackColor: Colors.white12,
                      thumbColor: const Color(0xFF38BDF8),
                    ),
                    child: Slider(
                      value: tempHeight.toDouble(),
                      min: 140,
                      max: 220,
                      divisions: 80,
                      onChanged: (val) {
                        setDialogState(() {
                          tempHeight = val.round();
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _update(_current.copyWith(clearHeight: true));
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Ocultar en perfil', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  onPressed: () {
                    _update(_current.copyWith(heightCm: tempHeight));
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- Occupation Dialog ---
  void _showOccupationDialog() {
    final controller = TextEditingController(text: _current.occupation ?? '');
    final presets = ['Desarrollador(a)', 'Diseño / Arte', 'Salud / Medicina', 'Educación', 'Estudiante', 'Ingeniería', 'Gastronomía'];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('💼', style: TextStyle(fontSize: 22)),
              SizedBox(width: 10),
              Text('Tu Ocupación o Profesión', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ej: Diseñador UI/UX, Veterinaria...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Sugerencias rápidas:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: presets.map((p) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF1E293B),
                    label: Text(p, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    onPressed: () {
                      controller.text = p;
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _update(_current.copyWith(clearOccupation: true));
                Navigator.of(ctx).pop();
              },
              child: const Text('Ocultar', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
              onPressed: () {
                final text = controller.text.trim();
                _update(_current.copyWith(
                  occupation: text.isNotEmpty ? text : null,
                  clearOccupation: text.isEmpty,
                ));
                Navigator.of(ctx).pop();
              },
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- Languages Dialog ---
  void _showLanguagesDialog() {
    final availableLanguages = [
      'Español', 'Inglés', 'Portugués', 'Francés', 'Alemán', 'Italiano', 'Japonés', 'Coreano', 'Chino'
    ];
    final selected = List<String>.from(_current.languages);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Text('🗣️', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 10),
                  Text('Idiomas que hablas', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableLanguages.map((lang) {
                  final isSel = selected.contains(lang);
                  return FilterChip(
                    selected: isSel,
                    label: Text(lang),
                    selectedColor: const Color(0xFF0284C7),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: isSel ? Colors.white : Colors.white70,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (val) {
                      setDialogState(() {
                        if (val) {
                          selected.add(lang);
                        } else {
                          selected.remove(lang);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _update(_current.copyWith(clearLanguages: true));
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Limpiar', style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0284C7)),
                  onPressed: () {
                    _update(_current.copyWith(languages: selected));
                    Navigator.of(dialogCtx).pop();
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatOption(List<MapEntry<String, String>> list, String key) {
    for (final e in list) {
      if (e.key == key) return e.value;
    }
    return key;
  }

  // --- Option Definitions ---
  static const List<MapEntry<String, String>> _smokingOptions = [
    MapEntry('no_smoke', '🚭 No fumo'),
    MapEntry('social', '🍷🚬 Fumo socialmente'),
    MapEntry('tobacco', '🚬 Fumo tabaco'),
    MapEntry('vape', '💨 Vapeo'),
  ];

  static const List<MapEntry<String, String>> _drinkingOptions = [
    MapEntry('no_drink', '🚫 No bebo'),
    MapEntry('social', '🍷 Bebo socialmente'),
    MapEntry('frequent', '🍻 Bebo frecuente'),
    MapEntry('sober', '✨ Sobrio(a)'),
  ];

  static const List<MapEntry<String, String>> _dietOptions = [
    MapEntry('omnivore', '🍖 Omnívoro(a)'),
    MapEntry('vegetarian', '🥗 Vegetariano(a)'),
    MapEntry('vegan', '🌱 Vegano(a)'),
    MapEntry('pescatarian', '🐟 Pesquetariano(a)'),
    MapEntry('gluten_free', '🌾 Sin gluten / Celiaco'),
  ];

  static const List<MapEntry<String, String>> _exerciseOptions = [
    MapEntry('daily', '🏋️ Activo(a) a diario'),
    MapEntry('often', '🏃 Regular (3-4 veces/sem)'),
    MapEntry('sometimes', '🚶 De vez en cuando'),
    MapEntry('rarely', '🛋️ Modo relax / Casi nunca'),
  ];

  static const List<MapEntry<String, String>> _kidsOptions = [
    MapEntry('no_kids', '🧸 Sin hijos'),
    MapEntry('have_kids', '👶 Tengo hijos'),
    MapEntry('want_kids', '🍼 Quiero tener hijos'),
    MapEntry('dont_want_kids', '🚫 No quiero tener hijos'),
    MapEntry('open_to_kids', '🌱 Abierto(a) a tener hijos'),
  ];

  static const List<MapEntry<String, String>> _petsOptions = [
    MapEntry('dog', '🐶 Tengo perro(a)'),
    MapEntry('cat', '🐱 Tengo gato(a)'),
    MapEntry('both', '🐾 Tengo perros y gatos'),
    MapEntry('other', '🐰 Otras mascotas'),
    MapEntry('no_pets', '🪴 Sin mascotas'),
    MapEntry('allergic', '🤧 Alérgico(a) a animales'),
  ];

  static const List<MapEntry<String, String>> _educationOptions = [
    MapEntry('university', '🎓 Título Universitario'),
    MapEntry('in_university', '📚 En la Universidad'),
    MapEntry('postgraduate', '📜 Postgrado / Máster'),
    MapEntry('technical', '🛠️ Formación Técnica'),
    MapEntry('high_school', '🎒 Secundaria / Bachillerato'),
  ];

  static const List<MapEntry<String, String>> _zodiacOptions = [
    MapEntry('aries', '♈ Aries'),
    MapEntry('taurus', '♉ Tauro'),
    MapEntry('gemini', '♊ Géminis'),
    MapEntry('cancer', '♋ Cáncer'),
    MapEntry('leo', '♌ Leo'),
    MapEntry('virgo', '♍ Virgo'),
    MapEntry('libra', '♎ Libra'),
    MapEntry('scorpio', '♏ Escorpio'),
    MapEntry('sagittarius', '♐ Sagitario'),
    MapEntry('capricorn', '♑ Capricornio'),
    MapEntry('aquarius', '♒ Acuario'),
    MapEntry('pisces', '♓ Piscis'),
  ];

  static const List<MapEntry<String, String>> _religionOptions = [
    MapEntry('agnostic', '✨ Agnóstico(a)'),
    MapEntry('atheist', '⚛️ Ateo(a)'),
    MapEntry('spiritual', '🧘 Espiritual'),
    MapEntry('christian', '⛪ Cristiano / Católico'),
    MapEntry('buddhist', '🪷 Budista'),
  ];
}
