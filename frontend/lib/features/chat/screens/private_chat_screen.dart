import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/user_profile.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../campfire/screens/campfire_view.dart';
import '../../game/bloc/game_bloc.dart';
import '../../mailbox/models/mailbox_models.dart';
import '../models/chat_message.dart';
import '../services/chat_service.dart';

class PrivateChatScreen extends StatefulWidget {
  final MailboxLetter letter;

  const PrivateChatScreen({super.key, required this.letter});

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ValueNotifier<List<ChatMessage>> _notifier;

  final List<String> _icebreakers = [
    '☕ ¡Hola! Me encantó nuestra charla en la fogata',
    '🎮 ¿Qué sueles jugar en tus ratos libres?',
    '✨ ¡Tuvimos muy linda complicidad en la cripta!',
    '🌱 Me gustó mucho tu vibra tranquila',
  ];

  @override
  void initState() {
    super.initState();
    _notifier = ChatService.getConversationNotifier(widget.letter);
    ChatService.ensureConnected();
    ChatService.checkPresence(widget.letter.partnerId);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage([String? presetText]) {
    final text = presetText ?? _textController.text;
    if (text.trim().isEmpty) return;

    ChatService.sendMessage(letter: widget.letter, text: text);
    if (presetText == null) {
      _textController.clear();
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final partner = widget.letter;

    final scaffold = Scaffold(
        backgroundColor: const Color(0xFF0F111A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF191728),
          elevation: 2,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: ValueListenableBuilder<Map<String, bool>>(
            valueListenable: ChatService.partnerPresenceNotifier,
            builder: (context, presenceMap, _) {
              final isOnline = presenceMap[partner.partnerId] == true ||
                  (partner.partnerId == 'userA' && presenceMap['alice'] == true) ||
                  (partner.partnerId == 'userB' && presenceMap['bob'] == true) ||
                  (partner.partnerId == 'alice' && presenceMap['userA'] == true) ||
                  (partner.partnerId == 'bob' && presenceMap['userB'] == true);

              final statusColor = isOnline ? const Color(0xFF66BB6A) : const Color(0xFF9E9E9E);
              final statusText = isOnline ? 'En línea' : 'Desconectado';

              return Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFFFD54F),
                        backgroundImage: partner.partnerPhoto != null && partner.partnerPhoto!.isNotEmpty
                            ? NetworkImage(partner.partnerPhoto!)
                            : null,
                        child: partner.partnerPhoto == null || partner.partnerPhoto!.isEmpty
                            ? const Icon(Icons.person, color: Colors.black87)
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF191728), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              partner.partnerName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text('✨', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              '${partner.partnerCommune} • $statusText',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<bool>(
                              valueListenable: WebSocketClient.isConnectedNotifier,
                              builder: (context, isWs, _) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isWs ? Colors.greenAccent : Colors.redAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isWs ? 'Red viva' : 'Sin red',
                                      style: TextStyle(
                                        color: isWs ? Colors.greenAccent.withOpacity(0.8) : Colors.redAccent.withOpacity(0.8),
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB300),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 2,
                ),
                icon: const Text('⚔️', style: TextStyle(fontSize: 13)),
                label: const Text(
                  'Invitar a Cita',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5),
                ),
                onPressed: _showDateInviteDialog,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Top Safe Dating Notice
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: const Color(0xFF282238).withOpacity(0.4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🌿', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    Text(
                      'Slow Dating: Conéctense a su propio ritmo.',
                      style: TextStyle(
                        color: Colors.amberAccent.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Active Ephemeral Date Invite Banner (Zero Clutter in Chat)
              _buildActiveInviteBanner(),

              // Chat Messages List
              Expanded(
                child: ValueListenableBuilder<List<ChatMessage>>(
                  valueListenable: _notifier,
                  builder: (context, messages, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('💬', style: TextStyle(fontSize: 36)),
                            const SizedBox(height: 8),
                            const Text(
                              '¡Ambos se eligieron para seguir en contacto!',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rompe el hielo con un mensaje acogedor ✨',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMe = msg.isFromMe;
                        final timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.76,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? const Color(0xFFD97706) : const Color(0xFF1E2132),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                            ),
                            border: Border.all(
                              color: isMe ? Colors.amberAccent.withOpacity(0.3) : Colors.white12,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: TextStyle(
                                  color: isMe ? Colors.white : Colors.white.withOpacity(0.92),
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Quick Icebreakers Chips
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _icebreakers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final text = _icebreakers[index];
                  return ActionChip(
                    backgroundColor: const Color(0xFF1E1B2E),
                    side: BorderSide(color: Colors.amberAccent.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    label: Text(
                      text,
                      style: const TextStyle(color: Color(0xFFFFD54F), fontSize: 11),
                    ),
                    onPressed: () => _sendMessage(text),
                  );
                },
              ),
            ),

            // Bottom Text Field Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF161824),
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF222638),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Escribe un mensaje tranquilo...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFB300),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.black87, size: 20),
                      onPressed: () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    try {
      if (context.read<GameBloc?>() != null) {
        return BlocListener<GameBloc, GameState>(
          listener: (context, state) {
            if (state is ActiveGameState) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          child: scaffold,
        );
      }
    } catch (_) {}

    return scaffold;
  }

  Widget _buildActiveInviteBanner() {
    return ValueListenableBuilder<Map<String, Map<String, dynamic>>>(
      valueListenable: ChatService.activeInvitesNotifier,
      builder: (context, activeInvites, _) {
        final invite = activeInvites[widget.letter.id];
        if (invite == null) return const SizedBox.shrink();

        final fromMe = invite['fromMe'] == true;
        final title = invite['title']?.toString() ?? 'una Cita';
        final dateType = invite['dateType']?.toString() ?? 'CRYPT';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C1B4D), Color(0xFF1E1630)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amberAccent.withOpacity(0.6), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      dateType == 'CAMPFIRE' ? '🔥' : (dateType == 'HOME' ? '🏠' : '🗡️'),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fromMe ? 'Invitación enviada' : '¡Invitación a Cita!',
                          style: const TextStyle(
                            color: Color(0xFFFFD54F),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          fromMe
                              ? 'Esperando que ${widget.letter.partnerName} acepte: $title'
                              : '${widget.letter.partnerName} te invita a $title',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  if (fromMe)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      tooltip: 'Cancelar invitación',
                      onPressed: () {
                        ChatService.dismissDateInvite(widget.letter.id);
                      },
                    ),
                ],
              ),
              if (!fromMe) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          ChatService.dismissDateInvite(widget.letter.id, partnerId: widget.letter.partnerId);
                        },
                        child: const Text('Ahora no', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB300),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.favorite, size: 16),
                        label: const Text('Aceptar y Jugar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: () {
                          ChatService.acceptDateInvite(
                            letter: widget.letter,
                            dateType: dateType,
                            title: title,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Aceptado! Conectando sala multijugador...'),
                              backgroundColor: Color(0xFF2E7D32),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showDateInviteDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1B2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('⚔️', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(
                    'Nueva Cita con ${widget.letter.partnerName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Elige la experiencia que te gustaría compartir:',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
              ),
              const SizedBox(height: 18),

              // Option 1: Crypt expedition
              _buildDateOptionTile(
                icon: '🗡️',
                title: 'Expedición en la Cripta',
                subtitle: 'Explorador y Guía superando trampas y acertijos juntos.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _sendDateInvite('CRYPT', 'Expedición en la Cripta 🗡️');
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Direct Campfire Round 2
              _buildDateOptionTile(
                icon: '🔥',
                title: 'Fogata de Conexión (Nivel 2)',
                subtitle: 'Saltar directo a la fogata con preguntas más íntimas y profundas.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _sendDateInvite('CAMPFIRE', 'Fogata de Conexión Profunda 🔥');
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Visit home
              _buildDateOptionTile(
                icon: '🏠',
                title: 'Visitar mi Hogar',
                subtitle: 'Compartir un té virtual en tu habitación decorada.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _sendDateInvite('HOME', 'Visita al Hogar ☕');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateOptionTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF28243A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFFFFD54F),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
          ],
        ),
      ),
    );
  }

  void _sendDateInvite(String type, String title) {
    ChatService.sendDateInvite(
      letter: widget.letter,
      dateType: type,
      title: title,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💌 ¡Invitación enviada a ${widget.letter.partnerName}!'),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 2),
      ),
    );

    _scrollToBottom();
  }

  void _launchDateActivity(String dateType) {
    if (dateType == 'CAMPFIRE') {
      final localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
      final localProfile = AuthService.currentUser ??
          UserProfile(
            id: localUserId,
            username: 'Tú',
            avatarConfig: AvatarStorageService.getUserConfig(localUserId),
            roomConfig: AvatarStorageService.getUserRoomConfig(localUserId),
            tastes: AvatarStorageService.getUserTastes(localUserId),
          );

      final partnerProfile = UserProfile(
        id: widget.letter.partnerId,
        username: widget.letter.partnerName,
        avatarConfig: widget.letter.partnerAvatar,
        profilePhoto: widget.letter.partnerPhoto,
        age: widget.letter.partnerAge,
        commune: widget.letter.partnerCommune,
        tastes: widget.letter.commonTastes,
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CampfireView(
            localUser: localProfile,
            partnerUser: partnerProfile,
            partnerName: widget.letter.partnerName,
            partnerAvatarConfig: widget.letter.partnerAvatar,
            seed: DateTime.now().millisecondsSinceEpoch,
            onReturnHome: () => Navigator.of(context).pop(),
          ),
        ),
      );
    } else if (dateType == 'CRYPT') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🗡️ Iniciando expedición en la cripta con ${widget.letter.partnerName}...'),
          backgroundColor: const Color(0xFF1976D2),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      // HOME
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1B2E),
          title: const Row(
            children: [
              Text('🏠', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('Visita al Hogar', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          content: Text(
            '¡${widget.letter.partnerName} ha aceptado tu invitación a tomar un té en tu habitación! ☕🌱\n\nPronto podrán caminar juntos por el cuarto.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD54F), foregroundColor: Colors.black87),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    }
  }
}
