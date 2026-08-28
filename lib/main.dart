import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/chat_repository.dart';
import 'data/guest_session_store.dart';
import 'data/local_mission_repository.dart';
import 'data/local_mission_store.dart';
import 'screens/auth_screen.dart';
import 'screens/magazine_screen.dart';
import 'screens/rooms_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/playful_illustrations.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
    runApp(const RandomMissionApp(supabaseEnabled: false));
    return;
  }

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabasePublishableKey,
  );
  runApp(const RandomMissionApp());
}

class RandomMissionApp extends StatefulWidget {
  const RandomMissionApp({
    this.skipSplash = false,
    this.repository,
    this.supabaseEnabled = true,
    super.key,
  });

  final bool skipSplash;
  final LocalMissionRepository? repository;
  final bool supabaseEnabled;

  @override
  State<RandomMissionApp> createState() => _RandomMissionAppState();
}

class _GuestOnlyEntry extends StatelessWidget {
  const _GuestOnlyEntry({required this.onGuest});

  final VoidCallback onGuest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest_rounded, size: 52),
                const SizedBox(height: 16),
                const Text(
                  '로그인 서버 설정이 필요해요',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                const Text(
                  '서버 설정 전에도 Guest 모드에서 로컬 기능을 사용할 수 있어요.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('offlineGuestModeButton'),
                  onPressed: onGuest,
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('Guest 모드로 시작'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          ? _AuthGate(
              skipSplash: widget.skipSplash,
              supabaseEnabled: widget.supabaseEnabled,
            )
          : widget.skipSplash
          ? _AppShell(repository: testRepository)
          : _SplashGate(repository: testRepository),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate({required this.skipSplash, required this.supabaseEnabled});

  final bool skipSplash;
  final bool supabaseEnabled;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final GuestSessionStore _guestSessionStore = GuestSessionStore();
  bool? _guestEnabled;

  @override
  void initState() {
    super.initState();
    _loadGuestMode();
  }

  Future<void> _loadGuestMode() async {
    final enabled = await _guestSessionStore.load();
    if (mounted) setState(() => _guestEnabled = enabled);
  }

  Future<void> _enterGuestMode() async {
    await _guestSessionStore.setEnabled(true);
    if (mounted) setState(() => _guestEnabled = true);
  }

  Future<void> _exitGuestMode() async {
    await _guestSessionStore.setEnabled(false);
    if (mounted) setState(() => _guestEnabled = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_guestEnabled == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!widget.supabaseEnabled) {
      return _guestEnabled!
          ? _GuestApp(
              skipSplash: widget.skipSplash,
              onExitGuest: _exitGuestMode,
            )
          : _GuestOnlyEntry(onGuest: _enterGuestMode);
    }
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.hasData
            ? snapshot.data!.session
            : client.auth.currentSession;
        if (session == null && _guestEnabled!) {
          return _GuestApp(
            skipSplash: widget.skipSplash,
            onExitGuest: _exitGuestMode,
          );
        }
        if (session == null) {
          return AuthScreen(client: client, onGuest: _enterGuestMode);
        }
        return _SignedInApp(
          key: ValueKey(session.user.id),
          client: client,
          user: session.user,
          skipSplash: widget.skipSplash,
        );
      },
    );
  }
}

class _GuestApp extends StatefulWidget {
  const _GuestApp({required this.skipSplash, required this.onExitGuest});

  final bool skipSplash;
  final Future<void> Function() onExitGuest;

  @override
  State<_GuestApp> createState() => _GuestAppState();
}

class _GuestAppState extends State<_GuestApp> {
  late final LocalMissionRepository _repository = LocalMissionRepository(
    previewUserId: 'local-guest',
    previewUserName: 'Guest',
    includePreviewData: true,
    store: SharedPreferencesMissionStore('mission_data_guest_v1'),
  );
  late final Future<void> _initialization = _repository.initialize();

