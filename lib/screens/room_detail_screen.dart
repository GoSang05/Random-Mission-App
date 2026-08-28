import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../data/local_media_store.dart';
import '../data/local_mission_repository.dart';
import '../models/chat_data.dart';
import '../models/mission_data.dart';
import '../utils/app_snackbar.dart';
import '../widgets/story_card_stack.dart';
import 'capture_screen.dart';
import 'conversation_screen.dart';
import 'local_room_chat_screen.dart';
import 'mission_feed_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
    required this.repository,
    required this.roomId,
    this.chatRepository,
    super.key,
  });

  final LocalMissionRepository repository;
  final String roomId;
  final ChatRepository? chatRepository;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final LocalMediaStore _mediaStore = LocalMediaStore();

  Future<void> _openCapture(Mission mission) async {
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
              roomId: widget.roomId,
              missionId: mission.id,
              localPath: savedPath,
              mediaKind: MissionMediaKind.photo,
            );
            onProgress(1);
          },
        ),
      ),
    );
    if (saved == true && mounted) {
      showAppSnackBar(context, '사진을 오늘의 스토리에 저장했어요.');
    }
  }

  void _openStory(
    List<MissionSubmission> submissions,
    int index, {
    bool history = false,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionFeedScreen(
          repository: widget.repository,
          roomId: widget.roomId,
          initialSubmissionId: submissions[index].id,
          history: history,
        ),
      ),
    );
  }

  Future<void> _openChat(MissionRoom room) async {
    final remote = widget.chatRepository;
    if (remote == null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => LocalRoomChatScreen(
            repository: widget.repository,
            roomId: room.id,
            title: '${room.name} 채팅',
          ),
        ),
      );
      return;
    }

    try {
      final id = await remote.ensureRoomConversation(room);
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ConversationScreen(
            repository: remote,
            conversation: ChatConversation(
              id: id,
              kind: ChatConversationKind.room,
              title: '${room.name} 채팅',
            ),
          ),
        ),
      );
    } on ChatRepositoryException catch (error) {
      if (mounted) showAppSnackBar(context, error.message);
    }
  }

  void _showHistory(MissionRoom room) {
    final history = widget.repository.submissionHistoryForRoom(room.id);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('지난 사진', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('아직 지난 기록이 없어요.')),
                )
              else
                SizedBox(
                  height: 360,
                  child: StoryCardStack(
                    submissions: history,
                    height: 330,
                    onStoryTap: (index) {
                      Navigator.of(context).pop();
                      _openStory(history, index, history: true);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettings(MissionRoom room) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('방 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              label: '방 코드',
              value: room.code ?? '-',
              onCopy: room.code == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: room.code!));
                      showAppSnackBar(context, '방 코드를 복사했어요.');
                    },
            ),
            if (room.isLocked) ...[
              const Divider(),
              _InfoRow(
                label: '비밀번호',
                value: room.password!,
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: room.password!));
                  showAppSnackBar(context, '비밀번호를 복사했어요.');
                },
              ),
            ],
            const Divider(),
            _InfoRow(label: '참여 인원', value: '${room.memberCount}명'),
          ],
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final room = widget.repository.roomById(widget.roomId);
        if (room == null) {
          return const Scaffold(body: Center(child: Text('방을 찾을 수 없어요.')));
        }
        final submissions = widget.repository.submissionsForRoom(room.id);
        return Scaffold(
          appBar: AppBar(
            title: Text(room.name),
            actions: [
              IconButton(
                key: const Key('roomChatButton'),
                tooltip: '방 채팅',
                onPressed: () => _openChat(room),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              IconButton(
                key: const Key('roomHistoryButton'),
                tooltip: '지난 사진',
                onPressed: () => _showHistory(room),
                icon: const Icon(Icons.history_rounded),
              ),
              IconButton(
                key: const Key('roomSettingsButton'),
                tooltip: '방 설정',
                onPressed: () => _showSettings(room),
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _SectionHeader(
                      title: '오늘의 미션',
                      count: room.missions.length,
                    ),
                    const SizedBox(height: 12),
                    for (final mission in room.missions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MissionCard(
                          mission: mission,
                          onCamera: () => _openCapture(mission),
                        ),
                      ),
                    const SizedBox(height: 22),
                    _SectionHeader(
                      title: '오늘 올라온 사진',
                      count: submissions.length,
                    ),
                    const SizedBox(height: 10),
                    StoryCardStack(
                      submissions: submissions,
                      height: 260,
                      onStoryTap: (index) => _openStory(submissions, index),
                    ),
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

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onCamera});

  final Mission mission;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mission.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
            IconButton.filledTonal(
              key: Key('roomCamera_${mission.id}'),
              tooltip: '사진으로 인증하기',
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (onCopy != null)
          IconButton(
            tooltip: '$label 복사',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
      ],
    );
  }
}
