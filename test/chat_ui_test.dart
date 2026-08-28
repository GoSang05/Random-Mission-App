import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/data/chat_repository.dart';
import 'package:random_mission_app/data/local_mission_repository.dart';
import 'package:random_mission_app/models/chat_data.dart';
import 'package:random_mission_app/models/mission_data.dart';
import 'package:random_mission_app/screens/chats_screen.dart';
import 'package:random_mission_app/screens/global_missions_screen.dart';
import 'package:random_mission_app/screens/room_detail_screen.dart';

class _FakeChatRepository implements ChatRepository {
  final _messages = <String, List<RemoteChatMessage>>{};
  final _updates = StreamController<String>.broadcast();

  @override
  String get currentUserId => 'current-user';

  @override
  Future<void> blockUser(String userId) async {}

  void dispose() => _updates.close();

  @override
  Future<void> ensureProfile(String displayName) async {}

  @override
  Future<List<ChatProfile>> findPeople(String searchText) async {
    return const [ChatProfile(userId: 'friend-user', displayName: '민지')];
  }

  @override
  Future<String> globalConversationId() async => 'global-chat';

  @override
  Future<String> ensureRoomConversation(MissionRoom room) async {
    return 'chat-${room.id}';
  }

  @override
  Future<JoinedChatRoom> joinRoomByCode(String inviteCode) async {
    return JoinedChatRoom(
      roomId: 'joined-room',
      roomName: '참여한 방',
      inviteCode: inviteCode,
      memberCount: 2,
    );
  }

  @override
  Future<List<JoinedChatRoom>> listJoinedRooms() async => const [];

  @override
  Future<List<ChatConversation>> listDirectConversations() async {
    return const [
      ChatConversation(
        id: 'direct-chat',
        kind: ChatConversationKind.direct,
        title: '민지',
        otherUserId: 'friend-user',
      ),
    ];
  }

  @override
  Future<ChatConversation> openDirectConversation(ChatProfile profile) async {
    return ChatConversation(
      id: 'direct-chat',
      kind: ChatConversationKind.direct,
      title: profile.displayName,
      otherUserId: profile.userId,
    );
  }

  @override
  Future<void> reportMessage(String messageId) async {}

  @override
  Future<void> sendMessage(String conversationId, String text) async {
    final messages = _messages.putIfAbsent(conversationId, () => []);
    messages.add(
      RemoteChatMessage(
        id: 'message-${messages.length}',
        conversationId: conversationId,
        senderUserId: currentUserId,
        senderName: '나',
        text: text.trim(),
        createdAt: DateTime.now(),
      ),
    );
    _updates.add(conversationId);
  }

  @override
  Stream<List<RemoteChatMessage>> watchMessages(String conversationId) async* {
    yield List.unmodifiable(_messages[conversationId] ?? const []);
    await for (final changedConversation in _updates.stream) {
      if (changedConversation == conversationId) {
        yield List.unmodifiable(_messages[conversationId] ?? const []);
      }
    }
  }
}

void main() {
  testWidgets('chat tab opens global and private conversations', (
    tester,
  ) async {
    final repository = _FakeChatRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatsScreen(repository: repository, onSignOut: () async {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('globalChatTile')), findsOneWidget);
    expect(find.text('민지'), findsOneWidget);

    await tester.tap(find.byKey(const Key('globalChatTile')));
    await tester.pumpAndSettle();
    expect(find.text('Global Chat'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('remoteChatMessageField')),
      '안녕하세요',
    );
    await tester.tap(find.byKey(const Key('remoteSendChatButton')));
    await tester.pumpAndSettle();
    expect(find.text('안녕하세요'), findsOneWidget);
  });

  testWidgets('mission room uses the authenticated realtime chat path', (
    tester,
  ) async {
    final missionRepository = LocalMissionRepository();
    final chatRepository = _FakeChatRepository();
    addTearDown(missionRepository.dispose);
    addTearDown(chatRepository.dispose);
    await missionRepository.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: RoomDetailScreen(
          repository: missionRepository,
          chatRepository: chatRepository,
          roomId: 'room-friends',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('roomChatButton')));
    await tester.pumpAndSettle();
    expect(find.text('친구들의 랜덤 미션 채팅'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('remoteChatMessageField')),
      '방 채팅 테스트',
    );
    await tester.tap(find.byKey(const Key('remoteSendChatButton')));
    await tester.pumpAndSettle();
    expect(find.text('방 채팅 테스트'), findsOneWidget);
  });

  testWidgets('global mission room opens the global conversation', (
    tester,
  ) async {
    final missionRepository = LocalMissionRepository();
    final chatRepository = _FakeChatRepository();
    addTearDown(missionRepository.dispose);
    addTearDown(chatRepository.dispose);
    await missionRepository.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: GlobalMissionsScreen(
          repository: missionRepository,
          chatRepository: chatRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('globalRoomChatButton')));
    await tester.pumpAndSettle();

    expect(find.text('Global Chat'), findsOneWidget);
    expect(find.byKey(const Key('remoteChatMessageField')), findsOneWidget);
  });
}
