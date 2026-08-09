import 'package:flutter/material.dart';

class MissionPost {
  const MissionPost({
    required this.author,
    required this.mission,
    required this.emoji,
    required this.startColor,
    required this.endColor,
    required this.sadCount,
    required this.heartCount,
  });

  final String author;
  final String mission;
  final String emoji;
  final Color startColor;
  final Color endColor;
  final int sadCount;
  final int heartCount;
}
