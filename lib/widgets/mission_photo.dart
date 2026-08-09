import 'dart:io';

import 'package:flutter/material.dart';

import '../models/mission_post.dart';

class MissionPhoto extends StatelessWidget {
  const MissionPhoto({
    required this.post,
    this.borderRadius = 22,
    this.showAuthor = true,
    super.key,
  });

  final MissionPost post;
  final double borderRadius;
  final bool showAuthor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (post.imagePath != null)
            Image.file(
              File(post.imagePath!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _PhotoPlaceholder(post: post),
            )
          else
            _PhotoPlaceholder(post: post),
          if (post.imagePath == null) ...[
            Positioned(
              top: -38,
              right: -28,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -35,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
            ),
            Center(
              child: Text(post.emoji, style: const TextStyle(fontSize: 86)),
            ),
          ],
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.32),
                ],
                stops: const [0.58, 1],
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
                  Text(
                    post.author,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({required this.post});

  final MissionPost post;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [post.startColor, post.endColor],
        ),
      ),
    );
  }
}
