import 'package:flutter/material.dart';

import '../data/local_mission_repository.dart';
import '../data/local_media_store.dart';
import '../data/chat_repository.dart';
import '../models/chat_data.dart';
import '../models/mission_data.dart';
import '../utils/app_snackbar.dart';
import '../widgets/doit_logo.dart';
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
          appBar: AppBar(
            title: const DoitLogo(fontSize: 24),
            actions: [
              IconButton(
                key: const Key('globalRoomChatButton'),
                tooltip: '글로벌 채팅',
                onPressed: _openGlobalChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Global Mission Room',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 5),
                        Text('${room.memberCount}명이 함께 도전 중이에요.'),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _DailyMissionNotice(),
                    const SizedBox(height: 20),
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
                                .where((post) => post.missionId == mission.id)
                                .toList();
                            return _GlobalMissionCard(
                              number: index + 1,
                              mission: mission,
                              posts: posts,
                              isUserCreated:
                                  mission.createdByUserId ==
                                  widget.repository.previewUserId,
                              onCapture: () => _openCapture(room, mission),
                              onStoryTap: (postIndex) =>
                                  _openStory(room, posts, postIndex),
                            );
                          },
                        ),
                        if (index != room.missions.length - 1)
                          const SizedBox(height: 14),
                      ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DailyMissionNotice extends StatelessWidget {
  const _DailyMissionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dailyMissionNotice'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF24212B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.today_rounded, color: Color(0xFFFFD580)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '모든 사용자에게 같은 미션이 표시되며 매일 자동으로 바뀌어요.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    '$number',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUserCreated ? 'USER MISSION' : 'TODAY\'S MISSION',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mission.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: Key('globalCamera$number'),
                  tooltip: '이 미션 인증하기',
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'MISSION STORIES · ${posts.length}',
              style: TextStyle(
                color: colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            StoryCardStack(
              submissions: posts,
              height: 190,
              onStoryTap: onStoryTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGlobalMissions extends StatelessWidget {
  const _EmptyGlobalMissions();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('오늘 표시할 미션이 없어요.')),
      ),
    );
  }
}
