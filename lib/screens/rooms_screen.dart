import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../data/local_mission_repository.dart';
import '../models/mission_data.dart';
import '../theme/app_theme.dart';
import '../widgets/doit_logo.dart';
import '../widgets/story_card_stack.dart';
import 'global_missions_screen.dart';
import 'mission_feed_screen.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({required this.repository, this.chatRepository, super.key});

  final LocalMissionRepository repository;
  final ChatRepository? chatRepository;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.initialize();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createRoom() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateRoomDialog(),
    );
    if (name == null || !mounted) return;

    try {
      final room = widget.repository.createRoom(name);
      final chatRepository = widget.chatRepository;
      if (chatRepository != null) {
        await chatRepository.ensureRoomConversation(room);
      }
      _message('${room.name} 방을 만들었어요. 초대 코드: ${room.code}');
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    } on ChatRepositoryException catch (error) {
      _message('${error.message} 방을 열면 다시 연결을 시도해요.');
    }
  }

  Future<void> _joinRoom() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _JoinRoomDialog(),
    );
    if (code == null || !mounted) return;

    final localResult = widget.repository.joinRoom(code);
    final chatRepository = widget.chatRepository;
    if (chatRepository == null) {
      _message(switch (localResult) {
        JoinRoomResult.joined => '방에 참여했어요!',
        JoinRoomResult.alreadyJoined => '이미 참여 중인 방이에요.',
        JoinRoomResult.invalidCode => '영문과 숫자로 된 코드를 확인해주세요.',
        JoinRoomResult.roomNotFound => '일치하는 방을 찾지 못했어요.',
      });
      return;
    }

    if (localResult == JoinRoomResult.invalidCode) {
      _message('영문과 숫자로 된 코드를 확인해주세요.');
      return;
    }
    try {
      final joined = await chatRepository.joinRoomByCode(code);
      widget.repository.importJoinedRoom(
        id: joined.roomId,
        name: joined.roomName,
        code: joined.inviteCode,
        memberCount: joined.memberCount,
      );
      _message(
        localResult == JoinRoomResult.alreadyJoined
            ? '이미 참여 중인 방이에요.'
            : '방에 참여했어요!',
      );
    } on ChatRepositoryException catch (error) {
      _message(error.message);
    }
  }

  void _openRoom(MissionRoom room) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomDetailScreen(
          repository: widget.repository,
          chatRepository: widget.chatRepository,
          roomId: room.id,
        ),
      ),
    );
  }

  void _openStory(MissionSubmission submission) {
    final room = widget.repository.roomById(submission.roomId);
    if (room == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionFeedScreen(
          repository: widget.repository,
          roomId: room.id,
          initialSubmissionId: submission.id,
        ),
      ),
    );
  }

  void _openGlobalRoom() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GlobalMissionsScreen(repository: widget.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        return switch (widget.repository.status) {
          RepositoryStatus.idle ||
          RepositoryStatus.loading => const _HomeLoading(),
          RepositoryStatus.error => _HomeError(
            message: widget.repository.errorMessage,
            onRetry: widget.repository.initialize,
          ),
          RepositoryStatus.ready => _buildHome(),
        };
      },
    );
  }

  Widget _buildHome() {
    final rooms = widget.repository.joinedRooms;
    final stories = widget.repository.recentPrivateSubmissions;

    return Scaffold(
      key: const ValueKey('rooms'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                18,
                AppSpacing.page,
                40,
              ),
              children: [
                const _HomeHeader(),
                const SizedBox(height: 16),
                const _PreviewNotice(),
                const SizedBox(height: 16),
                _GlobalMissionBanner(onTap: _openGlobalRoom),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        buttonKey: const Key('joinRoomButton'),
                        icon: Icons.key_rounded,
                        label: '코드로 참여',
                        onTap: _joinRoom,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        buttonKey: const Key('createRoomButton'),
                        icon: Icons.add_rounded,
                        label: '새 방 만들기',
                        primary: true,
                        onTap: _createRoom,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                _SectionTitle(title: 'My Rooms', count: rooms.length),
                const SizedBox(height: 14),
                if (rooms.isEmpty)
                  _EmptyRooms(onCreate: _createRoom)
                else
                  SizedBox(
                    height: 116,
                    child: ListView.separated(
                      key: const Key('roomsList'),
                      scrollDirection: Axis.horizontal,
                      itemCount: rooms.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, index) {
                        final room = rooms[index];
                        return _RoomTile(
                          room: room,
                          onTap: () => _openRoom(room),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 30),
                _SectionTitle(title: 'Friends Stories', count: stories.length),
                const SizedBox(height: 12),
                StoryCardStack(
                  key: const Key('homeStories'),
                  submissions: stories,
                  height: 238,
                  onStoryTap: (index) => _openStory(stories[index]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeLoading extends StatelessWidget {
  const _HomeLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: Key('homeLoading'),
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _HomeError extends StatelessWidget {
  const _HomeError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('homeError'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 14),
              Text(message ?? '미션을 불러오지 못했어요.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const DoitLogo(fontSize: 31),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '오늘도 한 번 해볼까요?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.person_rounded),
        ),
      ],
    );
  }
}

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('previewModeNotice'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4D8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '로컬 MVP 미리보기 · 앱을 닫으면 미션 데이터가 초기화돼요.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalMissionBanner extends StatelessWidget {
  const _GlobalMissionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('globalMissionButton'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GLOBAL MISSION ROOM',
                      style: TextStyle(
                        color: colors.onPrimary.withValues(alpha: 0.72),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '모두와 오늘의 미션 도전하기',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: colors.onPrimary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.public_rounded, color: colors.onPrimary, size: 38),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: colors.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return primary
        ? FilledButton.icon(
            key: buttonKey,
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            key: buttonKey,
            onPressed: onTap,
            icon: Icon(icon),
            label: Text(label),
          );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});

  final MissionRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 126,
      child: Card(
        child: InkWell(
          key: Key('roomTile_${room.code}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.groups_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const Spacer(),
                Text(
                  room.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  '${room.memberCount}명',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Text('아직 참여 중인 방이 없어요.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onCreate, child: const Text('첫 방 만들기')),
          ],
        ),
      ),
    );
  }
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 방 만들기'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('roomNameField'),
          controller: _controller,
          autofocus: true,
          maxLength: LocalMissionRepository.maxRoomNameLength,
          decoration: const InputDecoration(labelText: '방 이름'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? '방 이름을 입력해주세요.' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirmCreateRoomButton'),
          onPressed: _submit,
          child: const Text('방 만들기'),
        ),
      ],
    );
  }
}

class _JoinRoomDialog extends StatefulWidget {
  const _JoinRoomDialog();

  @override
  State<_JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<_JoinRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('코드로 참여'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('roomCodeField'),
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 12,
          decoration: const InputDecoration(hintText: '예: NIGHT7'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? '초대 코드를 입력해주세요.' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirmJoinRoomButton'),
          onPressed: _submit,
          child: const Text('참여하기'),
        ),
      ],
    );
  }
}
