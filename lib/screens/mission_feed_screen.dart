import 'dart:math';

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

class _MissionFeedScreenState extends State<MissionFeedScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _entryController;
  late int _currentIndex;
  final Set<int> _downReactions = {};
  final Set<int> _upReactions = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _entryController
      ..reset()
      ..forward();
  }

  void _toggleReaction({required bool isUp}) {
    final selected = isUp ? _upReactions : _downReactions;
    final opposite = isUp ? _downReactions : _upReactions;

    setState(() {
      if (!selected.add(_currentIndex)) {
        selected.remove(_currentIndex);
      } else {
        opposite.remove(_currentIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17151D),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.posts.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final post = widget.posts[index];

          return AnimatedBuilder(
            animation: Listenable.merge([_pageController, _entryController]),
            builder: (context, child) {
              var currentPage = widget.initialIndex.toDouble();
              if (_pageController.hasClients &&
                  _pageController.position.haveDimensions) {
                currentPage = _pageController.page ?? currentPage;
              }

              final distance = (currentPage - index).abs().clamp(0.0, 1.0);
              final direction = (currentPage - index).clamp(-1.0, 1.0);
              final swipeScale = 1 - distance * 0.07;
              final entryValue = Curves.easeOutCubic.transform(
                _entryController.value,
              );
              final entryScale = 0.965 + entryValue * 0.035;

              return Opacity(
                opacity: max(0.0, (1 - distance * 0.32) * entryValue),
                child: Transform.scale(
                  scale: swipeScale * entryScale,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateY(direction * -0.1),
                    child: child,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 9, 12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MissionPhoto(post: post, borderRadius: 30, showAuthor: false),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.42),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.58),
                          ],
                          stops: const [0, 0.5, 1],
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
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.black45,
                                      ),
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
                              horizontal: 16,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.76),
                              borderRadius: BorderRadius.circular(99),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.36),
                              ),
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ThumbButton(
                                key: const Key('thumbDownButton'),
                                icon: Icons.thumb_down_alt_rounded,
                                color: const Color(0xFFBD665C),
                                selected: _downReactions.contains(index),
                                onTap: () => _toggleReaction(isUp: false),
                              ),
                              const SizedBox(width: 18),
                              _ThumbButton(
                                key: const Key('thumbUpButton'),
                                icon: Icons.thumb_up_alt_rounded,
                                color: const Color(0xFF67A86C),
                                selected: _upReactions.contains(index),
                                onTap: () => _toggleReaction(isUp: true),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ThumbButton extends StatelessWidget {
  const _ThumbButton({
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.08 : 1,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 94,
            height: 58,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: selected ? 0.82 : 0.3),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.55 : 0.28),
                  blurRadius: selected ? 20 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 27),
          ),
        ),
      ),
    );
  }
}
