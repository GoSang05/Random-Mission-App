import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/mission_post.dart';
import '../widgets/doit_logo.dart';
import '../widgets/story_card_stack.dart';
import 'mission_feed_screen.dart';

class GlobalMissionsScreen extends StatefulWidget {
  const GlobalMissionsScreen({super.key});

  @override
  State<GlobalMissionsScreen> createState() => _GlobalMissionsScreenState();
}

class _GlobalMissionsScreenState extends State<GlobalMissionsScreen> {
  static const _missions = [
    ('하늘에서 가장 마음에 드는 색 찾기', '📷', '오늘 자정까지'),
    ('5,000원으로 가장 이상한 물건 찾기', '🛍️', '이번 주 일요일까지'),
    ('친구에게 뜬금없는 칭찬 보내기', '💌', '오늘 자정까지'),
  ];

  final ImagePicker _imagePicker = ImagePicker();
  final List<List<MissionPost>> _missionPosts = [
    [
      const MissionPost(
        author: '수아',
        mission: '하늘에서 가장 마음에 드는 색 찾기',
        emoji: '🌤️',
        startColor: Color(0xFF77BFEA),
        endColor: Color(0xFF416B95),
        sadCount: 1,
        heartCount: 18,
      ),
      const MissionPost(
        author: '도윤',
        mission: '하늘에서 가장 마음에 드는 색 찾기',
        emoji: '🌇',
        startColor: Color(0xFFF39A79),
        endColor: Color(0xFF73456D),
        sadCount: 2,
        heartCount: 14,
      ),
      const MissionPost(
        author: '하린',
        mission: '하늘에서 가장 마음에 드는 색 찾기',
        emoji: '☁️',
        startColor: Color(0xFFB8D4E8),
        endColor: Color(0xFF6B7B96),
        sadCount: 0,
        heartCount: 9,
      ),
    ],
    [
      const MissionPost(
        author: '지훈',
        mission: '5,000원으로 가장 이상한 물건 찾기',
        emoji: '🧸',
        startColor: Color(0xFFE6B36F),
        endColor: Color(0xFF79553D),
        sadCount: 5,
        heartCount: 21,
      ),
      const MissionPost(
        author: '예린',
        mission: '5,000원으로 가장 이상한 물건 찾기',
        emoji: '🕶️',
        startColor: Color(0xFF9A8DC0),
        endColor: Color(0xFF403756),
        sadCount: 3,
        heartCount: 12,
      ),
      const MissionPost(
        author: '민재',
        mission: '5,000원으로 가장 이상한 물건 찾기',
        emoji: '🪩',
        startColor: Color(0xFF8FC6BC),
        endColor: Color(0xFF315D5E),
        sadCount: 2,
        heartCount: 16,
      ),
    ],
    [
      const MissionPost(
        author: '서아',
        mission: '친구에게 뜬금없는 칭찬 보내기',
        emoji: '💬',
        startColor: Color(0xFFE89AAE),
        endColor: Color(0xFF82445F),
        sadCount: 1,
        heartCount: 24,
      ),
      const MissionPost(
        author: '태오',
        mission: '친구에게 뜬금없는 칭찬 보내기',
        emoji: '💛',
        startColor: Color(0xFFF1C961),
        endColor: Color(0xFF9B713A),
        sadCount: 0,
        heartCount: 19,
      ),
      const MissionPost(
        author: '유나',
        mission: '친구에게 뜬금없는 칭찬 보내기',
        emoji: '🥰',
        startColor: Color(0xFFC28FB7),
        endColor: Color(0xFF67426E),
        sadCount: 2,
        heartCount: 17,
      ),
    ],
  ];

  Future<void> _takeMissionPhoto(int missionIndex) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (photo == null || !mounted) return;

      setState(() {
        _missionPosts[missionIndex].insert(
          0,
          MissionPost(
            author: '나',
            mission: _missions[missionIndex].$1,
            emoji: '📸',
            startColor: const Color(0xFF8E86D8),
            endColor: const Color(0xFF433A7A),
            sadCount: 0,
            heartCount: 0,
            imagePath: photo.path,
          ),
        );
      });

      _showMessage('촬영한 사진을 미션 스토리에 올렸어요.');
    } catch (_) {
      if (mounted) _showMessage('카메라를 열지 못했어요. 권한을 확인해주세요.');
    }
  }

  void _openStory(int missionIndex, int postIndex) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MissionFeedScreen(
          roomName: 'Global Mission ${missionIndex + 1}',
          posts: _missionPosts[missionIndex],
          initialIndex: postIndex,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const DoitLogo(fontSize: 24)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Text(
              'Global Missions',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '모두가 같은 미션을 어떻게 즐겼는지 확인해보세요.',
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 24),
            for (var index = 0; index < _missions.length; index++) ...[
              _GlobalMissionCard(
                number: index + 1,
                title: _missions[index].$1,
                emoji: _missions[index].$2,
                due: _missions[index].$3,
                posts: _missionPosts[index],
                onCameraTap: () => _takeMissionPhoto(index),
                onStoryTap: (postIndex) => _openStory(index, postIndex),
              ),
              if (index != _missions.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlobalMissionCard extends StatelessWidget {
  const _GlobalMissionCard({
    required this.number,
    required this.title,
    required this.emoji,
    required this.due,
    required this.posts,
    required this.onCameraTap,
    required this.onStoryTap,
  });

  final int number;
  final String title;
  final String emoji;
  final String due;
  final List<MissionPost> posts;
  final VoidCallback onCameraTap;
  final ValueChanged<int> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 25)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MISSION $number',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(due, style: const TextStyle(color: Colors.black45)),
                  ],
                ),
              ),
              IconButton.filledTonal(
                key: Key('globalCamera$number'),
                tooltip: '이 미션 사진 촬영',
                onPressed: onCameraTap,
                icon: const Icon(Icons.camera_alt_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Text(
            'MISSION STORIES',
            style: TextStyle(
              color: colorScheme.primary,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          StoryCardStack(posts: posts, height: 178, onStoryTap: onStoryTap),
        ],
      ),
    );
  }
}
