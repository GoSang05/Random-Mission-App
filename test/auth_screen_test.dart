import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/data/auth_service.dart';
import 'package:random_mission_app/screens/auth_screen.dart';

class _FakeAuthService implements AuthService {
  String? signedInEmail;
  String? signedInPassword;
  String? signedUpEmail;
  String? confirmationEmail;
  bool googleSignInCalled = false;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signedInEmail = email;
    signedInPassword = password;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCalled = true;
  }

  @override
  Future<bool> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    signedUpEmail = email;
    return true;
  }

  @override
  Future<void> resendSignupConfirmation(String email) async {
    confirmationEmail = email;
  }
}

Future<_FakeAuthService> _pumpAuth(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final service = _FakeAuthService();
  await tester.pumpWidget(
    MaterialApp(home: AuthScreen.withService(authService: service)),
  );
  return service;
}

void main() {
  testWidgets('로그인 없이 Guest 모드로 들어갈 수 있다', (tester) async {
    final service = _FakeAuthService();
    var enteredGuest = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen.withService(
          authService: service,
          onGuest: () => enteredGuest = true,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('guestModeButton')));
    expect(enteredGuest, isTrue);
  });

  testWidgets('로그인은 기존의 짧은 비밀번호도 서버에 전달한다', (tester) async {
    final service = await _pumpAuth(tester);

    await tester.enterText(
      find.byKey(const Key('authEmailField')),
      ' USER@Example.COM ',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      '1234567',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(service.signedInEmail, 'user@example.com');
    expect(service.signedInPassword, '1234567');
    expect(find.text('비밀번호는 8자 이상이어야 해요.'), findsNothing);
  });

  testWidgets('회원가입은 비밀번호 확인 불일치를 차단한다', (tester) async {
    final service = await _pumpAuth(tester);

    await tester.tap(find.text('처음이신가요? 계정 만들기'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('authDisplayNameField')),
      '두잇 사용자',
    );
    await tester.enterText(
      find.byKey(const Key('authEmailField')),
      'user@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password1',
    );
    await tester.enterText(
      find.byKey(const Key('authConfirmPasswordField')),
      'password2',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('비밀번호가 서로 달라요.'), findsOneWidget);
    expect(service.signedUpEmail, isNull);
  });

  testWidgets('회원가입 뒤 인증 대기 화면에서 인증 이메일을 다시 요청한다', (tester) async {
    final service = await _pumpAuth(tester);

    await tester.tap(find.text('처음이신가요? 계정 만들기'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('authDisplayNameField')),
      '두잇 사용자',
    );
    await tester.enterText(
      find.byKey(const Key('authEmailField')),
      'USER@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      'password1',
    );
    await tester.enterText(
      find.byKey(const Key('authConfirmPasswordField')),
      'password1',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(find.text('인증 메일을 확인해 주세요'), findsOneWidget);
    await tester.tap(find.byKey(const Key('authResendConfirmationButton')));
    await tester.pump();
    expect(service.confirmationEmail, 'user@example.com');
  });

  testWidgets('Google 로그인 버튼이 인증 서비스를 호출한다', (tester) async {
    final service = await _pumpAuth(tester);

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pump();

    expect(service.googleSignInCalled, isTrue);
  });
}
