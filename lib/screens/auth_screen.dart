import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = Supabase.instance.client.auth;
      if (_isSignUp) {
        final response = await auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'nickname': _nicknameController.text.trim()},
        );

        if (!mounted) return;
        if (response.session == null) {
          _showMessage('인증 이메일을 보냈어요. 메일 인증 후 로그인해 주세요.');
          setState(() => _isSignUp = false);
        }
      } else {
        await auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on AuthException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('처리하지 못했어요. 네트워크 상태를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _isSignUp ? 'DOIT 시작하기' : '다시 만나서 반가워요';
    final buttonLabel = _isSignUp ? '회원가입' : '로그인';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'DOIT',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp
                          ? '친구와 오늘의 미션을 시작해 보세요.'
                          : '미션 기록을 이어서 확인해 보세요.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 36),
                    if (_isSignUp) ...[
                      TextFormField(
                        key: const Key('nicknameField'),
                        controller: _nicknameController,
                        textInputAction: TextInputAction.next,
                        maxLength: 20,
                        decoration: const InputDecoration(
                          labelText: '닉네임',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? '닉네임을 입력해 주세요.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const Key('emailField'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        hintText: 'name@example.com',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || !value.contains('@')) {
                          return '올바른 이메일을 입력해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('passwordField'),
                      controller: _passwordController,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: '비밀번호',
                        hintText: '6자 이상',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? '비밀번호는 6자 이상으로 입력해 주세요.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      key: const Key('authSubmitButton'),
                      onPressed: _isLoading ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(buttonLabel),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      key: const Key('authModeToggleButton'),
                      onPressed: _isLoading
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(
                        _isSignUp
                            ? '이미 계정이 있나요? 로그인'
                            : '처음이신가요? 회원가입',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
