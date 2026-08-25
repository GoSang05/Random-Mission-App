enum ChatConversationKind { global, room, direct }

class ChatProfile {
  const ChatProfile({required this.userId, required this.displayName});

  final String userId;
  final String displayName;

  factory ChatProfile.fromJson(Map<String, dynamic> json) {
    return ChatProfile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String,
    );
  }
}

class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.kind,
    required this.title,
    this.otherUserId,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String id;
  final ChatConversationKind kind;
  final String title;
  final String? otherUserId;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  factory ChatConversation.directFromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['conversation_id'] as String,
      kind: ChatConversationKind.direct,
      title: json['other_display_name'] as String,
      otherUserId: json['other_user_id'] as String,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: _dateTimeOrNull(json['last_message_at']),
    );
  }
}

class RemoteChatMessage {
  const RemoteChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderUserId;
  final String senderName;
  final String text;
  final DateTime createdAt;

  factory RemoteChatMessage.fromJson(Map<String, dynamic> json) {
    return RemoteChatMessage(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderUserId: json['sender_id'] as String,
      senderName: json['sender_display_name'] as String,
      text: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }
}

class JoinedChatRoom {
  const JoinedChatRoom({
    required this.roomId,
    required this.roomName,
    required this.inviteCode,
    required this.memberCount,
  });

  final String roomId;
  final String roomName;
  final String inviteCode;
  final int memberCount;

  factory JoinedChatRoom.fromJson(Map<String, dynamic> json) {
    return JoinedChatRoom(
      roomId: json['room_id'] as String,
      roomName: json['room_name'] as String,
      inviteCode: json['invite_code'] as String,
      memberCount: (json['member_count'] as num).toInt(),
    );
  }
}

DateTime? _dateTimeOrNull(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.parse(value).toLocal();
}
