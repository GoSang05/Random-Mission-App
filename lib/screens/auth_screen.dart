import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/doit_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({required this.client, super.key});

  final SupabaseClient client;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSignUp = false;
  var _isSubmitting = false;
  var _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_isSignUp) {
        final response = await widget.client.auth.signUp(
          email: email,
          password: password,
          data: {'display_name': _nameController.text.trim()},
        );
        if (response.session == null) {
          _showMessage('확인 이메일을 보냈어요. 이메일 인증 후 로그인해 주세요.');
          if (mounted) setState(() => _isSignUp = false);
        }
      } else {
        await widget.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
    } on AuthException catch (error) {
      _showMessage(_authMessage(error));
    } catch (_) {
      _showMessage('로그인 중 문제가 발생했어요. 인터넷 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (message.contains('already registered')) {
      return '이미 가입된 이메일이에요.';
    }
    if (message.contains('email not confirmed')) {
      return '이메일 인증을 먼저 완료해 주세요.';
    }
    if (message.contains('password')) {
      return '비밀번호는 8자 이상으로 입력해 주세요.';
    }
    return '계정을 확인하지 못했어요. 입력 내용을 다시 확인해 주세요.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: DoitLogo(fontSize: 42)),
                    const SizedBox(height: 12),
                    Text(
                      _isSignUp ? '친구들과 미션을 시작해요' : '다시 만나서 반가워요',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 30),
                    if (_isSignUp) ...[
                      TextFormField(
                        key: const Key('authDisplayNameField'),
                        controller: _nameController,
                        maxLength: 40,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '표시 이름',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '표시 이름을 입력해 주세요.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      key: const Key('authEmailField'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '이메일',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        return email.contains('@') && email.contains('.')
                            ? null
                            : '올바른 이메일을 입력해 주세요.';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('authPasswordField'),
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: '비밀번호',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value?.length ?? 0) < 8
                          ? '비밀번호는 8자 이상이어야 해요.'
                          : null,
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const Key('authSubmitButton'),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? '계정 만들기' : '로그인'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _isSignUp = !_isSignUp),
                      child: Text(_isSignUp ? '이미 계정이 있어요' : '처음이신가요? 계정 만들기'),
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
