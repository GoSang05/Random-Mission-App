import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';
import '../utils/app_snackbar.dart';
import '../widgets/doit_logo.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';

class AuthScreen extends StatefulWidget {
  AuthScreen({required SupabaseClient client, required this.onGuest, super.key})
    : authService = SupabaseAuthService(client);

  const AuthScreen.withService({
    required this.authService,
    this.onGuest,
    super.key,
  });

  final AuthService authService;
  final VoidCallback? onGuest;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  var _isSignUp = false;
  var _isSubmitting = false;
  var _obscurePassword = true;
  String? _pendingEmail;
  String? _pendingPassword;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _pendingPassword = null;
    super.dispose();
  }

  void _showMessage(String message) {
    if (mounted) showAppSnackBar(context, message);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;
      if (_isSignUp) {
        final needsEmail = await widget.authService.signUp(
          displayName: _nameController.text.trim(),
          email: email,
          password: password,
        );
        if (needsEmail && mounted) {
          setState(() {
            _pendingEmail = email;
            _pendingPassword = password;
          });
        }
      } else {
        await widget.authService.signIn(email: email, password: password);
      }
    } on TimeoutException {
      _showMessage('서버 응답이 늦어요. 인터넷 연결을 확인하고 다시 시도해 주세요.');
    } on AuthException catch (error) {
      _showMessage(_authMessage(error));
    } catch (_) {
      _showMessage('로그인 중 문제가 발생했어요. 인터넷 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.authService.signInWithGoogle();
    } on AuthActionCancelled {
      // The account picker was intentionally closed.
    } on AuthConfigurationException catch (error) {
      _showMessage(error.message);
    } on AuthException catch (error) {
      _showMessage(_authMessage(error));
    } on TimeoutException {
      _showMessage('Google 로그인 응답이 늦어요. 다시 시도해 주세요.');
    } catch (_) {
      _showMessage('Google 로그인에 실패했어요. 잠시 뒤 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    final code = error.code?.toLowerCase() ?? '';
    if (message.contains('invalid login credentials')) {
      return '이메일 또는 비밀번호가 올바르지 않아요.';
    }
    if (message.contains('already registered')) return '이미 가입된 이메일이에요.';
    if (message.contains('email not confirmed')) return '이메일 인증을 먼저 완료해 주세요.';
    if (code.contains('email_address_not_authorized') ||
        message.contains('email address not authorized')) {
      return '현재 메일 서버가 이 주소로 인증 메일을 보낼 수 없어요. 관리자에게 알려주세요.';
    }
    if (code.contains('over_email_send_rate_limit') ||
        message.contains('rate limit') ||
        message.contains('too many requests')) {
      return '요청이 너무 많아요. 잠시 뒤 다시 시도해 주세요.';
    }
    if (code.contains('signup_disabled') ||
        message.contains('signups not allowed')) {
      return '현재 새 계정을 만들 수 없어요. 관리자 설정을 확인해 주세요.';
    }
    if (code.contains('weak_password') || message.contains('password')) {
      return '비밀번호는 8자 이상으로 입력해 주세요.';
    }
    return '계정을 확인하지 못했어요. 입력 내용을 다시 확인해 주세요.';
  }

  Future<void> _resendConfirmation() async {
    if (_isSubmitting || _pendingEmail == null) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.authService.resendSignupConfirmation(_pendingEmail!);
      _showMessage('인증 이메일을 다시 보냈어요. 스팸함도 확인해 주세요.');
    } on TimeoutException {
      _showMessage('서버 응답이 늦어요. 인터넷 연결을 확인하고 다시 시도해 주세요.');
    } on AuthException catch (error) {
      _showMessage(_authMessage(error));
    } catch (_) {
      _showMessage('이메일을 보내지 못했어요. 인터넷 연결을 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _checkConfirmation() async {
    if (_isSubmitting || _pendingEmail == null || _pendingPassword == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await widget.authService.signIn(
        email: _pendingEmail!,
        password: _pendingPassword!,
      );
    } on AuthException catch (error) {
      _showMessage(_authMessage(error));
    } on TimeoutException {
      _showMessage('서버 응답이 늦어요. 잠시 뒤 다시 시도해 주세요.');
    } catch (_) {
      _showMessage('인증 상태를 확인하지 못했어요. 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

  void _switchMode() {
    _formKey.currentState?.reset();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() => _isSignUp = !_isSignUp);
  }

  void _leaveConfirmation() {
    _pendingPassword = null;
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _pendingEmail = null;
      _isSignUp = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: playfulCream,
      body: PlayfulBackground(
        child: SafeArea(
          child: Stack(
            children: [
              const Positioned(
                top: 24,
                left: 30,
                child: Doodle(
                  kind: DoodleKind.star,
                  color: Color(0xFFA384FF),
                  size: 34,
                ),
              ),
              const Positioned(
                top: 70,
                right: 40,
                child: Doodle(
                  kind: DoodleKind.heart,
                  color: Color(0xFFFF8EAE),
                  size: 34,
                ),
              ),
              const Positioned(
                bottom: 32,
                right: 42,
                child: Doodle(
                  kind: DoodleKind.sparkle,
                  color: playfulLime,
                  size: 26,
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(26, 30, 26, 38),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: _pendingEmail == null
                          ? _buildAuthForm()
                          : _buildConfirmationWaiting(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: DoitLogo(fontSize: _isSignUp ? 62 : 72)),
          const SizedBox(height: 12),
          Text(
            _isSignUp ? '친구들과 미션을 시작해요' : '다시 만나서 반가워요',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: playfulInk,
              fontSize: 25,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 34),
          if (_isSignUp) ...[
            _PlayfulAuthField(
              fieldKey: const Key('authDisplayNameField'),
              controller: _nameController,
              label: '표시 이름',
              icon: Icons.person_outline_rounded,
              maxLength: 40,
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? '표시 이름을 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: 15),
          ],
          _PlayfulAuthField(
            fieldKey: const Key('authEmailField'),
            controller: _emailController,
            label: '이메일',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: (value) =>
                _isValidEmail(value?.trim() ?? '') ? null : '올바른 이메일을 입력해 주세요.',
          ),
          const SizedBox(height: 15),
          _PlayfulAuthField(
            fieldKey: const Key('authPasswordField'),
            controller: _passwordController,
            label: '비밀번호',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: playfulInk,
              ),
            ),
            validator: (value) => (value?.length ?? 0) < 8
                ? _isSignUp
                      ? '비밀번호는 8자 이상이어야 해요.'
                      : (value?.isEmpty ?? true)
                      ? '비밀번호를 입력해 주세요.'
                      : null
                : null,
          ),
          if (_isSignUp) ...[
            const SizedBox(height: 15),
            _PlayfulAuthField(
              fieldKey: const Key('authConfirmPasswordField'),
              controller: _confirmPasswordController,
              label: '비밀번호 확인',
              icon: Icons.lock_reset_rounded,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (value) =>
                  value != _passwordController.text ? '비밀번호가 서로 달라요.' : null,
            ),
          ],
          const SizedBox(height: 24),
          _PlayfulActionButton(
            buttonKey: const Key('authSubmitButton'),
            label: _isSignUp ? '계정 만들기' : '로그인',
            busy: _isSubmitting,
            onPressed: _submit,
          ),
          const SizedBox(height: 13),
          _GoogleSignInButton(
            key: const Key('googleSignInButton'),
            enabled: !_isSubmitting,
            onPressed: _signInWithGoogle,
          ),
          if (widget.onGuest != null) ...[
            const SizedBox(height: 13),
            _OutlinedPlayfulButton(
              buttonKey: const Key('guestModeButton'),
              icon: Icons.person_outline_rounded,
              label: '로그인 없이 둘러보기',
              onPressed: _isSubmitting ? null : widget.onGuest,
            ),
          ],
          const SizedBox(height: 20),
          TextButton(
            onPressed: _isSubmitting ? null : _switchMode,
            child: Text(_isSignUp ? '이미 계정이 있어요' : '처음이신가요? 계정 만들기'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationWaiting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: DoitLogo(fontSize: 66)),
        const SizedBox(height: 28),
        PlayfulPanel(
          color: Colors.white,
          radius: 30,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 25),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7DBFF),
                  shape: BoxShape.circle,
                  border: Border.all(color: playfulInk, width: 3),
                ),
                child: const Icon(
                  Icons.mark_email_unread_rounded,
                  size: 40,
                  color: playfulPurple,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '인증 메일을 확인해 주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: playfulInk,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _pendingEmail!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: playfulPurple,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '메일 안의 인증 링크를 누른 뒤\n아래 버튼으로 완료 여부를 확인해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5, color: Color(0xFF5D5865)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PlayfulActionButton(
          buttonKey: const Key('authCheckConfirmationButton'),
          label: '인증 완료했어요',
          busy: _isSubmitting,
          onPressed: _checkConfirmation,
        ),
        const SizedBox(height: 12),
        _OutlinedPlayfulButton(
          buttonKey: const Key('authResendConfirmationButton'),
          icon: Icons.refresh_rounded,
          label: '인증 메일 다시 받기',
          onPressed: _isSubmitting ? null : _resendConfirmation,
        ),
        const SizedBox(height: 14),
        TextButton(
          key: const Key('authBackToLoginButton'),
          onPressed: _isSubmitting ? null : _leaveConfirmation,
          child: const Text('다른 계정으로 로그인'),
        ),
      ],
    );
  }
}

class _PlayfulAuthField extends StatelessWidget {
  const _PlayfulAuthField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffixIcon,
    this.maxLength,
    this.validator,
    this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffixIcon;
  final int? maxLength;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(22);
    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(color: Color(0xFFD8C8FF), offset: Offset(5, 6)),
          BoxShadow(color: playfulInk, offset: Offset(0, 4)),
        ],
      ),
      child: TextFormField(
        key: fieldKey,
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        obscureText: obscureText,
        maxLength: maxLength,
        autocorrect: false,
        textCapitalization: TextCapitalization.none,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        decoration: InputDecoration(
          hintText: label,
          counterText: '',
          prefixIcon: Padding(
            padding: const EdgeInsets.all(11),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE8DCFF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: playfulInk),
            ),
          ),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 21,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: playfulInk, width: 3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: playfulPurple, width: 3),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Color(0xFFE85E73), width: 3),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: const BorderSide(color: Color(0xFFE85E73), width: 3),
          ),
        ),
      ),
    );
  }
}

class _PlayfulActionButton extends StatelessWidget {
  const _PlayfulActionButton({
    required this.buttonKey,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: playfulInk, offset: Offset(0, 7))],
      ),
      child: FilledButton(
        key: buttonKey,
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(64),
          backgroundColor: playfulPurple,
          disabledBackgroundColor: const Color(0xFFAA9DEC),
          side: const BorderSide(color: playfulInk, width: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }
}

class _OutlinedPlayfulButton extends StatelessWidget {
  const _OutlinedPlayfulButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        foregroundColor: playfulPurple,
        backgroundColor: Colors.white,
        side: const BorderSide(color: playfulInk, width: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        foregroundColor: playfulInk,
        backgroundColor: Colors.white,
        side: const BorderSide(color: playfulInk, width: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              color: Color(0xFF4285F4),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Google로 계속하기',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
