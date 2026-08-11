import 'dart:math';

import 'package:flutter/material.dart';

import '../models/mission_post.dart';
import '../models/mission_room.dart';
import '../theme/app_theme.dart';
import '../widgets/doit_logo.dart';
import '../widgets/story_card_stack.dart';
import 'global_missions_screen.dart';
import 'mission_feed_screen.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  static const _codeCharacters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _missions = [
    '영화 포스터처럼 단체 사진 찍기',
    '각자 3,000원 이하 간식 하나 골라오기',
    '빨간색 물건 5개 찾아서 인증하기',
    '평소 가지 않던 길로 함께 산책하기',
    '서로에게 가장 안 어울리는 음료 골라주기',
  ];

  final Random _random = Random();
  final List<MissionRoom> _rooms = [
    MissionRoom(
      name: '야식단',
      code: 'FRI824',
      emoji: '🚕',
      mission: '각자 3,000원 이하 간식 하나 골라오기',
      memberCount: 4,
      isJoined: true,
    ),
    MissionRoom(
      name: '탐험대',
      code: 'CAMPUS',
      emoji: '🚕',
      mission: '빨간색 물건 5개 찾아서 인증하기',
      password: '1234',
      memberCount: 3,
      isJoined: true,
    ),
    MissionRoom(
      name: '산책 클럽',
      code: 'WALK77',
      emoji: '🌿',
      mission: '평소 가지 않던 길로 함께 산책하기',
      memberCount: 2,
    ),
  ];
  final Map<String, List<MissionPost>> _postsByRoom = {
    'FRI824': [
      const MissionPost(
        author: '민수',
        mission: '각자 3,000원 이하 간식 하나 골라오기',
        emoji: '🍪',
        startColor: Color(0xFFF0A56B),
        endColor: Color(0xFF7E4935),
        sadCount: 3,
        heartCount: 11,
      ),
      const MissionPost(
        author: '서연',
        mission: '오늘의 단체 사진 한 장 찍기',
        emoji: '📸',
        startColor: Color(0xFF8684B9),
        endColor: Color(0xFF272644),
        sadCount: 2,
        heartCount: 14,
      ),
    ],
    'CAMPUS': [
      const MissionPost(
        author: '지윤',
        mission: '빨간색 물건 5개 찾아서 인증하기',
        emoji: '🔴',
        startColor: Color(0xFFE78A94),
        endColor: Color(0xFF6D2A3A),
        sadCount: 1,
        heartCount: 8,
      ),
      const MissionPost(
        author: '현우',
        mission: '친구의 미션 사진에 반응 남기기',
        emoji: '🙌',
        startColor: Color(0xFF73B8A8),
        endColor: Color(0xFF285B57),
        sadCount: 4,
        heartCount: 10,
      ),
    ],
    'WALK77': [
      const MissionPost(
        author: '유진',
        mission: '평소 가지 않던 길로 함께 산책하기',
        emoji: '🌿',
        startColor: Color(0xFFA7C985),
        endColor: Color(0xFF3F6648),
        sadCount: 0,
        heartCount: 6,
      ),
    ],
  };

  List<MissionRoom> get _joinedRooms =>
      _rooms.where((room) => room.isJoined).toList();

  List<({MissionRoom room, MissionPost post, int index})> get _homeStories {
    final stories = <({MissionRoom room, MissionPost post, int index})>[];
    for (final room in _joinedRooms) {
      final posts = _postsByRoom[room.code] ?? const <MissionPost>[];
      for (var index = 0; index < posts.length; index++) {
        stories.add((room: room, post: posts[index], index: index));
      }
    }
    return stories;
  }

  String _createUniqueCode() {
    String code;
    do {
      code = List.generate(
        6,
        (_) => _codeCharacters[_random.nextInt(_codeCharacters.length)],
      ).join();
    } while (_rooms.any((room) => room.code == code));
    return code;
  }

  Future<void> _showCreateRoomDialog() async {
    final result = await showDialog<_CreateRoomResult>(
      context: context,
      builder: (context) => const _CreateRoomDialog(),
    );

    if (result == null || !mounted) return;

    final room = MissionRoom(
      name: result.name,
      code: _createUniqueCode(),
      emoji: ['🚀', '🎉', '🔥', '✨'][_random.nextInt(4)],
      mission: _missions[_random.nextInt(_missions.length)],
      password: result.password,
      memberCount: 1,
      isJoined: true,
    );

    setState(() {
      _rooms.insert(0, room);
      _postsByRoom[room.code] = [];
    });
    _showMessage('${room.name} 방을 만들었어요. 코드: ${room.code}');
  }

  Future<void> _showJoinRoomDialog() async {
    final result = await showDialog<_JoinRoomResult>(
      context: context,
      builder: (context) => const _JoinRoomDialog(),
    );

    if (result == null || !mounted) return;

    final roomIndex = _rooms.indexWhere(
      (room) => room.code == result.code.toUpperCase(),
    );

    if (roomIndex == -1) {
      _showMessage('일치하는 방이 없어요. 코드를 다시 확인해주세요.');
      return;
    }

    final room = _rooms[roomIndex];
    if (room.isJoined) {
      _showMessage('이미 참여 중인 방이에요.');
      return;
    }

    if (room.isLocked && room.password != result.password) {
      _showMessage('비밀번호가 맞지 않아요.');
      return;
    }

    setState(() {
      room.isJoined = true;
      room.memberCount += 1;
    });
    _showMessage('${room.name} 방에 참여했어요!');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openRoom(MissionRoom room) {
    final posts = _postsByRoom.putIfAbsent(room.code, () => []);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => RoomDetailScreen(
          room: room,
          posts: posts,
          onPostsChanged: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  void _openHomeStory(MissionRoom room, List<MissionPost> posts, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MissionFeedScreen(
          roomName: room.name,
          posts: posts,
          initialIndex: index,
        ),
      ),
    );
  }

  void _openGlobalMissions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const GlobalMissionsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('rooms'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                18,
                AppSpacing.page,
                40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _HomeHeader(),
                  const SizedBox(height: 24),
                  _GlobalMissionBanner(onTap: _openGlobalMissions),
                  const SizedBox(height: AppSpacing.item),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          actionKey: const Key('joinRoomButton'),
                          icon: Icons.key_rounded,
                          title: '코드로 참여',
                          subtitle: '초대 코드 입력',
                          onTap: _showJoinRoomDialog,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.item),
                      Expanded(
                        child: _QuickActionCard(
                          actionKey: const Key('createRoomButton'),
                          icon: Icons.add_rounded,
                          title: '새 방 만들기',
                          subtitle: '친구들과 시작',
                          emphasized: true,
                          onTap: _showCreateRoomDialog,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.section),
                  _SectionHeader(
                    title: 'My Rooms',
                    subtitle: '참여 중인 미션 방',
                    count: _joinedRooms.length,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 124,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _joinedRooms.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        if (index == _joinedRooms.length) {
                          return _CreateRoomTile(onTap: _showCreateRoomDialog);
                        }
                        final room = _joinedRooms[index];
                        return _RoomTile(
                          room: room,
                          onTap: () => _openRoom(room),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  const _SectionHeader(
                    title: 'Friends Stories',
                    subtitle: '친구들이 남긴 오늘의 순간',
                  ),
                  const SizedBox(height: 18),
                  StoryCardStack(
                    key: const Key('homeStories'),
                    posts: [for (final story in _homeStories) story.post],
                    height: 244,
                    onStoryTap: (index) {
                      final story = _homeStories[index];
                      _openHomeStory(
                        story.room,
                        _postsByRoom[story.room.code]!,
                        story.index,
                      );
                    },
                  ),
                ],
              ),
            ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        const DoitLogo(fontSize: 31),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('오늘도 한 번 해볼까요?', style: theme.textTheme.labelLarge),
            Text(
              '친구들과 새로운 미션을 시작해요',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: const Icon(Icons.person_rounded),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.actionKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final Key actionKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final background = emphasized ? colorScheme.primary : Colors.white;
    final foreground = emphasized
        ? colorScheme.onPrimary
        : colorScheme.onSurface;

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(
          color: emphasized ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: emphasized
                      ? Colors.white.withValues(alpha: 0.16)
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.small),
                ),
                child: Icon(
                  icon,
                  color: emphasized
                      ? colorScheme.onPrimary
                      : colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.count,
  });

  final String title;
  final String subtitle;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlobalMissionBanner extends StatelessWidget {
  const _GlobalMissionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.large),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('globalMissionButton'),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary,
                Color.lerp(colorScheme.primary, colorScheme.secondary, 0.72)!,
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -22,
                top: -28,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              'WEEKLY CHALLENGE',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Global Missions',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '모두와 같은 미션에 도전하고\n새로운 이야기를 남겨보세요.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(
                        Icons.public_rounded,
                        size: 30,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, required this.onTap});

  final MissionRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final useSecondary = room.code.codeUnitAt(0).isEven;
    final tileColor = useSecondary
        ? colorScheme.secondaryContainer
        : colorScheme.primaryContainer;
    final tileForeground = useSecondary
        ? colorScheme.onSecondaryContainer
        : colorScheme.onPrimaryContainer;

    return SizedBox(
      width: 92,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('roomTile_${room.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Column(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: tileForeground.withValues(alpha: 0.08),
                  ),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(room.emoji, style: const TextStyle(fontSize: 32)),
                    if (room.isLocked)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 23,
                          height: 23,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.82),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 13,
                            color: tileForeground,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 7),
              Text(
                room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateRoomTile extends StatelessWidget {
  const _CreateRoomTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Material(
            color: colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              side: BorderSide(color: colorScheme.outlineVariant, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 82,
                height: 82,
                child: Icon(
                  Icons.add_rounded,
                  size: 29,
                  color: colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '새 방',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateRoomResult {
  const _CreateRoomResult({required this.name, this.password});

  final String name;
  final String? password;
}

class _CreateRoomDialog extends StatefulWidget {
  const _CreateRoomDialog();

  @override
  State<_CreateRoomDialog> createState() => _CreateRoomDialogState();
}

class _CreateRoomDialogState extends State<_CreateRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _usePassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _CreateRoomResult(
        name: _nameController.text.trim(),
        password: _usePassword ? _passwordController.text : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 방 만들기'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('roomNameField'),
                controller: _nameController,
                autofocus: true,
                maxLength: 20,
                decoration: const InputDecoration(
                  labelText: '방 이름',
                  hintText: '예: 주말 탐험대',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '방 이름을 입력해주세요.';
                  }
                  return null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('비밀번호 설정'),
                subtitle: const Text('초대받은 친구만 들어올 수 있어요.'),
                value: _usePassword,
                onChanged: (value) => setState(() => _usePassword = value),
              ),
              if (_usePassword)
                TextFormField(
                  key: const Key('roomPasswordField'),
                  controller: _passwordController,
                  obscureText: true,
                  maxLength: 12,
                  decoration: const InputDecoration(labelText: '비밀번호'),
                  validator: (value) {
                    if (_usePassword && (value == null || value.length < 4)) {
                      return '비밀번호는 4자 이상 입력해주세요.';
                    }
                    return null;
                  },
                ),
            ],
          ),
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

class _JoinRoomResult {
  const _JoinRoomResult({required this.code, required this.password});

  final String code;
  final String password;
}

class _JoinRoomDialog extends StatefulWidget {
  const _JoinRoomDialog();

  @override
  State<_JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<_JoinRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _JoinRoomResult(
        code: _codeController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('코드로 참여'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('roomCodeField'),
              controller: _codeController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6자리 방 코드',
                hintText: 'ABC123',
              ),
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return '방 코드 6자리를 입력해주세요.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              key: const Key('joinPasswordField'),
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호 (있는 경우)'),
            ),
          ],
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
