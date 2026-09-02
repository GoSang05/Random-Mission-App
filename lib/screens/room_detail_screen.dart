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
            await widget.repository.addSubmissionPersisted(
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
        child: FractionallySizedBox(
          heightFactor: .86,
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
                          IconButton(
                            tooltip: '닫기',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      if (history.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
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
                          ),
                        )
                      else
                        Expanded(
                          child: _HistoryByDate(
                            submissions: history,
                            onStoryTap: (submission) {
                              final index = history.indexWhere(
                                (item) => item.id == submission.id,
                              );
                              Navigator.of(context).pop();
                              if (index >= 0) {
                                _openStory(history, index, history: true);
                              }
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
                    value: widget.repository.isRemote ? '설정됨' : room.password!,
                    onCopy: widget.repository.isRemote
                        ? null
                        : () {
                            Clipboard.setData(
                              ClipboardData(text: room.password!),
                            );
                            showAppSnackBar(context, '비밀번호를 복사했어요.');
                          },
                  ),
                ],
                const SizedBox(height: 10),
                _InfoRow(label: '참여 인원', value: '${room.memberCount}명'),
                const SizedBox(height: 20),
                if (!room.isGlobal) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('renameRoomButton'),
                          onPressed: () => _showRenameRoom(room),
                          icon: const Icon(Icons.edit_rounded),
                          label: const Text('이름 수정'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('viewRoomMembersButton'),
                          onPressed: () => _showRoomMembers(room),
                          icon: const Icon(Icons.groups_rounded),
                          label: const Text('멤버 보기'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('leaveRoomButton'),
                      onPressed: () => _confirmLeaveRoom(dialogContext, room),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('방 나가기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD8455D),
                        backgroundColor: const Color(0xFFFFE5EA),
                        side: const BorderSide(color: playfulInk, width: 2.5),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
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

  Future<void> _showRenameRoom(MissionRoom room) async {
    final controller = TextEditingController(text: room.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (renameContext) => AlertDialog(
        backgroundColor: playfulCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: playfulInk, width: 3),
        ),
        title: const Text(
          '방 이름 수정',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          key: const Key('renameRoomField'),
          controller: controller,
          autofocus: true,
          maxLength: LocalMissionRepository.maxRoomNameLength,
          decoration: const InputDecoration(hintText: '새 방 이름'),
          onSubmitted: (value) => Navigator.of(renameContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(renameContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirmRenameRoomButton'),
            onPressed: () => Navigator.of(renameContext).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null || newName.trim().isEmpty || !mounted) return;
    try {
      await widget.repository.renameRoomPersisted(room.id, newName);
      if (mounted) showAppSnackBar(context, '방 이름을 바꿨어요.');
    } on MissionRepositoryException catch (error) {
      if (mounted) showAppSnackBar(context, error.message);
    } on ArgumentError catch (error) {
      if (mounted) showAppSnackBar(context, error.message.toString());
    }
  }

  void _showRoomMembers(MissionRoom room) {
    showDialog<void>(
      context: context,
      builder: (membersContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PlayfulPanel(
            color: playfulCream,
            radius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '함께하는 멤버',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<MissionRoomMember>>(
                  future: widget.repository.listRoomMembers(room.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('멤버 목록을 불러오지 못했어요.'),
                      );
                    }
                    return ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: snapshot.data!.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (context, index) {
                          final member = snapshot.data![index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE8DCFF),
                              child: Text(member.displayName.characters.first),
                            ),
                            title: Text(
                              member.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            trailing: member.isOwner
                                ? const Chip(label: Text('방장'))
                                : null,
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(membersContext).pop(),
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeaveRoom(
    BuildContext settingsContext,
    MissionRoom room,
  ) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (confirmContext) => AlertDialog(
        backgroundColor: playfulCream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: const BorderSide(color: playfulInk, width: 3),
        ),
        title: const Text(
          '방에서 나갈까요?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '${room.name}에서 나가면 다시 참여하려면 방 코드가 필요해요.',
          style: const TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const Key('confirmLeaveRoomButton'),
            onPressed: () => Navigator.of(confirmContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD8455D),
              foregroundColor: Colors.white,
            ),
            child: const Text('나가기'),
          ),
        ],
      ),
    );
    if (shouldLeave != true || !mounted) return;
    try {
      await widget.repository.leaveRoomPersisted(room.id);
      if (!mounted) return;
      if (settingsContext.mounted) Navigator.of(settingsContext).pop();
      Navigator.of(context).pop();
    } on MissionRepositoryException catch (error) {
      if (mounted) showAppSnackBar(context, error.message);
    }
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
                          bareBackButton: true,
                          actions: [
                            PlayfulIconButton(
                              buttonKey: const Key('roomChatButton'),
                              tooltip: '방 채팅',
                              icon: Icons.chat_bubble_rounded,
                              iconColor: playfulPurple,
                              size: 48,
                              bare: true,
                              onPressed: () => _openChat(room),
                            ),
                            PlayfulIconButton(
                              buttonKey: const Key('roomHistoryButton'),
                              tooltip: '지난 사진',
                              icon: Icons.history_rounded,
                              iconColor: playfulPurple,
                              size: 48,
                              bare: true,
                              onPressed: () => _showHistory(room),
                            ),
                            PlayfulIconButton(
                              buttonKey: const Key('roomSettingsButton'),
                              tooltip: '방 설정',
                              icon: Icons.settings_rounded,
                              iconColor: playfulPurple,
                              size: 48,
                              bare: true,
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

class _HistoryByDate extends StatelessWidget {
  const _HistoryByDate({required this.submissions, required this.onStoryTap});

  final List<MissionSubmission> submissions;
  final ValueChanged<MissionSubmission> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<MissionSubmission>>{};
    for (final submission in submissions) {
      final created = submission.createdAt.toLocal();
      final date = DateTime(created.year, created.month, created.day);
      grouped.putIfAbsent(date, () => []).add(submission);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.separated(
      key: const Key('roomHistoryDateList'),
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: dates.length,
      separatorBuilder: (_, _) => const SizedBox(height: 24),
      itemBuilder: (context, index) {
        final date = dates[index];
        final dateSubmissions = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _historyDateLabel(date),
              key: Key('historyDate_${date.year}_${date.month}_${date.day}'),
              style: const TextStyle(
                color: playfulInk,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: .78,
              ),
              itemCount: dateSubmissions.length,
              itemBuilder: (context, photoIndex) {
                final submission = dateSubmissions[photoIndex];
                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: Key('historyPhoto_${submission.id}'),
                    onTap: () => onStoryTap(submission),
                    child: MissionPhoto(submission: submission),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  String _historyDateLabel(DateTime date) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.year}년 ${date.month}월 ${date.day}일 '
        '(${weekdays[date.weekday - 1]})';
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
