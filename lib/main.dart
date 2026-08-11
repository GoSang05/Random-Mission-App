import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/magazine_screen.dart';
import 'screens/rooms_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
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
      home: skipSplash ? const _AppShell() : const _SplashGate(),
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
      child: _showHome ? const _AppShell() : const _SplashScreen(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _selectedIndex = 0;
  final _pages = const [RoomsScreen(), MagazineScreen()];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: _selectedIndex, children: _pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() => _selectedIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: '미션'),
            NavigationDestination(icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories_rounded), label: '매거진'),
          ],
        ),
      );
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
