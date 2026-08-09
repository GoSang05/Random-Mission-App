import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/main.dart';

void main() {
  testWidgets('새 미션 방을 만들 수 있다', (tester) async {
    await tester.pumpWidget(const RandomMissionApp(skipSplash: true));

    expect(find.text('DOIT'), findsOneWidget);
    expect(find.text('Global Missions'), findsOneWidget);
    expect(find.text('My Rooms'), findsOneWidget);

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

    await tester.tap(find.byKey(const Key('missionPost0')));
    await tester.pumpAndSettle();

    expect(find.text('예쁜 장소에서 음료 마시기'), findsOneWidget);
    expect(find.text('1/4'), findsOneWidget);
    expect(find.text('😍'), findsOneWidget);
  });
}
