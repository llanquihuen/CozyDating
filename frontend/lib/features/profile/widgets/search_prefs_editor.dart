import 'package:flutter/material.dart';

/// Who you are and who you seek, where you are, your age and your search range (distance and the
/// optional age filter). Only you see these. [onChanged] reports every change; the caller saves.
///
/// Moved from the old profile form (`EditProfileScreen`, now gone) with its behaviour unchanged.
class SearchPrefs {
  const SearchPrefs({
    required this.gender,
    required this.seekingGender,
    required this.age,
    required this.commune,
    required this.isInternational,
    required this.maxDistanceKm,
    this.seekingAgeMin,
    this.seekingAgeMax,
  });

  final String gender;
  final String seekingGender;
  final int age;
  final String commune;
  final bool isInternational;
  final double maxDistanceKm;
  final int? seekingAgeMin;
  final int? seekingAgeMax;
}

class SearchPrefsEditor extends StatefulWidget {
  const SearchPrefsEditor({super.key, required this.initial, this.onChanged});

  final SearchPrefs initial;
  final ValueChanged<SearchPrefs>? onChanged;

  @override
  State<SearchPrefsEditor> createState() => _SearchPrefsEditorState();
}

class _SearchPrefsEditorState extends State<SearchPrefsEditor> {
  late String _userGender = widget.initial.gender;
  late String _seekingGender = widget.initial.seekingGender;
  late final int _userAge = widget.initial.age;
  late final String _userCommune = widget.initial.commune;
  late bool _isInternational = widget.initial.isInternational;
  late double _selectedDistanceKm = widget.initial.maxDistanceKm;
  late int? _seekingAgeMin = widget.initial.seekingAgeMin;
  late int? _seekingAgeMax = widget.initial.seekingAgeMax;
  late final TextEditingController _communeController = TextEditingController(text: _userCommune)
    ..addListener(_report);


  static const int _minAge = 18;
  static const int _maxAge = 99;

  SearchPrefs get _value => SearchPrefs(
        gender: _userGender,
        seekingGender: _seekingGender,
        age: _userAge,
        commune: _communeController.text.trim().isNotEmpty ? _communeController.text.trim() : _userCommune,
        isInternational: _isInternational,
        maxDistanceKm: _selectedDistanceKm,
        seekingAgeMin: _seekingAgeMin,
        seekingAgeMax: _seekingAgeMax,
      );

