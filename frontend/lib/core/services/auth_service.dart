import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/avatar_config.dart';
import '../models/room_config.dart';
import '../models/user_profile.dart';
import 'avatar_storage_service.dart';

class AuthService {
  static String? _token;
  static UserProfile? _currentUser;

  static String? get token => _token;
  static UserProfile? get currentUser => _currentUser;
  static bool get isAuthenticated => _token != null && _currentUser != null;

  static String get _baseUrl => AppConfig.baseUrl;

  /// Register a new user with avatar, tastes and customized initial room
  static Future<AuthResult> register({
    required String username,
    required String password,
    String? email,
    required int age,
    required String commune,
    required AvatarConfig avatarConfig,
    required List<String> tastes,
    required RoomConfig roomConfig,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/auth/register');
      final payload = {
        'username': username,
        'password': password,
        'email': email,
        'age': age,
        'commune': commune,
        'avatarConfig': avatarConfig.toJson(),
        'tastes': jsonEncode(tastes),
        'roomConfig': roomConfig.toJson(),
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        if (data['user'] != null) {
          _currentUser = UserProfile.fromMap(data['user']);
          // Sync local active memory
          AvatarStorageService.setActiveUser(_currentUser!.id);
          AvatarStorageService.saveUserConfig(_currentUser!.id, _currentUser!.avatarConfig);
          AvatarStorageService.saveUserRoomConfig(_currentUser!.id, _currentUser!.roomConfig);
          if (_currentUser!.tastes.isNotEmpty) {
            AvatarStorageService.saveUserTastes(_currentUser!.id, _currentUser!.tastes);
          }
        }
        return AuthResult(success: true, user: _currentUser, token: _token);
      } else {
        String errorMsg = 'Error en registro (${response.statusCode})';
        try {
          final errData = jsonDecode(response.body);
          if (errData['error'] != null) errorMsg = errData['error'];
        } catch (_) {}
        return AuthResult(success: false, errorMessage: errorMsg);
      }
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Error de conexión con el servidor: $e');
    }
  }

