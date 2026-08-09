import 'dart:async';

import 'package:flutter/material.dart';

import 'screens/rooms_screen.dart';

void main() {
  runApp(const RandomMissionApp());
}

class RandomMissionApp extends StatelessWidget {
  const RandomMissionApp({this.skipSplash = false, super.key});

  final bool skipSplash;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6750E8);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DOIT',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        scaffoldBackgroundColor: const Color(0xFFF7F6FB),
        fontFamilyFallback: const ['Noto Sans KR', 'Roboto'],
        useMaterial3: true,
      ),
      home: skipSplash ? const RoomsScreen() : const _SplashGate(),
    );
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  Timer? _timer;
  bool _showHome = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showHome = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      child: _showHome ? const RoomsScreen() : const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      key: ValueKey('splash'),
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'DOIT',
          style: TextStyle(
            color: Color(0xFF17151D),
            fontSize: 42,
            fontWeight: FontWeight.w900,
            letterSpacing: -2,
          ),
        ),
      ),
    );
  }
}
