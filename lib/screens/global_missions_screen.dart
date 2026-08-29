import 'package:flutter/material.dart';

import '../data/local_mission_repository.dart';
import '../data/local_media_store.dart';
import '../data/chat_repository.dart';
import '../models/chat_data.dart';
import '../models/mission_data.dart';
import '../utils/app_snackbar.dart';
import '../widgets/doit_logo.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';
import '../widgets/story_card_stack.dart';
import 'capture_screen.dart';
import 'conversation_screen.dart';
import 'local_room_chat_screen.dart';
import 'mission_feed_screen.dart';

class GlobalMissionsScreen extends StatefulWidget {
  const GlobalMissionsScreen({
    required this.repository,
    this.chatRepository,
    super.key,
  });

  final LocalMissionRepository repository;
  final ChatRepository? chatRepository;

  @override
  State<GlobalMissionsScreen> createState() => _GlobalMissionsScreenState();
}

class _GlobalMissionsScreenState extends State<GlobalMissionsScreen> {
  final LocalMediaStore _mediaStore = LocalMediaStore();
  void _message(String text) {
    showAppSnackBar(context, text);
  }

  Future<void> _openCapture(MissionRoom room, Mission mission) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CaptureScreen(
          missionTitle: mission.title,
          onSave: (result, onProgress) async {
            onProgress(0.2);
            final savedPath = await _mediaStore.persist(
              sourcePath: result.path,
              kind: MissionMediaKind.photo,
            );
            onProgress(0.7);
            widget.repository.addSubmission(
              roomId: room.id,
              missionId: mission.id,
              localPath: savedPath,
              mediaKind: MissionMediaKind.photo,
            );
            onProgress(1);
          },
        ),
      ),
    );
    if (saved == true && mounted) _message('글로벌 스토리에 인증을 저장했어요.');
  }

  Future<void> _openGlobalChat() async {
    final repository = widget.chatRepository;
    if (repository == null) {
      final room = widget.repository.globalRoom;
      if (room == null) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LocalRoomChatScreen(
            repository: widget.repository,
            roomId: room.id,
            title: 'Global Chat',
          ),
        ),
      );
      return;
    }
    try {
      final conversationId = await repository.globalConversationId();
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ConversationScreen(
            repository: repository,
            conversation: ChatConversation(
              id: conversationId,
              kind: ChatConversationKind.global,
              title: 'Global Chat',
            ),
          ),
        ),
      );
    } on ChatRepositoryException catch (error) {
      _message(error.message);
    }
  }

  void _openStory(MissionRoom room, List<MissionSubmission> posts, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionFeedScreen(
          repository: widget.repository,
          roomId: room.id,
          initialSubmissionId: posts[index].id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final room = widget.repository.globalRoom;
        if (room == null) {
          return const Scaffold(body: Center(child: Text('글로벌 방을 불러오지 못했어요.')));
        }
        final roomSubmissions = widget.repository.submissionsForRoom(room.id);

        return Scaffold(
          backgroundColor: playfulCream,
          body: SafeArea(
            child: PlayfulBackground(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                        child: PlayfulHeader(
                          title: 'DOIT',
                          titleWidget: const DoitLogo(fontSize: 34),
                          actions: [
                            PlayfulIconButton(
                              buttonKey: const Key('globalRoomChatButton'),
                              tooltip: '글로벌 채팅',
                              icon: Icons.chat_bubble_rounded,
                              iconColor: playfulPurple,
                              size: 50,
                              onPressed: _openGlobalChat,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
                          children: [
                            const Text(
                              'Global Mission Room',
                              style: TextStyle(
                                color: playfulInk,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              width: 72,
                              height: 4,
                              decoration: BoxDecoration(
                                color: playfulPurple,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${room.memberCount}명이 함께 도전 중이에요.',
                              style: const TextStyle(
                                color: playfulInk,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 22),
                            if (room.missions.isEmpty)
                              const _EmptyGlobalMissions()
                            else
                              for (
                                var index = 0;
                                index < room.missions.length;
                                index++
                              ) ...[
                                Builder(
                                  builder: (context) {
                                    final mission = room.missions[index];
                                    final posts = roomSubmissions
                                        .where(
                                          (post) =>
                                              post.missionId == mission.id,
                                        )
                                        .toList();
                                    return _GlobalMissionCard(
                                      number: index + 1,
                                      mission: mission,
                                      posts: posts,
                                      isUserCreated:
                                          mission.createdByUserId ==
                                          widget.repository.previewUserId,
                                      onCapture: () =>
                                          _openCapture(room, mission),
                                      onStoryTap: (postIndex) =>
                                          _openStory(room, posts, postIndex),
                                    );
                                  },
                                ),
                                if (index != room.missions.length - 1)
                                  const SizedBox(height: 22),
                              ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalMissionCard extends StatelessWidget {
  const _GlobalMissionCard({
    required this.number,
    required this.mission,
    required this.posts,
    required this.isUserCreated,
    required this.onCapture,
    required this.onStoryTap,
  });

  final int number;
  final Mission mission;
  final List<MissionSubmission> posts;
  final bool isUserCreated;
  final VoidCallback onCapture;
  final ValueChanged<int> onStoryTap;

  @override
  Widget build(BuildContext context) {
    return PlayfulPanel(
      padding: const EdgeInsets.all(18),
      radius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7D8FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: playfulInk, width: 2.5),
                ),
                child: Text(
                  '$number',
                  style: const TextStyle(
                    color: playfulInk,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUserCreated ? 'USER MISSION' : 'TODAY\'S MISSION',
                      style: const TextStyle(
                        color: playfulPurple,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.title,
                      style: const TextStyle(
                        color: playfulInk,
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              PlayfulIconButton(
                buttonKey: Key('globalCamera$number'),
                tooltip: '이 미션 인증하기',
                fill: const Color(0xFFE4D5FF),
                iconColor: const Color(0xFF3F3766),
                size: 56,
                onPressed: onCapture,
                icon: Icons.camera_alt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Color(0xFF9A79EF), thickness: 2),
          const SizedBox(height: 12),
          Text(
            'MISSION STORIES · ${posts.length}',
            style: const TextStyle(
              color: playfulPurple,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          if (posts.isEmpty)
            const _EmptyMissionStories()
          else
            StoryCardStack(
              submissions: posts,
              height: 190,
              onStoryTap: onStoryTap,
            ),
        ],
      ),
    );
  }
}

class _EmptyGlobalMissions extends StatelessWidget {
  const _EmptyGlobalMissions();

  @override
  Widget build(BuildContext context) {
    return const PlayfulPanel(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('오늘 표시할 미션이 없어요.')),
      ),
    );
  }
}

class _EmptyMissionStories extends StatelessWidget {
  const _EmptyMissionStories();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 104,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: Color(0xFFE9DEFF),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    color: playfulPurple,
                    size: 30,
                  ),
                ),
                Positioned(
                  right: -15,
                  bottom: -4,
                  child: Doodle(
                    kind: DoodleKind.star,
                    color: Color(0xFFFFE457),
                    size: 26,
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            Text(
              '아직 올라온 스토리가 없어요.',
              style: TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
