import 'package:flutter/material.dart';

import '../models/mission_post.dart';
import '../widgets/mission_photo.dart';

class MissionFeedScreen extends StatefulWidget {
  const MissionFeedScreen({
    required this.roomName,
    required this.posts,
    required this.initialIndex,
    super.key,
  });

  final String roomName;
  final List<MissionPost> posts;
  final int initialIndex;

  @override
  State<MissionFeedScreen> createState() => _MissionFeedScreenState();
}

class _MissionFeedScreenState extends State<MissionFeedScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  final Set<int> _sadReactions = {};
  final Set<int> _heartReactions = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleReaction(Set<int> reactions) {
    setState(() {
      if (!reactions.add(_currentIndex)) reactions.remove(_currentIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17151D),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.posts.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final post = widget.posts[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: 'mission-post-$index',
                child: MissionPhoto(
                  post: post,
                  borderRadius: 0,
                  showAuthor: false,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                    stops: const [0, 0.5, 1],
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back_rounded),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black38,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              widget.roomName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(blurRadius: 8, color: Colors.black45),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 48,
                            child: Center(
                              child: Text(
                                '${index + 1}/${widget.posts.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          post.mission,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF25212B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 18,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person_rounded),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              post.author,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _ReactionButton(
                            emoji: '🥺',
                            count:
                                post.sadCount +
                                (_sadReactions.contains(index) ? 1 : 0),
                            selected: _sadReactions.contains(index),
                            selectedColor: const Color(0xFFD17667),
                            onTap: () => _toggleReaction(_sadReactions),
                          ),
                          const SizedBox(width: 10),
                          _ReactionButton(
                            emoji: '😍',
                            count:
                                post.heartCount +
                                (_heartReactions.contains(index) ? 1 : 0),
                            selected: _heartReactions.contains(index),
                            selectedColor: const Color(0xFF69AA68),
                            onTap: () => _toggleReaction(_heartReactions),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.emoji,
    required this.count,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? selectedColor.withValues(alpha: 0.92)
          : Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(99),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
