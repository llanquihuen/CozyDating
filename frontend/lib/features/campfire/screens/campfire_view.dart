import 'dart:async' as async;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../game/bloc/game_bloc.dart';
import '../../mailbox/models/mailbox_models.dart';
import '../../mailbox/services/mailbox_service.dart';
import '../games/campfire_scene_game.dart';
import '../models/campfire_models.dart';
import '../services/campfire_card_catalog.dart';
import '../widgets/campfire_summary_dialog.dart';

class CampfireView extends StatefulWidget {
  final UserProfile localUser;
  final UserProfile? partnerUser;
  final String partnerName;
  final AvatarConfig? partnerAvatarConfig;
  final int? seed;
  final String? roomId;
  final VoidCallback onReturnHome;

  const CampfireView({
    super.key,
    required this.localUser,
    this.partnerUser,
    required this.partnerName,
    this.partnerAvatarConfig,
    this.seed,
    this.roomId,
    required this.onReturnHome,
  });

  @override
  State<CampfireView> createState() => _CampfireViewState();
}

class _CampfireViewState extends State<CampfireView> {
  late final CampfireSceneGame _game;
  late final List<CampfireCard> _cards;

  int _currentRound = 0;
  String? _localSelectedOptionId;
  String? _partnerSelectedOptionId;
  bool _isRevealed = false;

  int? _lastHandledEmoteTrigger;
  int? _lastHandledNextRoundTrigger;
  async.StreamSubscription<GameState>? _blocSub;

  @override
  void initState() {
    super.initState();

    final partnerFallback = widget.partnerUser ??
        UserProfile(
          id: 'partner_default',
          username: widget.partnerName,
          tastes: const ['game_coop', 'intent_slow'],
        );

    _cards = CampfireCardCatalog.selectCardsForUsers(
      widget.localUser,
      partnerFallback,
      seed: widget.seed,
    );

    _game = CampfireSceneGame(
      localAvatarConfig: widget.localUser.avatarConfig,
      partnerAvatarConfig: widget.partnerAvatarConfig ?? partnerFallback.avatarConfig,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      final bloc = context.read<GameBloc>();
      _blocSub ??= bloc.stream.listen(_handleGameState);
    } catch (_) {
      // Standalone mode / offline tests without GameBloc provider
    }
  }

  @override
  void dispose() {
    _blocSub?.cancel();
    super.dispose();
  }

  void _handleGameState(GameState state) {
    if (!mounted) return;
    if (state is ActiveGameState) {
      // 1. Synchronized partner emote
      if (state.latestEmote != null && state.emoteTrigger != _lastHandledEmoteTrigger) {
        _lastHandledEmoteTrigger = state.emoteTrigger;
        _game.triggerEmote(state.latestEmote!, onLeft: false);
      }

      // 2. Synchronized partner answer
      if (state.partnerCampfireRound == _currentRound &&
          state.partnerCampfireOptionId != null &&
          _partnerSelectedOptionId != state.partnerCampfireOptionId) {
        setState(() {
          _partnerSelectedOptionId = state.partnerCampfireOptionId;
        });
        if (_localSelectedOptionId != null && !_isRevealed) {
          _revealBothAnswers();
        }
      }

      // 3. Synchronized next round advance
      if (state.campfireNextRoundTrigger != null &&
          state.campfireNextRoundTrigger != _lastHandledNextRoundTrigger) {
        _lastHandledNextRoundTrigger = state.campfireNextRoundTrigger;
        if (_isRevealed && _currentRound < _cards.length - 1) {
          _advanceToRound(_currentRound + 1);
        }
      }
    }
  }

  void _onOptionSelected(String optionId) {
    if (_isRevealed || _localSelectedOptionId != null) return;

    setState(() {
      _localSelectedOptionId = optionId;
    });

    try {
      context.read<GameBloc>().add(SendCampfireAnswerEvent(
        round: _currentRound,
        optionId: optionId,
      ));
    } catch (e) {
      print('[CAMPFIRE] Offline mode sending answer: $e');
    }

    // If partner already selected their option for this round, reveal immediately!
    if (_partnerSelectedOptionId != null) {
      _revealBothAnswers();
    }
  }

  void _revealBothAnswers() {
    setState(() {
      _isRevealed = true;
    });

    // Trigger celebration emotes on fire scene
    if (_localSelectedOptionId == _partnerSelectedOptionId) {
      _game.triggerEmote('❤️', onLeft: true);
      _game.triggerEmote('❤️', onLeft: false);
    } else {
      _game.triggerEmote('✨', onLeft: true);
      _game.triggerEmote('🔥', onLeft: false);
    }
  }

  void _nextCard() {
    if (_currentRound < _cards.length - 1) {
      final nextRound = _currentRound + 1;
      try {
        context.read<GameBloc>().add(SendCampfireNextRoundEvent(round: nextRound));
      } catch (e) {
        print('[CAMPFIRE] Offline next round: $e');
      }
      _advanceToRound(nextRound);
    } else {
      _showCompletionDialog();
    }
  }

