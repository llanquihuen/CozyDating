import 'dart:async';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/models/room_config.dart';
import '../../../core/models/user_profile.dart';
import '../../game/bloc/game_bloc.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../lobby/games/cozy_room_game.dart';
import '../../lobby/screens/lighting_panel_sheet.dart';

/// Interactive screen for the "Visitar mi Hogar ☕" date mode.
///
/// Both the host and the visiting partner are present in the host's decorated
/// room. Real-time avatar movements, chair sitting, emotes, cozy actions
/// (drinking tea/coffee, playing music), and chat are synchronized over WebSockets.
class HomeVisitView extends StatefulWidget {
  final UserProfile localUser;
  final UserProfile partnerUser;
  final bool isHost;
  final String hostName;
  final RoomConfig hostRoomConfig;
  final VoidCallback onLeave;

  const HomeVisitView({
    super.key,
    required this.localUser,
    required this.partnerUser,
    required this.isHost,
    required this.hostName,
    required this.hostRoomConfig,
    required this.onLeave,
  });

  @override
  State<HomeVisitView> createState() => _HomeVisitViewState();
}

class _HomeVisitViewState extends State<HomeVisitView> {
  late CozyRoomGame _game;
  final TextEditingController _chatController = TextEditingController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _showChatInput = false;

  // Pointer & Gesture state for tap-to-move, pinch zoom, and pan in Home Visit
  final Map<int, Offset> _pointerPositions = {};
  double? _initialPinchDistance;
  double? _initialPinchZoom;
  Offset? _lastSinglePointerPos;
  Offset? _singleTapStartOffset;
  DateTime? _singleTapStartTime;

  // Top banner notification state (rendered over furniture and walls)
  String? _topNotificationText;
  DateTime? _topNotificationExpiry;
  Timer? _notificationTimer;

  // Track trigger timestamps to avoid re-triggering actions on unrelated state emissions
  int? _lastHandledMoveTrigger;
  int? _lastHandledSitTrigger;
  int? _lastHandledStandTrigger;
  int? _lastHandledEmoteTrigger;
  int? _lastHandledActionTrigger;
  int? _lastHandledChatTrigger;
  int? _lastHandledLightingTrigger;
  int? _lastHandledLightingRequestTrigger;
  Timer? _hostLightingSaveTimer;

