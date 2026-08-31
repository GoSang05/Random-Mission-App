import 'dart:io';

import 'package:flutter/material.dart';

import '../models/mission_data.dart';

class MissionPhoto extends StatelessWidget {
  const MissionPhoto({
    required this.submission,
    this.borderRadius = 22,
    this.showAuthor = true,
    super.key,
  });

  final MissionSubmission submission;
  final double borderRadius;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Media(submission: submission),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0x99000000)],
                stops: [0.55, 1],
              ),
            ),
          ),
          if (showAuthor)
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person_rounded, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      submission.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                      ),
                    ),
                  ),
                  if (submission.mediaKind == MissionMediaKind.video)
                    const Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({required this.submission});

  final MissionSubmission submission;

  @override
  Widget build(BuildContext context) {
    final path = submission.localPath;
    if (path != null && submission.mediaKind == MissionMediaKind.photo) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Placeholder(submission: submission),
      );
    }
    final remoteUrl = submission.remoteUrl;
    if (remoteUrl != null &&
        remoteUrl.isNotEmpty &&
        submission.mediaKind == MissionMediaKind.photo) {
      return Image.network(
        remoteUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _Placeholder(submission: submission),
      );
    }
    return _Placeholder(submission: submission);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.submission});

  final MissionSubmission submission;

  @override
  Widget build(BuildContext context) {
    final palette = submission.id.hashCode.isEven
        ? const [Color(0xFF7A73C7), Color(0xFF352F69)]
        : const [Color(0xFFE59A78), Color(0xFF704454)];
    final isVideo = submission.mediaKind == MissionMediaKind.video;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isVideo ? Icons.play_circle_fill_rounded : Icons.photo_rounded,
              color: Colors.white,
              size: 72,
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'VIDEO' : 'MISSION PHOTO',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