  void _advanceToRound(int round) {
    if (round < _cards.length) {
      setState(() {
        _currentRound = round;
        _localSelectedOptionId = null;
        _partnerSelectedOptionId = null;
        _isRevealed = false;
      });
    }
  }

  void _showCompletionDialog() {
    final hasFriendship = widget.localUser.tastes.contains('intent_gaming_duo') ||
        widget.localUser.tastes.contains('intent_cozy_chats');

    // Send date completion signal to server to record mailbox match
    try {
      context.read<GameBloc>().add(const SendCampfireCompletedEvent());
    } catch (e) {
      print('[CAMPFIRE] Offline completion: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CampfireSummaryDialog(
        partnerName: widget.partnerName,
        localAvatar: widget.localUser.avatarConfig,
        partnerAvatar: widget.partnerAvatarConfig,
        coinsEarned: 150,
        connectionTypeTitle: hasFriendship ? '¡DÚO DE AVENTURAS!' : '¡CONEXIÓN ESPECIAL!',
        connectionTypeEmoji: hasFriendship ? '🤝' : '❤️',
        onReturnHome: () {
          Navigator.of(context).pop();
          _handleReturnHome();
        },
      ),
    );
  }

  void _handleReturnHome() {
    // 1. Accrue coins to user profile & storage
    final localId = widget.localUser.id;
    final localName = widget.localUser.username;
    AvatarStorageService.addCoins(localId, 150);
    AuthService.addCoins(150);

    // 2. Generate Tinder-like date letter in mailbox
    final partner = widget.partnerUser;
    var partnerId = partner?.id ?? widget.partnerName.toLowerCase();
    var partnerName = widget.partnerName;

    // Safety guard: Ensure partner is never the local user
    if (partnerId.isEmpty || partnerId == localId) {
      partnerId = (localId == 'userA' || localId == 'alice') ? 'userB' : 'userA';
    }
    if (partnerName.isEmpty || partnerName == localName || partnerName == 'Tú') {
      partnerName = (localId == 'userA' || localId == 'alice') ? 'Bob' : 'Alice';
    }

    final partnerPhoto = partner?.profilePhoto ?? AvatarStorageService.getUserPhoto(partnerId);
    final partnerAge = (partner?.age != null && partner!.age > 0) ? partner.age : 24;
    final partnerCommune = (partner?.commune != null && partner!.commune.isNotEmpty) ? partner.commune : 'Santiago';

    final sharedTags = widget.localUser.tastes.where((t) => partner?.tastes.contains(t) ?? false).toList();
    final fallbackTags = _cards.map((c) => c.matchReason).whereType<String>().where((s) => s.isNotEmpty).take(3).toList();

    final dateLetter = MailboxLetter(
      id: widget.roomId ?? 'date_${DateTime.now().millisecondsSinceEpoch}',
      partnerId: partnerId,
      partnerName: partnerName,
      partnerAvatar: widget.partnerAvatarConfig ?? partner?.avatarConfig ?? AvatarStorageService.getUserConfig(partnerId),
      partnerPhoto: partnerPhoto,
      partnerAge: partnerAge,
      partnerCommune: partnerCommune,
      commonTastes: sharedTags.isNotEmpty ? sharedTags : (fallbackTags.isNotEmpty ? fallbackTags : const ['game_coop', 'intent_slow']),
      myDecision: MailboxDecision.pending,
      createdAt: DateTime.now(),
    );
    MailboxService.addDateLetter(dateLetter);

    // 3. Reset GameBloc
    try {
      context.read<GameBloc>().add(const ResetGameEvent());
    } catch (e) {
      print('[CAMPFIRE] ResetGameEvent: $e');
    }

    widget.onReturnHome();
  }

  void _sendReactionEmote(String emote) {
    _game.triggerEmote(emote, onLeft: true);
    try {
      context.read<GameBloc>().add(SendEmoteEvent(emote));
    } catch (e) {
      print('[CAMPFIRE] Offline emote: $e');
    }
  }

  String _getCategoryDiscreteLabel(CampfireCardType type) {
    switch (type) {
      case CampfireCardType.sharedPassion:
        return '🌿 Pasión en Común';
      case CampfireCardType.curiousContrast:
        return '⚖️ El Contraste';
      case CampfireCardType.deepConnection:
        return '✨ Conexión Real';
      case CampfireCardType.discoveryWildcard:
        return '🧭 Descubrimiento';
      case CampfireCardType.mirrorComplicity:
        return '✨ Complicidad';
      case CampfireCardType.universalValues:
        return '🌱 Valores Humanos';
    }
  }

