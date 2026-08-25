import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/chat_repository.dart';
import 'data/local_mission_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/magazine_screen.dart';
import 'screens/rooms_screen.dart';
import 'theme/app_theme.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
    throw StateError(
      'Supabase configuration is missing. Select the "Random Mission App" '
      'launch configuration in VS Code before starting the app.',
    );
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const RandomMissionApp());
}

class RandomMissionApp extends StatefulWidget {
  const RandomMissionApp({this.skipSplash = false, this.repository, super.key});

  final bool skipSplash;
  final LocalMissionRepository? repository;

  @override
  State<RandomMissionApp> createState() => _RandomMissionAppState();
}

class _RandomMissionAppState extends State<RandomMissionApp> {
  @override
  Widget build(BuildContext context) {
    final testRepository = widget.repository;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DOIT',
      theme: AppTheme.light,
      home: testRepository == null
          ? _AuthGate(skipSplash: widget.skipSplash)
          : widget.skipSplash
          ? _AppShell(repository: testRepository)
          : _SplashGate(repository: testRepository),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({required this.skipSplash});

  final bool skipSplash;

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data!.session
            : client.auth.currentSession;
        if (session == null) return AuthScreen(client: client);
        return _SignedInApp(
          key: ValueKey(session.user.id),
          client: client,
          user: session.user,
          skipSplash: skipSplash,
        );
      },
    );
  }
}

class _SignedInApp extends StatefulWidget {
  const _SignedInApp({
    required this.client,
    required this.user,
    required this.skipSplash,
    super.key,
  });

  final SupabaseClient client;
  final User user;
  final bool skipSplash;

  @override
  State<_SignedInApp> createState() => _SignedInAppState();
}

class _SignedInAppState extends State<_SignedInApp> {
  late final String _displayName = _userDisplayName(widget.user);
  late final LocalMissionRepository _missionRepository = LocalMissionRepository(
    previewUserId: widget.user.id,
    previewUserName: _displayName,
    includePreviewData: false,
  );
  late final ChatRepository _chatRepository = SupabaseChatRepository(
    widget.client,
  );
  late Future<void> _initialization = _initialize();

  Future<void> _initialize() async {
    await _chatRepository.ensureProfile(_displayName);
    await _missionRepository.initialize();
    final joinedRooms = await _chatRepository.listJoinedRooms();
    for (final room in joinedRooms) {
      _missionRepository.importJoinedRoom(
        id: room.roomId,
        name: room.roomName,
        code: room.inviteCode,
        memberCount: room.memberCount,
      );
    }
  }

  @override
  void dispose() {
    _missionRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    const Text('채팅 서비스를 준비하지 못했어요.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() => _initialization = _initialize());
                      },
                      child: const Text('다시 시도'),
                    ),
                    TextButton(
                      onPressed: widget.client.auth.signOut,
                      child: const Text('로그아웃'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return widget.skipSplash
            ? _AppShell(
                repository: _missionRepository,
                chatRepository: _chatRepository,
                onSignOut: widget.client.auth.signOut,
              )
            : _SplashGate(
                repository: _missionRepository,
                chatRepository: _chatRepository,
                onSignOut: widget.client.auth.signOut,
              );
      },
    );
  }

  String _userDisplayName(User user) {
    final metadataName = user.userMetadata?['display_name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      final cleanName = metadataName.trim();
      return cleanName.length <= 40 ? cleanName : cleanName.substring(0, 40);
    }
    final emailName = (user.email ?? '사용자').split('@').first.trim();
    if (emailName.isEmpty) return '사용자';
    return emailName.length <= 40 ? emailName : emailName.substring(0, 40);
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate({
    required this.repository,
    this.chatRepository,
    this.onSignOut,
  });

  final LocalMissionRepository repository;
  final ChatRepository? chatRepository;
  final Future<void> Function()? onSignOut;

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
      child: _showHome
          ? _AppShell(
              repository: widget.repository,
              chatRepository: widget.chatRepository,
              onSignOut: widget.onSignOut,
            )
          : const _SplashScreen(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.repository,
    this.chatRepository,
    this.onSignOut,
  });

  final LocalMissionRepository repository;
  final ChatRepository? chatRepository;
  final Future<void> Function()? onSignOut;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final chatRepository = widget.chatRepository;
    final pages = [
      RoomsScreen(
        repository: widget.repository,
        chatRepository: chatRepository,
      ),
      const MagazineScreen(),
      if (chatRepository != null)
        ChatsScreen(repository: chatRepository, onSignOut: widget.onSignOut!),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups_rounded),
            label: '미션',
          ),
          const NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: '매거진',
          ),
          if (chatRepository != null)
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: '채팅',
            ),
        ],
      ),
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