  /// Login with username / email and password
  static Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/auth/login');
      final payload = {
        'username': username,
        'password': password,
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        if (data['user'] != null) {
          _currentUser = UserProfile.fromMap(data['user']);
          if (_currentUser!.tastes.isEmpty) {
            final fallbackTastes = AvatarStorageService.getUserTastes(_currentUser!.id);
            _currentUser = _currentUser!.copyWith(tastes: fallbackTastes);
          } else {
            AvatarStorageService.saveUserTastes(_currentUser!.id, _currentUser!.tastes);
          }
          AvatarStorageService.setActiveUser(_currentUser!.id);
          AvatarStorageService.saveUserConfig(_currentUser!.id, _currentUser!.avatarConfig);
          AvatarStorageService.saveUserRoomConfig(_currentUser!.id, _currentUser!.roomConfig);
        }
        return AuthResult(success: true, user: _currentUser, token: _token);
      } else {
        String errorMsg = 'Error al iniciar sesión';
        try {
          final errData = jsonDecode(response.body);
          if (errData['error'] != null) errorMsg = errData['error'];
        } catch (_) {}
        return AuthResult(success: false, errorMessage: errorMsg);
      }
    } catch (e) {
      return AuthResult(success: false, errorMessage: 'Error de conexión: $e');
    }
  }

  /// Quick login for test accounts (Alice, Bob, etc.)
  static Future<AuthResult> loginTestUser(String testUserId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/auth/token?userId=$testUserId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        if (data['user'] != null) {
          _currentUser = UserProfile.fromMap(data['user']);
          if (_currentUser!.tastes.isEmpty) {
            final fallbackTastes = AvatarStorageService.getUserTastes(_currentUser!.id);
            _currentUser = _currentUser!.copyWith(tastes: fallbackTastes);
          } else {
            AvatarStorageService.saveUserTastes(_currentUser!.id, _currentUser!.tastes);
          }
        } else {
          final localTastes = AvatarStorageService.getUserTastes(testUserId);
          _currentUser = UserProfile(
            id: data['userId'] ?? testUserId,
            username: testUserId,
            ticketsBalance: data['ticketsBalance'] ?? 5,
            avatarConfig: AvatarStorageService.getUserConfig(testUserId),
            roomConfig: AvatarStorageService.getUserRoomConfig(testUserId),
            tastes: localTastes,
          );
        }
        AvatarStorageService.setActiveUser(_currentUser!.id);
        AvatarStorageService.saveUserConfig(_currentUser!.id, _currentUser!.avatarConfig);
        AvatarStorageService.saveUserRoomConfig(_currentUser!.id, _currentUser!.roomConfig);
        AvatarStorageService.saveUserTastes(_currentUser!.id, _currentUser!.tastes);
        return AuthResult(success: true, user: _currentUser, token: _token);
      }
      return AuthResult(success: false, errorMessage: 'Error al conectar usuario de prueba');
    } catch (e) {
      return AuthResult(success: false, errorMessage: '$e');
    }
  }

  /// Persist the RoomConfig to the backend database
  static Future<bool> saveRoomConfig(RoomConfig config) async {
    if (_currentUser == null) return false;
    final userId = _currentUser!.id;
    AvatarStorageService.saveUserRoomConfig(userId, config);

    try {
      final url = Uri.parse('$_baseUrl/api/user/room');
      final headers = {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
      final body = jsonEncode({
        'userId': userId,
        'roomConfig': config.toJson(),
      });

      final response = await http.put(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        _currentUser = _currentUser!.copyWith(roomConfig: config);
        return true;
      }
    } catch (e) {
      print('[ROOM SAVE ERROR] $e');
    }
    return false;
  }

  /// Persist the AvatarConfig to the backend database
  static Future<bool> saveAvatarConfig(AvatarConfig config) async {
    if (_currentUser == null) return false;
    final userId = _currentUser!.id;
    AvatarStorageService.saveUserConfig(userId, config);

    try {
      final url = Uri.parse('$_baseUrl/api/user/avatar');
      final headers = {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
      final body = jsonEncode({
        'userId': userId,
        'avatarConfig': config.toJson(),
      });

      final response = await http.put(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        _currentUser = _currentUser!.copyWith(avatarConfig: config);
        return true;
      }
    } catch (e) {
      print('[AVATAR SAVE ERROR] $e');
    }
    return false;
  }

  /// Update user taste preferences
  static Future<bool> updateTastes(List<String> tastes) async {
    if (_currentUser == null) return false;
    final userId = _currentUser!.id;
    _currentUser = _currentUser!.copyWith(tastes: tastes);
    AvatarStorageService.saveUserTastes(userId, tastes);

    try {
      final url = Uri.parse('$_baseUrl/auth/profile');
      final headers = {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
      final body = jsonEncode({
        'userId': userId,
        'tastes': jsonEncode(tastes),
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = UserProfile.fromMap(data);
        AvatarStorageService.saveUserTastes(userId, _currentUser!.tastes);
        return true;
      }
    } catch (e) {
      print('[TASTES SAVE ERROR] $e');
    }
    return false;
  }

  /// Update user real profile photo
  static Future<bool> updateProfilePhoto(String photo) async {
    if (_currentUser == null) return false;
    final userId = _currentUser!.id;
    _currentUser = _currentUser!.copyWith(profilePhoto: photo);
    AvatarStorageService.saveUserPhoto(userId, photo);

    try {
      final url = Uri.parse('$_baseUrl/auth/profile');
      final headers = {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };
      final body = jsonEncode({
        'userId': userId,
        'profilePhoto': photo,
      });

      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = UserProfile.fromMap(data);
        if (_currentUser!.profilePhoto != null) {
          AvatarStorageService.saveUserPhoto(userId, _currentUser!.profilePhoto!);
        }
        return true;
      }
    } catch (e) {
      print('[PHOTO SAVE ERROR] $e');
    }
    return false;
  }

  /// Fetch user ticket balance from backend
  static Future<int> fetchTicketBalance() async {
    if (_currentUser == null) return 0;
    try {
      final response = await http.get(Uri.parse('$_baseUrl/auth/balance?userId=${_currentUser!.id}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final balance = data['ticketsBalance'] ?? 0;
        _currentUser = _currentUser!.copyWith(ticketsBalance: balance);
        return balance;
      }
    } catch (_) {}
    return _currentUser!.ticketsBalance;
  }

  static void addCoins(int amount) {
    if (_currentUser != null) {
      final newBalance = _currentUser!.coinsBalance + amount;
      _currentUser = _currentUser!.copyWith(coinsBalance: newBalance);
      AvatarStorageService.addCoins(_currentUser!.id, amount);
    }
  }

  static void updateCurrentUser(UserProfile updated) {
    _currentUser = updated;
  }

  static void logout() {
    _token = null;
    _currentUser = null;
  }
}

class AuthResult {
  final bool success;
  final UserProfile? user;
  final String? token;
  final String? errorMessage;

  const AuthResult({
    required this.success,
    this.user,
    this.token,
    this.errorMessage,
  });
}
