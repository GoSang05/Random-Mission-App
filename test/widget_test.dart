import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/data/local_mission_repository.dart';
import 'package:random_mission_app/main.dart';

Future<LocalMissionRepository> pumpMvp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repository = LocalMissionRepository();
  await repository.initialize();
  addTearDown(repository.dispose);
  await tester.pumpWidget(
    RandomMissionApp(skipSplash: true, repository: repository),
  );
  await pumpUi(tester);
  return repository;
}

Future<void> pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> openRoom(WidgetTester tester, String code) async {
  final room = find.byKey(Key('roomTile_$code'));
  await tester.ensureVisible(room);
  await tester.tap(room);
  await pumpUi(tester);
}

void main() {
  testWidgets('홈에서 방을 만들고 초대 코드로 참여할 수 있다', (tester) async {
    final repository = await pumpMvp(tester);

    expect(find.text('DOIT'), findsOneWidget);
    expect(find.text('My Rooms'), findsOneWidget);
    expect(find.byKey(const Key('previewModeNotice')), findsOneWidget);

    await tester.tap(find.byKey(const Key('createRoomButton')));
    await pumpUi(tester);
    await tester.enterText(find.byKey(const Key('roomNameField')), '우리 동네 탐험대');
    await tester.tap(find.byKey(const Key('confirmCreateRoomButton')));
    await pumpUi(tester);
    expect(find.text('우리 동네 탐험대'), findsOneWidget);

    await tester.tap(find.byKey(const Key('joinRoomButton')));
    await pumpUi(tester);
    await tester.enterText(find.byKey(const Key('roomCodeField')), 'NIGHT7');
    await tester.tap(find.byKey(const Key('confirmJoinRoomButton')));
    await pumpUi(tester);
    expect(
      repository.joinedRooms.any((room) => room.name == '밤 산책 크루'),
      isTrue,
    );
  });

  testWidgets('개인 방에서 스토리 투표와 채팅을 사용할 수 있다', (tester) async {
    await pumpMvp(tester);
    await openRoom(tester, 'FRI824');

    expect(find.text('오늘의 미션'), findsOneWidget);
    expect(find.text('Room Chat'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('chatMessageField')),
      '테스트 메시지',
    );
    await tester.tap(find.byKey(const Key('sendChatButton')));
    await pumpUi(tester);
    expect(find.text('테스트 메시지'), findsOneWidget);

    final story = find.byKey(const Key('storyStackCard0'));
    await tester.ensureVisible(story);
    await tester.tap(story);
    await pumpUi(tester);

    expect(find.text('빨간색 물건 5개를 한 장에 찍기'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Accepted · 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('thumbDownButton')));
    await pumpUi(tester);
    expect(find.text('Accepted · 2'), findsOneWidget);
    expect(find.text('Not Accepted · 2'), findsOneWidget);
  });

  testWidgets('방 설정은 초대 코드와 인원만 노출한다', (tester) async {
    await pumpMvp(tester);
    await openRoom(tester, 'CAMPUS');

    await tester.tap(find.byKey(const Key('roomSettingsButton')));
    await pumpUi(tester);

    expect(find.text('방 설정'), findsOneWidget);
    expect(find.text('방 코드'), findsOneWidget);
    expect(find.text('CAMPUS'), findsOneWidget);
    expect(find.text('참여 인원'), findsOneWidget);
    expect(find.text('비밀번호'), findsNothing);
  });

  testWidgets('글로벌 방에서 사용자 미션과 캡처 화면을 연다', (tester) async {
    await pumpMvp(tester);

    await tester.tap(find.byKey(const Key('globalMissionButton')));
    await pumpUi(tester);
    expect(find.text('Global Mission Room'), findsOneWidget);
    expect(find.byKey(const Key('futureAiMissionNotice')), findsOneWidget);

    await tester.tap(find.byKey(const Key('createGlobalMissionButton')));
    await pumpUi(tester);
    await tester.enterText(
      find.byKey(const Key('globalMissionTitleField')),
      '오늘 가장 재미있는 간판 찍기',
    );
    await tester.tap(find.byKey(const Key('confirmGlobalMissionButton')));
    await pumpUi(tester);
    expect(find.text('오늘 가장 재미있는 간판 찍기'), findsOneWidget);

    final camera = find.byKey(const Key('globalCamera1'));
    await tester.ensureVisible(camera);
    await tester.tap(camera);
    await pumpUi(tester);

    expect(find.byKey(const Key('captureScreen')), findsOneWidget);
    expect(find.byKey(const Key('photoModeButton')), findsOneWidget);
    expect(find.byKey(const Key('videoModeButton')), findsOneWidget);
    expect(find.byKey(const Key('captureShutterButton')), findsOneWidget);
  });
}
