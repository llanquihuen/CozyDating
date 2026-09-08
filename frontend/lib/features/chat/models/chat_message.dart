class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isFromMe;
  final String? dateType; // 'CRYPT', 'CAMPFIRE', 'HOME'

  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
    this.dateType,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'matchId': matchId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isFromMe': isFromMe,
      if (dateType != null) 'dateType': dateType,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      matchId: map['matchId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      isFromMe: map['isFromMe'] == true,
      dateType: map['dateType'],
    );
  }
}
