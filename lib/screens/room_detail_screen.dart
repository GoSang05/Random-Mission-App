import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/mission_post.dart';
import '../models/mission_room.dart';
import '../widgets/story_card_stack.dart';
import 'mission_feed_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
    required this.room,
    required this.posts,
    required this.onPostsChanged,
    super.key,
  });

  final MissionRoom room;
  final List<MissionPost> posts;
  final VoidCallback onPostsChanged;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  List<String> get _missionItems => [
    widget.room.mission,
    '친구의 미션 사진에 반응 남기기',
    '오늘의 단체 사진 한 장 찍기',
  ];

  Future<void> _takeMissionPhoto(String mission) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null || !mounted) return;

      setState(() {
        widget.posts.insert(
          0,
          MissionPost(
            author: '나',
            mission: mission,
            emoji: '📸',
            startColor: const Color(0xFF8E86D8),
            endColor: const Color(0xFF433A7A),
            sadCount: 0,
            heartCount: 0,
            imagePath: photo.path,
          ),
        );
      });
      widget.onPostsChanged();
      _showMessage('촬영한 사진을 이 미션에 올렸어요.');
    } catch (_) {
      if (mounted) _showMessage('카메라를 열지 못했어요. 권한을 확인해주세요.');
    }
  }

  void _copyText(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    _showMessage('$label을 복사했어요.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showRoomSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => _RoomSettingsDialog(
        room: widget.room,
        onCopyCode: () => _copyText('방 코드', widget.room.code),
        onCopyPassword: widget.room.password == null
            ? null
            : () => _copyText('비밀번호', widget.room.password!),
      ),
    );
  }

  void _openPost(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MissionFeedScreen(
          roomName: widget.room.name,
          posts: widget.posts,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.room.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            key: const Key('roomSettingsButton'),
            tooltip: '방 설정',
            onPressed: _showRoomSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 18, 14, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '오늘의 미션',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 10),
                              for (
                                var index = 0;
                                index < _missionItems.length;
                                index++
                              )
                                _RoomMissionRow(
                                  key: Key('roomMission$index'),
                                  mission: _missionItems[index],
                                  color: colorScheme.primary,
                                  onCameraTap: () =>
                                      _takeMissionPhoto(_missionItems[index]),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            Text(
                              '친구들의 새 사진',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.posts.length}개',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
                if (widget.posts.isEmpty)
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          '아직 사진이 없어요.\n미션 옆 카메라로 첫 사진을 남겨보세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black45, height: 1.5),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    sliver: SliverToBoxAdapter(
                      child: StoryCardStack(
                        posts: widget.posts,
                        height: 290,
                        onStoryTap: _openPost,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomMissionRow extends StatelessWidget {
  const _RoomMissionRow({
    required this.mission,
    required this.color,
    required this.onCameraTap,
    super.key,
  });

  final String mission;
  final Color color;
  final VoidCallback onCameraTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              mission,
              style: const TextStyle(height: 1.4, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.filledTonal(
            tooltip: '이 미션 사진 촬영',
            onPressed: onCameraTap,
            icon: const Icon(Icons.camera_alt_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}

class _RoomSettingsDialog extends StatelessWidget {
  const _RoomSettingsDialog({
    required this.room,
    required this.onCopyCode,
    required this.onCopyPassword,
  });

  final MissionRoom room;
  final VoidCallback onCopyCode;
  final VoidCallback? onCopyPassword;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_rounded),
          SizedBox(width: 9),
          Text('방 설정'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SettingsInfoRow(label: '방 코드', value: room.code, onCopy: onCopyCode),
          const Divider(height: 1),
          _SettingsInfoRow(
            label: '비밀번호',
            value: room.password ?? '설정 안 함',
            onCopy: onCopyPassword,
          ),
          const Divider(height: 1),
          _SettingsInfoRow(label: '참여 인원', value: '${room.memberCount}명'),
        ],
      ),
      actions: [
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  const _SettingsInfoRow({
    required this.label,
    required this.value,
    this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
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
              icon: const Icon(Icons.copy_rounded, size: 20),
            ),
        ],
      ),
    );
  }
}
