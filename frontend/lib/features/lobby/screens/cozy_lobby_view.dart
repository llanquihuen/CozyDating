import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flame/game.dart';
import '../../../core/config/app_config.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../avatar/screens/character_creator_screen.dart';
import '../../game/bloc/game_bloc.dart';
import '../../mailbox/screens/mailbox_screen.dart';
import '../../mailbox/services/mailbox_service.dart';
import '../components/isometric_furniture_component.dart';
import '../components/isometric_interior_wall_component.dart';
import '../games/cozy_room_game.dart';
import 'room_decorator_sheet.dart';

class CozyLobbyView extends StatefulWidget {
  final String activeUserId;
  final ValueChanged<String> onUserChanged;
  final VoidCallback? onStartMatchmaking;
  final VoidCallback? onLogout;

  const CozyLobbyView({
    super.key,
    required this.activeUserId,
    required this.onUserChanged,
    this.onStartMatchmaking,
    this.onLogout,
  });

  static const List<Map<String, String>> defaultUsers = [
    {'id': 'alice', 'name': '🧑‍🦰 Alice (Explorador)'},
    {'id': 'bob', 'name': '👩‍🦱 Bob (Explorador)'},
    {'id': 'charlie', 'name': '🧔 Charlie (Guía)'},
    {'id': 'david', 'name': '👱‍♀️ David (Guía)'},
  ];

  @override
  State<CozyLobbyView> createState() => _CozyLobbyViewState();
}

enum LobbyEditMode { none, decorate, construct }
enum FloorEditTool { globalRoom, zoneBrush, eraser }
enum InteriorWallEditTool { addWall, allWalls, brush, eraser }

class _CozyLobbyViewState extends State<CozyLobbyView> with SingleTickerProviderStateMixin {
  late CozyRoomGame _roomGame;
  late AvatarConfig _currentAvatarConfig;
  late RoomConfig _currentRoomConfig;
  late TabController _constructorTabController;

  LobbyEditMode _editMode = LobbyEditMode.none;
  bool get _isDecorating => _editMode != LobbyEditMode.none;

  // Floor Selector State
  FloorEditTool _floorEditTool = FloorEditTool.globalRoom;
  String _floorCategory = 'colors'; // 'colors' or 'patterns'
  String _selectedFloorTexture = 'tiles'; // 'tiles' or 'carpet'
  String _selectedZoneFloorId = 'solid_white_tiles';

  // Wall Selector State (Paredes)
  FloorEditTool _wallEditTool = FloorEditTool.globalRoom;
  String _wallCategory = 'colors'; // 'colors' or 'patterns'
  String _selectedWallTexture = 'plaster'; // 'plaster' or 'tiles'
  String _selectedZoneWallId = 'solid_white_plaster';

  // Interior Wall Selector State (Muros Internos)
  InteriorWallEditTool _interiorWallEditTool = InteriorWallEditTool.addWall;
  String _interiorWallCategory = 'colors'; // 'colors' or 'patterns'
  String _selectedInteriorWallTexture = 'plaster'; // 'plaster' or 'tiles'

  final ValueNotifier<String?> _topNotificationNotifier = ValueNotifier<String?>(null);
  Timer? _topNotificationTimer;
  IsometricFurnitureComponent? _selectedFurniture;
  IsometricInteriorWallComponent? _selectedInteriorWall;
  final Map<int, Offset> _pointerPositions = {};
  double? _initialPinchDistance;
  double? _initialPinchZoom;
  Offset? _lastSinglePointerPos;
  Offset? _singleTapStartOffset;
  DateTime? _singleTapStartTime;

  void _showTopNotification(String message) {
    _topNotificationTimer?.cancel();
    _topNotificationNotifier.value = message;
    _topNotificationTimer = Timer(const Duration(milliseconds: 2200), () {
      _topNotificationNotifier.value = null;
    });
  }

  @override
  void dispose() {
    _topNotificationTimer?.cancel();
    _topNotificationNotifier.dispose();
    _constructorTabController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    MailboxService.fetchLetters(userId: widget.activeUserId);
    _constructorTabController = TabController(length: 3, vsync: this);
    _constructorTabController.addListener(() {
      if (!mounted) return;
      if (_editMode == LobbyEditMode.construct) {
        if (_constructorTabController.index == 0) {
          // Tab 0: Paredes
          if (_wallEditTool == FloorEditTool.zoneBrush) {
            _roomGame.setWallBrush(_selectedZoneWallId);
          } else if (_wallEditTool == FloorEditTool.eraser) {
            _roomGame.setWallBrush('__eraser__');
          } else {
            _roomGame.setWallBrush(null);
          }
          _roomGame.setFloorBrush(null);
        } else if (_constructorTabController.index == 1) {
          // Tab 1: Pisos
          if (_floorEditTool == FloorEditTool.zoneBrush) {
            _roomGame.setFloorBrush(_selectedZoneFloorId);
          } else if (_floorEditTool == FloorEditTool.eraser) {
            _roomGame.setFloorBrush('__eraser__');
          } else {
            _roomGame.setFloorBrush(null);
          }
          _roomGame.setWallBrush(null);
        } else if (_constructorTabController.index == 2) {
          // Tab 2: Muros Internos
          if (_interiorWallEditTool == InteriorWallEditTool.brush) {
            _roomGame.setWallBrush(_selectedZoneWallId);
          } else if (_interiorWallEditTool == InteriorWallEditTool.eraser) {
            _roomGame.setWallBrush('__eraser__');
          } else {
            _roomGame.setWallBrush(null);
          }
          _roomGame.setFloorBrush(null);
        }
      }
    });
    AvatarStorageService.setActiveUser(widget.activeUserId);
    _currentAvatarConfig = AvatarStorageService.getUserConfig(widget.activeUserId);
    _currentRoomConfig = AvatarStorageService.getUserRoomConfig(widget.activeUserId);

    _roomGame = CozyRoomGame(
      avatarConfig: _currentAvatarConfig,
      roomConfig: _currentRoomConfig,
      onOpenWardrobe: _openWardrobe,
      onOpenMatchmaking: _startMatchmaking,
      onFurnitureSelected: (comp) {
        setState(() {
          _selectedFurniture = comp;
          if (comp != null) _selectedInteriorWall = null;
        });
      },
      onInteriorWallSelected: (wall) {
        setState(() {
          _selectedInteriorWall = wall;
          if (wall != null) _selectedFurniture = null;
        });
      },
    );
  }

