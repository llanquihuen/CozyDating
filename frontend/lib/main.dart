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
import 'features/home_visit/screens/home_visit_view.dart';
import 'features/lobby/screens/cozy_lobby_view.dart';

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

class _GameLauncherScreenState extends State<GameLauncherScreen> {
  String _selectedUserId = 'alice';
  String? _introCompletedRoomId;

  String get _baseUrl => AppConfig.baseUrl;
  String get _wsUrl => AppConfig.wsUrl;

  @override
  void initState() {
    super.initState();
    if (AuthService.isAuthenticated) {
      _selectedUserId = AuthService.currentUser!.id;
      ChatService.ensureConnected();
    }
  }

  Future<void> _startMatchmaking(BuildContext context) async {
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
    }
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
        if (state is GameInitialState || state is TerminatedGameState) {
          _introCompletedRoomId = null;
          if (AuthService.isAuthenticated) {
            ChatService.ensureConnected();
          }
        }
      },
      builder: (context, state) {
        if (state is ActiveGameState) {
          // Si la fogata está activa, renderizarla directamente
          if (state.isCampfireActive) {
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
              setState(() {
                _selectedUserId = newId;
                AvatarStorageService.setActiveUser(newId);
              });
              await AuthService.loginTestUser(newId);
              await ChatService.reconnectAsUser(newId);
            },
            onLogout: () {
              setState(() {
                AuthService.logout();
                WebSocketClient.shared?.disconnect();
              });
            },
            onStartMatchmaking: () => _startMatchmaking(context),
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
