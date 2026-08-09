import 'dart:math';

import 'package:flutter/material.dart';

import '../models/mission_post.dart';
import 'mission_photo.dart';

class StoryCardStack extends StatelessWidget {
  const StoryCardStack({
    required this.posts,
    required this.onStoryTap,
    this.height = 220,
    super.key,
  });

  final List<MissionPost> posts;
  final ValueChanged<int> onStoryTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            '아직 올라온 스토리가 없어요.',
            style: TextStyle(color: Colors.black45),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final visibleCount = min(posts.length, 4);
        final cardHeight = height - 12;
        final cardWidth = min(cardHeight * 0.7, constraints.maxWidth * 0.64);
        final availableSpread = constraints.maxWidth - cardWidth;
        final spread = visibleCount == 1
            ? 0.0
            : min(58.0, availableSpread / (visibleCount - 1));
        final stackWidth = cardWidth + spread * (visibleCount - 1);

        return SizedBox(
          height: height,
          child: Center(
            child: SizedBox(
              width: stackWidth,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = visibleCount - 1; index >= 0; index--)
                    Positioned(
                      left: index * spread,
                      top: index * 4,
                      width: cardWidth,
                      height: cardHeight,
                      child: Transform.rotate(
                        angle: index == 0
                            ? -0.025
                            : (index.isEven ? -0.018 : 0.024),
                        child: GestureDetector(
                          key: Key('storyStackCard$index'),
                          onTap: () => onStoryTap(index),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 18,
                                  offset: const Offset(0, 9),
                                ),
                              ],
                            ),
                            child: MissionPhoto(
                              post: posts[index],
                              borderRadius: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
