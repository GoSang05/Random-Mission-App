import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_data.dart';
import '../models/mission_data.dart';

class ChatRepositoryException implements Exception {
  const ChatRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ChatRepository {
  static const maxMessageLength = 500;

  String get currentUserId;

  Future<void> ensureProfile(String displayName);

  Future<String> globalConversationId();

  Future<String> ensureRoomConversation(MissionRoom room);

  Future<List<JoinedChatRoom>> listJoinedRooms();

  Future<JoinedChatRoom> joinRoomByCode(String inviteCode);

  Future<List<ChatProfile>> findPeople(String searchText);

  Future<ChatConversation> openDirectConversation(ChatProfile profile);

  Future<List<ChatConversation>> listDirectConversations();

  Stream<List<RemoteChatMessage>> watchMessages(String conversationId);

  Future<void> sendMessage(String conversationId, String text);

  Future<void> blockUser(String userId);

  Future<void> reportMessage(String messageId);
}

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  User get _user {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ChatRepositoryException('다시 로그인해 주세요.');
    }
    return user;
  }

  @override
  String get currentUserId => _user.id;

  @override
  Future<void> ensureProfile(String displayName) async {
    final cleanName = _cleanRequired(displayName, maxLength: 40);
    try {
      await _client.rpc(
        'ensure_chat_profile',
        params: {'p_display_name': cleanName},
      );
    } catch (_) {
      throw const ChatRepositoryException('프로필을 준비하지 못했어요.');
    }
  }

  @override
  Future<String> globalConversationId() async {
    try {
      final result = await _client.rpc('get_global_chat');
      return result as String;
    } catch (_) {
      throw const ChatRepositoryException('글로벌 채팅을 열지 못했어요.');
    }
  }

  @override
  Future<String> ensureRoomConversation(MissionRoom room) async {
    final code = room.code;
    if (code == null) {
      throw const ChatRepositoryException('이 방에는 초대 코드가 없어요.');
    }
    try {
      final result = await _client.rpc(
        'register_room_chat',
        params: {
          'p_room_id': room.id,
          'p_room_name': room.name,
          'p_invite_code': code,
        },
      );
      return result as String;
    } on PostgrestException catch (error) {
      if (error.message.contains('not_a_room_member')) {
        throw const ChatRepositoryException('이 방의 채팅 멤버가 아니에요.');
      }
      throw const ChatRepositoryException('방 채팅을 준비하지 못했어요.');
    } catch (_) {
      throw const ChatRepositoryException('방 채팅을 준비하지 못했어요.');
    }
  }

  @override
  Future<JoinedChatRoom> joinRoomByCode(String inviteCode) async {
    final cleanCode = inviteCode.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(cleanCode)) {
      throw const ChatRepositoryException('영문과 숫자로 된 초대 코드를 확인해 주세요.');
    }
    try {
      final result = await _client.rpc(
        'join_room_chat',
        params: {'p_invite_code': cleanCode},
      );
      final rows = result as List<dynamic>;
      if (rows.isEmpty) {
        throw const ChatRepositoryException('일치하는 방을 찾지 못했어요.');
      }
      return JoinedChatRoom.fromJson(rows.first as Map<String, dynamic>);
    } on ChatRepositoryException {
      rethrow;
    } on PostgrestException catch (error) {
      if (error.message.contains('invalid_invite')) {
        throw const ChatRepositoryException('일치하는 방을 찾지 못했어요.');
      }
      throw const ChatRepositoryException('방에 참여하지 못했어요.');
    } catch (_) {
      throw const ChatRepositoryException('방에 참여하지 못했어요.');
    }
  }

  @override
  Future<List<JoinedChatRoom>> listJoinedRooms() async {
    try {
      final result = await _client.rpc('list_joined_room_chats');
      return (result as List<dynamic>)
          .map((row) => JoinedChatRoom.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw const ChatRepositoryException('참여 중인 방을 불러오지 못했어요.');
    }
  }

  @override
  Future<List<ChatProfile>> findPeople(String searchText) async {
    final cleanSearch = searchText.trim();
    try {
      final result = await _client.rpc(
        'find_chat_profiles',
        params: {'p_search': cleanSearch},
      );
      return (result as List<dynamic>)
          .map((row) => ChatProfile.fromJson(row as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      throw const ChatRepositoryException('사용자를 불러오지 못했어요.');
    }
  }

  @override
  Future<ChatConversation> openDirectConversation(ChatProfile profile) async {
    if (profile.userId == currentUserId) {
      throw const ChatRepositoryException('자신에게는 메시지를 보낼 수 없어요.');
    }
    try {
      final result = await _client.rpc(
        'get_or_create_direct_chat',
        params: {'p_other_user_id': profile.userId},
      );
      return ChatConversation(
        id: result as String,
        kind: ChatConversationKind.direct,
        title: profile.displayName,
        otherUserId: profile.userId,
      );
    } catch (_) {
      throw const ChatRepositoryException('개인 채팅을 열지 못했어요.');
    }
  }

  @override
  Future<List<ChatConversation>> listDirectConversations() async {
    try {
      final result = await _client.rpc('list_direct_chats');
      return (result as List<dynamic>)
          .map(
            (row) =>
                ChatConversation.directFromJson(row as Map<String, dynamic>),
          )
          .toList(growable: false);
    } catch (_) {
      throw const ChatRepositoryException('개인 채팅 목록을 불러오지 못했어요.');
    }
  }

  @override
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at')
        .limit(200)
        .map(
          (rows) =>
              rows.map(RemoteChatMessage.fromJson).toList(growable: false),
        );
  }

  @override
  Future<void> sendMessage(String conversationId, String text) async {
    try {
      final cleanText = _cleanRequired(
        text,
        maxLength: ChatRepository.maxMessageLength,
      );
      await _client.rpc(
        'send_chat_message',
        params: {'p_conversation_id': conversationId, 'p_body': cleanText},
      );
    } on PostgrestException catch (error) {
      if (error.message.contains('rate_limit')) {
        throw const ChatRepositoryException(
          '메시지를 너무 빠르게 보내고 있어요. 잠시 후 다시 시도해 주세요.',
        );
      }
      if (error.message.contains('not_a_chat_member')) {
        throw const ChatRepositoryException('이 채팅에 메시지를 보낼 권한이 없어요.');
      }
      if (error.message.contains('user_blocked')) {
        throw const ChatRepositoryException('차단된 사용자와는 메시지를 주고받을 수 없어요.');
      }
      throw const ChatRepositoryException('메시지를 보내지 못했어요.');
    } on ArgumentError catch (error) {
      throw ChatRepositoryException(error.message.toString());
    } catch (_) {
      throw const ChatRepositoryException('메시지를 보내지 못했어요.');
    }
  }

  @override
  Future<void> blockUser(String userId) async {
    if (userId == currentUserId) return;
    try {
      await _client.rpc('block_chat_user', params: {'p_user_id': userId});
    } catch (_) {
      throw const ChatRepositoryException('사용자를 차단하지 못했어요.');
    }
  }

  @override
  Future<void> reportMessage(String messageId) async {
    try {
      await _client.rpc(
        'report_chat_message',
        params: {'p_message_id': messageId},
      );
    } catch (_) {
      throw const ChatRepositoryException('메시지를 신고하지 못했어요.');
    }
  }

  String _cleanRequired(String value, {required int maxLength}) {
    final clean = value.trim();
    if (clean.isEmpty) throw ArgumentError('내용을 입력해 주세요.');
    if (clean.length > maxLength) {
      throw ArgumentError('$maxLength자 이하로 입력해 주세요.');
    }
    return clean;
  }
}
