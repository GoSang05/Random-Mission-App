import 'package:flutter/material.dart';

import '../data/local_mission_repository.dart';
import '../models/mission_data.dart';
import '../widgets/doit_logo.dart';
import '../widgets/story_card_stack.dart';
import 'capture_screen.dart';
import 'mission_feed_screen.dart';

class GlobalMissionsScreen extends StatefulWidget {
  const GlobalMissionsScreen({required this.repository, super.key});

  final LocalMissionRepository repository;

  @override
  State<GlobalMissionsScreen> createState() => _GlobalMissionsScreenState();
}

class _GlobalMissionsScreenState extends State<GlobalMissionsScreen> {
  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _createMission() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateMissionDialog(),
    );
    if (title == null || !mounted) return;
    try {
      widget.repository.createGlobalMission(title);
      _message('새 글로벌 미션을 등록했어요.');
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    }
  }

  Future<void> _openCapture(MissionRoom room, Mission mission) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CaptureScreen(
          missionTitle: mission.title,
          onSave: (result, onProgress) async {
            // ponytail: staged local progress; use Storage progress after backend approval.
            onProgress(0.2);
            await Future<void>.delayed(const Duration(milliseconds: 120));
            onProgress(0.7);
            widget.repository.addSubmission(
              roomId: room.id,
              missionId: mission.id,
              localPath: result.path,
              mediaKind: result.kind,
            );
            onProgress(1);
          },
        ),
      ),
    );
    if (saved == true && mounted) _message('글로벌 스토리에 인증을 저장했어요.');
  }

  void _openStory(MissionRoom room, List<MissionSubmission> posts, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionFeedScreen(
          repository: widget.repository,
          roomId: room.id,
          initialSubmissionId: posts[index].id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final room = widget.repository.globalRoom;
        if (room == null) {
          return const Scaffold(body: Center(child: Text('글로벌 방을 불러오지 못했어요.')));
        }
        final roomSubmissions = widget.repository.submissionsForRoom(room.id);

        return Scaffold(
          appBar: AppBar(title: const DoitLogo(fontSize: 24)),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Global Mission Room',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 5),
                              Text('${room.memberCount}명이 함께 도전 중이에요.'),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          key: const Key('createGlobalMissionButton'),
                          onPressed: _createMission,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('미션 만들기'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _AiMissionNotice(),
                    const SizedBox(height: 20),
                    if (room.missions.isEmpty)
                      const _EmptyGlobalMissions()
                    else
                      for (
                        var index = 0;
                        index < room.missions.length;
                        index++
                      ) ...[
                        Builder(
                          builder: (context) {
                            final mission = room.missions[index];
                            final posts = roomSubmissions
                                .where((post) => post.missionId == mission.id)
                                .toList();
                            return _GlobalMissionCard(
                              number: index + 1,
                              mission: mission,
                              posts: posts,
                              isUserCreated:
                                  mission.createdByUserId ==
                                  widget.repository.previewUserId,
                              onCapture: () => _openCapture(room, mission),
                              onStoryTap: (postIndex) =>
                                  _openStory(room, posts, postIndex),
                            );
                          },
                        ),
                        if (index != room.missions.length - 1)
                          const SizedBox(height: 14),
                      ],
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

class _AiMissionNotice extends StatelessWidget {
  const _AiMissionNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('futureAiMissionNotice'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF24212B),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFD580)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'AI 미션 추천은 제공업체와 보안 방식이 승인된 뒤 연결됩니다.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalMissionCard extends StatelessWidget {
  const _GlobalMissionCard({
    required this.number,
    required this.mission,
    required this.posts,
    required this.isUserCreated,
    required this.onCapture,
    required this.onStoryTap,
  });

  final int number;
  final Mission mission;
  final List<MissionSubmission> posts;
  final bool isUserCreated;
  final VoidCallback onCapture;
  final ValueChanged<int> onStoryTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    '$number',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUserCreated ? 'USER MISSION' : 'TODAY\'S MISSION',
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mission.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: Key('globalCamera$number'),
                  tooltip: '이 미션 인증하기',
                  onPressed: onCapture,
                  icon: const Icon(Icons.camera_alt_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'MISSION STORIES · ${posts.length}',
              style: TextStyle(
                color: colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            StoryCardStack(
              submissions: posts,
              height: 190,
              onStoryTap: onStoryTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyGlobalMissions extends StatelessWidget {
  const _EmptyGlobalMissions();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('아직 공개 미션이 없어요. 첫 미션을 만들어보세요.')),
      ),
    );
  }
}

class _CreateMissionDialog extends StatefulWidget {
  const _CreateMissionDialog();

  @override
  State<_CreateMissionDialog> createState() => _CreateMissionDialogState();
}

class _CreateMissionDialogState extends State<_CreateMissionDialog> {
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
      title: const Text('글로벌 미션 만들기'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('globalMissionTitleField'),
          controller: _controller,
          autofocus: true,
          maxLength: LocalMissionRepository.maxMissionTitleLength,
          maxLines: 3,
          decoration: const InputDecoration(hintText: '예: 오늘 가장 재미있는 간판 찍기'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? '미션 내용을 입력해주세요.' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          key: const Key('confirmGlobalMissionButton'),
          onPressed: _submit,
          child: const Text('등록하기'),
        ),
      ],
    );
  }
}
