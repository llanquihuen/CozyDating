import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../models/mailbox_models.dart';

class MailboxService {
  static const String _baseUrl = 'http://localhost:8080';

  static final ValueNotifier<int> unreadLettersCount = ValueNotifier<int>(0);
  static final List<MailboxLetter> _cachedLetters = [];

  /// Get all mailbox letters for active user
  static Future<List<MailboxLetter>> fetchLetters({String? userId}) async {
    final activeId = userId ?? AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    if (activeId.isEmpty) return [];

    try {
      final url = Uri.parse('$_baseUrl/api/mailbox?userId=$activeId');
      final headers = {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        _cachedLetters.clear();
        for (var item in data) {
          if (item is Map<String, dynamic>) {
            _cachedLetters.add(MailboxLetter.fromMap(item));
          }
        }
        _updateBadgeCount();
        return List.from(_cachedLetters);
      }
    } catch (e) {
      print('[MAILBOX FETCH ERROR] $e - Using local cache');
    }

    _updateBadgeCount();
    return List.from(_cachedLetters);
  }

  /// Submit decision and note for a letter
  static Future<bool> submitDecision({
    required String matchId,
    required MailboxDecision decision,
    String? note,
    String? userId,
  }) async {
    final activeId = userId ?? AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    final decisionStr = decision == MailboxDecision.keepInTouch ? 'KEEP_IN_TOUCH' : 'ARCHIVE';

    // Local update
    final index = _cachedLetters.indexWhere((l) => l.id == matchId);
    if (index != -1) {
      final current = _cachedLetters[index];
      // In local demo mode, if partner is a sample user, simulate mutual match if keeping in touch
      final willMatchLocally = decision == MailboxDecision.keepInTouch &&
          (current.partnerId == 'bob' || current.partnerId == 'userB' || current.partnerId == 'charlie' || current.partnerId == 'alice');

      _cachedLetters[index] = current.copyWith(
        myDecision: decision,
        myNote: note,
        isMutualMatch: willMatchLocally || current.isMutualMatch,
        partnerNote: willMatchLocally ? '¡Me encantó nuestra charla en la fogata! Ojalá juguemos pronto ☕✨' : current.partnerNote,
      );
      _updateBadgeCount();
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
          _cachedLetters[index] = _cachedLetters[index].copyWith(
            isMutualMatch: data['isMutualMatch'] == true,
            partnerNote: data['partnerNote']?.toString() ?? _cachedLetters[index].partnerNote,
          );
        }
        return true;
      }
    } catch (e) {
      print('[MAILBOX DECISION SUBMIT ERROR] $e');
    }

    return true;
  }

  /// Update unread letters badge count
  static void _updateBadgeCount() {
    final unread = _cachedLetters.where((l) => l.myDecision == MailboxDecision.pending).length;
    unreadLettersCount.value = unread;
  }

  /// Add a newly finished game date letter directly to mailbox
  static void addDateLetter(MailboxLetter letter) {
    _cachedLetters.removeWhere((l) => l.id == letter.id);
    _cachedLetters.insert(0, letter);
    _updateBadgeCount();
  }

  /// Sample demo letters for initial experience
  static List<MailboxLetter> _getSampleLetters(String activeUserId) {
    final isAlice = activeUserId == 'alice' || activeUserId == 'userA';
    final partnerId = isAlice ? 'userB' : 'userA';
    final partnerName = isAlice ? 'Bob' : 'Alice';
    final partnerPhoto = isAlice
        ? 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80'
        : 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80';

    return [
      MailboxLetter(
        id: 'date_sample_1',
        partnerId: partnerId,
        partnerName: partnerName,
        partnerAvatar: AvatarStorageService.getUserConfig(partnerId),
        partnerPhoto: partnerPhoto,
        partnerAge: isAlice ? 26 : 24,
        partnerCommune: isAlice ? 'Providencia' : 'Santiago',
        commonTastes: const ['game_coop', 'cinema_ghibli', 'life_coffee_tea', 'intent_slow'],
        myDecision: MailboxDecision.pending,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    ];
  }
}
