import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../chat/services/chat_service.dart';
import '../models/mailbox_models.dart';

class MailboxService {
  static String get _baseUrl => AppConfig.baseUrl;

  static final ValueNotifier<int> unreadLettersCount = ValueNotifier<int>(0);
  static final ValueNotifier<MailboxLetter?> mutualMatchCelebrationNotifier = ValueNotifier<MailboxLetter?>(null);
  static final ValueNotifier<MailboxLetter?> pendingCampfireDecisionNotifier = ValueNotifier<MailboxLetter?>(null);
  static final List<MailboxLetter> _cachedLetters = [];
  static String? _loadedUserId;

  static Future<void> _saveLettersToStorage(String userId, [List<MailboxLetter>? lettersToSave]) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'mailbox_letters_$userId';
      final list = lettersToSave ?? _cachedLetters;
      final jsonList = list.map((l) => l.toMap()).toList();
      await prefs.setString(key, jsonEncode(jsonList));
    } catch (e) {
      print('[MAILBOX STORAGE SAVE ERROR] $e');
    }
  }

  static Future<List<MailboxLetter>> _loadLettersFromStorage(String userId) async {
    if (userId.isEmpty) return [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'mailbox_letters_$userId';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final List list = jsonDecode(raw);
        final loaded = <MailboxLetter>[];
        for (var item in list) {
          if (item is Map<String, dynamic>) {
            final letter = MailboxLetter.fromMap(item);
            // Skip any letter explicitly saved under another user
            if (letter.ownerId != null && letter.ownerId!.isNotEmpty && letter.ownerId != userId) {
              continue;
            }
            loaded.add(letter.copyWith(ownerId: userId));
          }
        }
        return loaded;
      }
    } catch (e) {
      print('[MAILBOX STORAGE LOAD ERROR] $e');
    }
    return [];
  }

  static void triggerMutualMatchCelebration(MailboxLetter letter) {
    if (letter.isCelebrated || AvatarStorageService.isMatchAcknowledged(letter.id)) return;
    AvatarStorageService.markMatchAcknowledged(letter.id);
    final index = _cachedLetters.indexWhere((l) => l.id == letter.id);
    if (index != -1) {
      _cachedLetters[index] = _cachedLetters[index].copyWith(isCelebrated: true);
      final activeId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
      _saveLettersToStorage(activeId);
    }
    markMatchCelebratedOnServer(letter.id);
    mutualMatchCelebrationNotifier.value = letter;
  }

  static List<MailboxLetter> get letters => List.unmodifiable(_cachedLetters);
  static List<MailboxLetter> getLetters() => List.unmodifiable(_cachedLetters);

  static void clear() {
    _cachedLetters.clear();
    _loadedUserId = null;
    unreadLettersCount.value = 0;
    mutualMatchCelebrationNotifier.value = null;
    pendingCampfireDecisionNotifier.value = null;
    ChatService.clearUnread();
  }

  static void checkForUncelebratedMatches() {
    for (final letter in _cachedLetters) {
      if (letter.isMutualMatch && !letter.isCelebrated && !AvatarStorageService.isMatchAcknowledged(letter.id)) {
        triggerMutualMatchCelebration(letter);
        break;
      }
    }
  }

  static Future<void> markMatchCelebratedOnServer(String matchId, {String? userId}) async {
    final activeId = userId ?? AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    if (activeId.isEmpty) return;
    try {
      final url = Uri.parse('$_baseUrl/api/mailbox/celebrated');
      final headers = {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };
      await http.post(
        url,
        headers: headers,
        body: jsonEncode({'matchId': matchId, 'userId': activeId}),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      print('[MAILBOX CELEBRATED SYNC ERROR] $e');
    }
  }

  /// Get all mailbox letters for active user
  static Future<List<MailboxLetter>> fetchLetters({String? userId}) async {
    final activeId = (userId != null && userId.isNotEmpty)
        ? userId
        : (AuthService.currentUser?.id.isNotEmpty == true
            ? AuthService.currentUser!.id
            : AvatarStorageService.activeUserId);
    if (activeId.isEmpty) return [];

    // Reset memory cache if user changed or not yet loaded
    if (_loadedUserId != activeId) {
      _cachedLetters.clear();
      _loadedUserId = activeId;
    }

    // 1. Load locally persisted letters immediately
    final localStored = await _loadLettersFromStorage(activeId);
    if (localStored.isNotEmpty) {
      for (final letter in localStored) {
        if (letter.ownerId != null && letter.ownerId!.isNotEmpty && letter.ownerId != activeId) {
          continue;
        }
        final existingIdx = _cachedLetters.indexWhere((l) => l.id == letter.id);
        if (existingIdx == -1) {
          _cachedLetters.add(letter);
        } else {
          // If local stored has a decision that RAM didn't have, or vice versa, update
          if (_cachedLetters[existingIdx].myDecision == MailboxDecision.pending &&
              letter.myDecision != MailboxDecision.pending) {
            _cachedLetters[existingIdx] = letter;
          }
        }
      }
      _updateBadgeCount();
      checkForUncelebratedMatches();
    }

    // 2. Fetch from backend API if authenticated or token present
    if (!AuthService.isAuthenticated && AuthService.token == null) {
      _updateBadgeCount();
      checkForUncelebratedMatches();
      return List.from(_cachedLetters);
    }

    try {
      final url = Uri.parse('$_baseUrl/api/mailbox?userId=$activeId');
      final headers = {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final serverLetters = <MailboxLetter>[];
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            serverLetters.add(MailboxLetter.fromMap(item).copyWith(ownerId: activeId));
          }
        }

        // Merge server letters with local cache:
        // Server letters are authoritative for this user.
        // Local letters are ONLY preserved if they belong to activeId, are pending, and created recently (< 24 hours).
        // Any phantom/stale letters from previous test sessions or other users are pruned!
        final merged = <MailboxLetter>[...serverLetters];
        for (final local in _cachedLetters) {
          if (local.ownerId != null && local.ownerId!.isNotEmpty && local.ownerId != activeId) {
            continue;
          }

          final serverIdx = merged.indexWhere((s) => s.id == local.id);
          if (serverIdx == -1) {
            // If the letter is a server room (starts with 'room_') but the server doesn't return it for this user,
            // it means it belongs to another user or was pruned on the server. Do NOT adopt it!
            if (local.id.startsWith('room_')) {
              continue;
            }
            final isRecentPending = local.ownerId == activeId &&
                local.myDecision == MailboxDecision.pending &&
                DateTime.now().difference(local.createdAt).inHours < 2;
            if (isRecentPending) {
              merged.add(local.copyWith(ownerId: activeId));
            }
          } else {
            if (local.myDecision != MailboxDecision.pending && merged[serverIdx].myDecision == MailboxDecision.pending) {
              merged[serverIdx] = merged[serverIdx].copyWith(
                myDecision: local.myDecision,
                myNote: local.myNote,
              );
            }
            if (local.isCelebrated && !merged[serverIdx].isCelebrated) {
              merged[serverIdx] = merged[serverIdx].copyWith(isCelebrated: true);
            }
          }
        }

        _cachedLetters.clear();
        _cachedLetters.addAll(merged);
        await _saveLettersToStorage(activeId);
        _updateBadgeCount();
        checkForUncelebratedMatches();
        return List.from(_cachedLetters);
      }
    } catch (e) {
      print('[MAILBOX FETCH ERROR] $e - Using local cache');
    }

    _updateBadgeCount();
    checkForUncelebratedMatches();
    return List.from(_cachedLetters);
  }

  /// Submit decision and note for a letter
  static Future<bool> submitDecision({
    required String matchId,
    required MailboxDecision decision,
    String? note,
    String? userId,
  }) async {
    final activeId = (userId != null && userId.isNotEmpty)
        ? userId
        : (AuthService.currentUser?.id.isNotEmpty == true
            ? AuthService.currentUser!.id
            : AvatarStorageService.activeUserId);
    String decisionStr = 'ARCHIVE';
    if (decision == MailboxDecision.romance) {
      decisionStr = 'ROMANCE';
    } else if (decision == MailboxDecision.friendship) {
      decisionStr = 'FRIENDSHIP';
    } else if (decision == MailboxDecision.keepInTouch) {
      decisionStr = 'KEEP_IN_TOUCH';
    }

    // Local update
    final index = _cachedLetters.indexWhere((l) => l.id == matchId);
    if (index != -1) {
      final current = _cachedLetters[index];
      _cachedLetters[index] = current.copyWith(
        myDecision: decision,
        myNote: note,
      );
      _updateBadgeCount();
      _saveLettersToStorage(activeId);
    }

    if (!AuthService.isAuthenticated && AuthService.token == null) {
      return true;
    }

    try {
      final url = Uri.parse('$_baseUrl/api/mailbox/decision');
      final headers = {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };
      final body = jsonEncode({
        'userId': activeId,
        'matchId': matchId,
        'decision': decisionStr,
        'note': note,
      });

      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (index != -1) {
          final serverMatchTypeStr = data['matchType']?.toString().toUpperCase();
          ConnectionType serverMatchType = ConnectionType.none;
          if (serverMatchTypeStr == 'ROMANCE') {
            serverMatchType = ConnectionType.romance;
          } else if (serverMatchTypeStr == 'FRIENDSHIP') {
            serverMatchType = ConnectionType.friendship;
          }

          _cachedLetters[index] = _cachedLetters[index].copyWith(
            isMutualMatch: data['isMutualMatch'] == true,
            matchType: serverMatchType != ConnectionType.none ? serverMatchType : _cachedLetters[index].matchType,
            partnerNote: data['partnerNote']?.toString() ?? _cachedLetters[index].partnerNote,
          );
          _saveLettersToStorage(activeId);
        }
        return true;
      }
    } catch (e) {
      print('[MAILBOX DECISION SUBMIT ERROR] $e');
    }

    return true;
  }

  /// Update total badge count (pending letters + unread chat messages)
  static void _updateBadgeCount() {
    updateTotalBadgeCount();
  }

  static void updateTotalBadgeCount() {
    final unreadLetters = _cachedLetters.where((l) => l.myDecision == MailboxDecision.pending).length;
    final unreadChats = ChatService.totalUnreadMessages;
    unreadLettersCount.value = unreadLetters + unreadChats;
  }

  /// Add a newly finished game date letter directly to mailbox and persist it
  static Future<void> addDateLetter(MailboxLetter letter, {String? userId}) async {
    final activeId = (userId != null && userId.isNotEmpty)
        ? userId
        : (AuthService.currentUser?.id.isNotEmpty == true
            ? AuthService.currentUser!.id
            : AvatarStorageService.activeUserId);

    if (_loadedUserId != activeId) {
      _cachedLetters.clear();
      _loadedUserId = activeId;
    }

    final taggedLetter = letter.copyWith(ownerId: activeId);

    _cachedLetters.removeWhere((l) => l.id == taggedLetter.id);
    _cachedLetters.insert(0, taggedLetter);
    _updateBadgeCount();

    if (activeId.isNotEmpty) {
      final snapshot = List<MailboxLetter>.from(_cachedLetters);
      await _saveLettersToStorage(activeId, snapshot);
      _syncLetterRecordToServer(taggedLetter, activeId);
    }
  }

  static Future<MailboxLetter?> _syncLetterRecordToServer(MailboxLetter letter, String userId) async {
    if (!AuthService.isAuthenticated && AuthService.token == null) return null;
    try {
      final url = Uri.parse('$_baseUrl/api/mailbox/record');
      final headers = {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };
      final body = jsonEncode({
        'id': letter.id,
        'userId': userId,
        'partnerId': letter.partnerId,
        'partnerName': letter.partnerName,
        'partnerAvatar': letter.partnerAvatar.toJson(),
        'partnerPhoto': letter.partnerPhoto,
        'partnerAge': letter.partnerAge,
        'partnerCommune': letter.partnerCommune,
        'commonTastes': letter.commonTastes,
      });
      final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final serverPartnerPhoto = data['partnerPhoto']?.toString();
          final serverPartnerPhotos = data['partnerPhotos'];
          List<String> photosList = [];
          if (serverPartnerPhotos is List) {
            photosList = serverPartnerPhotos.map((e) => e.toString()).toList();
          } else if (serverPartnerPhotos is String && serverPartnerPhotos.isNotEmpty) {
            try {
              final decoded = jsonDecode(serverPartnerPhotos);
              if (decoded is List) {
                photosList = decoded.map((e) => e.toString()).toList();
              }
            } catch (_) {}
          }
          if (serverPartnerPhoto != null && serverPartnerPhoto.isNotEmpty && !photosList.contains(serverPartnerPhoto)) {
            photosList.insert(0, serverPartnerPhoto);
          }

          final enrichedLetter = letter.copyWith(
            partnerPhoto: (serverPartnerPhoto != null && serverPartnerPhoto.isNotEmpty) ? serverPartnerPhoto : letter.partnerPhoto,
            partnerPhotos: photosList.isNotEmpty ? photosList : letter.partnerPhotos,
            partnerAge: data['partnerAge'] is num ? (data['partnerAge'] as num).toInt() : letter.partnerAge,
            partnerCommune: data['partnerCommune']?.toString() ?? letter.partnerCommune,
            partnerName: data['partnerName']?.toString() ?? letter.partnerName,
          );

          final idx = _cachedLetters.indexWhere((l) => l.id == letter.id);
          if (idx != -1) {
            _cachedLetters[idx] = enrichedLetter;
            await _saveLettersToStorage(userId, _cachedLetters);
          }

          if (pendingCampfireDecisionNotifier.value?.id == letter.id) {
            pendingCampfireDecisionNotifier.value = enrichedLetter;
          }
          return enrichedLetter;
        }
      }
    } catch (e) {
      print('[MAILBOX RECORD SYNC ERROR] $e');
    }
    return null;
  }
}