  @override
  void initState() {
    super.initState();
    _game = CozyRoomGame(
      avatarConfig: widget.localUser.avatarConfig,
      partnerAvatarConfig: widget.partnerUser.avatarConfig,
      roomConfig: widget.hostRoomConfig,
      onLocalAvatarMove: (dest) {
        context.read<GameBloc>().add(SendHomeAvatarMoveEvent(
              gridX: dest.x.toDouble(),
              gridY: dest.y.toDouble(),
            ));
      },
      onLocalAvatarStand: (standPos) {
        context.read<GameBloc>().add(SendHomeAvatarStandEvent(
              gridX: standPos.x.toDouble(),
              gridY: standPos.y.toDouble(),
            ));
      },
      onLocalAvatarSit: (chair, spot) {
        context.read<GameBloc>().add(SendHomeAvatarSitEvent(
              chairId: chair.id,
              slotIndex: spot.slotIndex,
            ));
      },
      // Either player tapping a lamp / TV / fireplace.
      onLightingChanged: _onLocalLightingChanged,
    );

    // The guest asks the host for the live lighting on arrival, instead of trusting the
    // copy of the room it received (the host may have changed a light moments ago).
    if (!widget.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<GameBloc>().add(const SendHomeLightingEvent(request: true));
      });
    }
  }

  // --- Lighting sync ---------------------------------------------------------------------------

  /// A local lighting change (lamp tap, or the host's lights button / panel): show it to the
  /// partner, and if it's our room, keep it.
  void _onLocalLightingChanged() {
    if (!mounted) return;
    setState(() {});
    context.read<GameBloc>().add(SendHomeLightingEvent(snapshot: _game.lightingSnapshot()));
    _scheduleHostLightingSave();
  }

  /// The room belongs to the host, so only the host persists lighting changes made during
  /// the visit — including the ones the guest made. Debounced like the lobby's auto-save.
  void _scheduleHostLightingSave() {
    if (!widget.isHost) return;
    _hostLightingSaveTimer?.cancel();
    _hostLightingSaveTimer = Timer(const Duration(milliseconds: 1200), () {
      final saved = AvatarStorageService.getUserRoomConfig(widget.localUser.id);
      final updated = saved.copyWith(lighting: _game.roomConfig.lighting);
      AvatarStorageService.saveUserRoomConfig(widget.localUser.id, updated);
      AuthService.saveRoomConfig(updated);
    });
  }

  void _toggleHostMasterLights() {
    final on = !_game.roomConfig.lighting.masterOn;
    _game.setLightingMasterOn(on);
    _onLocalLightingChanged();
    _showTopNotification(on ? '💡 Luces de techo encendidas' : '🌑 Luces de techo apagadas');
  }

  void _openHostLightingPanel() {
    LightingPanelSheet.show(context, game: _game, onChanged: _onLocalLightingChanged);
  }

  /// Host only: tap = ceiling lights switch, tune icon = lights panel.
  Widget _buildHostLightsButton() {
    final on = _game.roomConfig.lighting.masterOn;
    final color = on ? const Color(0xFFFFD54F) : Colors.white54;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF261D3B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            key: const Key('visit_lights_master_button'),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
            onTap: _toggleHostMasterLights,
            onLongPress: _openHostLightingPanel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              child: Icon(on ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded, color: color, size: 16),
            ),
          ),
          Container(width: 1, height: 18, color: Colors.white12),
          InkWell(
            key: const Key('visit_lights_panel_button'),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
            onTap: _openHostLightingPanel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 8),
              child: Icon(Icons.tune_rounded, color: color, size: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _hostLightingSaveTimer?.cancel();
    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  void _sendEmote(String emote) {
    _game.showEmoteOverAvatar(emote, isLocal: true);
    context.read<GameBloc>().add(SendHomeEmoteEvent(emote: emote));
  }

  void _sendAction(String actionKey, String label) {
    _game.showEmoteOverAvatar(actionKey == 'tea' ? '🍵' : actionKey == 'music' ? '🎵' : '✨', isLocal: true);
    _showTopNotification('${widget.localUser.username} $label');
    context.read<GameBloc>().add(SendHomeActionEvent(
          actionType: actionKey,
          message: '${widget.localUser.username} $label',
        ));
  }

  void _sendChat() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    _chatController.clear();
    setState(() => _showChatInput = false);
    _chatFocusNode.unfocus();

    _game.showChatBubbleOverAvatar(text, isLocal: true);
    context.read<GameBloc>().add(SendHomeChatEvent(text: text));
  }

  void _showTopNotification(String message) {
    _notificationTimer?.cancel();
    setState(() {
      _topNotificationText = message;
      _topNotificationExpiry = DateTime.now().add(const Duration(seconds: 4));
    });

    _notificationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _topNotificationExpiry != null && DateTime.now().isAfter(_topNotificationExpiry!)) {
        setState(() {
          _topNotificationText = null;
        });
      }
    });
  }

  void _confirmLeave(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF261D3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Terminar la visita?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          widget.isHost
              ? '¿Deseas despedir a tu visita y cerrar la sesión hogareña?'
              : '¿Deseas despedirte de ${widget.hostName} y regresar a tu hogar?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Quedarme', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6584),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(dialogCtx).pop();
              context.read<GameBloc>().add(const SendHomeCompletedEvent());
              widget.onLeave();
            },
            child: const Text('Despedirme'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<GameBloc, GameState>(
      listener: (context, state) {
        if (state is! ActiveGameState) return;

        // Partner stood up
        if (state.partnerHomeStandTrigger != null &&
            state.partnerHomeStandTrigger != _lastHandledStandTrigger) {
          _lastHandledStandTrigger = state.partnerHomeStandTrigger;
          final standPos = state.partnerHomeMovePos != null
              ? Point(state.partnerHomeMovePos!.x.round(), state.partnerHomeMovePos!.y.round())
              : null;
          _game.standUpPartnerAvatar(standPos: standPos);
        }

        // Partner moved
        if (state.partnerHomeMovePos != null &&
            state.partnerHomeMoveTrigger != null &&
            state.partnerHomeMoveTrigger != _lastHandledMoveTrigger) {
          _lastHandledMoveTrigger = state.partnerHomeMoveTrigger;
          _game.movePartnerAvatar(Point(
            state.partnerHomeMovePos!.x.round(),
            state.partnerHomeMovePos!.y.round(),
          ));
        }

        // Partner sat down
        if (state.partnerHomeChairId != null &&
            state.partnerHomeSitTrigger != null &&
            state.partnerHomeSitTrigger != _lastHandledSitTrigger) {
          _lastHandledSitTrigger = state.partnerHomeSitTrigger;
          _game.sitPartnerAvatar(
            state.partnerHomeChairId!,
            state.partnerHomeSlotIndex ?? 0,
          );
        }

        // Partner sent an emote
        if (state.latestEmote != null &&
            state.latestEmote!.isNotEmpty &&
            state.emoteTrigger != null &&
            state.emoteTrigger != _lastHandledEmoteTrigger) {
          _lastHandledEmoteTrigger = state.emoteTrigger;
          _game.showEmoteOverAvatar(state.latestEmote!, isLocal: false);
        }

        // Partner sent an action notification -> show top banner over furniture
        if (state.homeActionMessage != null &&
            state.homeActionMessage!.isNotEmpty &&
            state.homeActionTrigger != null &&
            state.homeActionTrigger != _lastHandledActionTrigger) {
          _lastHandledActionTrigger = state.homeActionTrigger;
          _showTopNotification(state.homeActionMessage!);
        }

        // Partner changed the lighting -> apply their snapshot (and, as host, keep it)
        if (state.partnerHomeLighting != null &&
            state.partnerHomeLightingTrigger != null &&
            state.partnerHomeLightingTrigger != _lastHandledLightingTrigger) {
          _lastHandledLightingTrigger = state.partnerHomeLightingTrigger;
          _game.applyLightingSnapshot(state.partnerHomeLighting!);
          _scheduleHostLightingSave();
          setState(() {});
        }

        // Guest arrived and asked for the live lighting -> host answers with a snapshot
        if (widget.isHost &&
            state.homeLightingRequestTrigger != null &&
            state.homeLightingRequestTrigger != _lastHandledLightingRequestTrigger) {
          _lastHandledLightingRequestTrigger = state.homeLightingRequestTrigger;
          context.read<GameBloc>().add(SendHomeLightingEvent(snapshot: _game.lightingSnapshot()));
        }

        // Partner sent a chat message -> show speech bubble directly over partner avatar
        if (state.homeChatText != null &&
            state.homeChatText!.isNotEmpty &&
            state.homeChatTrigger != null &&
            state.homeChatTrigger != _lastHandledChatTrigger) {
          _lastHandledChatTrigger = state.homeChatTrigger;
          _game.showChatBubbleOverAvatar(state.homeChatText!, isLocal: false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF16141D),
        body: Stack(
          children: [
            // Flame Interactive Isometric Room Game with gesture listener
            Positioned.fill(
              child: Listener(
                onPointerDown: (event) {
                  _pointerPositions[event.pointer] = event.localPosition;
                  if (_pointerPositions.length == 1) {
                    _singleTapStartOffset = event.localPosition;
                    _singleTapStartTime = DateTime.now();
                    _lastSinglePointerPos = event.localPosition;
                  } else if (_pointerPositions.length >= 2) {
                    _singleTapStartOffset = null;
                    _singleTapStartTime = null;
                    _lastSinglePointerPos = null;

                    final keys = _pointerPositions.keys.toList();
                    final p1 = _pointerPositions[keys[0]]!;
                    final p2 = _pointerPositions[keys[1]]!;
                    _initialPinchDistance = (p1 - p2).distance;
                    _initialPinchZoom = _game.camera.viewfinder.zoom;
                  }
                },
                onPointerMove: (event) {
                  _pointerPositions[event.pointer] = event.localPosition;

                  // Multi-touch pinch zoom
                  if (_pointerPositions.length >= 2) {
                    final keys = _pointerPositions.keys.toList();
                    final p1 = _pointerPositions[keys[0]]!;
                    final p2 = _pointerPositions[keys[1]]!;
                    final currentDist = (p1 - p2).distance;

                    if (_initialPinchDistance != null && _initialPinchDistance! > 15 && _initialPinchZoom != null) {
                      final scaleFactor = currentDist / _initialPinchDistance!;
                      _game.setZoom(_initialPinchZoom! * scaleFactor);
                    }
                  } else if (_pointerPositions.length == 1) {
                    // Single finger camera pan
                    if (_lastSinglePointerPos != null) {
                      final delta = event.localPosition - _lastSinglePointerPos!;
                      if (delta.distance > 3) {
                        _singleTapStartOffset = null;
                        _game.panCamera(Vector2(delta.dx, delta.dy));
                      }
                    }
                    _lastSinglePointerPos = event.localPosition;
                  }
                },
                onPointerUp: (event) {
                  // Check if it was a single tap to move avatar or sit
                  if (_pointerPositions.length == 1 && _singleTapStartOffset != null && _singleTapStartTime != null) {
                    final elapsed = DateTime.now().difference(_singleTapStartTime!).inMilliseconds;
                    final dist = (event.localPosition - _singleTapStartOffset!).distance;
                    if (elapsed < 350 && dist < 16) {
                      _game.handleScreenTap(Vector2(event.localPosition.dx, event.localPosition.dy));
                    }
                  }

                  _pointerPositions.remove(event.pointer);
                  if (_pointerPositions.length < 2) {
                    _initialPinchDistance = null;
                    _initialPinchZoom = null;
                  }
                  if (_pointerPositions.isEmpty) {
                    _singleTapStartOffset = null;
                    _singleTapStartTime = null;
                    _lastSinglePointerPos = null;
                  }
                },
                onPointerCancel: (event) {
                  _pointerPositions.clear();
                  _initialPinchDistance = null;
                  _initialPinchZoom = null;
                  _singleTapStartOffset = null;
                  _singleTapStartTime = null;
                  _lastSinglePointerPos = null;
                },
                onPointerSignal: (pointerSignal) {
                  if (pointerSignal is PointerScrollEvent) {
                    final delta = pointerSignal.scrollDelta.dy;
                    if (delta < 0) {
                      _game.adjustZoom(1.1);
                    } else if (delta > 0) {
                      _game.adjustZoom(0.9);
                    }
                  }
                },
                child: GameWidget(game: _game),
              ),
            ),

            // Top Header: Date Information & Leave button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Host and date badge
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF261D3B).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.home_outlined, color: Color(0xFFFFB088), size: 20),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  widget.isHost
                                      ? 'Tu Hogar (Visita de ${widget.partnerUser.username})'
                                      : 'Hogar de ${widget.hostName}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Button to lower / raise interior walls
                          ElevatedButton.icon(
                            key: const Key('toggle_walls_cut_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _game.wallsCut
                                  ? const Color(0xFF00E5FF).withValues(alpha: 0.25)
                                  : const Color(0xFF261D3B).withValues(alpha: 0.85),
                              foregroundColor: _game.wallsCut ? const Color(0xFF00E5FF) : Colors.white70,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: _game.wallsCut
                                      ? const Color(0xFF00E5FF).withValues(alpha: 0.6)
                                      : Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                            ),
                            icon: Icon(
                              _game.wallsCut ? Icons.border_bottom_rounded : Icons.apartment_rounded,
                              size: 16,
                              color: _game.wallsCut ? const Color(0xFF00E5FF) : Colors.white70,
                            ),
                            label: Text(
                              _game.wallsCut ? 'Zócalo' : 'Muros',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _game.wallsCut ? const Color(0xFF00E5FF) : Colors.white70,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _game.toggleWallsCut();
                              });
                              _showTopNotification(_game.wallsCut
                                  ? 'Muros interiores reducidos a zócalo'
                                  : 'Muros interiores en altura completa');
                            },
                          ),
                          const SizedBox(width: 8),

                          if (widget.isHost) ...[
                            _buildHostLightsButton(),
                            const SizedBox(width: 8),
                          ],

                          // Leave Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE84118).withValues(alpha: 0.9),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            icon: const Icon(Icons.exit_to_app, size: 16),
                            label: const Text('Salir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () => _confirmLeave(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top Notification Banner (renders cleanly above furniture and room components)
            if (_topNotificationText != null)
              Positioned(
                top: 70,
                left: 20,
                right: 20,
                child: SafeArea(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2244).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD54F).withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('✨', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _topNotificationText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Bottom Cozy Action Bar & Emotes
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Chat text field overlay if active
                    if (_showChatInput)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF261D3B).withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF6C5CE7).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _chatController,
                                focusNode: _chatFocusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Escribe algo tierno...',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _sendChat(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send, color: Color(0xFFFF6584)),
                              onPressed: _sendChat,
                            ),
                          ],
                        ),
                      ),

                    // Cozy Interactions Card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E192E).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            iconText: '🍵',
                            tooltip: 'Compartir té',
                            onTap: () => _sendAction('tea', 'sirvió una taza de té calientito 🍵'),
                          ),
                          _buildActionButton(
                            iconText: '🎵',
                            tooltip: 'Poner música suave',
                            onTap: () => _sendAction('music', 'puso una melodía lo-fi relajante 🎵'),
                          ),
                          _buildActionButton(
                            iconText: '💖',
                            tooltip: 'Corazón',
                            onTap: () => _sendEmote('💖'),
                          ),
                          _buildActionButton(
                            iconText: '✨',
                            tooltip: 'Brillos',
                            onTap: () => _sendEmote('✨'),
                          ),
                          _buildActionButton(
                            iconText: '💬',
                            tooltip: 'Conversar',
                            onTap: () {
                              setState(() {
                                _showChatInput = !_showChatInput;
                                if (_showChatInput) {
                                  _chatFocusNode.requestFocus();
                                }
                              });
                            },
                          ),
                        ],
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

  Widget _buildActionButton({
    required String iconText,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              iconText,
              style: const TextStyle(fontSize: 22),
            ),
          ),
        ),
      ),
    );
  }
}
