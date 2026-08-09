import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/mission_post.dart';
import '../models/mission_room.dart';
import '../widgets/mission_photo.dart';
import 'mission_feed_screen.dart';

class RoomDetailScreen extends StatelessWidget {
  const RoomDetailScreen({required this.room, super.key});

  final MissionRoom room;

  List<MissionPost> get _posts => const [
    MissionPost(
      author: '민수',
      mission: '예쁜 장소에서 음료 마시기',
      emoji: '🥤',
      startColor: Color(0xFF8DC4E8),
      endColor: Color(0xFF31526E),
      sadCount: 4,
      heartCount: 12,
    ),
    MissionPost(
      author: '지윤',
      mission: '신발샷 모으기',
      emoji: '👟',
      startColor: Color(0xFFC5889E),
      endColor: Color(0xFF4C3047),
      sadCount: 2,
      heartCount: 9,
    ),
    MissionPost(
      author: '현우',
      mission: '노란색 물건 찾아오기',
      emoji: '🌼',
      startColor: Color(0xFFF7C95D),
      endColor: Color(0xFF9B6C25),
      sadCount: 1,
      heartCount: 7,
    ),
    MissionPost(
      author: '서연',
      mission: '영화 포스터처럼 찍기',
      emoji: '🎬',
      startColor: Color(0xFF8684B9),
      endColor: Color(0xFF272644),
      sadCount: 3,
      heartCount: 15,
    ),
  ];

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: room.code));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('방 코드를 복사했어요.')));
  }

  void _openPost(BuildContext context, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MissionFeedScreen(
          roomName: room.name,
          posts: _posts,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final missionItems = [
      room.mission,
      '친구의 미션 사진에 반응 남기기',
      '오늘의 단체 사진 한 장 찍기',
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          room.name,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: '방 코드 복사',
            onPressed: () => _copyCode(context),
            icon: const Icon(Icons.ios_share_rounded),
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
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ActionChip(
                            avatar: Icon(
                              room.isLocked
                                  ? Icons.lock_rounded
                                  : Icons.key_rounded,
                              size: 17,
                            ),
                            label: Text(
                              '${room.code} · ${room.memberCount}명',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            onPressed: () => _copyCode(context),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(20),
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
                              Row(
                                children: [
                                  Text(
                                    '오늘의 미션',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.black38,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              for (final mission in missionItems)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 9),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: const EdgeInsets.only(
                                          top: 7,
                                          right: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          mission,
                                          style: const TextStyle(
                                            height: 1.45,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
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
                              '좌우로 넘겨보기',
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverGrid.builder(
                    itemCount: _posts.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        key: Key('missionPost$index'),
                        onTap: () => _openPost(context, index),
                        child: Hero(
                          tag: 'mission-post-$index',
                          child: MissionPhoto(post: _posts[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사진 인증 기능은 다음 단계에서 연결할게요.')),
          );
        },
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('인증하기'),
      ),
    );
  }
}
