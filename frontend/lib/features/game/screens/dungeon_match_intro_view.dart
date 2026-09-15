import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../avatar/games/character_preview_game.dart';
import '../../lobby/games/cozy_room_game.dart';
import '../bloc/game_bloc.dart';

class DungeonMatchIntroView extends StatefulWidget {
  final ActiveGameState state;
  final VoidCallback onStartGame;

  const DungeonMatchIntroView({
    super.key,
    required this.state,
    required this.onStartGame,
  });

  @override
  State<DungeonMatchIntroView> createState() => _DungeonMatchIntroViewState();
}

class _DungeonMatchIntroViewState extends State<DungeonMatchIntroView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  Timer? _countdownTimer;
  int _countdown = 3;
  bool _isCountingDown = false;

  late String _localUserId;
  late String _partnerUserId;
  late AvatarConfig _localAvatar;
  late AvatarConfig _partnerAvatar;
  late RoomConfig _localRoom;
  late RoomConfig _partnerRoom;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseScale = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    var partnerCandidate = widget.state.session.partnerId;
    if (partnerCandidate.isEmpty || partnerCandidate == _localUserId) {
      if (_localUserId == 'alice') {
        partnerCandidate = 'bob';
      } else if (_localUserId == 'bob') {
        partnerCandidate = 'alice';
      } else if (_localUserId == 'charlie') {
        partnerCandidate = 'david';
      } else {
        partnerCandidate = 'bob';
      }
    }
    _partnerUserId = partnerCandidate;

    _localAvatar = AvatarStorageService.getUserConfig(_localUserId);
    _partnerAvatar = widget.state.partnerAvatarConfig ?? AvatarStorageService.getUserConfig(_partnerUserId);
    _localRoom = AvatarStorageService.getUserRoomConfig(_localUserId);
    _partnerRoom = widget.state.partnerRoomConfig ?? AvatarStorageService.getUserRoomConfig(_partnerUserId);

    _checkBothReady();
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1638),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.heart_broken, color: Colors.pinkAccent),
            SizedBox(width: 10),
            Text('¿Rechazar esta cita?', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Volverás a tu habitación en el Lobby y la sesión se cancelará amigablemente.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continuar Cita', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<GameBloc>().add(const SendEmergencyDisconnectEvent(shouldBlock: false));
            },
            child: const Text('Rechazar y Salir'),
          ),
        ],
      ),
    );
  }

  void _showRoomPreviewDialog({
    required BuildContext context,
    required String name,
    required AvatarConfig avatar,
    required RoomConfig room,
    required bool isLocal,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF1E1638),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: const Color(0xFFFFD54F).withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with Cottage Icon & Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cottage_rounded, color: Color(0xFFFFB74D), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLocal ? '🏡 Tu Habitación' : '🏡 El Hogar de $name',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getRoomStyleName(room),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Isometric Room Canvas Preview
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 280,
                    width: double.infinity,
                    color: const Color(0xFF110B22),
                    child: GameWidget(
                      key: ValueKey('room_modal_${isLocal ? "local" : "partner"}_${room.hashCode}'),
                      game: CozyRoomGame(
                        avatarConfig: avatar,
                        roomConfig: room,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Cozy description
                Text(
                  isLocal
                      ? 'Así lucirá tu rincón personal cuando invites visitas tranquilas ☕'
                      : 'Un vistazo al rincón decorado de $name. ¡Podrán visitarlo juntos en una cita más adelante! 🌱',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),

                // Dismiss Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text(
                      'Volver a la Preparación ✨',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void didUpdateWidget(covariant DungeonMatchIntroView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.partnerAvatarConfig != oldWidget.state.partnerAvatarConfig &&
        widget.state.partnerAvatarConfig != null) {
      setState(() {
        _partnerAvatar = widget.state.partnerAvatarConfig!;
      });
    }
    if (widget.state.partnerRoomConfig != oldWidget.state.partnerRoomConfig &&
        widget.state.partnerRoomConfig != null) {
      setState(() {
        _partnerRoom = widget.state.partnerRoomConfig!;
      });
    }
    _checkBothReady();
  }

  void _checkBothReady() {
    // Both ready or local confirmed & partner confirmed
    final bothReady = widget.state.localReady && widget.state.partnerReady;
    if (bothReady && !_isCountingDown) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_countdown <= 1) {
        timer.cancel();
        widget.onStartGame();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleReadyPressed() {
    context.read<GameBloc>().add(const SendGameReadyEvent());
    // In local simulation or if partner is already ready
    if (widget.state.partnerReady) {
      _startCountdown();
    }
  }

  String _formatUserName(String id) {
    if (id.isEmpty) return 'Compañero';
    return id[0].toUpperCase() + id.substring(1);
  }

  String _getRoomStyleName(RoomConfig room) {
    if (room.wallpaper.contains('stripes')) return 'Estilo Cozy Rayas';
    if (room.wallpaper.contains('brick')) return 'Estilo Rústico Piedra';
    if (room.wallpaper.contains('botanical')) return 'Estilo Botánico';
    return 'Habitación Personalizada';
  }

  @override
  Widget build(BuildContext context) {
    final isExplorer = widget.state.session.role == 'EXPLORER';
    final localReady = widget.state.localReady;
    final partnerReady = widget.state.partnerReady;

    return Scaffold(
      backgroundColor: const Color(0xFF130F26),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.3),
            radius: 1.2,
            colors: [
              Color(0xFF2C1E4A),
              Color(0xFF18122B),
              Color(0xFF0F0A1C),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with Reject button
              Padding(
                padding: const EdgeInsets.only(top: 10.0, bottom: 8.0, left: 16.0, right: 16.0),
                child: Row(
                  children: [
                    const SizedBox(width: 40), // Balance the close button
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              border: Border.all(color: const Color(0xFFFFC107), width: 1.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  '¡CITA ENCONTRADA!',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.auto_awesome, color: Colors.amber, size: 18),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Acto ${widget.state.session.act} • Mazmorra Cooperativa',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Rechazar cita y volver al lobby',
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: _showRejectDialog,
                    ),
                  ],
                ),
              ),

              // Players & Rooms Presentation
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      // Match Diorama: Two Cards
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left: Local Player
                          Expanded(
                            child: _buildPlayerCard(
                              name: 'Tú (${_formatUserName(_localUserId)})',
                              roleTitle: isExplorer ? 'Explorador 🔦' : 'Guía 🗺️',
                              roleColor: isExplorer ? const Color(0xFFFF9800) : const Color(0xFF00E5FF),
                              avatarConfig: _localAvatar,
                              roomConfig: _localRoom,
                              isReady: localReady,
                              isLocal: true,
                            ),
                          ),

                          // Center Connection
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 50.0),
                            child: ScaleTransition(
                              scale: _pulseScale,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.pinkAccent.withValues(alpha: 0.2),
                                  border: Border.all(color: Colors.pinkAccent, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.pinkAccent.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.favorite,
                                  color: Colors.pinkAccent,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          // Right: Partner Player
                          Expanded(
                            child: _buildPlayerCard(
                              name: widget.state.partnerUsername ?? _formatUserName(_partnerUserId),
                              roleTitle: !isExplorer ? 'Explorador 🔦' : 'Guía 🗺️',
                              roleColor: !isExplorer ? const Color(0xFFFF9800) : const Color(0xFF00E5FF),
                              avatarConfig: _partnerAvatar,
                              roomConfig: _partnerRoom,
                              isReady: partnerReady,
                              isLocal: false,
                              bio: AvatarStorageService.getUserBio(_partnerUserId),
                              intent: AvatarStorageService.getUserIntent(_partnerUserId),
                              age: 24,
                              commune: 'Santiago',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Role Mission & Simplified Objective Guide
                      _buildRoleMissionCard(
                        isExplorer: isExplorer,
                        partnerName: widget.state.partnerUsername ?? _formatUserName(_partnerUserId),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              _buildBottomActionSection(
                localReady: localReady,
                partnerReady: partnerReady,
                isCountingDown: _isCountingDown,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatIntentTitle(String intent) {
    switch (intent) {
      case 'intent_slow': return '☕ Slow Dating';
      case 'intent_serious': return '💍 Relación Seria';
      case 'intent_gaming_duo': return '🎮 Gaming Duo';
      case 'intent_cozy_chats': return '💬 Charlas Cozy';
      default: return '✨ Conectar';
    }
  }

  Widget _buildPlayerCard({
    required String name,
    required String roleTitle,
    required Color roleColor,
    required AvatarConfig avatarConfig,
    required RoomConfig roomConfig,
    required bool isReady,
    required bool isLocal,
    String? bio,
    String? intent,
    int? age,
    String? commune,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1638).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady ? Colors.greenAccent : Colors.white.withValues(alpha: 0.15),
          width: isReady ? 2.0 : 1.0,
        ),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Role Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Text(
              roleTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: roleColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Avatar Frame
          Center(
            child: SizedBox(
              height: 120,
              width: 95,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GameWidget(
                  key: ValueKey('preview_${isLocal ? "local" : "partner"}_${avatarConfig.hashCode}_${avatarConfig.hairStyle}_${avatarConfig.topStyle}'),
                  game: CharacterPreviewGame(
                    config: avatarConfig,
                    initialFaceZoom: false,
                  ),
                ),
              ),
            ),
          ),

          // Player Name, Age & Commune
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Column(
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (!isLocal && age != null)
                  Text(
                    '$age años • ${commune ?? "Santiago"}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // Partner Dating Intent Badge
          if (!isLocal && intent != null && intent.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Text(
                  _formatIntentTitle(intent),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Partner Bio ("Acerca de mí")
          if (!isLocal && bio != null && bio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '«$bio»',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    height: 1.2,
                  ),
                ),
              ),
            ),

          // Sneakpeek Interactivo de Habitación (Toca para explorar modal completo)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _showRoomPreviewDialog(
                  context: context,
                  name: name,
                  avatar: avatarConfig,
                  room: roomConfig,
                  isLocal: isLocal,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF281C48).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB74D).withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.cottage_rounded, color: Color(0xFFFFB74D), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isLocal ? 'Tu Habitación' : 'Cuarto de ${name.split(" ").first}',
                                    style: const TextStyle(
                                      color: Color(0xFFFFB74D),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.visibility, color: Color(0xFFFFD54F), size: 13),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_getRoomStyleName(roomConfig)} • Toca para ver',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Ready Status Indicator
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isReady
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isReady ? Colors.greenAccent : Colors.white24,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.hourglass_empty,
                  color: isReady ? Colors.greenAccent : Colors.white54,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  isReady ? 'LISTO' : 'PREPARANDO',
                  style: TextStyle(
                    color: isReady ? Colors.greenAccent : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleMissionCard({required bool isExplorer, required String partnerName}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1638).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExplorer ? Colors.orangeAccent.withValues(alpha: 0.4) : Colors.cyanAccent.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isExplorer ? Icons.explore : Icons.map_outlined,
                color: isExplorer ? Colors.orangeAccent : Colors.cyanAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                isExplorer ? 'TE VAN A GUIAR 🔦' : 'TÚ TIENES EL MAPA 🗺️',
                style: TextStyle(
                  color: isExplorer ? Colors.orangeAccent : Colors.cyanAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isExplorer) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.volume_up, color: Colors.orangeAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Te van a guiar: necesitas que $partnerName te dé las instrucciones paso a paso.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag, color: Colors.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🎯 Objetivo: Debes juntar las runas en el orden que $partnerName te va a decir para luego ir corriendo a la salida.',
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.cyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.draw, color: Colors.cyanAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tú tienes el mapa completo: debes guiar a $partnerName dibujando el camino en tu pantalla.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.route, color: Colors.tealAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '🎯 Objetivo: Comunícale a $partnerName el orden secreto de las runas que debe pisar para abrir la salida.',
                      style: const TextStyle(
                        color: Color(0xFF99F6E4),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomActionSection({
    required bool localReady,
    required bool partnerReady,
    required bool isCountingDown,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0A1C),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCountingDown) ...[
            Text(
              '¡Comenzando en $_countdown...!',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (4 - _countdown) / 3.0,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                minHeight: 6,
              ),
            ),
          ] else if (!localReady) ...[
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _showRejectDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent.shade100,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text(
                        'Rechazar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _handleReadyPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4081),
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: const Color(0xFFFF4081).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                      label: const Text(
                        '¡Listo para la Cita!',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  partnerReady
                      ? '¡Preparando mazmorra...!'
                      : 'Esperando a que tu cita confirme...',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showRejectDialog,
              child: Text(
                'Cancelar Cita',
                style: TextStyle(
                  color: Colors.redAccent.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
