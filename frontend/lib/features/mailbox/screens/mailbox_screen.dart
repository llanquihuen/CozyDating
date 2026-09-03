import 'package:flutter/material.dart';
import '../../../core/models/preference_tags.dart';
import '../models/mailbox_models.dart';
import '../services/mailbox_service.dart';

class MailboxScreen extends StatefulWidget {
  final VoidCallback? onClosed;

  const MailboxScreen({super.key, this.onClosed});

  @override
  State<MailboxScreen> createState() => _MailboxScreenState();
}

class _MailboxScreenState extends State<MailboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<MailboxLetter> _letters = [];
  bool _isLoading = true;

  final Map<String, String> _selectedNotes = {};
  final Map<String, TextEditingController> _customNoteControllers = {};

  final List<String> _quickStickers = [
    '☕ ¡Me encantó nuestra charla!',
    '🗡️ ¡Gran equipo en la mazmorra!',
    '🎮 ¡Ojalá juguemos de nuevo!',
    '✨ ¡Tuvimos muy linda sintonía!',
    '🌱 Me gustó tu energía tranquila',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLetters();
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (var controller in _customNoteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLetters() async {
    setState(() => _isLoading = true);
    final letters = await MailboxService.fetchLetters();
    if (mounted) {
      setState(() {
        _letters = letters;
        _isLoading = false;
      });
    }
  }

  PreferenceItem? _getPreferenceItem(String id) {
    for (final category in PreferenceCatalog.categories) {
      for (final item in category.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }

  Future<void> _handleDecision(MailboxLetter letter, MailboxDecision decision) async {
    final customText = _customNoteControllers[letter.id]?.text.trim();
    final selectedSticker = _selectedNotes[letter.id];
    String? finalNote;
    if (customText != null && customText.isNotEmpty) {
      finalNote = customText;
    } else if (selectedSticker != null) {
      finalNote = selectedSticker;
    }

    await MailboxService.submitDecision(
      matchId: letter.id,
      decision: decision,
      note: finalNote,
    );

    await _loadLetters();

    if (mounted) {
      if (decision == MailboxDecision.keepInTouch) {
        final updated = _letters.firstWhere((l) => l.id == letter.id, orElse: () => letter);
        if (updated.isMutualMatch) {
          _showMutualMatchDialog(updated);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('💌 Carta enviada con cariño... Llegará si el destino coincide ✨'),
              backgroundColor: Color(0xFF2E7D32),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🕊️ Guardado con cariño en tu Baúl de Recuerdos'),
            backgroundColor: Color(0xFF455A64),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showMutualMatchDialog(MailboxLetter letter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFFFD54F), width: 2),
        ),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✨ ¡Conexión Mutua! ✨', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '¡Ambos eligieron seguir en contacto!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 14),
            if (letter.partnerPhoto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  letter.partnerPhoto!,
                  height: 160,
                  width: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 80, color: Colors.white70),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              '${letter.partnerName}, ${letter.partnerAge} años',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text('📍 ${letter.partnerCommune}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            if (letter.partnerNote != null && letter.partnerNote!.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.4)),
                ),
                child: Text(
                  '💬 "${letter.partnerNote}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFFFE082), fontStyle: FontStyle.italic, fontSize: 13),
                ),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD54F),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              _tabController.animateTo(1); // Go to mutual matches tab
            },
            child: const Text('Ver en Conexiones Mutuas', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingLetters = _letters.where((l) => l.myDecision == MailboxDecision.pending).toList();
    final mutualMatches = _letters.where((l) => l.isMutualMatch).toList();
    final archivedLetters = _letters.where((l) => l.myDecision == MailboxDecision.archived || (l.myDecision == MailboxDecision.keepInTouch && !l.isMutualMatch)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF14121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1B2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.onClosed?.call();
            Navigator.of(context).pop();
          },
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📮 ', style: TextStyle(fontSize: 20)),
            Text(
              'Buzón de Recuerdos',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD54F),
          indicatorWeight: 3,
          labelColor: const Color(0xFFFFD54F),
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('💌 Nuevas'),
                  if (pendingLetters.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD54F),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${pendingLetters.length}',
                        style: const TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✨ Mutuas'),
                  if (mutualMatches.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF66BB6A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${mutualMatches.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: '📜 Baúl'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFD54F)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingTab(pendingLetters),
                _buildMutualTab(mutualMatches),
                _buildArchivedTab(archivedLetters),
              ],
            ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab 1: Pending Letters with Real Photo Reveal
  // -------------------------------------------------------------------------
  Widget _buildPendingTab(List<MailboxLetter> letters) {
    if (letters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📭', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Buzón al día', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'No tienes cartas pendientes.\n¡Juega una cita en la mazmorra para conocer a alguien!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        return _buildPendingLetterCard(letters[index]);
      },
    );
  }

  Widget _buildPendingLetterCard(MailboxLetter letter) {
    _customNoteControllers.putIfAbsent(letter.id, () => TextEditingController());
    final controller = _customNoteControllers[letter.id]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Letter Header / Postal Stamp
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF28253B),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('💌 ', style: TextStyle(fontSize: 16)),
                    Text(
                      'Carta de la Fogata',
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD54F).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.5)),
                  ),
                  child: const Text('✨ Foto Revelada', style: TextStyle(color: Color(0xFFFFD54F), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Real Photo Polaroid Card
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: letter.partnerPhoto != null && letter.partnerPhoto!.isNotEmpty
                            ? Image.network(
                                letter.partnerPhoto!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildAvatarFallback(letter),
                              )
                            : _buildAvatarFallback(letter),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${letter.partnerName}, ${letter.partnerAge}',
                        style: const TextStyle(
                          color: Color(0xFF1E1B2E),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: 'Caveat',
                        ),
                      ),
                      Text(
                        '📍 ${letter.partnerCommune}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Discovered affinities from campfire
                if (letter.commonTastes.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '🔥 Afinidades descubiertas en la Fogata:',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: letter.commonTastes.map((tagId) {
                      final item = _getPreferenceItem(tagId);
                      final emoji = item?.emoji ?? '✨';
                      final title = item?.title ?? tagId;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF28253B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Text('$emoji $title', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Quick Stickers Selector
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '💬 Elige una nota rápida o escribe tu mensaje:',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _quickStickers.map((sticker) {
                    final isSelected = _selectedNotes[letter.id] == sticker;
                    return ChoiceChip(
                      label: Text(sticker, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black87 : Colors.white70)),
                      selected: isSelected,
                      selectedColor: const Color(0xFFFFD54F),
                      backgroundColor: const Color(0xFF28253B),
                      onSelected: (selected) {
                        setState(() {
                          _selectedNotes[letter.id] = selected ? sticker : '';
                          if (selected) controller.text = sticker;
                        });
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 10),

                // Note composer TextField
                TextField(
                  controller: controller,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Escribe una nota cálida de despedida...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFF14121F),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 16),

                // Friendly Decision Buttons (Zero-rejection)
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: BorderSide(color: Colors.white.withOpacity(0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => _handleDecision(letter, MailboxDecision.archived),
                        child: const Text('🕊️ Guardar recuerdo', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD54F),
                          foregroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                        ),
                        onPressed: () => _handleDecision(letter, MailboxDecision.keepInTouch),
                        child: const Text('💌 Seguir en contacto', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(MailboxLetter letter) {
    return Container(
      height: 180,
      width: double.infinity,
      color: const Color(0xFF28253B),
      child: const Center(
        child: Icon(Icons.account_circle, size: 90, color: Color(0xFFFFD54F)),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab 2: Mutual Matches (Both said Yes!)
  // -------------------------------------------------------------------------
  Widget _buildMutualTab(List<MailboxLetter> letters) {
    if (letters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Aún no hay conexiones mutuas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              'Cuando ambos elijan "Seguir en contacto",\nsus cartas y notas aparecerán aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFFD54F).withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: letter.partnerPhoto != null
                        ? Image.network(letter.partnerPhoto!, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: Colors.white))
                        : const Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(letter.partnerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 6),
                            const Text('✨', style: TextStyle(fontSize: 14)),
                          ],
                        ),
                        Text('${letter.partnerAge} años • ${letter.partnerCommune}', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF66BB6A).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF66BB6A)),
                          ),
                          child: const Text('¡Match Confirmado! 💖', style: TextStyle(color: Color(0xFF81C784), fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (letter.partnerNote != null && letter.partnerNote!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFD54F).withOpacity(0.3)),
                  ),
                  child: Text(
                    '💬 Su nota: "${letter.partnerNote}"',
                    style: const TextStyle(color: Color(0xFFFFE082), fontStyle: FontStyle.italic, fontSize: 13),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Tab 3: Archived Memories
  // -------------------------------------------------------------------------
  Widget _buildArchivedTab(List<MailboxLetter> letters) {
    if (letters.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📜', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Baúl de Recuerdos vacío', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        final isSentWaiting = letter.myDecision == MailboxDecision.keepInTouch && !letter.isMutualMatch;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B2E).withOpacity(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: letter.partnerPhoto != null
                    ? Image.network(letter.partnerPhoto!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54))
                    : const Icon(Icons.person, color: Colors.white54),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(letter.partnerName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${letter.partnerAge} años • ${letter.partnerCommune}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      isSentWaiting
                          ? '💌 Carta enviada con cariño ✨'
                          : '🕊️ Guardado como lindo recuerdo',
                      style: TextStyle(
                        color: isSentWaiting ? const Color(0xFFFFD54F) : Colors.white60,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
