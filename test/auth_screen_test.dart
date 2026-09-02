import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/data/auth_service.dart';
import 'package:random_mission_app/screens/auth_screen.dart';

class _FakeAuthService implements AuthService {
  String? signedInId;
  String? signedInPassword;
  String? signedUpId;
  bool googleSignInCalled = false;

  @override
  Future<void> signIn({
    required String loginId,
    required String password,
  }) async {
    signedInId = loginId;
    signedInPassword = password;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCalled = true;
  }

  @override
  Future<void> signUp({
    required String displayName,
    required String loginId,
    required String password,
  }) async {
    signedUpId = loginId;
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
    String? guestName;
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen.withService(
          authService: service,
          onGuest: (name) => guestName = name,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('guestModeButton')));
    await tester.pump();
    expect(find.byKey(const Key('guestDisplayNameField')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('guestDisplayNameField')),
      '별이',
    );
    await tester.tap(find.byKey(const Key('guestStartButton')));
    expect(guestName, '별이');
  });

  testWidgets('로그인은 기존의 짧은 비밀번호도 서버에 전달한다', (tester) async {
    final service = await _pumpAuth(tester);

    await tester.enterText(
      find.byKey(const Key('authLoginIdField')),
      ' USER_123 ',
    );
    await tester.enterText(
      find.byKey(const Key('authPasswordField')),
      '1234567',
    );
    await tester.tap(find.byKey(const Key('authSubmitButton')));
    await tester.pump();

    expect(service.signedInId, 'user_123');
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
      find.byKey(const Key('authLoginIdField')),
      'user_123',
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
    expect(service.signedUpId, isNull);
  });

  testWidgets('ID와 비밀번호로 바로 회원가입을 요청한다', (tester) async {
    final service = await _pumpAuth(tester);

    await tester.tap(find.text('처음이신가요? 계정 만들기'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('authDisplayNameField')),
      '두잇 사용자',
    );
    await tester.enterText(
      find.byKey(const Key('authLoginIdField')),
      'USER_123',
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

    expect(service.signedUpId, 'user_123');
    expect(find.text('인증 메일을 확인해 주세요'), findsNothing);
  });

  testWidgets('Google 로그인 버튼이 인증 서비스를 호출한다', (tester) async {
    final service = await _pumpAuth(tester);

    await tester.tap(find.byKey(const Key('googleSignInButton')));
    await tester.pump();

    expect(service.googleSignInCalled, isTrue);
  });
}
