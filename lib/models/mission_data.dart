enum MissionRoomKind { private, global }

enum MissionMediaKind { photo, video }

enum VoteChoice { accepted, notAccepted }

class Mission {
  const Mission({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.createdByUserId,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final String createdByUserId;
}

class MissionRoom {
  MissionRoom({
    required this.id,
    required this.name,
    required this.kind,
    required this.isJoined,
    required this.memberCount,
    required List<Mission> missions,
    this.code,
    this.password,
  }) : missions = List.unmodifiable(missions);

  final String id;
  final String name;
  final MissionRoomKind kind;
  final String? code;
  final String? password;
  final bool isJoined;
  final int memberCount;
  final List<Mission> missions;

  bool get isGlobal => kind == MissionRoomKind.global;
  bool get isLocked => password != null && password!.isNotEmpty;

  MissionRoom copyWith({
    bool? isJoined,
    int? memberCount,
    List<Mission>? missions,
    String? password,
  }) {
    return MissionRoom(
      id: id,
      name: name,
      kind: kind,
      code: code,
      password: password ?? this.password,
      isJoined: isJoined ?? this.isJoined,
      memberCount: memberCount ?? this.memberCount,
      missions: missions ?? this.missions,
    );
  }
}

class MissionSubmission {
  const MissionSubmission({
    required this.id,
    required this.roomId,
    required this.missionId,
    required this.authorUserId,
    required this.authorName,
    required this.mediaKind,
    required this.createdAt,
    this.localPath,
    this.remoteUrl,
    this.storagePath,
    this.acceptedVotes = 0,
    this.notAcceptedVotes = 0,
    this.currentUserVote,
  });

  final String id;
  final String roomId;
  final String missionId;
  final String authorUserId;
  final String authorName;
  final String? localPath;
  final String? remoteUrl;
  final String? storagePath;
  final MissionMediaKind mediaKind;
  final DateTime createdAt;
  final int acceptedVotes;
  final int notAcceptedVotes;
  final VoteChoice? currentUserVote;

  MissionSubmission copyWith({
    int? acceptedVotes,
    int? notAcceptedVotes,
    VoteChoice? currentUserVote,
  }) {
    return MissionSubmission(
      id: id,
      roomId: roomId,
      missionId: missionId,
      authorUserId: authorUserId,
      authorName: authorName,
      localPath: localPath,
      remoteUrl: remoteUrl,
      storagePath: storagePath,
      mediaKind: mediaKind,
      createdAt: createdAt,
      acceptedVotes: acceptedVotes ?? this.acceptedVotes,
      notAcceptedVotes: notAcceptedVotes ?? this.notAcceptedVotes,
      currentUserVote: currentUserVote ?? this.currentUserVote,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderUserId,
    required this.senderName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String roomId;
  final String senderUserId;
  final String senderName;
  final String text;
  final DateTime createdAt;
}
