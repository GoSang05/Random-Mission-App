import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/chat_repository.dart';
import '../data/local_media_store.dart';
import '../data/local_mission_repository.dart';
import '../models/chat_data.dart';
import '../models/mission_data.dart';
import '../utils/app_snackbar.dart';
import '../widgets/mission_photo.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';
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
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (context) => SafeArea(
        minimum: const EdgeInsets.all(12),
        child: PlayfulPanel(
          color: playfulCream,
          radius: 30,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: PlayfulBackground(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Doodle(
                          kind: DoodleKind.star,
                          color: Color(0xFFFF8FB3),
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '지난 사진',
                            style: TextStyle(
                              color: playfulInk,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        PlayfulIconButton(
                          icon: Icons.close_rounded,
                          tooltip: '닫기',
                          size: 42,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 34),
                        child: Column(
                          children: [
                            Doodle(
                              kind: DoodleKind.sparkle,
                              color: playfulPurple,
                              size: 38,
                            ),
                            SizedBox(height: 14),
                            Text(
                              '아직 지난 기록이 없어요.',
                              style: TextStyle(
                                color: Colors.black45,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
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
          ),
        ),
      ),
    );
  }

  void _showSettings(MissionRoom room) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: PlayfulPanel(
            color: playfulCream,
            radius: 30,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Doodle(kind: DoodleKind.star, color: playfulLime, size: 30),
                    SizedBox(width: 10),
                    Text(
                      '방 설정',
                      style: TextStyle(
                        color: playfulInk,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                  const SizedBox(height: 10),
                  _InfoRow(
                    label: '비밀번호',
                    value: room.password!,
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: room.password!));
                      showAppSnackBar(context, '비밀번호를 복사했어요.');
                    },
                  ),
                ],
                const SizedBox(height: 10),
                _InfoRow(label: '참여 인원', value: '${room.memberCount}명'),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: playfulLime,
                      foregroundColor: playfulInk,
                      side: const BorderSide(color: playfulInk, width: 2.5),
                    ),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
          ),
        ),
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
          backgroundColor: playfulCream,
          body: SafeArea(
            child: PlayfulBackground(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                        child: PlayfulHeader(
                          title: room.name,
                          actions: [
                            PlayfulIconButton(
                              buttonKey: const Key('roomChatButton'),
                              tooltip: '방 채팅',
                              icon: Icons.chat_bubble_rounded,
                              iconColor: playfulPurple,
                              size: 48,
                              onPressed: () => _openChat(room),
                            ),
                            PlayfulIconButton(
                              buttonKey: const Key('roomHistoryButton'),
                              tooltip: '지난 사진',
                              icon: Icons.history_rounded,
                              iconColor: playfulPurple,
                              size: 48,
                              onPressed: () => _showHistory(room),
                            ),
                            PlayfulIconButton(
                              buttonKey: const Key('roomSettingsButton'),
                              tooltip: '방 설정',
                              icon: Icons.settings_rounded,
                              iconColor: playfulPurple,
                              size: 48,
                              onPressed: () => _showSettings(room),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 38),
                          children: [
                            PlayfulSectionHeader(
                              title: '오늘의 미션',
                              count: room.missions.length,
                            ),
                            const SizedBox(height: 16),
                            for (
                              var index = 0;
                              index < room.missions.length;
                              index++
                            )
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _MissionCard(
                                  mission: room.missions[index],
                                  decorationIndex: index,
                                  onCamera: () =>
                                      _openCapture(room.missions[index]),
                                ),
                              ),
                            const SizedBox(height: 18),
                            PlayfulSectionHeader(
                              title: '오늘 올라온 사진',
                              count: submissions.length,
                            ),
                            const SizedBox(height: 16),
                            _RoomStoryGrid(
                              submissions: submissions,
                              onStoryTap: (index) =>
                                  _openStory(submissions, index),
                            ),
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

class _MissionCard extends StatelessWidget {
  const _MissionCard({
    required this.mission,
    required this.decorationIndex,
    required this.onCamera,
  });

  final Mission mission;
  final int decorationIndex;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return PlayfulPanel(
      padding: const EdgeInsets.fromLTRB(16, 11, 10, 11),
      radius: 24,
      child: SizedBox(
        height: 58,
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.bolt_rounded, color: playfulPurple, size: 42),
                Positioned(
                  left: decorationIndex.isEven ? -12 : 28,
                  bottom: -13,
                  child: Doodle(
                    kind: decorationIndex.isEven
                        ? DoodleKind.star
                        : DoodleKind.sparkle,
                    color: decorationIndex.isEven
                        ? playfulLime
                        : const Color(0xFFFF8FB3),
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                mission.title,
                style: const TextStyle(
                  color: playfulInk,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PlayfulIconButton(
              buttonKey: Key('roomCamera_${mission.id}'),
              tooltip: '사진으로 인증하기',
              fill: const Color(0xFFE4D5FF),
              iconColor: const Color(0xFF3F3766),
              size: 52,
              onPressed: onCamera,
              icon: Icons.camera_alt_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomStoryGrid extends StatelessWidget {
  const _RoomStoryGrid({required this.submissions, required this.onStoryTap});

  final List<MissionSubmission> submissions;
  final ValueChanged<int> onStoryTap;

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return PlayfulPanel(
        child: SizedBox(
          height: 150,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Doodle(
                  kind: DoodleKind.star,
                  color: Color(0xFFFF8FB3),
                  size: 42,
                ),
                const SizedBox(height: 12),
                Text(
                  '아직 올라온 사진이 없어요.',
                  style: TextStyle(
                    color: playfulInk.withValues(alpha: .55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(submissions.length, (index) {
            return Container(
              width: width,
              height: width * 1.12,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: playfulInk, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFD0BEFF), offset: Offset(5, 6)),
                  BoxShadow(color: playfulInk, offset: Offset(0, 4)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(21),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: Key('storyStackCard$index'),
                  onTap: () => onStoryTap(index),
                  child: MissionPhoto(
                    submission: submissions[index],
                    borderRadius: 0,
                  ),
                ),
              ),
            );
          }),
        );
      },
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: playfulInk, width: 2.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: playfulInk,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (onCopy != null)
            PlayfulIconButton(
              tooltip: '$label 복사',
              icon: Icons.copy_rounded,
              iconColor: playfulPurple,
              size: 40,
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}
