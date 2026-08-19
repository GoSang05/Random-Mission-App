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
}
