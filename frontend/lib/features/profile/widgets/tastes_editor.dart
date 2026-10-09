import 'package:flutter/material.dart';

import '../../../core/models/preference_tags.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';

/// Vibes and tastes by category (single-choice categories keep one). Each change reaches the server
/// at once ([AuthService.updateTastes]) and is reported through [onChanged].
///
/// Moved from the old profile form (`EditProfileScreen`, now gone) with its behaviour unchanged.
class TastesEditor extends StatefulWidget {
  const TastesEditor({super.key, required this.initialTastes, required this.initialIntent, this.onChanged});

  final List<String> initialTastes;
  final String initialIntent;
  final ValueChanged<List<String>>? onChanged;

  @override
  State<TastesEditor> createState() => _TastesEditorState();
}

class _TastesEditorState extends State<TastesEditor> {
  late final Set<String> _selectedTastes = Set<String>.from(widget.initialTastes);
  // ignore: unused_field
  late String _selectedIntent = widget.initialIntent;

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    widget.onChanged?.call(_selectedTastes.toList());
  }

  @override
  Widget build(BuildContext context) => _buildTastesSection();

  Widget _buildTastesSection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.interests, color: Color(0xFFA855F7), size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tus Vibes, Ejes & Gustos Cozy',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedTastes.length} seleccionados',
                style: const TextStyle(color: Color(0xFFC084FC), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Los 4 primeros ejes son obligatorios para conectar en sintonía. Los dilemas y gustos alimentan las preguntas de la fogata.',
            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          ...PreferenceCatalog.categories.map((cat) {
            final hasSelected = cat.items.any((it) => _selectedTastes.contains(it.id));
            final isObligatoryAndMissing = cat.isRequired && !hasSelected;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1120),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isObligatoryAndMissing
                      ? const Color(0xFFEF4444).withOpacity(0.6)
                      : (cat.isRequired ? const Color(0xFFF59E0B).withOpacity(0.4) : const Color(0xFF334155)),
                  width: isObligatoryAndMissing ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(cat.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cat.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                      ),
                      if (cat.isRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isObligatoryAndMissing
                                ? const Color(0xFFEF4444).withOpacity(0.2)
                                : const Color(0xFFF59E0B).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isObligatoryAndMissing ? '⚠️ Requerido' : '✓ Listo',
                            style: TextStyle(
                              color: isObligatoryAndMissing ? const Color(0xFFF87171) : const Color(0xFFFBBF24),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else if (cat.isSingleSelect)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Opcional • Elige solo 1',
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Opcional',
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    cat.isSingleSelect && !cat.isRequired
                        ? '${cat.description} (Opcional - solo se puede elegir 1)'
                        : cat.description,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: cat.items.map((item) {
                      final isSelected = _selectedTastes.contains(item.id);
                      return FilterChip(
                        label: Text('${item.emoji} ${item.title}'),
                        selected: isSelected,
                        selectedColor: cat.isRequired
                            ? const Color(0xFFF59E0B).withOpacity(0.3)
                            : const Color(0xFFA855F7).withOpacity(0.3),
                        backgroundColor: const Color(0xFF1E293B),
                        checkmarkColor: cat.isRequired ? const Color(0xFFFBBF24) : const Color(0xFFC084FC),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? (cat.isRequired ? const Color(0xFFF59E0B) : const Color(0xFFA855F7))
                                : const Color(0xFF334155),
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (cat.isSingleSelect) {
                              // Desmarcar otros items de la misma categoría
                              for (final other in cat.items) {
                                _selectedTastes.remove(other.id);
                              }
                              if (selected) {
                                _selectedTastes.add(item.id);
                                if (cat.id == 'dating_intentions') {
                                  _selectedIntent = item.id;
                                  AvatarStorageService.saveUserIntent(
                                    AuthService.currentUser?.id ?? AvatarStorageService.activeUserId,
                                    item.id,
                                  );
                                }
                              }
                            } else {
                              if (selected) {
                                _selectedTastes.add(item.id);
                              } else {
                                _selectedTastes.remove(item.id);
                              }
                            }
                          });
                          AuthService.updateTastes(_selectedTastes.toList());
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

}
