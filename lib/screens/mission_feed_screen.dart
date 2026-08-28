import 'package:flutter/material.dart';

import '../data/local_mission_repository.dart';
import '../models/mission_data.dart';
import '../widgets/mission_photo.dart';
import '../utils/app_snackbar.dart';

class MissionFeedScreen extends StatefulWidget {
  const MissionFeedScreen({
    required this.repository,
    required this.roomId,
    required this.initialSubmissionId,
    this.history = false,
    super.key,
  });

  final LocalMissionRepository repository;
  final String roomId;
  final String initialSubmissionId;
  final bool history;

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

  List<MissionSubmission> _submissions() => widget.history
      ? widget.repository.submissionHistoryForRoom(widget.roomId)
      : widget.repository.submissionsForRoom(widget.roomId);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _vote(MissionSubmission submission, VoteChoice choice) {
    final changed = widget.repository.castVote(submission.id, choice);
    if (!changed) {
      showAppSnackBar(context, '이미 같은 선택으로 투표했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final room = widget.repository.roomById(widget.roomId);
        final submissions = _submissions();
        if (room == null || submissions.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('표시할 스토리가 없어요.')),
          );
        }

        _currentIndex = _currentIndex.clamp(0, submissions.length - 1);
        return Scaffold(
          backgroundColor: const Color(0xFF17151D),
          body: PageView.builder(
            controller: _pageController,
            itemCount: submissions.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final submission = submissions[index];
              final mission = widget.repository.missionById(
                widget.roomId,
                submission.missionId,
              );
              return _StoryPage(
                roomName: room.name,
                missionTitle: mission?.title ?? '미션',
                submission: submission,
                position: index + 1,
                total: submissions.length,
                onBack: () => Navigator.of(context).pop(),
                onVote: (choice) => _vote(submission, choice),
              );
            },
          ),
        );
      },
    );
  }
}

class _StoryPage extends StatelessWidget {
  const _StoryPage({
    required this.roomName,
    required this.missionTitle,
    required this.submission,
    required this.position,
    required this.total,
    required this.onBack,
    required this.onVote,
  });

  final String roomName;
  final String missionTitle;
  final MissionSubmission submission;
  final int position;
  final int total;
  final VoidCallback onBack;
  final ValueChanged<VoteChoice> onVote;

  @override
  Widget build(BuildContext context) {
    final accepted = submission.acceptedVotes;
    final rejected = submission.notAcceptedVotes;
    final hasVotes = accepted + rejected > 0;
    final approved = hasVotes && accepted > rejected;
    final statusColor = !hasVotes
        ? const Color(0xFF68656F)
        : approved
        ? const Color(0xFF4F9A63)
        : const Color(0xFFB85B55);
    final statusText = !hasVotes
        ? '투표를 기다리는 중'
        : approved
        ? '현재 승인됨'
        : '현재 미승인';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MissionPhoto(
            submission: submission,
            borderRadius: 30,
            showAuthor: false,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xAA000000),
                    Colors.transparent,
                    Color(0xCC000000),
                  ],
                  stops: [0, 0.52, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: onBack,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black38,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          roomName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '$position/$total',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      missionTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    submission.authorName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _VoteButton(
                          buttonKey: const Key('thumbDownButton'),
                          icon: Icons.thumb_down_alt_rounded,
                          label: 'Not Accepted',
                          count: rejected,
                          color: const Color(0xFFBD665C),
                          selected:
                              submission.currentUserVote ==
                              VoteChoice.notAccepted,
                          onTap: () => onVote(VoteChoice.notAccepted),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _VoteButton(
                          buttonKey: const Key('thumbUpButton'),
                          icon: Icons.thumb_up_alt_rounded,
                          label: 'Accepted',
                          count: accepted,
                          color: const Color(0xFF5C9F68),
                          selected:
                              submission.currentUserVote == VoteChoice.accepted,
                          onTap: () => onVote(VoteChoice.accepted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$label, $count표',
      child: FilledButton.icon(
        key: buttonKey,
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: selected ? color : color.withValues(alpha: 0.72),
          foregroundColor: Colors.white,
          side: BorderSide(
            color: selected ? Colors.white : Colors.white30,
            width: 2,
          ),
        ),
        icon: Icon(icon),
        label: Text(
          '$label · $count',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