  Color _getCategoryColor(CampfireCardType type) {
    switch (type) {
      case CampfireCardType.sharedPassion:
        return Colors.lightGreenAccent;
      case CampfireCardType.curiousContrast:
        return Colors.orangeAccent;
      case CampfireCardType.deepConnection:
        return Colors.pinkAccent;
      case CampfireCardType.discoveryWildcard:
        return Colors.cyanAccent;
      case CampfireCardType.mirrorComplicity:
        return Colors.purpleAccent;
      case CampfireCardType.universalValues:
        return Colors.amberAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = _cards[_currentRound];
    final categoryLabel = _getCategoryDiscreteLabel(currentCard.type);
    final categoryColor = _getCategoryColor(currentCard.type);

    return Scaffold(
        backgroundColor: const Color(0xFF090A10),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Discrete Category Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Discrete escape button
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      icon: const Text('🪙', style: TextStyle(fontSize: 14)),
                      label: const Text(
                        'Reclamar botín y salir',
                        style: TextStyle(fontSize: 11),
                      ),
                      onPressed: _handleReturnHome,
                    ),
                    const Spacer(),
                    // Discrete Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: categoryColor.withOpacity(0.6)),
                      ),
                      child: Text(
                        categoryLabel,
                        style: TextStyle(
                          color: categoryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Round Progress Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.6)),
                      ),
                      child: Text(
                        'Ronda ${_currentRound + 1} de ${_cards.length}',
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Campfire Flame Canvas (Upper half)
              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepOrangeAccent.withOpacity(0.12),
                        blurRadius: 24,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: GameWidget(game: _game),
                ),
              ),

              // Quick Emote Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: ['❤️', '👏', '☕', '🔥', '😂'].map((emote) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: InkWell(
                        onTap: () => _sendReactionEmote(emote),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141724),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(emote, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Card & Options Area (Lower half)
              Expanded(
                flex: 6,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131520),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Partner Answer Hint Banner (before local answer)
                      if (_partnerSelectedOptionId != null && _localSelectedOptionId == null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.tealAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.tealAccent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Text('✨', style: TextStyle(fontSize: 12)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${widget.partnerName} ya ha elegido. ¡Selecciona tu opción para revelar!',
                                  style: const TextStyle(color: Colors.tealAccent, fontSize: 10.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Match Reason Badge (Por qué se hace esta pregunta)
                      if (currentCard.matchReason != null && currentCard.matchReason!.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.psychology_alt_rounded, size: 14, color: Colors.amberAccent),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  currentCard.matchReason!,
                                  style: const TextStyle(
                                    color: Color(0xFFFDE68A),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],

                      // Category Header
                      Text(
                        currentCard.categoryHeader,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Question Text
                      Text(
                        currentCard.question,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Options List
                      Expanded(
                        child: ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: currentCard.options.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final option = currentCard.options[index];
                            final isLocalSelected = _localSelectedOptionId == option.id;
                            final isPartnerSelected = _partnerSelectedOptionId == option.id;

                            Color borderColor = Colors.white10;
                            Color bgColor = const Color(0xFF1C2030);

                            if (isLocalSelected && isPartnerSelected && _isRevealed) {
                              borderColor = Colors.amberAccent;
                              bgColor = Colors.amber.withOpacity(0.18);
                            } else if (isLocalSelected && _isRevealed) {
                              borderColor = Colors.tealAccent;
                              bgColor = Colors.teal.withOpacity(0.15);
                            } else if (isPartnerSelected && _isRevealed) {
                              borderColor = Colors.deepOrangeAccent;
                              bgColor = Colors.deepOrange.withOpacity(0.15);
                            } else if (isLocalSelected) {
                              borderColor = Colors.tealAccent;
                              bgColor = Colors.teal.withOpacity(0.15);
                            }

                            return InkWell(
                              onTap: () => _onOptionSelected(option.id),
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor, width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    Text(option.emoji, style: const TextStyle(fontSize: 18)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        option.text,
                                        style: TextStyle(
                                          color: isLocalSelected ? Colors.white : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: isLocalSelected ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (isLocalSelected && isPartnerSelected && _isRevealed)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Text(
                                          '¡Ambos! ✨',
                                          style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      )
                                    else ...[
                                      if (isLocalSelected)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 6),
                                          child: Text('Tú', style: TextStyle(color: Colors.tealAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      if (isPartnerSelected && _isRevealed)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 6),
                                          child: Text(
                                            widget.partnerName,
                                            style: const TextStyle(color: Colors.deepOrangeAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Action Button or Waiting indicator
                      if (_localSelectedOptionId != null && !_isRevealed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${widget.partnerName} está eligiendo su respuesta...',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                        )
                      else if (_isRevealed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber.shade700,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _nextCard,
                              child: Text(
                                _currentRound < _cards.length - 1 ? 'Siguiente Tarjeta ➔' : '✨ Finalizar Fogata',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
