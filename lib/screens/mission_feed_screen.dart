import 'package:flutter/material.dart';

import '../data/local_mission_repository.dart';
import '../models/mission_data.dart';
import '../widgets/mission_photo.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';

class MissionFeedScreen extends StatefulWidget {
  const MissionFeedScreen({
    required this.repository,
    required this.roomId,
    required this.initialSubmissionId,
    this.history = false,
    this.allJoinedPrivateRooms = false,
    super.key,
  });

  final LocalMissionRepository repository;
  final String roomId;
  final String initialSubmissionId;
  final bool history;
  final bool allJoinedPrivateRooms;

  @override
  State<MissionFeedScreen> createState() => _MissionFeedScreenState();
}

class _MissionFeedScreenState extends State<MissionFeedScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final submissions = _submissions();
    final initial = submissions.indexWhere(
      (submission) => submission.id == widget.initialSubmissionId,
    );
    _currentIndex = initial < 0 ? 0 : initial;
    _pageController = PageController(initialPage: _currentIndex);
  }

  List<MissionSubmission> _submissions() {
    if (widget.allJoinedPrivateRooms) {
      return widget.repository.recentPrivateSubmissions;
    }
    return widget.history
        ? widget.repository.submissionHistoryForRoom(widget.roomId)
        : widget.repository.submissionsForRoom(widget.roomId);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index, int total) {
    if (index < 0 || index >= total || !_pageController.hasClients) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final submissions = _submissions();
        if (submissions.isEmpty) {
          return Scaffold(
            backgroundColor: playfulCream,
            body: PlayfulBackground(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: PlayfulHeader(title: '스토리'),
                    ),
                    const Expanded(child: Center(child: Text('표시할 스토리가 없어요.'))),
                  ],
                ),
              ),
            ),
          );
        }

        _currentIndex = _currentIndex.clamp(0, submissions.length - 1);
        return Scaffold(
          backgroundColor: playfulCream,
          body: PlayfulBackground(
            child: PageView.builder(
              key: const Key('missionStoryPageView'),
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              itemCount: submissions.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final submission = submissions[index];
                final room = widget.repository.roomById(submission.roomId);
                final mission = widget.repository.missionById(
                  submission.roomId,
                  submission.missionId,
                );
                return _StoryPage(
                  roomName: room?.name ?? '미션 방',
                  missionTitle: mission?.title ?? '미션',
                  submission: submission,
                  position: index + 1,
                  total: submissions.length,
                  onBack: () => Navigator.of(context).pop(),
                  onPrevious: index == 0
                      ? null
                      : () => _goToPage(index - 1, submissions.length),
                  onNext: index == submissions.length - 1
                      ? null
                      : () => _goToPage(index + 1, submissions.length),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StoryPage extends StatefulWidget {
  const _StoryPage({
    required this.roomName,
    required this.missionTitle,
    required this.submission,
    required this.position,
    required this.total,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
  });

  final String roomName;
  final String missionTitle;
  final MissionSubmission submission;
  final int position;
  final int total;
  final VoidCallback onBack;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage> {
  bool _longPressRecognized = false;

  void _handleTapDown(TapDownDetails _) {
    _longPressRecognized = false;
  }

  void _handleTapUp(TapUpDetails details, double width) {
    if (_longPressRecognized) {
      _longPressRecognized = false;
      return;
    }
    if (details.localPosition.dx <= width / 3) {
      widget.onPrevious?.call();
    } else if (details.localPosition.dx >= width * 2 / 3) {
      widget.onNext?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = widget.submission;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5D4FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: playfulInk, width: 3),
                      boxShadow: const [
                        BoxShadow(color: playfulInk, offset: Offset(0, 5)),
                      ],
                    ),
                    child: BackButton(
                      color: playfulInk,
                      onPressed: widget.onBack,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: playfulInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      '${widget.position}/${widget.total}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: playfulInk,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: playfulInk, width: 3),
                boxShadow: const [
                  BoxShadow(color: playfulInk, offset: Offset(0, 5)),
                ],
              ),
              child: Row(
                children: [
                  const Doodle(
                    kind: DoodleKind.sparkle,
                    color: playfulPurple,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.missionTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: playfulInk,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Doodle(
                    kind: DoodleKind.sparkle,
                    color: playfulLime,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    key: const Key('storyTapArea'),
                    behavior: HitTestBehavior.opaque,
                    onTapDown: _handleTapDown,
                    onTapUp: (details) =>
                        _handleTapUp(details, constraints.maxWidth),
                    onLongPressStart: (_) => _longPressRecognized = true,
                    onLongPressEnd: (_) {},
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: playfulInk, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0xFFCAB6FF),
                            offset: Offset(6, 7),
                          ),
                          BoxShadow(color: playfulInk, offset: Offset(0, 5)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(23),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MissionPhoto(
                              submission: submission,
                              borderRadius: 0,
                              showAuthor: false,
                            ),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.transparent,
                                    Color(0xB8000000),
                                  ],
                                  stops: [0, .58, 1],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 18,
                              child: Column(
                                children: [
                                  Text(
                                    submission.authorName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black,
                                          blurRadius: 5,
                                          offset: Offset(1, 2),
                                        ),
                                      ],
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
