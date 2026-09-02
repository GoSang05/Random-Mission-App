import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/data/local_mission_repository.dart';
import 'package:random_mission_app/main.dart';
import 'package:random_mission_app/models/mission_data.dart';
import 'package:random_mission_app/screens/room_detail_screen.dart';
import 'package:random_mission_app/screens/rooms_screen.dart';

class _LockedJoinRepository extends LocalMissionRepository {
  final attempts = <String?>[];

  @override
  Future<JoinRoomResult> joinRoomPersisted(
    String code, {
    String? password,
  }) async {
    attempts.add(password);
    return password == '4321'
        ? JoinRoomResult.joined
        : JoinRoomResult.wrongPassword;
  }
}

Future<LocalMissionRepository> pumpMvp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repository = LocalMissionRepository();
  await repository.initialize();
  final friends = repository.importJoinedRoom(
    id: 'test-room-friends',
    name: '친구들의 랜덤 미션',
    code: 'FRI824',
    memberCount: 4,
  );
  final campus = repository.importJoinedRoom(
    id: 'test-room-campus',
    name: '캠퍼스 탐험대',
    code: 'CAMPUS',
    memberCount: 6,
  );
  repository.addSubmission(
    roomId: friends.id,
    missionId: friends.missions.first.id,
    localPath: '/test/friends.jpg',
    mediaKind: MissionMediaKind.photo,
  );
  repository.addSubmission(
    roomId: campus.id,
    missionId: campus.missions.first.id,
    localPath: '/test/campus.jpg',
    mediaKind: MissionMediaKind.photo,
  );
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
  testWidgets('home stories navigate across joined private rooms', (
    tester,
  ) async {
    await pumpMvp(tester);

    final firstStory = find.byKey(const Key('storyStackCard0'));
    await tester.ensureVisible(firstStory);
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await pumpUi(tester);
    await tester.tap(firstStory);
    await pumpUi(tester);

    expect(find.text('1/2'), findsOneWidget);
    final tapArea = find.byKey(const Key('storyTapArea'));
    final initialRect = tester.getRect(tapArea);
    final rightSide = Offset(initialRect.right - 12, initialRect.center.dy);

    await tester.longPressAt(rightSide);
    await pumpUi(tester);
    expect(find.text('1/2'), findsOneWidget);

    await tester.tapAt(rightSide);
    await pumpUi(tester);
    expect(find.text('2/2'), findsOneWidget);

    final secondRect = tester.getRect(tapArea);
    await tester.tapAt(Offset(secondRect.left + 12, secondRect.center.dy));
    await pumpUi(tester);
    expect(find.text('1/2'), findsOneWidget);

    await tester.drag(tapArea, const Offset(-300, 0));
    await pumpUi(tester);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('프로필 설정에서 로그아웃할 수 있다', (tester) async {
    final repository = LocalMissionRepository();
    await repository.initialize();
    addTearDown(repository.dispose);
    var signedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RoomsScreen(
          repository: repository,
          displayName: '테스트 사용자',
          onSignOut: () async => signedOut = true,
        ),
      ),
    );
    await pumpUi(tester);

    await tester.tap(find.byKey(const Key('profileSettingsButton')));
    await pumpUi(tester);
    expect(find.text('테스트 사용자'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profileSignOutButton')));
    await pumpUi(tester);
    expect(find.text('로그아웃할까요?'), findsOneWidget);
    expect(signedOut, isFalse);
    await tester.tap(find.byKey(const Key('confirmSignOutButton')));
    await pumpUi(tester);
    expect(signedOut, isTrue);
  });

  testWidgets('홈에서 방을 만들고 초대 코드로 참여할 수 있다', (tester) async {
    final repository = await pumpMvp(tester);

    expect(find.text('DOIT'), findsOneWidget);
    expect(find.text('My Rooms'), findsOneWidget);
    expect(find.text('매거진'), findsNothing);
    expect(find.byKey(const Key('previewModeNotice')), findsNothing);

    await tester.tap(find.byKey(const Key('createRoomButton')));
    await pumpUi(tester);
    await tester.enterText(find.byKey(const Key('roomNameField')), '우리 동네 탐험대');
    await tester.tap(find.byKey(const Key('privateRoomSwitch')));
    await pumpUi(tester);
    await tester.enterText(find.byKey(const Key('roomPasswordField')), '1234');
    await tester.tap(find.byKey(const Key('confirmCreateRoomButton')));
    await pumpUi(tester);
    expect(find.text('우리 동네 탐험대'), findsOneWidget);
    expect(
      repository.joinedRooms
          .firstWhere((room) => room.name == '우리 동네 탐험대')
          .isLocked,
      isTrue,
    );
  });

  testWidgets('개인 방에서 스토리와 채팅을 사용할 수 있다', (tester) async {
    await pumpMvp(tester);
    await openRoom(tester, 'FRI824');

    expect(find.text('오늘의 미션'), findsOneWidget);
    await tester.tap(find.byKey(const Key('roomChatButton')));
    await pumpUi(tester);

    await tester.enterText(
      find.byKey(const Key('chatMessageField')),
      '테스트 메시지',
    );
    await tester.tap(find.byKey(const Key('sendChatButton')));
    await pumpUi(tester);
    expect(find.text('테스트 메시지'), findsOneWidget);
    await tester.pageBack();
    await pumpUi(tester);

    final story = find.byKey(const Key('storyStackCard0'));
    await tester.ensureVisible(story);
    await tester.tap(story);
    await pumpUi(tester);

    expect(find.text('1/1'), findsOneWidget);
    expect(find.byKey(const Key('thumbDownButton')), findsNothing);
    expect(find.byKey(const Key('thumbUpButton')), findsNothing);
    expect(find.text('투표를 기다리는 중'), findsNothing);
  });

  testWidgets('코드 참여는 잠긴 방에서만 비밀번호를 추가로 묻는다', (tester) async {
    final repository = _LockedJoinRepository();
    await repository.initialize();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(home: RoomsScreen(repository: repository)),
    );
    await pumpUi(tester);

    await tester.tap(find.byKey(const Key('joinRoomButton')));
    await pumpUi(tester);
    expect(find.byKey(const Key('roomCodeField')), findsOneWidget);
    expect(find.byKey(const Key('joinRoomPasswordField')), findsNothing);

    await tester.enterText(find.byKey(const Key('roomCodeField')), 'LOCKED');
    await tester.tap(find.byKey(const Key('confirmJoinRoomButton')));
    await pumpUi(tester);
    expect(repository.attempts, [null]);
    expect(find.byKey(const Key('joinRoomPasswordField')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('joinRoomPasswordField')),
      '4321',
    );
    await tester.tap(find.byKey(const Key('confirmJoinRoomPasswordButton')));
    await pumpUi(tester);
    expect(repository.attempts, [null, '4321']);
  });

  testWidgets('방 히스토리는 지난 사진을 날짜별로 묶는다', (tester) async {
    var now = DateTime(2026, 8, 30, 12);
    final repository = LocalMissionRepository(now: () => now);
    await repository.initialize();
    addTearDown(repository.dispose);
    final room = repository.createRoom('날짜별 기록');
    repository.addSubmission(
      roomId: room.id,
      missionId: room.missions.first.id,
      localPath: '/test/august-30.jpg',
      mediaKind: MissionMediaKind.photo,
    );
    now = DateTime(2026, 8, 31, 12);
    repository.refreshDailyMissionsIfNeeded();
    final nextRoom = repository.roomById(room.id)!;
    repository.addSubmission(
      roomId: room.id,
      missionId: nextRoom.missions.first.id,
      localPath: '/test/august-31.jpg',
      mediaKind: MissionMediaKind.photo,
    );
    now = DateTime(2026, 9, 1, 12);
    repository.refreshDailyMissionsIfNeeded();

    await tester.pumpWidget(
      MaterialApp(
        home: RoomDetailScreen(repository: repository, roomId: room.id),
      ),
    );
    await pumpUi(tester);
    await tester.tap(find.byKey(const Key('roomHistoryButton')));
    await pumpUi(tester);

    expect(find.byKey(const Key('roomHistoryDateList')), findsOneWidget);
    expect(find.byKey(const Key('historyDate_2026_8_31')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('roomHistoryDateList')),
      const Offset(0, -420),
    );
    await pumpUi(tester);
    expect(find.byKey(const Key('historyDate_2026_8_30')), findsOneWidget);
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

  testWidgets('글로벌 방에서 일일 미션과 사진 캡처 화면을 연다', (tester) async {
    await pumpMvp(tester);

    await tester.tap(find.byKey(const Key('globalMissionButton')));
    await pumpUi(tester);
    expect(find.text('Global Mission Room'), findsOneWidget);
    expect(find.byKey(const Key('dailyMissionNotice')), findsNothing);
    expect(find.byKey(const Key('createGlobalMissionButton')), findsNothing);

    final camera = find.byKey(const Key('globalCamera1'));
    await tester.ensureVisible(camera);
    await tester.tap(camera);
    await pumpUi(tester);

    expect(find.byKey(const Key('captureScreen')), findsOneWidget);
    expect(find.byKey(const Key('videoModeButton')), findsNothing);
    expect(find.byKey(const Key('cameraCaptureButton')), findsOneWidget);
  });

  testWidgets('Guest 프로필에서 닉네임을 변경하고 미션 추가는 제공하지 않는다', (tester) async {
    final repository = await pumpMvp(tester);

    await tester.tap(find.byKey(const Key('profileSettingsButton')));
    await pumpUi(tester);
    expect(find.text('설정'), findsOneWidget);
    expect(find.text('로컬 데이터 저장'), findsNothing);
    await tester.tap(find.byKey(const Key('profileIdentityTile')));
    await pumpUi(tester);
    await tester.enterText(
      find.byKey(const Key('profileNicknameField')),
      '새 닉네임',
    );
    await tester.tap(find.byKey(const Key('saveProfileNicknameButton')));
    await pumpUi(tester);
    expect(find.byKey(const Key('addRoomMissionButton')), findsNothing);
    expect(repository.previewUserName, '새 닉네임');
  });
}
