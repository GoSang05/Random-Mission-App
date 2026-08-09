import 'dart:math';

import 'package:flutter/material.dart';

import '../models/mission_post.dart';
import '../models/mission_room.dart';
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      key: const ValueKey('rooms'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
              children: [
                const Center(child: DoitLogo()),
                const SizedBox(height: 30),
                _GlobalMissionBanner(onTap: _openGlobalMissions),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Text(
                      'My Rooms',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${_joinedRooms.length}',
                        style: TextStyle(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('joinRoomButton'),
                      tooltip: '코드로 참여',
                      onPressed: _showJoinRoomDialog,
                      icon: const Icon(Icons.key_rounded),
                    ),
                    IconButton.filled(
                      key: const Key('createRoomButton'),
                      tooltip: '새 방 만들기',
                      onPressed: _showCreateRoomDialog,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 112,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _joinedRooms.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 13),
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
                const SizedBox(height: 34),
                Text(
                  'Friends Stories',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                StoryCardStack(
                  key: const Key('homeStories'),
                  posts: [for (final story in _homeStories) story.post],
                  height: 226,
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
    );
  }
}

class _GlobalMissionBanner extends StatelessWidget {
  const _GlobalMissionBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('globalMissionButton'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Global Missions',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '모두와 같은 미션에 도전하기',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.72,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Text('📷', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 7),
              Icon(
                Icons.arrow_forward_rounded,
                color: colorScheme.onPrimaryContainer,
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
    return SizedBox(
      width: 82,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('roomTile_${room.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E1E8),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(room.emoji, style: const TextStyle(fontSize: 30)),
                    if (room.isLocked)
                      const Positioned(
                        top: 8,
                        right: 8,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 14,
                          color: Colors.black45,
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
                style: const TextStyle(
                  fontSize: 12,
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
    return SizedBox(
      width: 82,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFFD8D5E2)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: const SizedBox(
                width: 72,
                height: 72,
                child: Icon(Icons.add_rounded, size: 29),
              ),
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '새 방',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                  border: OutlineInputBorder(),
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
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
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
                border: OutlineInputBorder(),
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
              decoration: const InputDecoration(
                labelText: '비밀번호 (있는 경우)',
                border: OutlineInputBorder(),
              ),
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