  void _report() => widget.onChanged?.call(_value);

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _report();
  }

  @override
  void dispose() {
    _communeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildIdentitySection(),
        const SizedBox(height: 16),
        _buildDistanceAndAgeSection(),
      ],
    );
  }

  Widget _buildIdentitySection() {
    final genderOptions = [
      {'value': 'MAN', 'label': '👨 Hombre'},
      {'value': 'WOMAN', 'label': '👩 Mujer'},
      {'value': 'NON_BINARY', 'label': '✨ No binario'},
    ];

    final seekingOptions = [
      {'value': 'WOMAN', 'label': '👩 Mujeres'},
      {'value': 'MAN', 'label': '👨 Hombres'},
      {'value': 'ANY', 'label': '💫 Todos'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección Identidad & Búsqueda
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFFFF4081), size: 20),
              SizedBox(width: 8),
              Flexible(
                  child: Text(
                'Identidad & A Quién Buscas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'El emparejamiento empareja solo a personas con compatibilidad mutua.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // ¿Cómo te identificas? (Soy)
          const Text('Soy:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: genderOptions.map((opt) {
              final isSelected = _userGender == opt['value'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                selectedColor: const Color(0xFFFF4081).withOpacity(0.3),
                backgroundColor: const Color(0xFF0F172A),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFFFF4081) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFFF4081) : const Color(0xFF475569),
                ),
                onSelected: (selected) {
                  if (!selected) return;
                  setState(() => _userGender = opt['value']!);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ¿A quién buscas? (Busco)
          const Text('Busco conocer:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: seekingOptions.map((opt) {
              final isSelected = _seekingGender == opt['value'];
              return ChoiceChip(
                label: Text(opt['label']!),
                selected: isSelected,
                selectedColor: const Color(0xFF38BDF8).withOpacity(0.3),
                backgroundColor: const Color(0xFF0F172A),
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                ),
                onSelected: (selected) {
                  if (selected) setState(() => _seekingGender = opt['value']!);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  bool get _hasAgeFilter => _seekingAgeMin != null || _seekingAgeMax != null;

  /// Where you are, how far to search, and the optional age range sought.
  Widget _buildDistanceAndAgeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sección Ubicación
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF10B981), size: 20),
              SizedBox(width: 8),
              Flexible(
                  child: Text(
                'Tu Ciudad / Comuna',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Escribe la ciudad o comuna donde resides para calcular distancias aproximadas.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // Campo de texto de Ciudad y Edad
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _communeController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.location_city, color: Color(0xFF10B981), size: 18),
                    hintText: 'Ej. Santiago, Valdivia, Viña...',
                    hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF475569)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFF10B981)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF475569)),
                ),
                child: Text(
                  '$_userAge años',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nota de privacidad amigable
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tu privacidad está protegida: Solo calculamos proximidad aproximada (~2 km), nunca tu calle ni dirección exacta.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 12),

          // Alcance Internacional
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Explorar sin fronteras (Global):',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Emparejar con compañeros de otros países',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                ],
              )),
              Switch(
                value: _isInternational,
                activeColor: const Color(0xFF38BDF8),
                onChanged: (val) {
                  setState(() => _isInternational = val);
                },
              ),
            ],
          ),

          if (!_isInternational) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                    child: const Text(
                  'Distancia máxima preferida:',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                )),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Text(
                    _selectedDistanceKm >= 100 ? 'Sin límite (Nacional)' : '${_selectedDistanceKm.toInt()} km',
                    style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            Slider(
              value: _selectedDistanceKm.clamp(5.0, 100.0),
              min: 5.0,
              max: 100.0,
              divisions: 19,
              activeColor: const Color(0xFF10B981),
              inactiveColor: const Color(0xFF334155),
              onChanged: (val) {
                setState(() => _selectedDistanceKm = val);
              },
            ),
            const Text(
              '💡 Si transcurren más de 15 segundos sin personas en tu radio, la búsqueda se expandirá gradualmente para no hacerte esperar.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
            ),
          ],

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF334155)),
          const SizedBox(height: 12),

          // Filtro de edad: apagado por defecto; si se activa, cuenta en ambos sentidos
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtrar por edad',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Solo te emparejamos si cada uno está en el rango del otro.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasAgeFilter,
                activeThumbColor: const Color(0xFF38BDF8),
                onChanged: (on) => setState(() {
                  if (on) {
                    // Start around the player's own age.
                    _seekingAgeMin = (_userAge - 5).clamp(_minAge, _maxAge);
                    _seekingAgeMax = (_userAge + 5).clamp(_minAge, _maxAge);
                  } else {
                    _seekingAgeMin = null;
                    _seekingAgeMax = null;
                  }
                }),
              ),
            ],
          ),
          if (_hasAgeFilter) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Edad que buscas:',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_seekingAgeMin ?? _minAge} – ${_seekingAgeMax ?? _maxAge} años',
                  style: const TextStyle(color: Color(0xFF7DD3FC), fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            RangeSlider(
              values: RangeValues(
                (_seekingAgeMin ?? _minAge).toDouble(),
                (_seekingAgeMax ?? _maxAge).toDouble(),
              ),
              min: _minAge.toDouble(),
              max: _maxAge.toDouble(),
              divisions: _maxAge - _minAge,
              activeColor: const Color(0xFF38BDF8),
              inactiveColor: const Color(0xFF334155),
              labels: RangeLabels('${_seekingAgeMin ?? _minAge}', '${_seekingAgeMax ?? _maxAge}'),
              onChanged: (range) => setState(() {
                _seekingAgeMin = range.start.round();
                _seekingAgeMax = range.end.round();
              }),
            ),
          ],
        ],
      ),
    );
  }
}