  @override
  void dispose() {
    _repository.dispose();
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
        final app = _AppShell(
          repository: _repository,
          displayName: 'Guest',
          isGuest: true,
          onSignOut: widget.onExitGuest,
          localStorageScope: 'guest',
        );
        return widget.skipSplash
            ? app
            : _SplashGate(
                repository: _repository,
                displayName: 'Guest',
                isGuest: true,
                onSignOut: widget.onExitGuest,
                localStorageScope: 'guest',
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
    store: SharedPreferencesMissionStore('mission_data_${widget.user.id}_v1'),
  );
  late final ChatRepository _chatRepository = SupabaseChatRepository(
    widget.client,
  );
  ChatRepository? _availableChatRepository;
  String? _startupNotice;
  late Future<void> _initialization = _initialize();

  Future<void> _initialize() async {
    await _missionRepository.initialize();
    try {
      await _chatRepository.ensureProfile(_displayName);
      final joinedRooms = await _chatRepository.listJoinedRooms();
      for (final room in joinedRooms) {
        _missionRepository.importJoinedRoom(
          id: room.roomId,
          name: room.roomName,
          code: room.inviteCode,
          memberCount: room.memberCount,
        );
      }
      _availableChatRepository = _chatRepository;
      _startupNotice = null;
    } catch (_) {
      _availableChatRepository = null;
      _startupNotice = '로그인은 완료됐지만 채팅 서버에 연결하지 못했어요. 미션 기능은 계속 사용할 수 있어요.';
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
                chatRepository: _availableChatRepository,
                onSignOut: widget.client.auth.signOut,
                startupNotice: _startupNotice,
                displayName: _displayName,
                localStorageScope: widget.user.id,
              )
            : _SplashGate(
                repository: _missionRepository,
                chatRepository: _availableChatRepository,
                onSignOut: widget.client.auth.signOut,
                startupNotice: _startupNotice,
                displayName: _displayName,
                localStorageScope: widget.user.id,
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
    this.startupNotice,
    this.displayName = '나',
    this.isGuest = false,
    this.localStorageScope = 'preview',
  });

  final LocalMissionRepository repository;
  final ChatRepository? chatRepository;
  final Future<void> Function()? onSignOut;
  final String? startupNotice;
  final String displayName;
  final bool isGuest;
  final String localStorageScope;

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
              startupNotice: widget.startupNotice,
              displayName: widget.displayName,
              isGuest: widget.isGuest,
              localStorageScope: widget.localStorageScope,
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
    this.startupNotice,
    this.displayName = '나',
    this.isGuest = false,
    this.localStorageScope = 'preview',
  });

  final LocalMissionRepository repository;
  final ChatRepository? chatRepository;
  final Future<void> Function()? onSignOut;
  final String? startupNotice;
  final String displayName;
  final bool isGuest;
  final String localStorageScope;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCameraAccess());
  }

  Future<void> _requestCameraAccess() async {
    try {
      await Permission.camera.request();
    } catch (_) {
      // Widget tests and unsupported desktop targets may not expose permissions.
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatRepository = widget.chatRepository;
    final pages = [
      RoomsScreen(
        repository: widget.repository,
        chatRepository: chatRepository,
        displayName: widget.displayName,
        isGuest: widget.isGuest,
        onSignOut: widget.onSignOut,
        profileStorageScope: widget.localStorageScope,
      ),
      MagazineScreen(storageScope: widget.localStorageScope),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: _PlayfulBottomNavigation(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
      ),
    );
  }
}

class _PlayfulBottomNavigation extends StatelessWidget {
  const _PlayfulBottomNavigation({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: playfulCream,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(18, 7, 18, 10),
        child: Container(
          height: 72,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFEF8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: playfulInk, width: 3),
            boxShadow: const [
              BoxShadow(color: playfulInk, offset: Offset(0, 5)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomDestination(
                  selected: selectedIndex == 0,
                  icon: Icons.groups_rounded,
                  label: '미션',
                  onTap: () => onDestinationSelected(0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _BottomDestination(
                  selected: selectedIndex == 1,
                  icon: Icons.auto_stories_outlined,
                  label: '매거진',
                  onTap: () => onDestinationSelected(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDestination extends StatelessWidget {
  const _BottomDestination({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: selected ? const Color(0xFFE5D5FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(23),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(23),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? playfulPurple : playfulInk,
                size: 27,
              ),
              const SizedBox(height: 1),
              Text(
                label,
                style: TextStyle(
                  color: selected ? playfulPurple : playfulInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
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
