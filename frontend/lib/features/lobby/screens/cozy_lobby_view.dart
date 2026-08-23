import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flame/game.dart';
import '../../../core/models/avatar_config.dart';
import '../../../core/models/room_config.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../avatar/screens/character_creator_screen.dart';
import '../../game/bloc/game_bloc.dart';
import '../components/isometric_furniture_component.dart';
import '../components/isometric_interior_wall_component.dart';
import '../games/cozy_room_game.dart';
import 'room_decorator_sheet.dart';

class CozyLobbyView extends StatefulWidget {
  final String activeUserId;
  final ValueChanged<String> onUserChanged;
  final VoidCallback? onStartMatchmaking;

  const CozyLobbyView({
    super.key,
    required this.activeUserId,
    required this.onUserChanged,
    this.onStartMatchmaking,
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

class _CozyLobbyViewState extends State<CozyLobbyView> {
  late CozyRoomGame _roomGame;
  late AvatarConfig _currentAvatarConfig;
  late RoomConfig _currentRoomConfig;

  bool _isDecorating = false;
  IsometricFurnitureComponent? _selectedFurniture;
  IsometricInteriorWallComponent? _selectedInteriorWall;
  final Map<int, Offset> _pointerPositions = {};
  double? _initialPinchDistance;
  double? _initialPinchZoom;
  Offset? _lastSinglePointerPos;
  Offset? _singleTapStartOffset;
  DateTime? _singleTapStartTime;

  @override
  void initState() {
    super.initState();
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
            _roomGame.updateAvatarConfig(newConfig);
            setState(() {
              _currentAvatarConfig = newConfig;
            });
          },
        ),
      ),
    );
  }

  void _enterDecorateMode() {
    setState(() {
      _isDecorating = true;
      _roomGame.setDecorateMode(true);
      _selectedFurniture = null;
      _selectedInteriorWall = null;
    });
  }

  void _saveAndExitDecorateMode() {
    final updatedConfig = _roomGame.exportCurrentRoomConfig();
    AvatarStorageService.saveUserRoomConfig(widget.activeUserId, updatedConfig);
    setState(() {
      _currentRoomConfig = updatedConfig;
      _isDecorating = false;
      _roomGame.setDecorateMode(false);
      _selectedFurniture = null;
      _selectedInteriorWall = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ ¡Decoración guardada exitosamente!'),
        backgroundColor: Color(0xFF282531),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _cancelDecorateMode() {
    _roomGame.updateRoomConfig(_currentRoomConfig);
    setState(() {
      _isDecorating = false;
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
            socketUrl: 'ws://localhost:8080/game',
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
                      ? _buildDecorateTopBar()
                      : _buildNormalTopBar(selectedDropdownValue),
                ),
              ),

              // 3. Floating Selected Furniture Action Toolbar — hovers right above the
              // selected object in the isometric world (Only in Decorate Mode)
              if (_isDecorating && _selectedFurniture != null && _selectedFurniture!.type != FurnitureType.portal)
                _FollowingOverlay(
                  anchor: () => _roomGame.getSelectedFurnitureAnchor(),
                  child: _buildSelectedFurnitureToolbar(),
                ),

              // 4. Floating Selected Interior Wall Action Toolbar — hovers right above
              // the selected wall (Only in Decorate Mode)
              if (_isDecorating && _selectedInteriorWall != null)
                _FollowingOverlay(
                  anchor: () => _roomGame.getSelectedInteriorWallAnchor(),
                  child: _buildSelectedInteriorWallToolbar(),
                ),

              // 5. Bottom Docked Overlay (Normal Mode or Decorator Toolbar)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _isDecorating
                    ? _buildDecorateBottomBar(context)
                    : Padding(
                        padding: EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: MediaQuery.of(context).padding.bottom + 12,
                        ),
                        child: isQueued ? _buildQueuedCard() : _buildIdleActionCard(),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNormalTopBar(String selectedDropdownValue) {
    return Row(
      children: [
        // User Profile Mocking Dropdown (Flexible with isExpanded so it never overflows)
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF282531).withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
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
                  fontSize: 13,
                ),
                items: CozyLobbyView.defaultUsers.map((user) {
                  return DropdownMenuItem<String>(
                    value: user['id'],
                    child: Text(
                      user['name']!,
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
        const SizedBox(width: 8),

        // Action Buttons (Decorar Habitación & Armario)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF282531).withOpacity(0.9),
            foregroundColor: const Color(0xFF00E5FF),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: _enterDecorateMode,
          icon: const Text('🎨', style: TextStyle(fontSize: 14)),
          label: const Text('Decorar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
        const SizedBox(width: 6),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF282531).withOpacity(0.9),
            foregroundColor: const Color(0xFFFFD54F),
            side: const BorderSide(color: Color(0xFFFFD54F), width: 1.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: _openWardrobe,
          icon: const Text('🪞', style: TextStyle(fontSize: 14)),
          label: const Text('Armario', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildDecorateTopBar() {
    final currentRes = _roomGame.roomConfig.resolution;
    // Scrolls horizontally instead of overflowing on narrow phones — the three groups
    // below (badge, resolution switcher, save/cancel) don't always fit a mobile width.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
        // Active Decorate Mode Indicator Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6D00).withOpacity(0.25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFF6D00), width: 1.5),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎨', style: TextStyle(fontSize: 14)),
              SizedBox(width: 6),
              Text(
                'DECORAR',
                style: TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Resolution Switcher (64x128 HD / 32x64 Retro Pixel)
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1C27),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF453F58)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  _roomGame.updateResolution('64x128');
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentRes == '64x128' ? const Color(0xFF2563EB) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '64x128 HD',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: currentRes == '64x128' ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _roomGame.updateResolution('32x64');
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentRes == '32x64' ? const Color(0xFF8B5CF6) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '32x64 Retro',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: currentRes == '32x64' ? Colors.white : Colors.white60,
                    ),
                  ),
                ),
              ),
            ],
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
      padding: EdgeInsets.only(top: 8, bottom: bottomInset + 12, left: 16, right: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1C27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF453F58), width: 2)),
      ),
      child: DefaultTabController(
        length: 3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TabBar(
              indicatorColor: Color(0xFFFFD54F),
              labelColor: Color(0xFFFFD54F),
              unselectedLabelColor: Colors.white60,
              labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              tabs: [
                Tab(text: '🛋️ Muebles'),
                Tab(text: '🧱 Paredes'),
                Tab(text: '🪵 Pisos'),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: TabBarView(
                children: [
                  _buildFurnitureCategoriesSelector(),
                  _buildWallpaperSelector(),
                  _buildFloorSelector(),
                ],
              ),
            ),
          ],
        ),
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
      scrollDirection: Axis.horizontal,
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return GestureDetector(
          onTap: () {
            RoomDecoratorSheet.show(
              context,
              initialConfig: _roomGame.roomConfig,
              initialCategory: cat['id']!,
              onConfigChanged: (cfg) {
                _roomGame.updateRoomConfig(cfg);
                setState(() {});
              },
              onSave: (cfg) {
                _roomGame.updateRoomConfig(cfg);
                setState(() {});
              },
              onAddFurniture: (item) {
                _roomGame.addFurnitureFromCatalog(item);
              },
              onAddInteriorWall: (styleOption) {
                _roomGame.addInteriorWallFromStyle(styleOption);
              },
            );
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
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: RoomThemes.wallpapers.length,
      itemBuilder: (context, index) {
        final item = RoomThemes.wallpapers[index];
        final isSelected = _roomGame.roomConfig.wallpaper == item.id;
        return GestureDetector(
          onTap: () {
            final updated = _roomGame.roomConfig.copyWith(wallpaper: item.id);
            _roomGame.updateRoomConfig(updated);
            setState(() {});
          },
          child: Container(
            width: 100,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF383247) : const Color(0xFF282531),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFF453F58),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
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
    );
  }

  Widget _buildFloorSelector() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: RoomThemes.floors.length,
      itemBuilder: (context, index) {
        final item = RoomThemes.floors[index];
        final isSelected = _roomGame.roomConfig.floor == item.id;
        return GestureDetector(
          onTap: () {
            final updated = _roomGame.roomConfig.copyWith(floor: item.id);
            _roomGame.updateRoomConfig(updated);
            setState(() {});
          },
          child: Container(
            width: 100,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF383247) : const Color(0xFF282531),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? const Color(0xFFFFD54F) : const Color(0xFF453F58),
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFFFFD54F) : Colors.white,
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
    );
  }

  Widget _buildIdleActionCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF24212D).withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
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
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Habitación Cozy (Lobby)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                ),
                Text(
                  'Toca el suelo para caminar • Pulsa "Decorar" para editar tu habitación',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6D00),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
