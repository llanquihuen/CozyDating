import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'core/models/game_models.dart';
import 'core/network/websocket_client.dart';
import 'core/services/avatar_storage_service.dart';
import 'features/avatar/screens/character_creator_screen.dart';
import 'features/game/bloc/game_bloc.dart';
import 'features/game/game_view.dart';
import 'features/game/guide_game_view.dart';
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
  final String _serverHost = kIsWeb
      ? 'localhost'
      : (Platform.isAndroid ? '10.0.2.2' : 'localhost');
  final int _serverPort = 8080;

  String _selectedUserId = 'alice';
  int _currentTicketBalance = 5;
  bool _isFetchingBalance = false;

  final List<Map<String, String>> _users = const [
    {'id': 'alice', 'name': 'Alice (Explorer)'},
    {'id': 'bob', 'name': 'Bob (Explorer)'},
    {'id': 'charlie', 'name': 'Charlie (Guide)'},
    {'id': 'david', 'name': 'David (Guide)'},
  ];

  bool _isAuthenticating = false;
  String? _jwtToken;

  String get _baseUrl => 'http://$_serverHost:$_serverPort';
  String get _wsUrl => 'ws://$_serverHost:$_serverPort/game';

  @override
  void initState() {
    super.initState();
    _fetchUserBalance(_selectedUserId);
  }

  Future<void> _fetchUserBalance(String userId) async {
    setState(() {
      _isFetchingBalance = true;
    });
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/balance?userId=$userId'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _currentTicketBalance = data['ticketsBalance'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('[BALANCE FETCH ERROR] Could not fetch balance for $userId: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingBalance = false;
        });
      }
    }
  }

  Future<void> _resetAllVoiceTickets(BuildContext context) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/unblock-all'),
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Partidas de voz restablecidas para todos los usuarios!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchUserBalance(_selectedUserId);
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error resetting tickets: $e');
    }
  }

  Future<void> _loginAndAuthenticate(BuildContext context) async {
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/auth/token?userId=$_selectedUserId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _jwtToken = data['token'];
        if (data['ticketsBalance'] != null) {
          setState(() {
            _currentTicketBalance = data['ticketsBalance'];
          });
        }
        print('[AUTH SUCCESS] Obtained JWT for $_selectedUserId: $_jwtToken');

        if (mounted && _jwtToken != null) {
          context.read<GameBloc>().add(JoinQueueEvent(
                socketUrl: _wsUrl,
                token: _jwtToken!,
                commune: 'PROVINCIA',
                timeSlot: 'SLOT_2000',
                mode: 'STANDARD',
              ));
        }
      } else {
        _showErrorSnackBar(context, 'Auth Failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      _showErrorSnackBar(context, 'Error connecting to backend auth: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
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
      },
      builder: (context, state) {
        if (state is ActiveGameState) {
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

        if (state is GameInitialState || state is MatchmakingQueueState) {
          return CozyLobbyView(
            key: ValueKey('lobby_$_selectedUserId'),
            activeUserId: _selectedUserId,
            onUserChanged: (newId) {
              setState(() {
                _selectedUserId = newId;
                AvatarStorageService.setActiveUser(newId);
                _fetchUserBalance(newId);
              });
            },
            onStartMatchmaking: () => _loginAndAuthenticate(context),
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
    if (state is GameInitialState) {
      return _buildLoginSelector(context);
    }

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

  Widget _buildLoginSelector(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.favorite_rounded, color: Colors.deepOrange, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Cozy Dungeon Dating',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecciona un usuario de prueba para autenticarte e ingresar a la cola de matchmaking.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // User Dropdown Selection
            DropdownButtonFormField<String>(
              value: _selectedUserId,
              decoration: const InputDecoration(
                labelText: 'Usuario de prueba',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              items: _users.map((u) {
                return DropdownMenuItem<String>(
                  value: u['id'],
                  child: Text(u['name']!),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedUserId = val;
                  });
                  _fetchUserBalance(val);
                }
              },
            ),
            const SizedBox(height: 16),
            // Voice Match Ticket Balance Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _currentTicketBalance > 0
                    ? Colors.teal.withOpacity(0.2)
                    : Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _currentTicketBalance > 0 ? Colors.tealAccent : Colors.redAccent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.mic,
                        color: _currentTicketBalance > 0 ? Colors.tealAccent : Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Partidas de Voz:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  _isFetchingBalance
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          '$_currentTicketBalance Disponibles',
                          style: TextStyle(
                            color: _currentTicketBalance > 0 ? Colors.tealAccent : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Button to Reset All Voice Matches
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: Colors.amber.shade700),
              ),
              onPressed: () => _resetAllVoiceTickets(context),
              icon: const Icon(Icons.refresh, color: Colors.amberAccent, size: 18),
              label: const Text(
                '🔄 Restablecer Partidas de Voz de Todos',
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: const Color(0xFFFFD54F),
                side: const BorderSide(color: Color(0xFFFFD54F), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CharacterCreatorScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.face_retouching_natural),
              label: const Text('Personalizar Avatar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isAuthenticating ? null : () => _loginAndAuthenticate(context),
              icon: _isAuthenticating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isAuthenticating ? 'Conectando...' : 'Iniciar Matchmaking'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueCard(BuildContext context, MatchmakingQueueState state) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.deepOrange),
            const SizedBox(height: 16),
            const Text(
              'Buscando Pareja...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Partida Finalizada',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
