import 'package:flutter/material.dart';

import '../widgets/doit_logo.dart';

class GlobalMissionsScreen extends StatelessWidget {
  const GlobalMissionsScreen({super.key});

  static const _missions = [
    ('하늘에서 가장 마음에 드는 색 찾기', '📷', '오늘 자정까지'),
    ('5,000원으로 가장 이상한 물건 찾기', '🛍️', '이번 주 일요일까지'),
    ('친구에게 뜬금없는 칭찬 보내기', '💌', '오늘 자정까지'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: const DoitLogo(fontSize: 24)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            Text(
              'Global Missions',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              '모두가 같은 미션을 어떻게 즐겼는지 확인해보세요.',
              style: TextStyle(color: Colors.black54, height: 1.5),
            ),
            const SizedBox(height: 24),
            for (var index = 0; index < _missions.length; index++) ...[
              _GlobalMissionCard(
                number: index + 1,
                title: _missions[index].$1,
                emoji: _missions[index].$2,
                due: _missions[index].$3,
              ),
              if (index != _missions.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlobalMissionCard extends StatelessWidget {
  const _GlobalMissionCard({
    required this.number,
    required this.title,
    required this.emoji,
    required this.due,
  });

  final int number;
  final String title;
  final String emoji;
  final String due;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 25)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MISSION $number',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(due, style: const TextStyle(color: Colors.black45)),
              ],
            ),
          ),
          const Icon(Icons.camera_alt_rounded, color: Colors.black38),
        ],
      ),
    );
  }
}
