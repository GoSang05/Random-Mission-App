import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/main.dart';

void main() {
  testWidgets('새 미션 방을 만들 수 있다', (tester) async {
    await tester.pumpWidget(const RandomMissionApp(skipSplash: true));

    expect(find.text('DOIT'), findsOneWidget);
    expect(find.text('Global Missions'), findsOneWidget);
    expect(find.text('My Rooms'), findsOneWidget);
    expect(find.text('Friends Stories'), findsOneWidget);
    expect(find.text('오늘의 순간을 남겨보세요'), findsNothing);

    await tester.tap(find.byKey(const Key('createRoomButton')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('roomNameField')), '우리 동네 탐험대');
    await tester.tap(find.byKey(const Key('confirmCreateRoomButton')));
    await tester.pumpAndSettle();

    expect(find.text('우리 동네 탐험대'), findsOneWidget);
  });

  testWidgets('방에서 친구 사진 피드를 열 수 있다', (tester) async {
    await tester.pumpWidget(const RandomMissionApp(skipSplash: true));

    await tester.tap(find.byKey(const Key('roomTile_FRI824')));
    await tester.pumpAndSettle();

    expect(find.text('오늘의 미션'), findsOneWidget);
    expect(find.text('친구들의 새 사진'), findsOneWidget);

    await tester.tap(find.byKey(const Key('storyStackCard0')));
    await tester.pumpAndSettle();

    expect(find.text('각자 3,000원 이하 간식 하나 골라오기'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byKey(const Key('thumbDownButton')), findsOneWidget);
    expect(find.byKey(const Key('thumbUpButton')), findsOneWidget);
  });

  testWidgets('방 설정에서 코드와 비밀번호 및 인원을 확인할 수 있다', (tester) async {
    await tester.pumpWidget(const RandomMissionApp(skipSplash: true));

    await tester.tap(find.byKey(const Key('roomTile_CAMPUS')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('roomSettingsButton')));
    await tester.pumpAndSettle();

    expect(find.text('방 설정'), findsOneWidget);
    expect(find.text('방 코드'), findsOneWidget);
    expect(find.text('CAMPUS'), findsOneWidget);
    expect(find.text('비밀번호'), findsOneWidget);
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('참여 인원'), findsOneWidget);
    expect(find.text('3명'), findsOneWidget);
  });

  testWidgets('글로벌 미션마다 스토리와 카메라 버튼이 있다', (tester) async {
    await tester.pumpWidget(const RandomMissionApp(skipSplash: true));

    await tester.tap(find.byKey(const Key('globalMissionButton')));
    await tester.pumpAndSettle();

    expect(find.text('MISSION STORIES'), findsWidgets);
    expect(find.byKey(const Key('globalCamera1')), findsOneWidget);
  });
}
