import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:random_mission_app/data/local_media_store.dart';
import 'package:random_mission_app/data/local_mission_repository.dart';
import 'package:random_mission_app/data/local_mission_store.dart';
import 'package:random_mission_app/models/mission_data.dart';

class _MemoryMissionStore implements LocalMissionStore {
  LocalMissionSnapshot? snapshot;

  @override
  Future<LocalMissionSnapshot?> load() async => snapshot;

  @override
  Future<void> save(LocalMissionSnapshot snapshot) async {
    this.snapshot = snapshot;
  }
}

void main() {
  test('방, 미션, 사진 경로와 채팅을 다시 실행한 저장소에서 복원한다', () async {
    final store = _MemoryMissionStore();
    final first = LocalMissionRepository(
      previewUserId: 'local-user',
      includePreviewData: false,
      store: store,
    );
    await first.initialize();
    final room = first.createRoom('저장 테스트');
    final mission = room.missions.first;
    first.addSubmission(
      roomId: room.id,
      missionId: mission.id,
      localPath: '/documents/mission_media/photo.jpg',
      mediaKind: MissionMediaKind.photo,
    );
    first.sendMessage(room.id, '로컬 메시지');
    await first.persistPendingChanges();

    final restored = LocalMissionRepository(
      previewUserId: 'local-user',
      includePreviewData: false,
      store: store,
    );
    await restored.initialize();

    final restoredRoom = restored.roomById(room.id);
    expect(restoredRoom, isNotNull);
    expect(
      restoredRoom!.missions.map((item) => item.title),
      room.missions.map((item) => item.title),
    );
    expect(
      restored.submissionsForRoom(room.id).single.localPath,
      contains('photo.jpg'),
    );
    expect(restored.messagesForRoom(room.id).single.text, '로컬 메시지');
  });

  test('큰 사진을 최대 1920px JPEG로 최적화해 앱 폴더에 보관한다', () async {
    final directory = await Directory.systemTemp.createTemp('doit-media-test-');
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}${Platform.pathSeparator}source.png');
    final original = image.Image(width: 2400, height: 2000);
    source.writeAsBytesSync(image.encodePng(original));

    final store = LocalMediaStore(documentsDirectory: () async => directory);
    final savedPath = await store.persist(
      sourcePath: source.path,
      kind: MissionMediaKind.photo,
    );
    final optimized = image.decodeImage(await File(savedPath).readAsBytes());

    expect(savedPath, endsWith('.jpg'));
    expect(optimized, isNotNull);
    expect(optimized!.width, lessThanOrEqualTo(1920));
    expect(optimized.height, lessThanOrEqualTo(1920));
  });
}
