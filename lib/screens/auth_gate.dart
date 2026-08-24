import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_screen.dart';
import 'rooms_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;

        if (session == null) return const AuthScreen();

        return _ProfileBootstrapper(user: session.user);
      },
    );
  }
}

class _ProfileBootstrapper extends StatefulWidget {
  const _ProfileBootstrapper({required this.user});

  final User user;

  @override
  State<_ProfileBootstrapper> createState() => _ProfileBootstrapperState();
}

class _ProfileBootstrapperState extends State<_ProfileBootstrapper> {
  late final Future<void> _setupProfile;

  @override
  void initState() {
    super.initState();
    _setupProfile = _createProfileIfNeeded();
  }

  Future<void> _createProfileIfNeeded() async {
    final nickname = widget.user.userMetadata?['nickname'] as String? ??
        widget.user.email?.split('@').first ??
        'DOIT User';

    await Supabase.instance.client.from('profiles').upsert({
      'id': widget.user.id,
      'nickname': nickname,
    }, onConflict: 'id');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _setupProfile,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return _ProfileError(error: snapshot.error);
        }

        return const RoomsScreen();
      },
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 16),
              const Text(
                '프로필을 준비하지 못했어요.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Supabase의 profiles RLS 정책을 다시 확인해 주세요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Supabase.instance.client.auth.signOut(),
                child: const Text('로그아웃'),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
