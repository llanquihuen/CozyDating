import 'package:flutter/material.dart';
import '../../../core/models/preference_tags.dart';
import '../../../core/widgets/fullscreen_photo_viewer.dart';
import '../../mailbox/models/mailbox_models.dart';
import '../../mailbox/widgets/letter_photo_carousel.dart';

class PostCampfireDecisionDialog extends StatefulWidget {
  final MailboxLetter letter;
  final int coinsEarned;
  final ValueChanged<MailboxDecision> onDecision;
  final VoidCallback onPostponeToHome;
  final VoidCallback? onShowFullProfile;

  const PostCampfireDecisionDialog({
    super.key,
    required this.letter,
    this.coinsEarned = 150,
    required this.onDecision,
    required this.onPostponeToHome,
    this.onShowFullProfile,
  });

  @override
  State<PostCampfireDecisionDialog> createState() => _PostCampfireDecisionDialogState();
}

class _PostCampfireDecisionDialogState extends State<PostCampfireDecisionDialog> {
  bool _isSubmitting = false;
  MailboxDecision? _selectedDecision;

  void _handleDecision(MailboxDecision decision) {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _selectedDecision = decision;
    });
    widget.onDecision(decision);
  }

  @override
  Widget build(BuildContext context) {
    final letter = widget.letter;
    final photos = letter.effectivePhotos;

    return Dialog(
      backgroundColor: const Color(0xFF111422),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Coins Banner
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '+${widget.coinsEarned} MONEDAS · AVENTURA SUPERADA',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFCD34D),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Title
              Text(
                '¿Cómo sentiste la conexión con ${letter.partnerName}?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Han compartido historias frente al fuego. Ahora pueden revelarse mutuamente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // Real Photo Polaroid Card
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    LetterPhotoCarousel(
                      photos: photos,
                      height: 290,
                      onTap: widget.onShowFullProfile,
                      onExpand: (index) {
                        FullScreenPhotoViewer.open(
                          context,
                          photos: photos,
                          initialIndex: index,
                          title: letter.partnerName,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${letter.partnerName}, ${letter.partnerAge}',
                      style: const TextStyle(
                        color: Color(0xFF1E1B2E),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        fontFamily: 'Caveat',
                      ),
                    ),
                    Text(
                      '📍 ${letter.partnerCommune}',
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                    if (letter.effectiveBio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '"${letter.effectiveBio}"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Discovered tags from campfire
              if (letter.commonTastes.isNotEmpty) ...[
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: letter.commonTastes.take(4).map((tagId) {
                    final item = PreferenceCatalog.findById(tagId);
                    final emoji = item?.emoji ?? '✨';
                    final title = item?.title ?? tagId;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2333),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Text(
                        '$emoji $title',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
              ],

              // Confidentiality Shield / Privacy Notice
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE11D48).withOpacity(0.4)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tu voto es secreto. Si eliges Romance y la otra persona Amistad, conectarán como amigos y nunca sabrá que elegiste Romance.',
                        style: TextStyle(
                          color: Color(0xFFFDA4AF),
                          fontSize: 11,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (_isSubmitting) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                  ),
                ),
              ] else ...[
                // Option 1: 💖 Hubo Chispa (Romance)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    elevation: 3,
                  ),
                  onPressed: () => _handleDecision(MailboxDecision.romance),
                  child: const Row(
                    children: [
                      Text('💖', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hubo Chispa! (Romance)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Sentí química y me gustaría conocerle más',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Option 2: 🤝 Buena Onda (Amistad / Dúo)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                    elevation: 2,
                  ),
                  onPressed: () => _handleDecision(MailboxDecision.friendship),
                  child: const Row(
                    children: [
                      Text('🤝', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gran Onda (Amistad / Dúo)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Me encantó la partida para jugar o charlar',
                              style: TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Option 3: 🕊️ Buen Recuerdo (Pasar)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  ),
                  onPressed: () => _handleDecision(MailboxDecision.archived),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🕊️', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 8),
                      Text(
                        'Dejar como un buen recuerdo',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Option 4: 💭 Déjame pensarlo · Ir a mi Hogar
                TextButton.icon(
                  onPressed: widget.onPostponeToHome,
                  icon: const Icon(Icons.home_rounded, size: 18, color: Color(0xFFF59E0B)),
                  label: const Text(
                    '💭 Déjame pensarlo · Ir a mi Hogar',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    '(Podrás decidir con calma desde tu buzón)',
                    style: TextStyle(color: Colors.white38, fontSize: 10.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
