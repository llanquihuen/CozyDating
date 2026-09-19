import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'core/config/app_config.dart';
import 'core/models/avatar_config.dart';
import 'core/models/game_models.dart';
import 'core/models/room_config.dart';
import 'core/models/user_profile.dart';
import 'core/network/websocket_client.dart';
import 'core/services/auth_service.dart';
import 'core/services/avatar_storage_service.dart';
import 'features/auth/screens/welcome_screen.dart';
import 'features/campfire/screens/campfire_view.dart';
import 'features/chat/services/chat_service.dart';
import 'features/chat/widgets/global_date_invite_overlay.dart';
import 'features/game/bloc/game_bloc.dart';
import 'features/game/game_view.dart';
import 'features/game/guide_game_view.dart';
import 'features/game/screens/dungeon_match_intro_view.dart';
import 'features/game/widgets/dungeon_defeat_dialog.dart';
import 'features/game/widgets/dungeon_victory_dialog.dart';
import 'features/home_visit/screens/home_visit_view.dart';
import 'features/lobby/screens/cozy_lobby_view.dart';
import 'features/mailbox/services/mailbox_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final webSocketClient = WebSocketClient();
  runApp(MyApp(webSocketClient: webSocketClient));
}

class MyApp extends StatelessWidget {
  final WebSocketClient webSocketClient;

  const MyApp({super.key, required this.webSocketClient});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => GameBloc(webSocketClient: webSocketClient),
      child: MaterialApp(
        title: 'Cozy Slow Dating',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        builder: (context, child) => GlobalDateInviteOverlay(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const GameLauncherScreen(),
      ),
    );
  }
}

class GameLauncherScreen extends StatefulWidget {
  const GameLauncherScreen({super.key});

  @override
  State<GameLauncherScreen> createState() => _GameLauncherScreenState();
}

class _GameLauncherScreenState extends State<GameLauncherScreen> with WidgetsBindingObserver {
  String _selectedUserId = 'alice';
  String? _introCompletedRoomId;
  String? _victoryShownRoomId;

  bool _isMatchmakingRequestInFlight = false;
  DateTime? _pausedAt;
  bool _showingQueuePausedDialog = false;

