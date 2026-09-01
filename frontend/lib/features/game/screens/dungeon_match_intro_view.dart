import 'dart:async';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/game_models.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../avatar/games/character_preview_game.dart';
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
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Role Mission & Mini-Tutorial Guide
                      _buildRoleMissionCard(isExplorer: isExplorer),
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

  Widget _buildPlayerCard({
    required String name,
    required String roleTitle,
    required Color roleColor,
    required AvatarConfig avatarConfig,
    required RoomConfig roomConfig,
    required bool isReady,
    required bool isLocal,
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
        children: [
          // Role Banner
          Container(
            width: double.infinity,
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
          SizedBox(
            height: 130,
            width: 100,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GameWidget(
                key: ValueKey('preview_${isLocal ? "local" : "partner"}_${avatarConfig.hashCode}_${avatarConfig.hairStyle}_${avatarConfig.topStyle}_${avatarConfig.skinColor.value}_${avatarConfig.hairColor.value}_${avatarConfig.topColor.value}'),
                game: CharacterPreviewGame(
                  config: avatarConfig,
                  initialFaceZoom: false,
                ),
              ),
            ),
          ),

          // Player Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          // Room Decoration Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cottage, color: Color(0xFFFFB74D), size: 14),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _getRoomStyleName(roomConfig),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

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
              mainAxisSize: MainAxisSize.min,
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

  Widget _buildRoleMissionCard({required bool isExplorer}) {
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
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isExplorer ? 'TU MISIÓN DE EXPLORADOR' : 'TU MISIÓN DE GUÍA',
                style: TextStyle(
                  color: isExplorer ? Colors.orangeAccent : Colors.cyanAccent,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isExplorer) ...[
            _buildRuleItem(
              icon: Icons.gamepad_outlined,
              title: 'Explora en la penumbra',
              subtitle: 'Usa la cruceta virtual para moverte y empujar bloques.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              icon: Icons.key_outlined,
              title: 'Encuentra la llave dorada',
              subtitle: 'Localízala en el laberinto y dirígete al Santuario de escape.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              icon: Icons.lightbulb_outline,
              title: 'Confía en tu Guía',
              subtitle: 'Sigue los destellos luminosos que tu cita te marque en el suelo.',
            ),
          ] else ...[
            _buildRuleItem(
              icon: Icons.remove_red_eye_outlined,
              title: 'Visión táctica completa',
              subtitle: 'Tienes la perspectiva del mapa entero y la posición de tu pareja.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              icon: Icons.touch_app_outlined,
              title: 'Envía señales luminosas',
              subtitle: 'Toca cualquier zona de la pantalla para guiar a tu explorador.',
            ),
            const SizedBox(height: 8),
            _buildRuleItem(
              icon: Icons.shield_outlined,
              title: 'Desactiva peligros',
              subtitle: 'Presiona los botones para desarmar trampas de pinchos a distancia.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white70, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                const SizedBox(width: 16),
                TextButton(
                  onPressed: () {
                    widget.onStartGame();
                  },
                  child: Text(
                    'Entrar directamente (Prueba)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
