import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/preference_tags.dart';
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

    final partnerName = widget.state.partnerUsername ??
        (widget.state.session.partnerUsername != null && widget.state.session.partnerUsername!.isNotEmpty
            ? widget.state.session.partnerUsername!
            : _formatUserName(_partnerUserId));
    final partnerBio = widget.state.partnerBio ??
        AvatarStorageService.getUserBio(_partnerUserId);
    final partnerIntent = AvatarStorageService.getUserIntent(_partnerUserId);
    final partnerAge = widget.state.partnerAge ??
        widget.state.session.partnerAge ??
        AvatarStorageService.getUserAge(_partnerUserId);
    final partnerCommune = widget.state.partnerCommune ??
        widget.state.session.partnerCommune ??
        AvatarStorageService.getUserCommune(_partnerUserId);
    final partnerTastes = widget.state.partnerTastes ??
        (widget.state.session.partnerTastes.isNotEmpty
            ? widget.state.session.partnerTastes
            : AvatarStorageService.getUserTastes(_partnerUserId));

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
                      // 1. Local Player: Compact Face Only Header (No Room)
                      _buildLocalPlayerHeader(
                        name: 'Tú (${_formatUserName(_localUserId)})',
                        roleTitle: isExplorer ? 'Explorador 🔦' : 'Guía 🗺️',
                        roleColor: isExplorer ? const Color(0xFFFF9800) : const Color(0xFF00E5FF),
                        avatarConfig: _localAvatar,
                        isReady: localReady,
                      ),

                      // Romantic Connection Divider
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Row(
                          children: [
                            const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: ScaleTransition(
                                scale: _pulseScale,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.favorite, color: Colors.pinkAccent, size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      'TU CITA EN LA MAZMORRA',
                                      style: TextStyle(
                                        color: Colors.pinkAccent.shade100,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.favorite, color: Colors.pinkAccent, size: 16),
                                  ],
                                ),
                              ),
                            ),
                            const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
                          ],
                        ),
                      ),

                      // 2. Partner: Featured Full-Width Card (Age, Full Bio, Room, Tastes)
                      _buildPartnerFeaturedCard(
                        name: partnerName,
                        roleTitle: !isExplorer ? 'Explorador 🔦' : 'Guía 🗺️',
                        roleColor: !isExplorer ? const Color(0xFFFF9800) : const Color(0xFF00E5FF),
                        avatarConfig: _partnerAvatar,
                        roomConfig: _partnerRoom,
                        isReady: partnerReady,
                        bio: partnerBio,
                        intent: partnerIntent,
                        age: partnerAge,
                        commune: partnerCommune,
                        tastes: partnerTastes,
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

  Widget _buildLocalPlayerHeader({
    required String name,
    required String roleTitle,
    required Color roleColor,
    required AvatarConfig avatarConfig,
    required bool isReady,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1638).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isReady ? Colors.greenAccent : Colors.white.withValues(alpha: 0.15),
          width: isReady ? 1.8 : 1.0,
        ),
        boxShadow: isReady
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.2),
                  blurRadius: 10,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Face only: circular zoomed avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: roleColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: roleColor.withValues(alpha: 0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: ClipOval(
              child: GameWidget(
                key: ValueKey('preview_local_face_${avatarConfig.hashCode}_${avatarConfig.hairStyle}'),
                game: CharacterPreviewGame(
                  config: avatarConfig,
                  initialFaceZoom: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: roleColor.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        roleTitle,
                        style: TextStyle(
                          color: roleColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  isReady ? '✓ Confirmado para la expedición' : 'Esperando tu confirmación...',
                  style: TextStyle(
                    color: isReady ? Colors.greenAccent : Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isReady ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isReady ? Colors.greenAccent : Colors.white24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.hourglass_empty,
                  size: 13,
                  color: isReady ? Colors.greenAccent : Colors.white54,
                ),
                const SizedBox(width: 4),
                Text(
                  isReady ? 'LISTO' : 'PENDIENTE',
                  style: TextStyle(
                    color: isReady ? Colors.greenAccent : Colors.white54,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerFeaturedCard({
    required String name,
    required String roleTitle,
    required Color roleColor,
    required AvatarConfig avatarConfig,
    required RoomConfig roomConfig,
    required bool isReady,
    required String bio,
    required String intent,
    required int age,
    required String commune,
    required List<String> tastes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1638).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isReady ? Colors.greenAccent : const Color(0xFFFF80AB).withValues(alpha: 0.4),
          width: isReady ? 2.0 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: isReady
                ? Colors.greenAccent.withValues(alpha: 0.2)
                : const Color(0xFFFF80AB).withValues(alpha: 0.12),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Banner: Rol & Ready Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.stars_rounded, color: roleColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  'TU CITA • $roleTitle',
                  style: TextStyle(
                    color: roleColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isReady
                        ? Colors.green.withValues(alpha: 0.25)
                        : Colors.amber.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isReady ? Colors.greenAccent : Colors.amberAccent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isReady ? Icons.check_circle : Icons.hourglass_top,
                        size: 12,
                        color: isReady ? Colors.greenAccent : Colors.amberAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isReady ? 'LISTO' : 'PREPARANDO',
                        style: TextStyle(
                          color: isReady ? Colors.greenAccent : Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar + Primary Info Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Avatar
                    Container(
                      height: 125,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFFFD54F).withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: GameWidget(
                          key: ValueKey('preview_partner_full_${avatarConfig.hashCode}_${avatarConfig.hairStyle}_${avatarConfig.topStyle}'),
                          game: CharacterPreviewGame(
                            config: avatarConfig,
                            initialFaceZoom: false,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Name, Age, Commune, Intent
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.cake_outlined, size: 14, color: Color(0xFFFFD54F)),
                              const SizedBox(width: 4),
                              Text(
                                '$age años',
                                style: const TextStyle(
                                  color: Color(0xFFFFD54F),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Text('•', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
                              ),
                              const Icon(Icons.location_on_outlined, size: 14, color: Colors.white70),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  commune,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Intent Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              _formatIntentTitle(intent),
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Full Description (Se ve ENTERA, sin truncar)
                if (bio.isNotEmpty) ...[
                  const Row(
                    children: [
                      Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFFFFD54F)),
                      SizedBox(width: 6),
                      Text(
                        'Acerca de mí',
                        style: TextStyle(
                          color: Color(0xFFFFD54F),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      '«$bio»',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 12,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Sus Gustos (Tastes chips)
                if (tastes.isNotEmpty) ...[
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 15, color: Color(0xFFFFB74D)),
                      SizedBox(width: 6),
                      Text(
                        'Sus Gustos & Intereses',
                        style: TextStyle(
                          color: Color(0xFFFFB74D),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tastes.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E204F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFFFB74D).withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          PreferenceCatalog.formatTaste(t),
                          style: const TextStyle(
                            color: Color(0xFFFFE082),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // La Habitación (Interactive sneakpeek card)
                const Row(
                  children: [
                    Icon(Icons.cottage_rounded, size: 16, color: Color(0xFFFFB74D)),
                    SizedBox(width: 6),
                    Text(
                      'Su Habitación',
                      style: TextStyle(
                        color: Color(0xFFFFB74D),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _showRoomPreviewDialog(
                      context: context,
                      name: name,
                      avatar: avatarConfig,
                      room: roomConfig,
                      isLocal: false,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFF281C48).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFFB74D).withValues(alpha: 0.6),
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
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.cottage_rounded, color: Color(0xFFFFB74D), size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cuarto de ${name.split(" ").first}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFB74D),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_getRoomStyleName(roomConfig)} • Toca para explorar en 3D 🔍',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFFFD54F), size: 14),
                        ],
                      ),
                    ),
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
