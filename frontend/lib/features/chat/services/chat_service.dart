import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/app_config.dart';
import '../../../core/network/websocket_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/avatar_storage_service.dart';
import '../../mailbox/models/mailbox_models.dart';
import '../models/chat_message.dart';

class ChatService {
  static final Map<String, ValueNotifier<List<ChatMessage>>> _notifiers = {};
  static final Map<String, List<ChatMessage>> _messages = {};

  static final ValueNotifier<Map<String, bool>> partnerPresenceNotifier =
      ValueNotifier<Map<String, bool>>({});

  static final ValueNotifier<Map<String, dynamic>?> incomingDateInviteNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Outgoing date invite waiting for partner response in Lobby
  static final ValueNotifier<Map<String, dynamic>?> outgoingDateInviteNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  /// Ephemeral active date invites per matchId (key: matchId, value: Map with status, title, fromMe, etc.)
  static final ValueNotifier<Map<String, Map<String, dynamic>>> activeInvitesNotifier =
      ValueNotifier<Map<String, Map<String, dynamic>>>({});

  static StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  /// Initialize WebSocket listener for real multiplayer chat and presence
  static void initSocketListener() {
    if (_socketSubscription != null) return;

    final client = WebSocketClient.shared;
    if (client == null) return;

    _socketSubscription = client.messageStream.listen(_handleIncomingSocketMessage);
  }

