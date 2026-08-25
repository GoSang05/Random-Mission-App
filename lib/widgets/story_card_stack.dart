import 'package:flutter/material.dart';

import '../models/mission_data.dart';
import 'mission_photo.dart';

class StoryCardStack extends StatelessWidget {
  const StoryCardStack({
    required this.submissions,
    required this.onStoryTap,
    this.height = 220,
    super.key,
  });

  final List<MissionSubmission> submissions;
  final ValueChanged<int> onStoryTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            '아직 올라온 스토리가 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black45),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: ListView.separated(
        key: const Key('storyStrip'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: submissions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: height * 0.68,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('storyStackCard$index'),
                onTap: () => onStoryTap(index),
                child: MissionPhoto(submission: submissions[index]),
              ),
            ),
          );
        },
      ),
    );
  }
}
