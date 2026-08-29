import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'dart:async';
import 'dart:io';

import '../data/chat_repository.dart';
import '../data/local_mission_repository.dart';
import '../data/local_media_store.dart';
import '../data/local_profile_store.dart';
import '../models/mission_data.dart';
import '../utils/app_snackbar.dart';
import '../widgets/doit_logo.dart';
import '../widgets/mission_photo.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';
import 'global_missions_screen.dart';
import 'mission_feed_screen.dart';
import 'room_detail_screen.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({
    required this.repository,
    this.chatRepository,
    this.displayName = '나',
    this.isGuest = false,
    this.onSignOut,
    this.profileStorageScope = 'preview',
    super.key,
  });

  final LocalMissionRepository repository;
  final ChatRepository? chatRepository;
  final String displayName;
  final bool isGuest;
  final Future<void> Function()? onSignOut;
  final String profileStorageScope;

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  late String _displayName = widget.displayName;
  String? _avatarPath;
  late final LocalProfileStore _profileStore = LocalProfileStore(
    widget.profileStorageScope,
  );
  final LocalMediaStore _mediaStore = LocalMediaStore();
  Timer? _dailyRefreshTimer;

  @override
  void initState() {
    super.initState();
    widget.repository.initialize();
    _loadProfile();
    _scheduleDailyRefresh();
  }

  void _scheduleDailyRefresh() {
    _dailyRefreshTimer?.cancel();
    final utcNow = DateTime.now().toUtc();
    final koreaNow = utcNow.add(const Duration(hours: 9));
    final nextKoreaMidnight = DateTime.utc(
      koreaNow.year,
      koreaNow.month,
      koreaNow.day + 1,
    );
    final nextUtc = nextKoreaMidnight.subtract(const Duration(hours: 9));
    _dailyRefreshTimer = Timer(nextUtc.difference(utcNow), () {
      widget.repository.refreshDailyMissionsIfNeeded();
      _scheduleDailyRefresh();
    });
  }

  @override
  void dispose() {
    _dailyRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _profileStore.load();
    if (profile == null || !mounted) return;
    widget.repository.updatePreviewUserName(profile.displayName);
    setState(() {
      _displayName = profile.displayName;
      _avatarPath = profile.avatarPath;
    });
  }

  void _message(String text) {
    showAppSnackBar(context, text);
  }

  Future<void> _createRoom() async {
    final input = await showDialog<_CreateRoomInput>(
      context: context,
      builder: (_) => const _CreateRoomDialog(),
    );
    if (input == null || !mounted) return;

    try {
      final room = widget.repository.createRoom(
        input.name,
        password: input.password,
      );
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
    final input = await showDialog<_JoinRoomInput>(
      context: context,
      builder: (_) => const _JoinRoomDialog(),
    );
    if (input == null || !mounted) return;

    final code = input.code;
    final localResult = widget.repository.joinRoom(
      code,
      password: input.password,
    );
    final chatRepository = widget.chatRepository;
    if (chatRepository == null) {
      _message(switch (localResult) {
        JoinRoomResult.joined => '방에 참여했어요!',
        JoinRoomResult.alreadyJoined => '이미 참여 중인 방이에요.',
        JoinRoomResult.invalidCode => '영문과 숫자로 된 코드를 확인해주세요.',
        JoinRoomResult.wrongPassword => '방 비밀번호가 일치하지 않아요.',
        JoinRoomResult.roomNotFound => '일치하는 방을 찾지 못했어요.',
      });
      return;
    }

    if (localResult == JoinRoomResult.invalidCode ||
        localResult == JoinRoomResult.wrongPassword) {
      _message(
        localResult == JoinRoomResult.wrongPassword
            ? '방 비밀번호가 일치하지 않아요.'
            : '영문과 숫자로 된 코드를 확인해주세요.',
      );
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
        builder: (_) => GlobalMissionsScreen(
          repository: widget.repository,
          chatRepository: widget.chatRepository,
        ),
      ),
    );
  }

  Future<void> _showProfileSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (sheetContext) => SafeArea(
        minimum: const EdgeInsets.all(12),
        child: PlayfulPanel(
          color: playfulCream,
          radius: 30,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: PlayfulBackground(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Doodle(
                          kind: DoodleKind.star,
                          color: playfulLime,
                          size: 30,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            '설정',
                            style: TextStyle(
                              color: playfulInk,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        PlayfulIconButton(
                          icon: Icons.close_rounded,
                          tooltip: '닫기',
                          size: 42,
                          onPressed: () => Navigator.of(sheetContext).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: playfulInk, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFD4C2FF),
                            offset: Offset(4, 5),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: ListTile(
                          key: const Key('profileIdentityTile'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5D4FF),
                              shape: BoxShape.circle,
                              border: Border.all(color: playfulInk, width: 2),
                            ),
                            child: _ProfileAvatar(path: _avatarPath),
                          ),
                          title: Text(
                            _displayName,
                            style: const TextStyle(
                              color: playfulInk,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(
                            widget.isGuest ? 'Guest 모드' : '로그인 계정',
                            style: const TextStyle(
                              color: playfulPurple,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.edit_rounded,
                            color: playfulPurple,
                          ),
                          onTap: () => _editNickname(sheetContext),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: playfulInk, width: 2.5),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 3,
                          ),
                          leading: const Icon(
                            Icons.add_a_photo_rounded,
                            color: playfulPurple,
                            size: 29,
                          ),
                          title: const Text(
                            '프로필 사진 변경',
                            style: TextStyle(
                              color: playfulInk,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          trailing: const Doodle(
                            kind: DoodleKind.sparkle,
                            color: Color(0xFFFF8FB3),
                            size: 22,
                          ),
                          onTap: () => _changeProfilePhoto(sheetContext),
                        ),
                      ),
                    ),
                    if (widget.onSignOut != null) ...[
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        key: const Key('profileSignOutButton'),
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await widget.onSignOut!();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFD8E3),
                          foregroundColor: playfulInk,
                          side: const BorderSide(color: playfulInk, width: 2.5),
                        ),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('로그아웃'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editNickname(BuildContext sheetContext) async {
    final controller = TextEditingController(text: _displayName);
    final value = await showDialog<String>(
      context: context,
      barrierColor: Colors.black45,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PlayfulPanel(
            color: playfulCream,
            radius: 30,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Doodle(
                      kind: DoodleKind.heart,
                      color: Color(0xFFFF8FB3),
                      size: 29,
                    ),
                    SizedBox(width: 10),
                    Text(
                      '닉네임 변경',
                      style: TextStyle(
                        color: playfulInk,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  key: const Key('profileNicknameField'),
                  controller: controller,
                  autofocus: true,
                  maxLength: 40,
                  decoration: InputDecoration(
                    hintText: '닉네임',
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: playfulInk,
                        width: 2.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(
                        color: playfulPurple,
                        width: 3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: playfulInk,
                          side: const BorderSide(color: playfulInk, width: 2.5),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const Key('saveProfileNicknameButton'),
                        onPressed: () =>
                            Navigator.of(context).pop(controller.text.trim()),
                        style: FilledButton.styleFrom(
                          backgroundColor: playfulLime,
                          foregroundColor: playfulInk,
                          side: const BorderSide(color: playfulInk, width: 2.5),
                        ),
                        child: const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (value == null || value.isEmpty || !mounted) return;
    widget.repository.updatePreviewUserName(value);
    setState(() => _displayName = value);
    await _saveProfile();
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  }

  Future<void> _changeProfilePhoto(BuildContext sheetContext) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final path = await _mediaStore.persist(
      sourcePath: picked.path,
      kind: MissionMediaKind.photo,
    );
    if (!mounted) return;
    setState(() => _avatarPath = path);
    await _saveProfile();
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
  }

  Future<void> _saveProfile() => _profileStore.save(
    LocalProfile(displayName: _displayName, avatarPath: _avatarPath),
  );

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
      backgroundColor: playfulCream,
      body: SafeArea(
        child: CustomPaint(
          painter: const PlayfulDotBackground(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 42),
                children: [
                  _HomeHeader(
                    onProfileTap: _showProfileSettings,
                    avatarPath: _avatarPath,
                  ),
                  const SizedBox(height: 18),
                  _GlobalMissionBanner(onTap: _openGlobalRoom),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final join = _QuickAction(
                        buttonKey: const Key('joinRoomButton'),
                        icon: Icons.key_rounded,
                        label: '코드로 참여',
                        onTap: _joinRoom,
                      );
                      final create = _QuickAction(
                        buttonKey: const Key('createRoomButton'),
                        icon: Icons.add_rounded,
                        label: '새 방 만들기',
                        primary: true,
                        onTap: _createRoom,
                      );
                      if (constraints.maxWidth < 340) {
                        return Column(
                          children: [join, const SizedBox(height: 12), create],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: join),
                          const SizedBox(width: 12),
                          Expanded(child: create),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _SectionTitle(title: 'My Rooms', count: rooms.length),
                  const SizedBox(height: 12),
                  if (rooms.isEmpty)
                    _EmptyRooms(onCreate: _createRoom)
                  else
                    SizedBox(
                      height: 184,
                      child: ListView.separated(
                        key: const Key('roomsList'),
                        scrollDirection: Axis.horizontal,
                        itemCount: rooms.length,
                        clipBehavior: Clip.none,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, index) {
                          final room = rooms[index];
                          return _RoomTile(
                            room: room,
                            variant: index,
                            onTap: () => _openRoom(room),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 28),
                  _SectionTitle(
                    title: 'Friends Stories',
                    count: stories.length,
                  ),
                  const SizedBox(height: 12),
                  _FriendsStoriesGrid(
                    key: const Key('homeStories'),
                    submissions: stories,
                    onStoryTap: (index) => _openStory(stories[index]),
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
  const _HomeHeader({required this.onProfileTap, this.avatarPath});

  final VoidCallback onProfileTap;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const _PlayfulLogo(),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '오늘도 한 번 해볼까요?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: playfulInk,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: const Color(0xFFEAD7FF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: playfulInk, width: 3),
          ),
          child: InkWell(
            key: const Key('profileSettingsButton'),
            borderRadius: BorderRadius.circular(16),
            onTap: onProfileTap,
            child: SizedBox.square(
              dimension: 54,
              child: Center(
                child: _ProfileAvatar(path: avatarPath, radius: 15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayfulLogo extends StatelessWidget {
  const _PlayfulLogo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const DoitLogo(fontSize: 43),
        const Positioned(
          left: 31,
          top: 15,
          child: Doodle(kind: DoodleKind.star, color: playfulLime, size: 17),
        ),
        const Positioned(
          right: -18,
          bottom: 2,
          child: Doodle(kind: DoodleKind.sparkle, size: 14),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: playfulInk, offset: Offset(0, 7))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7658F0), Color(0xFF4939C7)],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: playfulInk, width: 3),
          ),
          child: InkWell(
            key: const Key('globalMissionButton'),
            onTap: onTap,
            child: SizedBox(
              height: 164,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Positioned(
                        right: -8,
                        top: 5,
                        bottom: -3,
                        width: constraints.maxWidth * .48,
                        child: const GlobalMissionIllustration(),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          constraints.maxWidth < 370 ? 20 : 26,
                          30,
                          constraints.maxWidth * .38,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'GLOBAL MISSION ROOM',
                              style: TextStyle(
                                color: Color(0xFFDCCFFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '모두와\n오늘의 미션 도전하기',
                              maxLines: 2,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: constraints.maxWidth < 370 ? 21 : 24,
                                height: 1.22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.2,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x66000000),
                                    offset: Offset(2, 3),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 15,
                        bottom: 14,
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(
                              BorderSide(color: playfulInk, width: 3),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: playfulInk,
                            size: 27,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
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
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: primary ? playfulLime : playfulCream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: playfulInk, width: 3),
        boxShadow: const [BoxShadow(color: playfulInk, offset: Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: buttonKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: primary ? playfulInk : playfulPurple, size: 29),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: playfulInk,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: playfulInk,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 2),
              Transform.rotate(
                angle: -.08,
                child: Container(
                  margin: const EdgeInsets.only(left: 2),
                  width: 46,
                  height: 4,
                  decoration: BoxDecoration(
                    color: playfulPurple,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE9D8FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: playfulInk, width: 2.5),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: playfulInk,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({
    required this.room,
    required this.variant,
    required this.onTap,
  });

  final MissionRoom room;
  final int variant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 146,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: playfulInk, width: 3),
        boxShadow: const [BoxShadow(color: playfulInk, offset: Offset(0, 5))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(25),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('roomTile_${room.code}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RoomIllustration(variant: variant),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0x33000000),
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: playfulPurple,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            room.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: playfulInk,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '♙ ${room.memberCount}명',
                            style: const TextStyle(
                              color: playfulInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Doodle(
                      kind: variant.isEven ? DoodleKind.star : DoodleKind.heart,
                      color: variant.isEven
                          ? const Color(0xFFFFE457)
                          : const Color(0xFFFF8FB3),
                      size: 24,
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

class _EmptyRooms extends StatelessWidget {
  const _EmptyRooms({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: playfulInk, width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            const Text('아직 참여 중인 방이 없어요.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                backgroundColor: playfulLime,
                foregroundColor: playfulInk,
              ),
              child: const Text('첫 방 만들기'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendsStoriesGrid extends StatelessWidget {
  const _FriendsStoriesGrid({
    required this.submissions,
    required this.onStoryTap,
    super.key,
  });

  final List<MissionSubmission> submissions;
  final ValueChanged<int> onStoryTap;

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return Container(
        height: 126,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .75),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: playfulInk, width: 3),
        ),
        child: const Center(
          child: Text(
            '아직 새로운 스토리가 없어요',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = constraints.maxWidth < 360 ? 10.0 : 14.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        final itemHeight = itemWidth * .76;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(submissions.length, (index) {
            return SizedBox(
              width: itemWidth,
              height: itemHeight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: playfulInk, width: 3),
                  boxShadow: const [
                    BoxShadow(color: playfulInk, offset: Offset(0, 5)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
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
              ),
            );
          }),
        );
      },
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
  final _passwordController = TextEditingController();
  bool _isPrivate = false;

  @override
  void dispose() {
    _controller.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _CreateRoomInput(
        name: _controller.text.trim(),
        password: _isPrivate ? _passwordController.text.trim() : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('새 방 만들기'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const Key('roomNameField'),
              controller: _controller,
              autofocus: true,
              maxLength: LocalMissionRepository.maxRoomNameLength,
              decoration: const InputDecoration(labelText: '방 이름'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? '방 이름을 입력해주세요.'
                  : null,
            ),
            SwitchListTile(
              key: const Key('privateRoomSwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('비밀 방'),
              subtitle: const Text('입장할 때 비밀번호가 필요해요.'),
              value: _isPrivate,
              onChanged: (value) => setState(() => _isPrivate = value),
            ),
            if (_isPrivate)
              TextFormField(
                key: const Key('roomPasswordField'),
                controller: _passwordController,
                obscureText: true,
                maxLength: 40,
                decoration: const InputDecoration(labelText: '입장 비밀번호'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? '비밀번호를 입력해주세요.'
                    : null,
                onFieldSubmitted: (_) => _submit(),
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
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      _JoinRoomInput(
        code: _controller.text.trim(),
        password: _passwordController.text.trim(),
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
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              maxLength: 12,
              decoration: const InputDecoration(hintText: '예: NIGHT7'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? '초대 코드를 입력해주세요.'
                  : null,
            ),
            TextFormField(
              key: const Key('joinRoomPasswordField'),
              controller: _passwordController,
              obscureText: true,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '비밀번호 (비밀 방인 경우)'),
              onFieldSubmitted: (_) => _submit(),
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

class _CreateRoomInput {
  const _CreateRoomInput({required this.name, this.password});

  final String name;
  final String? password;
}

class _JoinRoomInput {
  const _JoinRoomInput({required this.code, required this.password});

  final String code;
  final String password;
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({this.path, this.radius = 20});

  final String? path;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    return CircleAvatar(
      radius: radius,
      backgroundImage: path == null ? null : FileImage(File(path)),
      child: path == null ? const Icon(Icons.person_rounded) : null,
    );
  }
}