  static void _handleIncomingSocketMessage(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'CHAT_MESSAGE':
        _onReceiveChatMessage(msg);
        break;
      case 'DATE_INVITE':
        _onReceiveDateInvite(msg);
        break;
      case 'DATE_INVITE_RESPONSE':
        _onReceiveDateInviteResponse(msg);
        break;
      case 'DATE_INVITE_CANCEL':
        final matchId = msg['matchId'] as String?;
        if (matchId != null && incomingDateInviteNotifier.value != null) {
          if (incomingDateInviteNotifier.value!['matchId'] == matchId) {
            incomingDateInviteNotifier.value = null;
          }
        }
        break;
      case 'DATE_INVITE_BUSY':
        outgoingDateInviteNotifier.value = null;
        break;
      case 'PRESENCE_STATUS':
        final targetId = msg['targetUserId'] as String?;
        final isOnline = msg['isOnline'] == true;
        if (targetId != null) {
          final updated = Map<String, bool>.from(partnerPresenceNotifier.value);
          updated[targetId] = isOnline;
          partnerPresenceNotifier.value = updated;
        }
        break;
      case 'USER_PRESENCE_UPDATE':
        final userId = msg['userId'] as String?;
        final isOnline = msg['isOnline'] == true;
        if (userId != null) {
          final updated = Map<String, bool>.from(partnerPresenceNotifier.value);
          updated[userId] = isOnline;
          partnerPresenceNotifier.value = updated;
        }
        break;
    }
  }

  static void _onReceiveChatMessage(Map<String, dynamic> data) {
    final matchId = data['matchId'] as String?;
    final fromUserId = data['fromUserId'] as String?;
    final text = data['text'] as String?;
    final messageId = data['messageId'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';

    if (matchId == null || text == null) return;

    final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    if (fromUserId == myId) return; // Don't duplicate self messages

    final newMsg = ChatMessage(
      id: messageId,
      matchId: matchId,
      senderId: fromUserId ?? 'partner',
      text: text,
      timestamp: DateTime.now(),
      isFromMe: false,
    );

    if (!_messages.containsKey(matchId)) {
      _messages[matchId] = [];
    }

    final list = _messages[matchId]!;
    if (list.any((m) => m.id == messageId)) return;

    list.add(newMsg);
    if (_notifiers.containsKey(matchId)) {
      _notifiers[matchId]!.value = List.from(list);
    }
  }

  static void _onReceiveDateInvite(Map<String, dynamic> data) {
    final matchId = data['matchId'] as String?;
    final fromUserId = data['fromUserId'] as String?;
    final dateType = data['dateType'] as String? ?? 'CRYPT';
    final title = data['title'] as String? ?? 'Cita Especial';
    final inviterName = data['inviterName'] as String? ?? 'Compañero';
    final messageId = data['messageId'] as String? ?? 'invite_${DateTime.now().millisecondsSinceEpoch}';

    if (matchId == null) return;

    final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    if (fromUserId == myId) return;

    // Ephemeral invite state - do NOT inject junk into chat conversation history
    final currentInvites = Map<String, Map<String, dynamic>>.from(activeInvitesNotifier.value);
    currentInvites[matchId] = {
      'inviteId': messageId,
      'matchId': matchId,
      'fromMe': false,
      'fromUserId': fromUserId,
      'inviterName': inviterName,
      'dateType': dateType,
      'title': title,
      'status': 'PENDING',
    };
    activeInvitesNotifier.value = currentInvites;

    // Trigger lobby/global notification
    incomingDateInviteNotifier.value = Map<String, dynamic>.from(data);
  }

  static void _onReceiveDateInviteResponse(Map<String, dynamic> data) {
    final matchId = data['matchId'] as String?;
    final accepted = data['accepted'] == true;

    if (matchId != null) {
      final currentInvites = Map<String, Map<String, dynamic>>.from(activeInvitesNotifier.value);
      currentInvites.remove(matchId);
      activeInvitesNotifier.value = currentInvites;
    }
    incomingDateInviteNotifier.value = null;
    outgoingDateInviteNotifier.value = null;
  }

  static bool enableAutoConnect = true;

  /// Ensure client is connected and registered online with presence mode
  static Future<void> ensureConnected() async {
    if (!enableAutoConnect) return;
    if (!AuthService.isAuthenticated) return;
    try {
      final bindingStr = WidgetsBinding.instance.runtimeType.toString();
      if (bindingStr.contains('TestWidgetsFlutterBinding') || bindingStr.contains('AutomatedTestWidgetsFlutterBinding')) {
        return;
      }
    } catch (_) {
      return;
    }

    final client = WebSocketClient.shared;
    if (client == null) return;

    final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    final token = AuthService.token ?? '';
    final presenceMode = AvatarStorageService.getPresenceMode(myId);

    if (!client.isConnected) {
      await client.connect(AppConfig.wsUrl, token);
    }

    initSocketListener();

    client.sendMessage({
      'type': 'USER_ONLINE',
      'token': token,
      'userId': myId,
      'presenceMode': presenceMode,
    });
  }

  /// Change presence mode (ONLINE vs INVISIBLE)
  static void setPresenceMode(String mode) {
    final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    AvatarStorageService.setPresenceMode(myId, mode);

    final client = WebSocketClient.shared;
    if (client != null && client.isConnected) {
      client.sendMessage({
        'type': 'SET_PRESENCE_MODE',
        'presenceMode': mode,
      });
    }
  }

  /// Check online presence for a specific partner
  static void checkPresence(String partnerId) {
    final client = WebSocketClient.shared;
    if (client != null && client.isConnected) {
      client.sendMessage({
        'type': 'PRESENCE_CHECK',
        'targetUserId': partnerId,
      });
    }
  }

  /// Get or initialize the ValueNotifier for a match conversation
  static ValueNotifier<List<ChatMessage>> getConversationNotifier(MailboxLetter letter) {
    if (!_notifiers.containsKey(letter.id)) {
      _initConversation(letter);
      fetchHistory(letter.id);
    }
    return _notifiers[letter.id]!;
  }

  static void _initConversation(MailboxLetter letter) {
    final list = <ChatMessage>[];

    // Seed initial partner note if present
    if (letter.partnerNote != null && letter.partnerNote!.isNotEmpty) {
      list.add(ChatMessage(
        id: 'msg_init_partner_${letter.id}',
        matchId: letter.id,
        senderId: letter.partnerId,
        text: letter.partnerNote!,
        timestamp: letter.createdAt.add(const Duration(minutes: 1)),
        isFromMe: false,
      ));
    }

    // Seed local user's note if present
    if (letter.myNote != null && letter.myNote!.isNotEmpty) {
      list.add(ChatMessage(
        id: 'msg_init_local_${letter.id}',
        matchId: letter.id,
        senderId: 'me',
        text: letter.myNote!,
        timestamp: letter.createdAt.add(const Duration(minutes: 2)),
        isFromMe: true,
      ));
    }

    _messages[letter.id] = list;
    _notifiers[letter.id] = ValueNotifier<List<ChatMessage>>(List.from(list));
  }

  /// Fetch remote message history from backend REST endpoint
  static Future<void> fetchHistory(String matchId) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/chat/messages?matchId=$matchId');
      final headers = {
        'Content-Type': 'application/json',
        if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
      };

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
          final remoteMessages = <ChatMessage>[];

          for (var item in data) {
            if (item is Map<String, dynamic>) {
              final senderId = item['senderId']?.toString() ?? '';
              final isFromMe = senderId == myId ||
                  (senderId == 'userA' && myId == 'alice') ||
                  (senderId == 'userB' && myId == 'bob');

              final dateType = item['dateType']?.toString();
              final text = item['text']?.toString() ?? '';

              // Clean chat: filter out any legacy date invite junk from earlier tests
              if (dateType != null && dateType.isNotEmpty) continue;
              if (text.contains('Te he invitado a una nueva Cita') || text.contains('ha aceptado la invitación')) {
                continue;
              }

              remoteMessages.add(ChatMessage(
                id: item['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
                matchId: matchId,
                senderId: senderId,
                text: text,
                dateType: null,
                timestamp: item['createdAt'] != null
                    ? DateTime.tryParse(item['createdAt'].toString()) ?? DateTime.now()
                    : DateTime.now(),
                isFromMe: isFromMe,
              ));
            }
          }

          if (remoteMessages.isNotEmpty) {
            _messages[matchId] = remoteMessages;
            if (_notifiers.containsKey(matchId)) {
              _notifiers[matchId]!.value = List.from(remoteMessages);
            }
          }
        }
      }
    } catch (e) {
      print('[CHAT HISTORY FETCH ERROR] $e');
    }
  }

  /// Send a new message in real multiplayer
  static void sendMessage({
    required MailboxLetter letter,
    required String text,
  }) {
    if (text.trim().isEmpty) return;

    final trimmed = text.trim();
    final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    final newMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';

    final newMsg = ChatMessage(
      id: newMsgId,
      matchId: letter.id,
      senderId: myId,
      text: trimmed,
      timestamp: DateTime.now(),
      isFromMe: true,
    );

    if (!_messages.containsKey(letter.id)) {
      _initConversation(letter);
    }

    _messages[letter.id]!.add(newMsg);
    _notifiers[letter.id]!.value = List.from(_messages[letter.id]!);

    // Real multiplayer socket send
    final client = WebSocketClient.shared;
    if (client != null && client.isConnected) {
      client.sendMessage({
        'type': 'CHAT_MESSAGE',
        'matchId': letter.id,
        'toUserId': letter.partnerId,
        'text': trimmed,
        'messageId': newMsgId,
      });
    } else {
      // Asynchronous backend persistence fallback when WebSocket is not connected
      _persistMessageHttp(
        id: newMsgId,
        matchId: letter.id,
        senderId: myId,
        receiverId: letter.partnerId,
        text: trimmed,
      );
    }
  }

  /// Send an interactive date invite in real multiplayer (ephemeral, not cluttering chat)
  static void sendDateInvite({
    required MailboxLetter letter,
    required String dateType,
    required String title,
  }) {
    final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    final myName = AuthService.currentUser?.username ?? 'Compañero';
    final inviteId = 'invite_${DateTime.now().millisecondsSinceEpoch}';

    // Update ephemeral active invite state
    final currentInvites = Map<String, Map<String, dynamic>>.from(activeInvitesNotifier.value);
    currentInvites[letter.id] = {
      'inviteId': inviteId,
      'matchId': letter.id,
      'fromMe': true,
      'dateType': dateType,
      'title': title,
      'status': 'WAITING',
    };
    activeInvitesNotifier.value = currentInvites;

    // Set waiting state for lobby
    outgoingDateInviteNotifier.value = {
      'inviteId': inviteId,
      'matchId': letter.id,
      'partnerId': letter.partnerId,
      'partnerName': letter.partnerName,
      'dateType': dateType,
      'title': title,
    };

    // Real multiplayer socket send
    final client = WebSocketClient.shared;
    if (client != null && client.isConnected) {
      client.sendMessage({
        'type': 'DATE_INVITE',
        'matchId': letter.id,
        'toUserId': letter.partnerId,
        'inviterName': myName,
        'dateType': dateType,
        'title': title,
        'messageId': inviteId,
      });
    }
  }

  /// Cancel an outgoing date invite and unblock lobby
  static void cancelDateInvite({
    required String matchId,
    required String partnerId,
  }) {
    final client = WebSocketClient.shared;
    final myId = AuthService.currentUser?.id ?? AvatarStorageService.activeUserId;
    if (client != null && client.isConnected) {
      client.sendMessage({
        'type': 'DATE_INVITE_CANCEL',
        'matchId': matchId,
        'fromUserId': myId,
        'toUserId': partnerId,
      });
    }

    final currentInvites = Map<String, Map<String, dynamic>>.from(activeInvitesNotifier.value);
    currentInvites.remove(matchId);
    activeInvitesNotifier.value = currentInvites;
    outgoingDateInviteNotifier.value = null;
  }

  /// Accept an interactive date invite (triggers real multiplayer session on server)
  static void acceptDateInvite({
    required MailboxLetter letter,
    required String dateType,
    required String title,
  }) {
    final client = WebSocketClient.shared;
    if (client != null && client.isConnected) {
      client.sendMessage({
        'type': 'DATE_INVITE_RESPONSE',
        'matchId': letter.id,
        'toUserId': letter.partnerId,
        'accepted': true,
        'dateType': dateType,
        'title': title,
      });
    }

    // Clear active invite state
    final currentInvites = Map<String, Map<String, dynamic>>.from(activeInvitesNotifier.value);
    currentInvites.remove(letter.id);
    activeInvitesNotifier.value = currentInvites;
    incomingDateInviteNotifier.value = null;
  }

  /// Dismiss or reject an active date invite
  static void dismissDateInvite(
    String matchId, {
    String? partnerId,
  }) {
    final client = WebSocketClient.shared;
    if (client != null && client.isConnected && partnerId != null) {
      client.sendMessage({
        'type': 'DATE_INVITE_RESPONSE',
        'matchId': matchId,
        'toUserId': partnerId,
        'accepted': false,
      });
    }

    final currentInvites = Map<String, Map<String, dynamic>>.from(activeInvitesNotifier.value);
    currentInvites.remove(matchId);
    activeInvitesNotifier.value = currentInvites;
    incomingDateInviteNotifier.value = null;
  }

  /// Reconnect WebSocket immediately when user switches in Lobby
  static Future<void> reconnectAsUser(String newUserId) async {
    final client = WebSocketClient.shared;
    if (client == null) return;

    final token = AuthService.token ?? '';
    final presenceMode = AvatarStorageService.getPresenceMode(newUserId);

    if (client.isConnected) {
      await client.disconnect();
    }

    await client.connect(AppConfig.wsUrl, token);
    initSocketListener();

    client.sendMessage({
      'type': 'USER_ONLINE',
      'token': token,
      'userId': newUserId,
      'presenceMode': presenceMode,
    });
  }

  static void _persistMessageHttp({
    required String id,
    required String matchId,
    required String senderId,
    required String receiverId,
    required String text,
    String? dateType,
  }) {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/chat/messages');
      http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (AuthService.token != null) 'Authorization': 'Bearer ${AuthService.token}',
        },
        body: jsonEncode({
          'id': id,
          'matchId': matchId,
          'senderId': senderId,
          'receiverId': receiverId,
          'text': text,
          'dateType': dateType,
        }),
      ).catchError((e) => http.Response('', 500));
    } catch (_) {}
  }
}
