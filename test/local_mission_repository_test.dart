import 'package:flutter_test/flutter_test.dart';
import 'package:random_mission_app/data/local_mission_repository.dart';
import 'package:random_mission_app/models/mission_data.dart';

void main() {
  test('local repository keeps room access and votes consistent', () async {
    final repository = LocalMissionRepository();
    addTearDown(repository.dispose);
    await repository.initialize();

    expect(repository.status, RepositoryStatus.ready);
    expect(repository.roomById('room-night'), isNull);
    expect(
      () => repository.addSubmission(
        roomId: 'room-night',
        missionId: 'mission-private-shadow',
        localPath: '/tmp/photo.jpg',
        mediaKind: MissionMediaKind.photo,
      ),
      throwsStateError,
    );
    expect(repository.joinRoom('NIGHT7'), JoinRoomResult.joined);
    expect(repository.joinRoom('NIGHT7'), JoinRoomResult.alreadyJoined);

    const submissionId = 'submission-global-sora';
    expect(repository.castVote(submissionId, VoteChoice.accepted), isTrue);
    expect(repository.castVote(submissionId, VoteChoice.accepted), isFalse);
    expect(
      repository
          .submissionsForRoom('room-global')
          .firstWhere((submission) => submission.id == submissionId)
          .acceptedVotes,
      13,
    );

    expect(repository.castVote(submissionId, VoteChoice.notAccepted), isTrue);
    final changed = repository
        .submissionsForRoom('room-global')
        .firstWhere((submission) => submission.id == submissionId);
    expect(changed.acceptedVotes, 12);
    expect(changed.notAcceptedVotes, 3);
    expect(changed.currentUserVote, VoteChoice.notAccepted);
  });

  test('signed-in product starts without private preview rooms', () async {
    final repository = LocalMissionRepository(
      previewUserId: 'signed-in-user',
      previewUserName: '민트',
      includePreviewData: false,
    );
    addTearDown(repository.dispose);
    await repository.initialize();

    expect(repository.joinedRooms, isEmpty);
    expect(repository.globalRoom, isNotNull);

    final imported = repository.importJoinedRoom(
      id: 'shared-room-id',
      name: '공유 미션 방',
      code: 'SHARED',
      memberCount: 2,
    );
    expect(imported.isJoined, isTrue);
    expect(repository.joinedRooms.single.id, 'shared-room-id');
  });
}