  String get _baseUrl => AppConfig.baseUrl;
  String get _wsUrl => AppConfig.wsUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AuthService.isAuthenticated) {
      _selectedUserId = AuthService.currentUser!.id;
      ChatService.ensureConnected();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('[APP LIFECYCLE] AppLifecycleState changed to: $state');
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _pausedAt = DateTime.now();
      WebSocketClient.shared?.onAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      final pausedTime = _pausedAt;
      _pausedAt = null;
      WebSocketClient.shared?.onAppResumed();

      if (AuthService.isAuthenticated) {
        ChatService.ensureConnected();
      }

      // Check if user was searching for a match when they left
      if (mounted) {
        final currentGameState = context.read<GameBloc>().state;
        if (currentGameState is MatchmakingQueueState && pausedTime != null) {
          final awaySeconds = DateTime.now().difference(pausedTime).inSeconds;
          print('[APP LIFECYCLE] Returned from background while searching for match. Away for $awaySeconds seconds.');
          if (awaySeconds > 60 && !_showingQueuePausedDialog) {
            _handleMatchmakingAwayPause(context);
          }
        }
      }
    }
  }

  void _handleMatchmakingAwayPause(BuildContext context) {
    _showingQueuePausedDialog = true;
    context.read<GameBloc>().add(const ResetGameEvent());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.pause_circle_outline_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Búsqueda en Pausa',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Pausamos la búsqueda de citas mientras no estabas para que no te perdieras el inicio de la mazmorra.\n\n¿Deseas reanudar la búsqueda ahora?',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showingQueuePausedDialog = false;
            },
            child: const Text('Quedarme en el Lobby', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showingQueuePausedDialog = false;
              _startMatchmaking(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reanudar búsqueda'),
          ),
        ],
      ),
    );
  }

  Future<void> _startMatchmaking(BuildContext context) async {
    if (_isMatchmakingRequestInFlight) return;
    final currentGameState = context.read<GameBloc>().state;
    if (currentGameState is MatchmakingQueueState) return;

    _isMatchmakingRequestInFlight = true;
    try {
      String token;
      String userId;

      if (AuthService.isAuthenticated && AuthService.token != null) {
        token = AuthService.token!;
        userId = AuthService.currentUser!.id;
      } else {
        final result = await AuthService.loginTestUser(_selectedUserId);
        if (result.success && AuthService.token != null) {
          token = AuthService.token!;
          userId = AuthService.currentUser!.id;
        } else {
          final response = await http.get(
            Uri.parse('$_baseUrl/auth/token?userId=$_selectedUserId'),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            token = data['token'];
            userId = data['userId'] ?? _selectedUserId;
          } else {
            if (mounted) {
              _showErrorSnackBar(context, 'Error de autenticación (${response.statusCode})');
            }
            return;
          }
        }
      }

      if (AuthService.currentUser != null && !AuthService.currentUser!.isVerified) {
        if (mounted) {
          _showUnverifiedDialog(context);
        }
        return;
      }

      if (mounted) {
        context.read<GameBloc>().add(JoinQueueEvent(
              socketUrl: _wsUrl,
              token: token,
              commune: AuthService.currentUser?.commune ?? 'PROVINCIA',
              timeSlot: 'SLOT_2000',
              mode: 'STANDARD',
            ));
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(context, 'Error al conectar con matchmaking: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMatchmakingRequestInFlight = false;
        });
      } else {
        _isMatchmakingRequestInFlight = false;
      }
    }
  }

  void _showUnverifiedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 26),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Identidad Sin Certificar',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Aquí nos cuidamos entre todos. Para que cada cita sea segura y con personas 100% reales, verificamos cada perfil con una selfie rápida. ¡Solo te tomará un minuto!',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (context, state) {
        if (state is ErrorGameState) {
          _showErrorSnackBar(context, state.message);
        }
        if ((state is GameInitialState || state is TerminatedGameState) && !_isMatchmakingRequestInFlight) {
          _introCompletedRoomId = null;
          if (AuthService.isAuthenticated) {
            ChatService.ensureConnected();
          }
        }
      },
      builder: (context, state) {
        if (state is ActiveGameState) {
          // Si la fogata está activa, renderizarla directamente
          if (state.isCampfireActive || state.isDungeonFailed) {
            final localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
            final localTastes = (AuthService.currentUser?.tastes != null && AuthService.currentUser!.tastes.isNotEmpty)
                ? AuthService.currentUser!.tastes
                : AvatarStorageService.getUserTastes(localUserId);

            final localUsername = AuthService.currentUser?.username ?? 'Tú';
            final localProfile = AuthService.currentUser?.copyWith(tastes: localTastes) ??
                UserProfile(
                  id: localUserId,
                  username: localUsername,
                  avatarConfig: AvatarStorageService.getUserConfig(localUserId),
                  roomConfig: AvatarStorageService.getUserRoomConfig(localUserId),
                  tastes: localTastes,
                );

            var partnerId = state.session.partnerId;
            var partnerName = state.partnerUsername ?? state.session.partnerUsername;

            // Defensive resolution: partner must never be the local user
            if (partnerId.isEmpty || partnerId == localUserId) {
              partnerId = (localUserId == 'userA' || localUserId == 'alice') ? 'userB' : 'userA';
            }
            if (partnerName == null || partnerName.isEmpty || partnerName == localUsername || partnerName == 'Tú') {
              partnerName = (localUserId == 'userA' || localUserId == 'alice') ? 'Bob' : 'Alice';
            }

            final partnerTastes = (state.partnerTastes != null && state.partnerTastes!.isNotEmpty)
                ? state.partnerTastes!
                : (state.session.partnerTastes.isNotEmpty
                    ? state.session.partnerTastes
                    : AvatarStorageService.getUserTastes(partnerId));

            final partnerProfile = UserProfile(
              id: partnerId,
              username: partnerName,
              avatarConfig: state.partnerAvatarConfig ?? state.session.partnerAvatarConfig ?? AvatarStorageService.getUserConfig(partnerId),
              roomConfig: state.partnerRoomConfig ?? state.session.partnerRoomConfig ?? AvatarStorageService.getUserRoomConfig(partnerId),
              tastes: partnerTastes,
            );

            // Celebrar victoria o consuelo de derrota de mazmorra antes de pasar a la fogata
            if (_victoryShownRoomId != state.session.roomId) {
              return Scaffold(
                backgroundColor: const Color(0xFF0F172A),
                body: state.isDungeonFailed
                    ? DungeonDefeatDialog(
                        localAvatar: localProfile.avatarConfig,
                        partnerAvatar: partnerProfile.avatarConfig,
                        partnerName: partnerName,
                        defeatTitle: state.dungeonLives <= 0
                            ? '¡SE AGOTARON LAS VIDAS!'
                            : '¡SE APAGÓ LA LINTERNA!',
                        defeatSubtitle: state.dungeonLives <= 0
                            ? 'Las trampas y púas agotaron los corazones de la expedición'
                            : 'El laberinto se cerró por hoy con $partnerName',
                        onProceedToCampfire: () {
                          setState(() {
                            _victoryShownRoomId = state.session.roomId;
                          });
                        },
                      )
                    : DungeonVictoryDialog(
                        localAvatar: localProfile.avatarConfig,
                        partnerAvatar: partnerProfile.avatarConfig,
                        partnerName: partnerName,
                        onProceedToCampfire: () {
                          setState(() {
                            _victoryShownRoomId = state.session.roomId;
                          });
                        },
                      ),
              );
            }

            return CampfireView(
              key: ValueKey('campfire_${state.session.roomId}'),
              localUser: localProfile,
              partnerUser: partnerProfile,
              partnerName: partnerName,
              partnerAvatarConfig: partnerProfile.avatarConfig,
              seed: state.session.seed,
              roomId: state.session.roomId,
              onReturnHome: () {
                context.read<GameBloc>().add(const ResetGameEvent());
              },
            );
          }

          // Si la cita de Visita al Hogar está activa, renderizar HomeVisitView
          if (state.isHomeVisitActive || state.session.mode == 'HOME') {
            final localUserId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
            final localUsername = AuthService.currentUser?.username ?? 'Tú';
            final localProfile = AuthService.currentUser ??
                UserProfile(
                  id: localUserId,
                  username: localUsername,
                  avatarConfig: AvatarStorageService.getUserConfig(localUserId),
                  roomConfig: AvatarStorageService.getUserRoomConfig(localUserId),
                );

            var partnerId = state.session.partnerId;
            var partnerName = state.partnerUsername ?? state.session.partnerUsername;
            if (partnerId.isEmpty || partnerId == localUserId) {
              partnerId = (localUserId == 'userA' || localUserId == 'alice') ? 'userB' : 'userA';
            }
            if (partnerName == null || partnerName.isEmpty || partnerName == localUsername || partnerName == 'Tú') {
              partnerName = (localUserId == 'userA' || localUserId == 'alice') ? 'Bob' : 'Alice';
            }

            final partnerProfile = UserProfile(
              id: partnerId,
              username: partnerName,
              avatarConfig: state.partnerAvatarConfig ?? state.session.partnerAvatarConfig ?? AvatarStorageService.getUserConfig(partnerId),
              roomConfig: state.partnerRoomConfig ?? state.session.partnerRoomConfig ?? AvatarStorageService.getUserRoomConfig(partnerId),
            );

            // Determinar si el anfitrión es el usuario local o el compañero
            final hostId = state.hostUserId ?? state.session.hostUserId ?? state.session.partnerId;
            final isLocalHost = hostId == localUserId;
            final hostName = isLocalHost ? localUsername : partnerName;
            final hostRoomConfig = isLocalHost ? localProfile.roomConfig : partnerProfile.roomConfig;

            return HomeVisitView(
              key: ValueKey('home_visit_${state.session.roomId}'),
              localUser: localProfile,
              partnerUser: partnerProfile,
              isHost: isLocalHost,
              hostName: hostName,
              hostRoomConfig: hostRoomConfig,
              onLeave: () {
                context.read<GameBloc>().add(const ResetGameEvent());
              },
            );
          }

          // Si no ha completado la pantalla de match intro para esta sala, mostrarla
          if (_introCompletedRoomId != state.session.roomId) {
            return DungeonMatchIntroView(
              key: ValueKey('match_intro_${state.session.roomId}_act${state.session.act}'),
              state: state,
              onStartGame: () {
                setState(() {
                  _introCompletedRoomId = state.session.roomId;
                });
              },
            );
          }

          final isExplorer = state.session.role == 'EXPLORER';
          if (isExplorer) {
            return GameView(
              key: ValueKey('explorer_${state.session.roomId}_${state.session.role}_act${state.session.act}'),
              state: state,
            );
          } else {
            return GuideGameView(
              key: ValueKey('guide_${state.session.roomId}_${state.session.role}_act${state.session.act}'),
              state: state,
            );
          }
        }

        // If not authenticated and in initial state, show Welcome Screen
        if (!AuthService.isAuthenticated && state is GameInitialState) {
          return WelcomeScreen(
            onAuthenticated: () {
              setState(() {
                _selectedUserId = AuthService.currentUser!.id;
              });
              ChatService.ensureConnected();
            },
          );
        }

        if (state is GameInitialState || state is MatchmakingQueueState) {
          return CozyLobbyView(
            key: ValueKey('lobby_${AuthService.currentUser?.id ?? _selectedUserId}'),
            activeUserId: AuthService.currentUser?.id ?? _selectedUserId,
            onUserChanged: (newId) async {
              MailboxService.clear();
              setState(() {
                _selectedUserId = newId;
                AvatarStorageService.setActiveUser(newId);
              });
              await AuthService.loginTestUser(newId);
              await ChatService.reconnectAsUser(newId);
            },
            onLogout: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
              ChatService.resetSession();
              context.read<GameBloc>().add(const ResetGameEvent());
              AuthService.logout();
              MailboxService.clear();
              WebSocketClient.shared?.disconnect();
              setState(() {});
            },
            onStartMatchmaking: () => _startMatchmaking(context),
          );
        }

        if (state is ErrorGameState) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F172A),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFF87171), size: 48),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Aviso de Conexión',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            context.read<GameBloc>().add(const ResetGameEvent());
                            if (AuthService.isAuthenticated) {
                              ChatService.ensureConnected();
                            }
                          },
                          icon: const Icon(Icons.home_rounded),
                          label: const Text('Volver al Lobby'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Color(0xFF475569)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final success = await (WebSocketClient.shared?.reconnectNow() ?? Future.value(false));
                            if (success && context.mounted) {
                              context.read<GameBloc>().add(const ResetGameEvent());
                              ChatService.ensureConnected();
                            }
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reintentar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE07A5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Cozy Slow Dating'),
            centerTitle: true,
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _buildBody(context, state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, GameState state) {
    if (state is MatchmakingQueueState) {
      return _buildQueueCard(context, state);
    }

    if (state is PausedGameState) {
      return _PausedGameCard(session: state.session, reason: state.reason);
    }

    if (state is TerminatedGameState) {
      return _buildTerminatedCard(context, state.reason);
    }

    return const SizedBox.shrink();
  }

  Widget _buildQueueCard(BuildContext context, MatchmakingQueueState state) {
    return Card(
      elevation: 4,
      color: const Color(0xFF1E1C27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFB300)),
            const SizedBox(height: 16),
            const Text(
              'Buscando Pareja...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Esperando en la cola de matchmaking (${state.mode}).',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                context.read<GameBloc>().add(const ResetGameEvent());
              },
              child: const Text('Cancelar Búsqueda'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminatedCard(BuildContext context, String reason) {
    return Card(
      elevation: 4,
      color: const Color(0xFF1E1C27),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Partida Finalizada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              reason,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              onPressed: () {
                context.read<GameBloc>().add(const ResetGameEvent());
              },
              child: const Text('Volver al Menú Principal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PausedGameCard extends StatefulWidget {
  final SessionInitPayload session;
  final String reason;

  const _PausedGameCard({required this.session, required this.reason});

  @override
  State<_PausedGameCard> createState() => _PausedGameCardState();
}

class _PausedGameCardState extends State<_PausedGameCard> {
  int _secondsLeft = 20;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsLeft > 1) {
            _secondsLeft--;
          } else {
            _countdownTimer?.cancel();
            context.read<GameBloc>().add(const ResetGameEvent());
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              'Partida Pausada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.reason,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            Text(
              'Reconectando automáticamente... ($_secondsLeft s)',
              style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              onPressed: () {
                context.read<GameBloc>().add(const SendEmergencyDisconnectEvent(shouldBlock: false));
              },
              child: const Text('Salir de la Partida'),
            ),
          ],
        ),
      ),
    );
  }
}