  @override
  void didUpdateWidget(covariant CozyLobbyView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeUserId != widget.activeUserId) {
      AvatarStorageService.setActiveUser(widget.activeUserId);
      _currentAvatarConfig = AvatarStorageService.getUserConfig(widget.activeUserId);
      _currentRoomConfig = AvatarStorageService.getUserRoomConfig(widget.activeUserId);
      _roomGame.updateAvatarConfig(_currentAvatarConfig);
      _roomGame.updateRoomConfig(_currentRoomConfig);
      setState(() {});
    }
  }

  void _openWardrobe() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CharacterCreatorScreen(
          initialConfig: _currentAvatarConfig,
          onSaved: (newConfig) {
            AvatarStorageService.saveUserConfig(widget.activeUserId, newConfig);
            AuthService.saveAvatarConfig(newConfig);
            _roomGame.updateAvatarConfig(newConfig);
            setState(() {
              _currentAvatarConfig = newConfig;
            });
            _showTopNotification('✨ Avatar guardado en la nube');
          },
        ),
      ),
    );
  }

  void _openMailbox() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MailboxScreen(
          onClosed: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _enterDecorateMode() {
    setState(() {
      _editMode = LobbyEditMode.decorate;
      _roomGame.setDecorateMode(true);
      _selectedFurniture = null;
      _selectedInteriorWall = null;
    });
  }

  void _enterConstructorMode() {
    setState(() {
      _editMode = LobbyEditMode.construct;
      _roomGame.setDecorateMode(true);
      _selectedFurniture = null;
      _selectedInteriorWall = null;
      if (_constructorTabController.index == 1) {
        if (_floorEditTool == FloorEditTool.zoneBrush) {
          _roomGame.setFloorBrush(_selectedZoneFloorId);
        } else if (_floorEditTool == FloorEditTool.eraser) {
          _roomGame.setFloorBrush('__eraser__');
        } else {
          _roomGame.setFloorBrush(null);
        }
      } else {
        _roomGame.setFloorBrush(null);
      }
    });
  }

  void _openFurnitureCatalog([String category = 'living']) {
    RoomDecoratorSheet.show(
      context,
      initialConfig: _roomGame.roomConfig,
      initialCategory: category,
      onConfigChanged: (cfg) {
        _roomGame.updateRoomConfig(cfg, reloadFurniture: false);
        setState(() {});
      },
      onSave: (cfg) {
        _roomGame.updateRoomConfig(cfg, reloadFurniture: false);
        setState(() {});
      },
      onAddFurniture: (item) {
        _roomGame.addFurnitureFromCatalog(item);
      },
      onAddInteriorWall: (styleOption) {
        _roomGame.addInteriorWallFromStyle(styleOption);
      },
      onNotification: _showTopNotification,
    );
  }

  void _saveAndExitDecorateMode() {
    _roomGame.setFloorBrush(null);
    final updatedConfig = _roomGame.exportCurrentRoomConfig();
    AvatarStorageService.saveUserRoomConfig(widget.activeUserId, updatedConfig);
    AuthService.saveRoomConfig(updatedConfig);
    final wasConstructor = (_editMode == LobbyEditMode.construct);
    setState(() {
      _currentRoomConfig = updatedConfig;
      _editMode = LobbyEditMode.none;
      _roomGame.setDecorateMode(false);
      _selectedFurniture = null;
      _selectedInteriorWall = null;
    });

    _showTopNotification(wasConstructor ? '✨ Construcción guardada en la nube' : '✨ Decoración guardada en la nube');
  }

  void _cancelDecorateMode() {
    _roomGame.setFloorBrush(null);
    _roomGame.updateRoomConfig(_currentRoomConfig);
    setState(() {
      _editMode = LobbyEditMode.none;
      _roomGame.setDecorateMode(false);
      _selectedFurniture = null;
      _selectedInteriorWall = null;
    });
  }

  void _startMatchmaking() {
    if (widget.onStartMatchmaking != null) {
      widget.onStartMatchmaking!();
      return;
    }

    final state = context.read<GameBloc>().state;
    if (state is! MatchmakingQueueState) {
      final tokens = {
        'alice': 'alice_jwt',
        'bob': 'bob_jwt',
        'charlie': 'charlie_jwt',
        'david': 'david_jwt',
        'userA': 'user_a_jwt',
        'userB': 'user_b_jwt',
        'userC': 'user_c_jwt',
        'userD': 'user_d_jwt',
      };
      final token = tokens[widget.activeUserId] ?? 'alice_jwt';
      context.read<GameBloc>().add(JoinQueueEvent(
            socketUrl: AppConfig.wsUrl,
            token: token,
            commune: 'Santiago',
            timeSlot: '20',
            mode: 'VOICE',
          ));
    }
  }

  void _cancelMatchmaking() {
    context.read<GameBloc>().add(const SendEmergencyDisconnectEvent(shouldBlock: false));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GameBloc, GameState>(
      builder: (context, state) {
        final isQueued = state is MatchmakingQueueState;

        // Safe dropdown value resolution
        final hasActive = CozyLobbyView.defaultUsers.any((u) => u['id'] == widget.activeUserId);
        final selectedDropdownValue = hasActive ? widget.activeUserId : CozyLobbyView.defaultUsers.first['id']!;

        return Scaffold(
          backgroundColor: const Color(0xFF16141D),
          body: Stack(
            children: [
              // 1. Interactive 2:1 Isometric Cozy Room with Pinch-to-Zoom & Scroll Zoom
              Positioned.fill(
                child: Listener(
                  onPointerDown: (event) {
                    _pointerPositions[event.pointer] = event.localPosition;
                    if (_pointerPositions.length == 1) {
                      _singleTapStartOffset = event.localPosition;
                      _singleTapStartTime = DateTime.now();
                      _lastSinglePointerPos = event.localPosition;
                    } else if (_pointerPositions.length >= 2) {
                      // Multi-touch pinch engaged! Invalidate tap immediately
                      _singleTapStartOffset = null;
                      _singleTapStartTime = null;
                      _lastSinglePointerPos = null;

                      final keys = _pointerPositions.keys.toList();
                      final p1 = _pointerPositions[keys[0]]!;
                      final p2 = _pointerPositions[keys[1]]!;
                      _initialPinchDistance = (p1 - p2).distance;
                      _initialPinchZoom = _roomGame.camera.viewfinder.zoom;
                    }
                  },
                  onPointerMove: (event) {
                    _pointerPositions[event.pointer] = event.localPosition;

                    // 1. Pinch to Zoom with 2 or more fingers
                    if (_pointerPositions.length >= 2) {
                      final keys = _pointerPositions.keys.toList();
                      final p1 = _pointerPositions[keys[0]]!;
                      final p2 = _pointerPositions[keys[1]]!;
                      final currentDist = (p1 - p2).distance;

                      if (_initialPinchDistance != null && _initialPinchDistance! > 15 && _initialPinchZoom != null) {
                        final scaleFactor = currentDist / _initialPinchDistance!;
                        _roomGame.setZoom(_initialPinchZoom! * scaleFactor);
                      }
                    } else if (_pointerPositions.length == 1) {
                      // 2. Single finger pan camera in normal mode
                      if (!_isDecorating && _lastSinglePointerPos != null) {
                        final delta = event.localPosition - _lastSinglePointerPos!;
                        if (delta.distance > 3) {
                          _singleTapStartOffset = null; // Moving -> not a static tap
                          _roomGame.panCamera(Vector2(delta.dx, delta.dy));
                        }
                      }
                      _lastSinglePointerPos = event.localPosition;
                    }
                  },
                  onPointerUp: (event) {
                    // Check if it was a single tap
                    if (_pointerPositions.length == 1 && _singleTapStartOffset != null && _singleTapStartTime != null) {
                      final elapsed = DateTime.now().difference(_singleTapStartTime!).inMilliseconds;
                      final dist = (event.localPosition - _singleTapStartOffset!).distance;
                      if (elapsed < 350 && dist < 16) {
                        _roomGame.handleScreenTap(Vector2(event.localPosition.dx, event.localPosition.dy));
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
                        _roomGame.adjustZoom(1.1);
                      } else if (delta > 0) {
                        _roomGame.adjustZoom(0.9);
                      }
                    }
                  },
                  child: GameWidget(game: _roomGame),
                ),
              ),

              // 2. Top Header Overlay (Normal Mode or Decorate Mode Header)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    left: 16,
                    right: 16,
                    bottom: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: _isDecorating
                      ? _buildEditTopBar()
                      : _buildNormalTopBar(selectedDropdownValue),
                ),
              ),

              // 2. Top Discreet Notification Toast (Clean, subtle, non-intrusive text)
              Positioned(
                top: MediaQuery.of(context).padding.top + 54,
                left: 60,
                right: 20,
                child: IgnorePointer(
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _topNotificationNotifier,
                    builder: (context, message, _) {
                      if (message == null) return const SizedBox.shrink();
                      return Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xF01E1C27),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFFFB300).withOpacity(0.5),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // 4. Floating Selected Furniture Action Toolbar — hovers right above the
              // selected object in the isometric world (Only in Decorate Mode)
              if (_isDecorating && _selectedFurniture != null && _selectedFurniture!.type != FurnitureType.portal)
                _FollowingOverlay(
                  anchor: () => _roomGame.getSelectedFurnitureAnchor(),
                  child: _buildSelectedFurnitureToolbar(),
                ),

              // 5. Floating Selected Interior Wall Action Toolbar — hovers right above
              // the selected wall (Only in Decorate Mode)
              if (_isDecorating && _selectedInteriorWall != null)
                _FollowingOverlay(
                  anchor: () => _roomGame.getSelectedInteriorWallAnchor(),
                  child: _buildSelectedInteriorWallToolbar(),
                ),

              // 6. Bottom Docked Overlay (Normal Mode, Decorator Toolbar or Constructor Toolbar)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _editMode == LobbyEditMode.decorate
                    ? _buildDecorateBottomBar(context)
                    : (_editMode == LobbyEditMode.construct
                        ? _buildConstructorBottomBar(context)
                        : Padding(
                            padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: MediaQuery.of(context).padding.bottom + 12,
                            ),
                            child: isQueued ? _buildQueuedCard() : _buildIdleActionCard(),
                          )),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNormalTopBar(String selectedDropdownValue) {
    final user = AuthService.currentUser;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 1. User Profile & Wardrobe Card (Tap to edit Avatar, Tastes & Real Photo)
        InkWell(
          onTap: _openWardrobe,
          borderRadius: BorderRadius.circular(20),
          child: user != null
              ? Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282531).withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.7), width: 1.2),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 15,
                            backgroundColor: const Color(0xFFFFB300),
                            backgroundImage: (user.profilePhoto != null && user.profilePhoto!.isNotEmpty)
                                ? NetworkImage(user.profilePhoto!)
                                : null,
                            child: (user.profilePhoto == null || user.profilePhoto!.isEmpty)
                                ? const Icon(Icons.person, size: 18, color: Colors.black)
                                : null,
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E1B2E),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('🪞', style: TextStyle(fontSize: 9)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    user.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12.5,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB300).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${user.ticketsBalance} 🎟️',
                                    style: const TextStyle(
                                      color: Color(0xFFFFD54F),
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 1),
                            const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🪞 Editar Avatar & Gustos ✨',
                                  style: TextStyle(
                                    color: Color(0xFFFFE082),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.onLogout != null) ...[
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: widget.onLogout,
                          child: const Padding(
                            padding: EdgeInsets.all(2.0),
                            child: Icon(Icons.logout, color: Colors.redAccent, size: 15),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : Container(
                  width: 140,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282531).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF453F58)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedDropdownValue,
                      dropdownColor: const Color(0xFF282531),
                      icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFFFD54F), size: 18),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      items: CozyLobbyView.defaultUsers.map((u) {
                        return DropdownMenuItem<String>(
                          value: u['id'],
                          child: Text(
                            u['name']!,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          widget.onUserChanged(val);
                        }
                      },
                    ),
                  ),
                ),
        ),

        // 2. Buzón de Recuerdos (Post-Date Matches & Letters)
        ValueListenableBuilder<int>(
          valueListenable: MailboxService.unreadLettersCount,
          builder: (context, unreadCount, _) {
            return ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: unreadCount > 0 ? const Color(0xFF3B1E2E).withOpacity(0.95) : const Color(0xFF282531).withOpacity(0.92),
                foregroundColor: unreadCount > 0 ? const Color(0xFFFF80AB) : const Color(0xFFFFD54F),
                side: BorderSide(
                  color: unreadCount > 0 ? const Color(0xFFFF4081) : const Color(0xFFFFD54F),
                  width: unreadCount > 0 ? 1.6 : 1.2,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                visualDensity: VisualDensity.compact,
                elevation: 3,
              ),
              onPressed: _openMailbox,
              icon: const Text('📮', style: TextStyle(fontSize: 14)),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Buzón', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4081),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEditTopBar() {
    final currentRes = _roomGame.roomConfig.resolution;
    final isConstructor = _editMode == LobbyEditMode.construct;
    final badgeColor = isConstructor ? const Color(0xFFFFB300) : const Color(0xFFFF6D00);
    final badgeLabel = isConstructor ? 'CONSTRUCTOR' : 'DECORAR';
    final badgeIcon = isConstructor ? '🔨' : '🎨';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Active Mode Indicator Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: badgeColor, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(badgeIcon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    color: const Color(0xFFFFD54F),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Walls toggle in edit mode
          InkWell(
            onTap: () {
              _roomGame.toggleWallsCut();
              AvatarStorageService.saveUserRoomConfig(widget.activeUserId, _roomGame.roomConfig);
              setState(() {});
              _showTopNotification(_roomGame.wallsCut
                  ? '🚪 Muros bajos: mostrando zócalo'
                  : '🚪 Muros completos');
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _roomGame.wallsCut
                    ? const Color(0xFF00E5FF).withOpacity(0.25)
                    : const Color(0xFF282531).withOpacity(0.9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _roomGame.wallsCut ? const Color(0xFF00E5FF) : const Color(0xFF453F58),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _roomGame.wallsCut ? Icons.border_bottom_rounded : Icons.apartment_rounded,
                    color: _roomGame.wallsCut ? const Color(0xFF00E5FF) : Colors.white70,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _roomGame.wallsCut ? 'Zócalo' : 'Muros',
                    style: TextStyle(
                      color: _roomGame.wallsCut ? const Color(0xFF00E5FF) : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Save & Exit / Cancel
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _cancelDecorateMode,
                child: const Text('Cancelar', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 4),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _saveAndExitDecorateMode,
                icon: const Icon(Icons.check, size: 14, color: Colors.black),
                label: const Text('Listo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Small circular icon-only action button used by the floating selection toolbars —
  /// compact enough to hover right above the selected object without covering it.
  Widget _floatingIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withOpacity(0.2),
        shape: CircleBorder(side: BorderSide(color: color, width: 1.3)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFurnitureToolbar() {
    if (_selectedFurniture == null) return const SizedBox.shrink();
    final f = _selectedFurniture!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C27).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (f.isWallItem) ...[
            _floatingIconButton(
              icon: f.wallHeightLevel == 'high' ? Icons.vertical_align_top : Icons.vertical_align_center,
              color: const Color(0xFFA78BFA),
              tooltip: f.wallHeightLevel == 'high' ? 'Altura alta' : 'Altura media',
              onPressed: () {
                _roomGame.toggleSelectedWallHeight();
                setState(() {});
              },
            ),
            const SizedBox(width: 6),
          ],
          _floatingIconButton(
            icon: Icons.rotate_right_rounded,
            color: const Color(0xFF00E5FF),
            tooltip: 'Girar',
            onPressed: () {
              _roomGame.rotateSelectedFurniture();
              setState(() {});
            },
          ),
          const SizedBox(width: 6),
          _floatingIconButton(
            icon: Icons.delete_outline,
            color: const Color(0xFFEF5350),
            tooltip: 'Borrar',
            onPressed: () {
              _roomGame.deleteSelectedFurniture();
              setState(() {
                _selectedFurniture = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedInteriorWallToolbar() {
    if (_selectedInteriorWall == null) return const SizedBox.shrink();
    final w = _selectedInteriorWall!;
    final isNorth = (w.orientation == 'north');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C27).withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 10),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _floatingIconButton(
            icon: Icons.swap_horiz_rounded,
            color: const Color(0xFF00E5FF),
            tooltip: isNorth ? 'Arista Norte (tocar para girar)' : 'Arista Oeste (tocar para girar)',
            onPressed: () {
              _roomGame.rotateSelectedInteriorWall();
              setState(() {});
            },
          ),
          const SizedBox(width: 6),
          _floatingIconButton(
            icon: w.hasDoorway ? Icons.door_front_door_outlined : Icons.lock_outline,
            color: w.hasDoorway ? const Color(0xFF10B981) : const Color(0xFF8B5CF6),
            tooltip: w.hasDoorway ? 'Paso Libre' : 'Muro Sólido',
            onPressed: () {
              _roomGame.toggleSelectedInteriorWallDoorway();
              setState(() {});
            },
          ),
          const SizedBox(width: 6),
          _floatingIconButton(
            icon: Icons.add_circle_outline,
            color: const Color(0xFFFFD54F),
            tooltip: 'Agregar otro igual',
            onPressed: () {
              // Adds another wall with the same style as the one currently selected —
              // placing several walls of a kind is common, so this saves a trip back to the catalog.
              final styleOpt = InteriorWallStyles.all.firstWhere(
                (s) => s.id == w.style,
                orElse: () => InteriorWallStyles.all.first,
              );
              _roomGame.addInteriorWallFromStyle(styleOpt);
              setState(() {});
            },
          ),
          const SizedBox(width: 6),
          _floatingIconButton(
            icon: Icons.delete_outline,
            color: const Color(0xFFEF5350),
            tooltip: 'Borrar',
            onPressed: () {
              _roomGame.deleteSelectedInteriorWall();
              setState(() {
                _selectedInteriorWall = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDecorateBottomBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(top: 10, bottom: bottomInset + 12, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1C27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF453F58), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text(
                '🛋️ Muebles & Decoración',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF).withOpacity(0.18),
                  foregroundColor: const Color(0xFF00E5FF),
                  side: const BorderSide(color: Color(0xFF00E5FF), width: 1.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _openFurnitureCatalog('living'),
                icon: const Icon(Icons.grid_view_rounded, size: 14),
                label: const Text('Abrir Catálogo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: _buildFurnitureCategoriesSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildConstructorBottomBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(top: 8, bottom: bottomInset + 12, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1C27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF453F58), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _constructorTabController,
            indicatorColor: const Color(0xFFFFB300),
            labelColor: const Color(0xFFFFB300),
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            tabs: const [
              Tab(text: '🧱 Paredes'),
              Tab(text: '🪵 Pisos'),
              Tab(text: '🚪 Muros Internos'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 125,
            child: TabBarView(
              controller: _constructorTabController,
              children: [
                _buildWallpaperSelector(),
                _buildFloorSelector(),
                _buildInteriorWallsSelector(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFurnitureCategoriesSelector() {
    final categories = const [
      {
        'id': 'living',
        'emoji': '🛋️',
        'name': 'Salón y Mesas',
        'desc': 'Mesas, sillas, estantes',
      },
      {
        'id': 'bedroom',
        'emoji': '🛏️',
        'name': 'Dormitorio',
        'desc': 'Camas, armarios, velador',
      },
      {
        'id': 'kitchen_bath',
        'emoji': '🍳',
        'name': 'Cocina y Baño',
        'desc': 'Nevera, cocina, bañera',
      },
      {
        'id': 'patio',
        'emoji': '🪴',
        'name': 'Patio y Jardín',
        'desc': 'Bancos, fuentes, flores',
      },
      {
        'id': 'guide',
        'emoji': '📦',
        'name': 'Cubos Guías',
        'desc': 'Paralelepípedos guía',
      },
      {
        'id': 'surface',
        'emoji': '🕯️',
        'name': 'Sobremesa',
        'desc': 'Tazas, lámparas, libros',
      },
      {
        'id': 'walls',
        'emoji': '🖼️',
        'name': 'Paredes',
        'desc': 'Ventanas y cuadros',
      },
    ];

    return ListView.builder(
      key: const PageStorageKey('furniture_categories_scroll_list'),
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return GestureDetector(
          onTap: () {
            _openFurnitureCatalog(cat['id']!);
          },
          child: Container(
            width: 130,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF282531),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF453F58), width: 1.2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(cat['emoji']!, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  cat['name']!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  cat['desc']!,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white60,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWallpaperSelector() {
    final hasOverrides = _roomGame.roomConfig.wallOverrides.isNotEmpty;

    final currentWallpaperId = _roomGame.roomConfig.wallpaper;
    final currentWallpaperOpt = RoomThemes.getWallpaperOption(currentWallpaperId);
    final isCurrentWallpaperTiles = currentWallpaperOpt.textureType == 'tiles' || currentWallpaperId.contains('tiles');
    final isZoneWallTiles = _selectedZoneWallId.contains('tiles');

    final activeTexture = (_wallEditTool == FloorEditTool.zoneBrush)
        ? (isZoneWallTiles ? 'tiles' : 'plaster')
        : (isCurrentWallpaperTiles ? 'tiles' : _selectedWallTexture);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Tool Selection Row
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              // All Walls (Todo el Salón)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _wallEditTool = FloorEditTool.globalRoom;
                    _roomGame.setWallBrush(null);
                  });
                  _showTopNotification('🌟 Modo: Cambiar papel tapiz de todo el salón');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _wallEditTool == FloorEditTool.globalRoom ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _wallEditTool == FloorEditTool.globalRoom ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_outlined, size: 12, color: _wallEditTool == FloorEditTool.globalRoom ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Todo el Salón',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _wallEditTool == FloorEditTool.globalRoom ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // Zone Brush Mode
              GestureDetector(
                onTap: () {
                  setState(() {
                    _wallEditTool = FloorEditTool.zoneBrush;
                    _roomGame.setWallBrush(_selectedZoneWallId);
                  });
                  _showTopNotification('🖌️ Pincel activo: toca o arrastra en las paredes para pintar');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _wallEditTool == FloorEditTool.zoneBrush ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _wallEditTool == FloorEditTool.zoneBrush ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.brush, size: 12, color: _wallEditTool == FloorEditTool.zoneBrush ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Pintar Zona',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _wallEditTool == FloorEditTool.zoneBrush ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // Eraser Mode
              GestureDetector(
                onTap: () {
                  setState(() {
                    _wallEditTool = FloorEditTool.eraser;
                    _roomGame.setWallBrush('__eraser__');
                  });
                  _showTopNotification('🧹 Borrador activo: toca paneles para restaurar a la pared base');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _wallEditTool == FloorEditTool.eraser ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _wallEditTool == FloorEditTool.eraser ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cleaning_services, size: 12, color: _wallEditTool == FloorEditTool.eraser ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Borrador',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _wallEditTool == FloorEditTool.eraser ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (hasOverrides)
                GestureDetector(
                  onTap: () {
                    _roomGame.clearAllWallOverrides();
                    setState(() {});
                    _showTopNotification('🧹 Se restauraron todas las paredes al papel tapiz base');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.delete_sweep, size: 12, color: Color(0xFFEF5350)),
                        SizedBox(width: 3),
                        Text(
                          'Limpiar Zonas',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Category & Texture Sub-Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              // Category: Colores vs Patrones
              GestureDetector(
                onTap: () => setState(() => _wallCategory = 'colors'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _wallCategory == 'colors' ? const Color(0xFF453F58) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🎨 Colores',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _wallCategory == 'colors' ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _wallCategory = 'patterns'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _wallCategory == 'patterns' ? const Color(0xFF453F58) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🪵 Patrones',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _wallCategory == 'patterns' ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ),

              if (_wallCategory == 'colors') ...[
                const SizedBox(width: 10),
                Container(width: 1, height: 12, color: Colors.white24),
                const SizedBox(width: 10),
                const Text(
                  'Textura:',
                  style: TextStyle(fontSize: 9, color: Colors.white60),
                ),
                const SizedBox(width: 4),

                // Texture Switcher: Yeso / Liso
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWallTexture = 'plaster';
                      if (_wallEditTool == FloorEditTool.globalRoom) {
                        final newId = RoomThemes.changeWallpaperTexture(_roomGame.roomConfig.wallpaper, 'plaster');
                        _roomGame.updateWallpaper(newId);
                      } else if (_wallEditTool == FloorEditTool.zoneBrush) {
                        _selectedZoneWallId = RoomThemes.changeWallpaperTexture(_selectedZoneWallId, 'plaster');
                        _roomGame.setWallBrush(_selectedZoneWallId);
                      }
                    });
                    _showTopNotification('🧱 Textura cambiada a: Yeso / Liso');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeTexture == 'plaster' ? const Color(0xFFFFB300) : const Color(0xFF282531),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTexture == 'plaster' ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧱', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          'Yeso/Liso',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: activeTexture == 'plaster' ? Colors.black : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Texture Switcher: Azulejos
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWallTexture = 'tiles';
                      if (_wallEditTool == FloorEditTool.globalRoom) {
                        final newId = RoomThemes.changeWallpaperTexture(_roomGame.roomConfig.wallpaper, 'tiles');
                        _roomGame.updateWallpaper(newId);
                      } else if (_wallEditTool == FloorEditTool.zoneBrush) {
                        _selectedZoneWallId = RoomThemes.changeWallpaperTexture(_selectedZoneWallId, 'tiles');
                        _roomGame.setWallBrush(_selectedZoneWallId);
                      }
                    });
                    _showTopNotification('🔲 Textura cambiada a: Azulejos Cerámicos');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeTexture == 'tiles' ? const Color(0xFFFFB300) : const Color(0xFF282531),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTexture == 'tiles' ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔲', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          'Azulejos',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: activeTexture == 'tiles' ? Colors.black : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 3. Carousel List (Colors or Patterns)
        Expanded(
          child: _wallCategory == 'colors'
              ? ListView.builder(
                  key: const PageStorageKey('wallpapers_colors_scroll_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: RoomThemes.wallpaperColors.length,
                  itemBuilder: (context, index) {
                    final colorOpt = RoomThemes.wallpaperColors[index];
                    final wpId = RoomThemes.getWallpaperId(colorOpt.key, activeTexture);

                    final currentGlobalOpt = RoomThemes.getWallpaperOption(_roomGame.roomConfig.wallpaper);
                    final isGlobalSelected = currentGlobalOpt.color?.value == colorOpt.color.value &&
                        ((currentGlobalOpt.textureType == 'tiles') == (activeTexture == 'tiles'));

                    final currentBrushOpt = RoomThemes.getWallpaperOption(_selectedZoneWallId);
                    final isBrushSelected = currentBrushOpt.color?.value == colorOpt.color.value &&
                        ((currentBrushOpt.textureType == 'tiles') == (activeTexture == 'tiles'));

                    final isSelected = (_wallEditTool == FloorEditTool.globalRoom)
                        ? isGlobalSelected
                        : (_wallEditTool == FloorEditTool.zoneBrush && isBrushSelected);

                    final textureLabel = activeTexture == 'tiles' ? 'Azulejos' : 'Yeso/Liso';
                    final textureIcon = activeTexture == 'tiles' ? '🔲' : '🧱';

                    return GestureDetector(
                      onTap: () {
                        if (_wallEditTool == FloorEditTool.globalRoom) {
                          _roomGame.updateWallpaper(wpId);
                          setState(() {});
                          _showTopNotification('$textureIcon $textureLabel ${colorOpt.name} aplicado a todo el salón');
                        } else if (_wallEditTool == FloorEditTool.zoneBrush) {
                          setState(() {
                            _selectedZoneWallId = wpId;
                            _roomGame.setWallBrush(wpId);
                          });
                          _showTopNotification('🖌️ Pincel: $textureLabel ${colorOpt.name}. ¡Toca o arrastra en las paredes!');
                        } else {
                          setState(() {
                            _wallEditTool = FloorEditTool.zoneBrush;
                            _selectedZoneWallId = wpId;
                            _roomGame.setWallBrush(wpId);
                          });
                          _showTopNotification('🖌️ Pincel: $textureLabel ${colorOpt.name}. ¡Toca o arrastra en las paredes!');
                        }
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF383247) : const Color(0xFF282531),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: colorOpt.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorOpt.color.withOpacity(0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Text(textureIcon, style: const TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              colorOpt.name,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFFFFB300) : Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  key: const PageStorageKey('wallpapers_patterns_scroll_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: RoomThemes.wallpaperPatterns.length,
                  itemBuilder: (context, index) {
                    final item = RoomThemes.wallpaperPatterns[index];
                    final isGlobalSelected = _roomGame.roomConfig.wallpaper == item.id;
                    final isBrushSelected = _selectedZoneWallId == item.id;
                    final isSelected = (_wallEditTool == FloorEditTool.globalRoom)
                        ? isGlobalSelected
                        : (_wallEditTool == FloorEditTool.zoneBrush && isBrushSelected);

                    return GestureDetector(
                      onTap: () {
                        if (_wallEditTool == FloorEditTool.globalRoom) {
                          _roomGame.updateWallpaper(item.id);
                          setState(() {});
                          _showTopNotification('🌟 Pared cambiada a: ${item.name}');
                        } else if (_wallEditTool == FloorEditTool.zoneBrush) {
                          setState(() {
                            _selectedZoneWallId = item.id;
                            _roomGame.setWallBrush(item.id);
                          });
                          _showTopNotification('🖌️ Pincel: ${item.name}. ¡Toca o arrastra en las paredes!');
                        } else {
                          setState(() {
                            _wallEditTool = FloorEditTool.zoneBrush;
                            _selectedZoneWallId = item.id;
                            _roomGame.setWallBrush(item.id);
                          });
                          _showTopNotification('🖌️ Pincel: ${item.name}. ¡Toca o arrastra en las paredes!');
                        }
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF383247) : const Color(0xFF282531),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 3),
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFFFFB300) : Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFloorSelector() {
    final hasOverrides = _roomGame.roomConfig.floorOverrides.isNotEmpty;

    final currentFloorId = _roomGame.roomConfig.floor;
    final currentFloorOpt = RoomThemes.getFloorOption(currentFloorId);
    final isCurrentFloorCarpet = currentFloorOpt.textureType == 'carpet' || currentFloorId.contains('carpet');
    final isZoneFloorCarpet = _selectedZoneFloorId.contains('carpet');

    final activeTexture = (_floorEditTool == FloorEditTool.zoneBrush)
        ? (isZoneFloorCarpet ? 'carpet' : 'tiles')
        : (isCurrentFloorCarpet ? 'carpet' : _selectedFloorTexture);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Tool Selection Row
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              // All Room Mode
              GestureDetector(
                onTap: () {
                  setState(() {
                    _floorEditTool = FloorEditTool.globalRoom;
                    _roomGame.setFloorBrush(null);
                  });
                  _showTopNotification('🌟 Modo: Cambiar piso de todo el salón');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _floorEditTool == FloorEditTool.globalRoom ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _floorEditTool == FloorEditTool.globalRoom ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.home_outlined, size: 12, color: _floorEditTool == FloorEditTool.globalRoom ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Todo el Salón',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _floorEditTool == FloorEditTool.globalRoom ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // Zone Brush Mode
              GestureDetector(
                onTap: () {
                  setState(() {
                    _floorEditTool = FloorEditTool.zoneBrush;
                    _roomGame.setFloorBrush(_selectedZoneFloorId);
                  });
                  _showTopNotification('🖌️ Pincel activo: toca o arrastra en el suelo para pintar');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _floorEditTool == FloorEditTool.zoneBrush ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _floorEditTool == FloorEditTool.zoneBrush ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.brush, size: 12, color: _floorEditTool == FloorEditTool.zoneBrush ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Pintar Zona',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _floorEditTool == FloorEditTool.zoneBrush ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),
              // Eraser Mode
              GestureDetector(
                onTap: () {
                  setState(() {
                    _floorEditTool = FloorEditTool.eraser;
                    _roomGame.setFloorBrush('__eraser__');
                  });
                  _showTopNotification('🧹 Borrador activo: toca baldosas para restaurar al piso base');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _floorEditTool == FloorEditTool.eraser ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _floorEditTool == FloorEditTool.eraser ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cleaning_services, size: 12, color: _floorEditTool == FloorEditTool.eraser ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Borrador',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _floorEditTool == FloorEditTool.eraser ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (hasOverrides)
                GestureDetector(
                  onTap: () {
                    _roomGame.clearAllFloorOverrides();
                    setState(() {});
                    _showTopNotification('🧹 Se restauraron todas las baldosas al piso base');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF5350).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF5350).withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.delete_sweep, size: 12, color: Color(0xFFEF5350)),
                        SizedBox(width: 3),
                        Text(
                          'Limpiar Zonas',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. Texture and Category Selector Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              // Category toggle: Colores vs Patrones
              GestureDetector(
                onTap: () {
                  setState(() {
                    _floorCategory = 'colors';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _floorCategory == 'colors' ? const Color(0xFF453F58) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _floorCategory == 'colors' ? const Color(0xFFFFB300) : const Color(0xFF383247),
                    ),
                  ),
                  child: Text(
                    '🎨 Colores',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _floorCategory == 'colors' ? const Color(0xFFFFB300) : Colors.white60,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _floorCategory = 'patterns';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _floorCategory == 'patterns' ? const Color(0xFF453F58) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _floorCategory == 'patterns' ? const Color(0xFFFFB300) : const Color(0xFF383247),
                    ),
                  ),
                  child: Text(
                    '🪵 Patrones',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _floorCategory == 'patterns' ? const Color(0xFFFFB300) : Colors.white60,
                    ),
                  ),
                ),
              ),

              if (_floorCategory == 'colors') ...[
                const SizedBox(width: 8),
                Container(width: 1, height: 14, color: const Color(0xFF453F58)),
                const SizedBox(width: 8),
                const Text(
                  'Textura:',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                const SizedBox(width: 4),
                // Tile texture toggle button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFloorTexture = 'tiles';
                      if (_floorEditTool == FloorEditTool.globalRoom) {
                        final newId = RoomThemes.changeTexture(_roomGame.roomConfig.floor, 'tiles');
                        _roomGame.updateFloor(newId);
                        _showTopNotification('🔲 Textura cambiada a: Baldosas (Cuadros)');
                      } else {
                        _selectedZoneFloorId = RoomThemes.changeTexture(_selectedZoneFloorId, 'tiles');
                        _roomGame.setFloorBrush(_selectedZoneFloorId);
                        _showTopNotification('🔲 Pincel cambiado a textura: Baldosas');
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeTexture == 'tiles' ? const Color(0xFFFFB300) : const Color(0xFF282531),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTexture == 'tiles' ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔲', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          'Baldosas',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: activeTexture == 'tiles' ? Colors.black : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Carpet texture toggle button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFloorTexture = 'carpet';
                      if (_floorEditTool == FloorEditTool.globalRoom) {
                        final newId = RoomThemes.changeTexture(_roomGame.roomConfig.floor, 'carpet');
                        _roomGame.updateFloor(newId);
                        _showTopNotification('🧶 Textura cambiada a: Alfombra (Felpa)');
                      } else {
                        _selectedZoneFloorId = RoomThemes.changeTexture(_selectedZoneFloorId, 'carpet');
                        _roomGame.setFloorBrush(_selectedZoneFloorId);
                        _showTopNotification('🧶 Pincel cambiado a textura: Alfombra');
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeTexture == 'carpet' ? const Color(0xFFFFB300) : const Color(0xFF282531),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTexture == 'carpet' ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧶', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          'Alfombra',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: activeTexture == 'carpet' ? Colors.black : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 3. Carousel List (Colors or Patterns)
        Expanded(
          child: _floorCategory == 'colors'
              ? ListView.builder(
                  key: const PageStorageKey('floors_colors_scroll_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: RoomThemes.floorColors.length,
                  itemBuilder: (context, index) {
                    final colorOpt = RoomThemes.floorColors[index];
                    final floorId = RoomThemes.getFloorId(colorOpt.key, activeTexture);

                    final currentGlobalOpt = RoomThemes.getFloorOption(_roomGame.roomConfig.floor);
                    final isGlobalSelected = currentGlobalOpt.color?.value == colorOpt.color.value &&
                        ((currentGlobalOpt.textureType == 'carpet') == (activeTexture == 'carpet'));

                    final currentBrushOpt = RoomThemes.getFloorOption(_selectedZoneFloorId);
                    final isBrushSelected = currentBrushOpt.color?.value == colorOpt.color.value &&
                        ((currentBrushOpt.textureType == 'carpet') == (activeTexture == 'carpet'));

                    final isSelected = (_floorEditTool == FloorEditTool.globalRoom)
                        ? isGlobalSelected
                        : (_floorEditTool == FloorEditTool.zoneBrush && isBrushSelected);

                    final textureLabel = activeTexture == 'carpet' ? 'Alfombra' : 'Baldosa';
                    final textureIcon = activeTexture == 'carpet' ? '🧶' : '🔲';

                    return GestureDetector(
                      onTap: () {
                        if (_floorEditTool == FloorEditTool.globalRoom) {
                          _roomGame.updateFloor(floorId);
                          setState(() {});
                          _showTopNotification('$textureIcon $textureLabel ${colorOpt.name} aplicado a todo el salón');
                        } else if (_floorEditTool == FloorEditTool.zoneBrush) {
                          setState(() {
                            _selectedZoneFloorId = floorId;
                            _roomGame.setFloorBrush(floorId);
                          });
                          _showTopNotification('🖌️ Pincel: $textureLabel ${colorOpt.name}. ¡Toca o arrastra en el suelo!');
                        } else {
                          setState(() {
                            _floorEditTool = FloorEditTool.zoneBrush;
                            _selectedZoneFloorId = floorId;
                            _roomGame.setFloorBrush(floorId);
                          });
                          _showTopNotification('🖌️ Pincel: $textureLabel ${colorOpt.name}. ¡Toca o arrastra en el suelo!');
                        }
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF383247) : const Color(0xFF282531),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: colorOpt.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white24, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorOpt.color.withOpacity(0.4),
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(textureIcon, style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              colorOpt.name,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFFFFB300) : Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              textureLabel,
                              style: TextStyle(
                                fontSize: 7.5,
                                color: isSelected ? const Color(0xFFFFB300).withOpacity(0.8) : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  key: const PageStorageKey('floors_patterns_scroll_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: RoomThemes.patterns.length,
                  itemBuilder: (context, index) {
                    final item = RoomThemes.patterns[index];
                    final isGlobalSelected = _roomGame.roomConfig.floor == item.id;
                    final isBrushSelected = _selectedZoneFloorId == item.id;
                    final isSelected = (_floorEditTool == FloorEditTool.globalRoom)
                        ? isGlobalSelected
                        : (_floorEditTool == FloorEditTool.zoneBrush && isBrushSelected);

                    return GestureDetector(
                      onTap: () {
                        if (_floorEditTool == FloorEditTool.globalRoom) {
                          _roomGame.updateFloor(item.id);
                          setState(() {});
                          _showTopNotification('🌟 Piso cambiado a: ${item.name}');
                        } else if (_floorEditTool == FloorEditTool.zoneBrush) {
                          setState(() {
                            _selectedZoneFloorId = item.id;
                            _roomGame.setFloorBrush(item.id);
                          });
                          _showTopNotification('🖌️ Pincel: ${item.name}. ¡Toca o arrastra en el suelo!');
                        } else {
                          setState(() {
                            _floorEditTool = FloorEditTool.zoneBrush;
                            _selectedZoneFloorId = item.id;
                            _roomGame.setFloorBrush(item.id);
                          });
                          _showTopNotification('🖌️ Pincel: ${item.name}. ¡Toca o arrastra en el suelo!');
                        }
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF383247) : const Color(0xFF282531),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                            width: isSelected ? 2.0 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.emoji, style: const TextStyle(fontSize: 20)),
                            const SizedBox(height: 3),
                            Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? const Color(0xFFFFB300) : Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInteriorWallsSelector() {
    final activeTexture = _selectedInteriorWallTexture;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. Tool Selection Row
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            children: [
              // Add Wall Mode
              GestureDetector(
                onTap: () {
                  setState(() {
                    _interiorWallEditTool = InteriorWallEditTool.addWall;
                    _roomGame.setWallBrush(null);
                  });
                  _showTopNotification('➕ Modo: Toca un diseño o color para añadir un muro');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _interiorWallEditTool == InteriorWallEditTool.addWall ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _interiorWallEditTool == InteriorWallEditTool.addWall ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, size: 12, color: _interiorWallEditTool == InteriorWallEditTool.addWall ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Añadir Muro',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _interiorWallEditTool == InteriorWallEditTool.addWall ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // All Walls (Todos los Muros)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _interiorWallEditTool = InteriorWallEditTool.allWalls;
                    _roomGame.setWallBrush(null);
                  });
                  _showTopNotification('🎨 Modo: Toca un color para pintar TODOS los muros del salón');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _interiorWallEditTool == InteriorWallEditTool.allWalls ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _interiorWallEditTool == InteriorWallEditTool.allWalls ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.format_paint_rounded, size: 12, color: _interiorWallEditTool == InteriorWallEditTool.allWalls ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Todos los Muros',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _interiorWallEditTool == InteriorWallEditTool.allWalls ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Paint Single Wall (Zone Brush)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _interiorWallEditTool = InteriorWallEditTool.brush;
                    _roomGame.setWallBrush(_selectedZoneWallId);
                  });
                  _showTopNotification('🖌️ Pincel activo: toca muros en el salón para pintarlos individualmente');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _interiorWallEditTool == InteriorWallEditTool.brush ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _interiorWallEditTool == InteriorWallEditTool.brush ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.brush, size: 12, color: _interiorWallEditTool == InteriorWallEditTool.brush ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Pintar Muro',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _interiorWallEditTool == InteriorWallEditTool.brush ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 5),

              // Eraser
              GestureDetector(
                onTap: () {
                  setState(() {
                    _interiorWallEditTool = InteriorWallEditTool.eraser;
                    _roomGame.setWallBrush('__eraser__');
                  });
                  _showTopNotification('🧹 Borrador: toca un muro en el salón para restaurarlo al blanco base');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _interiorWallEditTool == InteriorWallEditTool.eraser ? const Color(0xFFFFB300) : const Color(0xFF282531),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _interiorWallEditTool == InteriorWallEditTool.eraser ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cleaning_services, size: 12, color: _interiorWallEditTool == InteriorWallEditTool.eraser ? Colors.black : Colors.white70),
                      const SizedBox(width: 3),
                      Text(
                        'Borrador',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: _interiorWallEditTool == InteriorWallEditTool.eraser ? Colors.black : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Category & Texture Sub-Bar
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _interiorWallCategory = 'colors'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _interiorWallCategory == 'colors' ? const Color(0xFF453F58) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🎨 Colores',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _interiorWallCategory == 'colors' ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _interiorWallCategory = 'patterns'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: _interiorWallCategory == 'patterns' ? const Color(0xFF453F58) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '🪵 Diseños',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: _interiorWallCategory == 'patterns' ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ),

              if (_interiorWallCategory == 'colors') ...[
                const SizedBox(width: 10),
                Container(width: 1, height: 12, color: Colors.white24),
                const SizedBox(width: 10),
                const Text(
                  'Textura:',
                  style: TextStyle(fontSize: 9, color: Colors.white60),
                ),
                const SizedBox(width: 4),

                // Texture Switcher: Yeso / Liso
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedInteriorWallTexture = 'plaster';
                      if (_interiorWallEditTool == InteriorWallEditTool.brush) {
                        _selectedZoneWallId = RoomThemes.changeWallpaperTexture(_selectedZoneWallId, 'plaster');
                        _roomGame.setWallBrush(_selectedZoneWallId);
                      }
                    });
                    _showTopNotification('🧱 Textura de muros: Yeso / Liso');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeTexture == 'plaster' ? const Color(0xFFFFB300) : const Color(0xFF282531),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTexture == 'plaster' ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🧱', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          'Yeso/Liso',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: activeTexture == 'plaster' ? Colors.black : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Texture Switcher: Azulejos
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedInteriorWallTexture = 'tiles';
                      if (_interiorWallEditTool == InteriorWallEditTool.brush) {
                        _selectedZoneWallId = RoomThemes.changeWallpaperTexture(_selectedZoneWallId, 'tiles');
                        _roomGame.setWallBrush(_selectedZoneWallId);
                      }
                    });
                    _showTopNotification('🔲 Textura de muros: Azulejos Cerámicos');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: activeTexture == 'tiles' ? const Color(0xFFFFB300) : const Color(0xFF282531),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: activeTexture == 'tiles' ? const Color(0xFFFFB300) : const Color(0xFF453F58),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔲', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          'Azulejos',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: activeTexture == 'tiles' ? Colors.black : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // 3. Carousel List
        Expanded(
          child: _interiorWallCategory == 'colors'
              ? ListView.builder(
                  key: const PageStorageKey('interior_walls_colors_scroll_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: RoomThemes.wallpaperColors.length,
                  itemBuilder: (context, index) {
                    final colorOpt = RoomThemes.wallpaperColors[index];
                    final styleId = RoomThemes.getWallpaperId(colorOpt.key, activeTexture);
                    final styleOpt = InteriorWallStyles.getOption(styleId);

                    final textureLabel = activeTexture == 'tiles' ? 'Azulejos' : 'Yeso/Liso';
                    final textureIcon = activeTexture == 'tiles' ? '🔲' : '🧱';

                    return GestureDetector(
                      onTap: () {
                        if (_interiorWallEditTool == InteriorWallEditTool.allWalls) {
                          final count = _roomGame.applyStyleToAllInteriorWalls(styleOpt);
                          setState(() {});
                          _showTopNotification(count > 0 ? '✨ ¡$count muros actualizados a "$textureLabel ${colorOpt.name}"!' : 'No hay muros sólidos para pintar.');
                        } else if (_interiorWallEditTool == InteriorWallEditTool.brush) {
                          setState(() {
                            _selectedZoneWallId = styleId;
                            _roomGame.setWallBrush(styleId);
                          });
                          _showTopNotification('🖌️ Pincel: $textureLabel ${colorOpt.name}. ¡Toca muros para pintarlos!');
                        } else {
                          _roomGame.addInteriorWallFromStyle(styleOpt);
                          setState(() {});
                          _showTopNotification('¡$textureLabel ${colorOpt.name} añadido! Arrástralo a su posición.');
                        }
                      },
                      child: Container(
                        width: 90,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF282531),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF453F58),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    color: colorOpt.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white30, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colorOpt.color.withOpacity(0.4),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Text(textureIcon, style: const TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              colorOpt.name,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                )
              : ListView.builder(
                  key: const PageStorageKey('interior_walls_structural_scroll_list'),
                  scrollDirection: Axis.horizontal,
                  itemCount: InteriorWallStyles.structural.length,
                  itemBuilder: (context, index) {
                    final item = InteriorWallStyles.structural[index];
                    final isDoorway = item.isDoorway;
                    final isCardDisabled = _interiorWallEditTool == InteriorWallEditTool.allWalls && isDoorway;

                    return GestureDetector(
                      onTap: () {
                        if (_interiorWallEditTool == InteriorWallEditTool.allWalls) {
                          if (isDoorway) {
                            _showTopNotification('Los marcos de paso libre no se usan para pintar muros.');
                            return;
                          }
                          final count = _roomGame.applyStyleToAllInteriorWalls(item);
                          setState(() {});
                          _showTopNotification(count > 0 ? '✨ ¡$count muros actualizados a "${item.name}"!' : 'No hay muros sólidos para pintar.');
                        } else if (_interiorWallEditTool == InteriorWallEditTool.brush) {
                          setState(() {
                            _selectedZoneWallId = item.id;
                            _roomGame.setWallBrush(item.id);
                          });
                          _showTopNotification('🖌️ Pincel: ${item.name}. ¡Toca muros en el salón para cambiarlos!');
                        } else {
                          _roomGame.addInteriorWallFromStyle(item);
                          setState(() {});
                          _showTopNotification('¡${item.name} añadido! Arrástralo a su posición.');
                        }
                      },
                      child: Opacity(
                        opacity: isCardDisabled ? 0.35 : 1.0,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF282531),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCardDisabled
                                  ? Colors.white24
                                  : const Color(0xFFA78BFA).withOpacity(0.6),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(item.emoji, style: const TextStyle(fontSize: 20)),
                              const SizedBox(height: 2),
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isCardDisabled ? Colors.white54 : Colors.white,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isCardDisabled
                                    ? '🚫 No aplicable'
                                    : (item.isDoorway ? '🚪 Paso Libre' : '🧱 Muro Sólido'),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isCardDisabled
                                      ? Colors.white38
                                      : const Color(0xFFA78BFA),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildIdleActionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF24212D).withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF433E53)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Muros Toggle (Modo Zócalo)
          Material(
            color: _roomGame.wallsCut
                ? const Color(0xFF00E5FF).withOpacity(0.25)
                : const Color(0xFF1E1C27).withOpacity(0.85),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _roomGame.wallsCut ? const Color(0xFF00E5FF) : const Color(0xFF453F58),
                width: 1.2,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                _roomGame.toggleWallsCut();
                AvatarStorageService.saveUserRoomConfig(widget.activeUserId, _roomGame.roomConfig);
                setState(() {});
                _showTopNotification(_roomGame.wallsCut
                    ? '🚪 Muros bajos: mostrando zócalo'
                    : '🚪 Muros completos');
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _roomGame.wallsCut ? Icons.border_bottom_rounded : Icons.apartment_rounded,
                      color: _roomGame.wallsCut ? const Color(0xFF00E5FF) : Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _roomGame.wallsCut ? 'Zócalo' : 'Muros',
                      style: TextStyle(
                        color: _roomGame.wallsCut ? const Color(0xFF00E5FF) : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 2. Mi Hogar Menu (Decorar Muebles & Modo Constructor)
          PopupMenuButton<String>(
            tooltip: 'Diseñar Hogar',
            color: const Color(0xFF1E1B2E),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFFFB300), width: 1.2),
            ),
            onSelected: (val) {
              if (val == 'decorate') {
                _enterDecorateMode();
              } else if (val == 'construct') {
                _enterConstructorMode();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'decorate',
                child: Row(
                  children: [
                    Text('🎨 ', style: TextStyle(fontSize: 16)),
                    Text(
                      'Decorar Muebles',
                      style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              const PopupMenuItem(
                value: 'construct',
                child: Row(
                  children: [
                    Text('🔨 ', style: TextStyle(fontSize: 16)),
                    Text(
                      'Modo Constructor',
                      style: TextStyle(color: Color(0xFFFFB300), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C27).withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.8), width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🏡', style: TextStyle(fontSize: 14)),
                  SizedBox(width: 4),
                  Text('Mi Hogar', style: TextStyle(color: Color(0xFFFFD54F), fontWeight: FontWeight.bold, fontSize: 12)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, color: Color(0xFFFFD54F), size: 16),
                ],
              ),
            ),
          ),

          const Spacer(),

          // 3. Iniciar Cita Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6D00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 4,
            ),
            onPressed: _startMatchmaking,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Iniciar Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildQueuedCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1C24).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6D00), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6D00).withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFFFF6D00)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Buscando Pareja en la Mazmorra...',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
                Text(
                  'Santiago • Modo Voz • Sigue explorando tu cuarto',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: _cancelMatchmaking,
            child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Floats [child] directly over a point supplied by [anchor] — recomputed every frame so
/// it tracks the selected object as it's dragged or the camera zooms/pans. [anchor] returns
/// a point in the GameWidget's own coordinate space (which lines up 1:1 with this Stack).
/// The point marks where the *bottom-center* of [child] should sit, so the toolbar always
/// hovers just above whatever it's attached to.
class _FollowingOverlay extends StatefulWidget {
  final Vector2? Function() anchor;
  final Widget child;

  const _FollowingOverlay({required this.anchor, required this.child});

  @override
  State<_FollowingOverlay> createState() => _FollowingOverlayState();
}

class _FollowingOverlayState extends State<_FollowingOverlay> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.anchor();
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    // Only trust the anchor when it's a real, finite point — a stray NaN/Infinity (e.g. a
    // one-frame glitch mid-pan) must never reach Positioned/the canvas.
    final hasValidAnchor = anchor != null && anchor.x.isFinite && anchor.y.isFinite;

    // Worth showing only when the point is both valid and actually within the camera's
    // rendered viewport — otherwise the object has panned/zoomed out of view.
    final isOnScreen = hasValidAnchor && anchor.x >= 0 && anchor.x <= screenSize.width && anchor.y >= 0 && anchor.y <= screenSize.height;

    // Keep the toolbar clear of the header gradient and bottom decorator dock, and away
    // from the left/right edges. Falls back to screen-center (never NaN/Infinity) when the
    // anchor isn't valid — harmless since nothing is shown there in that case anyway.
    final maxX = screenSize.width > 180.0 ? screenSize.width - 90.0 : screenSize.width / 2;
    final minY = topPadding + 110.0;
    final maxY = screenSize.height > (topPadding + 320.0) ? screenSize.height - 210.0 : minY;
    final targetX = hasValidAnchor ? anchor.x.clamp(90.0, maxX) : screenSize.width / 2;
    final targetY = hasValidAnchor ? anchor.y.clamp(minY, maxY) : screenSize.height / 2;

    // The Stack's direct child is *always* this one Positioned — never swapped for a plain
    // SizedBox at this level — since alternating widget types there is what was actually
    // triggering the black-screen crash. Only the (interactive-or-not) content underneath
    // it changes, which is safe: fully present when on-screen (no IgnorePointer needed, so
    // the buttons work normally), or simply absent otherwise.
    return Positioned(
      left: targetX,
      top: targetY - 10,
      child: isOnScreen
          ? FractionalTranslation(
              translation: const Offset(-0.5, -1.0),
              child: widget.child,
            )
          : const SizedBox.shrink(),
    );
  }
}
