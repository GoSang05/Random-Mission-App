import 'package:flutter/foundation.dart';

import '../models/mission_data.dart';

enum RepositoryStatus { idle, loading, ready, error }

enum JoinRoomResult { joined, alreadyJoined, invalidCode, roomNotFound }

/// In-memory data for the non-production MVP preview.
///
/// This intentionally provides no persistence, authentication, uploads, or
/// authorization. Replace it with the approved Supabase repository before
/// treating any private-room boundary as secure.
class LocalMissionRepository extends ChangeNotifier {
  LocalMissionRepository({
    this.previewUserId = 'preview-user',
    this.previewUserName = '나',
  });

  static const maxRoomNameLength = 40;
  static const maxMissionTitleLength = 120;
  static const maxMessageLength = 500;
  static const maxLocalPathLength = 2048;

  final String previewUserId;
  final String previewUserName;

  final List<MissionRoom> _rooms = [];
  final List<MissionSubmission> _submissions = [];
  final List<ChatMessage> _messages = [];
  final Map<String, Map<String, VoteChoice>> _votesBySubmission = {};

  RepositoryStatus _status = RepositoryStatus.idle;
  String? _errorMessage;
  int _nextId = 1000;
  int _nextRoomCode = 100;

  RepositoryStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RepositoryStatus.loading;

  List<MissionRoom> get joinedRooms => List.unmodifiable(
    _rooms.where(
      (room) => room.kind == MissionRoomKind.private && room.isJoined,
    ),
  );

  MissionRoom? get globalRoom {
    for (final room in _rooms) {
      if (room.kind == MissionRoomKind.global) return room;
    }
    return null;
  }

  List<MissionSubmission> get recentPrivateSubmissions {
    final joinedIds = joinedRooms.map((room) => room.id).toSet();
    final recent =
        _submissions
            .where((submission) => joinedIds.contains(submission.roomId))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(recent.take(10));
  }

  Future<void> initialize() async {
    if (_status == RepositoryStatus.loading ||
        _status == RepositoryStatus.ready) {
      return;
    }

    _status = RepositoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _seedPreviewData();
      _status = RepositoryStatus.ready;
    } catch (_) {
      _clearData();
      _errorMessage = '미리보기 데이터를 불러오지 못했어요.';
      _status = RepositoryStatus.error;
    }
    notifyListeners();
  }

  MissionRoom? roomById(String roomId) {
    final room = _roomById(roomId);
    if (room == null ||
        (room.kind == MissionRoomKind.private && !room.isJoined)) {
      return null;
    }
    return room;
  }

  Mission? missionById(String roomId, String missionId) {
    final room = roomById(roomId);
    if (room == null) return null;
    for (final mission in room.missions) {
      if (mission.id == missionId) return mission;
    }
    return null;
  }

  List<MissionSubmission> submissionsForRoom(String roomId) {
    if (roomById(roomId) == null) return const [];
    final submissions =
        _submissions.where((submission) => submission.roomId == roomId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(submissions);
  }

  List<ChatMessage> messagesForRoom(String roomId) {
    if (roomById(roomId) == null) return const [];
    final messages =
        _messages.where((message) => message.roomId == roomId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(messages);
  }

  MissionRoom createRoom(String name) {
    _requireReady();
    final cleanName = _requiredText(name, '방 이름', maxRoomNameLength);
    final now = DateTime.now();
    final mission = Mission(
      id: _id('mission'),
      title: '오늘 가장 웃긴 순간을 찍어보세요',
      createdAt: now,
      createdByUserId: previewUserId,
    );
    final room = MissionRoom(
      id: _id('room'),
      name: cleanName,
      kind: MissionRoomKind.private,
      code: _roomCode(),
      isJoined: true,
      memberCount: 1,
      missions: [mission],
    );
    _rooms.insert(0, room);
    notifyListeners();
    return room;
  }

  JoinRoomResult joinRoom(String code) {
    _requireReady();
    final cleanCode = code.trim().toUpperCase();
    if (cleanCode.isEmpty ||
        cleanCode.length > 12 ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(cleanCode)) {
      return JoinRoomResult.invalidCode;
    }

    final index = _rooms.indexWhere(
      (room) => room.kind == MissionRoomKind.private && room.code == cleanCode,
    );
    if (index == -1) return JoinRoomResult.roomNotFound;
    if (_rooms[index].isJoined) return JoinRoomResult.alreadyJoined;

    _rooms[index] = _rooms[index].copyWith(
      isJoined: true,
      memberCount: _rooms[index].memberCount + 1,
    );
    notifyListeners();
    return JoinRoomResult.joined;
  }

  Mission createGlobalMission(String title) {
    _requireReady();
    final cleanTitle = _requiredText(title, '미션', maxMissionTitleLength);
    final roomIndex = _rooms.indexWhere(
      (room) => room.kind == MissionRoomKind.global,
    );
    if (roomIndex == -1) throw StateError('Global room is unavailable.');

    final mission = Mission(
      id: _id('mission'),
      title: cleanTitle,
      createdAt: DateTime.now(),
      createdByUserId: previewUserId,
    );
    final room = _rooms[roomIndex];
    _rooms[roomIndex] = room.copyWith(missions: [...room.missions, mission]);
    notifyListeners();
    return mission;
  }

  MissionSubmission addSubmission({
    required String roomId,
    required String missionId,
    required String localPath,
    required MissionMediaKind mediaKind,
  }) {
    _requireReady();
    final cleanPath = _requiredText(localPath, '미디어 경로', maxLocalPathLength);
    final room = _accessibleRoom(roomId);
    if (missionById(room.id, missionId) == null) {
      throw ArgumentError.value(missionId, 'missionId', 'Unknown mission.');
    }

    final submission = MissionSubmission(
      id: _id('submission'),
      roomId: room.id,
      missionId: missionId,
      authorUserId: previewUserId,
      authorName: previewUserName,
      localPath: cleanPath,
      mediaKind: mediaKind,
      createdAt: DateTime.now(),
    );
    _submissions.insert(0, submission);
    _votesBySubmission[submission.id] = {};
    notifyListeners();
    return submission;
  }

  bool castVote(String submissionId, VoteChoice choice) {
    _requireReady();
    final submissionIndex = _submissions.indexWhere(
      (submission) => submission.id == submissionId,
    );
    if (submissionIndex == -1) {
      throw ArgumentError.value(
        submissionId,
        'submissionId',
        'Unknown submission.',
      );
    }
    _accessibleRoom(_submissions[submissionIndex].roomId);

    final votes = _votesBySubmission.putIfAbsent(submissionId, () => {});
    if (votes[previewUserId] == choice) return false;

    votes[previewUserId] = choice;
    _syncVotes(submissionId);
    notifyListeners();
    return true;
  }

  ChatMessage sendMessage(String roomId, String text) {
    _requireReady();
    final room = _accessibleRoom(roomId);
    final cleanText = _requiredText(text, '메시지', maxMessageLength);
    final message = ChatMessage(
      id: _id('message'),
      roomId: room.id,
      senderUserId: previewUserId,
      senderName: previewUserName,
      text: cleanText,
      createdAt: DateTime.now(),
    );
    _messages.add(message);
    notifyListeners();
    return message;
  }

  MissionRoom _accessibleRoom(String roomId) {
    final room = _roomById(roomId);
    if (room == null) {
      throw ArgumentError.value(roomId, 'roomId', 'Unknown room.');
    }
    if (room.kind == MissionRoomKind.private && !room.isJoined) {
      throw StateError('Join this room before accessing it.');
    }
    return room;
  }

  MissionRoom? _roomById(String roomId) {
    for (final room in _rooms) {
      if (room.id == roomId) return room;
    }
    return null;
  }

  void _requireReady() {
    if (_status != RepositoryStatus.ready) {
      throw StateError('Initialize the repository before using it.');
    }
  }

  String _requiredText(String value, String label, int maxLength) {
    final clean = value.trim();
    if (clean.isEmpty) throw ArgumentError('$label을(를) 입력해 주세요.');
    if (clean.length > maxLength) {
      throw ArgumentError('$label은(는) $maxLength자 이하여야 해요.');
    }
    return clean;
  }

  String _id(String prefix) => '$prefix-${_nextId++}';

  String _roomCode() {
    String code;
    do {
      code = 'RM${(_nextRoomCode++).toString().padLeft(4, '0')}';
    } while (_rooms.any((room) => room.code == code));
    return code;
  }

  void _syncVotes(String submissionId) {
    final index = _submissions.indexWhere(
      (submission) => submission.id == submissionId,
    );
    if (index == -1) return;
    final votes = _votesBySubmission[submissionId] ?? const {};
    _submissions[index] = _submissions[index].copyWith(
      acceptedVotes: votes.values
          .where((vote) => vote == VoteChoice.accepted)
          .length,
      notAcceptedVotes: votes.values
          .where((vote) => vote == VoteChoice.notAccepted)
          .length,
      currentUserVote: votes[previewUserId],
    );
  }

  void _seedVotes(
    String submissionId, {
    int accepted = 0,
    int notAccepted = 0,
    VoteChoice? previewVote,
  }) {
    final votes = <String, VoteChoice>{};
    for (var index = 0; index < accepted; index++) {
      votes['seed-$submissionId-a-$index'] = VoteChoice.accepted;
    }
    for (var index = 0; index < notAccepted; index++) {
      votes['seed-$submissionId-n-$index'] = VoteChoice.notAccepted;
    }
    if (previewVote != null) votes[previewUserId] = previewVote;
    _votesBySubmission[submissionId] = votes;
    _syncVotes(submissionId);
  }

  void _clearData() {
    _rooms.clear();
    _submissions.clear();
    _messages.clear();
    _votesBySubmission.clear();
  }

  void _seedPreviewData() {
    _clearData();
    final now = DateTime.now();
    final friendsMission = Mission(
      id: 'mission-private-red',
      title: '빨간색 물건 5개를 한 장에 찍기',
      createdAt: now.subtract(const Duration(hours: 8)),
      createdByUserId: 'seed-user-minji',
    );
    final campusMission = Mission(
      id: 'mission-private-1000won',
      title: '1,000원으로 가장 쓸모없는 물건 사기',
      createdAt: now.subtract(const Duration(hours: 7)),
      createdByUserId: 'seed-user-jun',
    );
    final nightMission = Mission(
      id: 'mission-private-shadow',
      title: '가장 이상한 그림자를 찍기',
      createdAt: now.subtract(const Duration(hours: 6)),
      createdByUserId: 'seed-user-sora',
    );
    final globalMission = Mission(
      id: 'mission-global-blue',
      title: '오늘 발견한 파란색을 공유하기',
      createdAt: now.subtract(const Duration(hours: 5)),
      createdByUserId: 'system-preview',
    );

    _rooms.addAll([
      MissionRoom(
        id: 'room-friends',
        name: '친구들의 랜덤 미션',
        kind: MissionRoomKind.private,
        code: 'FRI824',
        isJoined: true,
        memberCount: 4,
        missions: [friendsMission],
      ),
      MissionRoom(
        id: 'room-campus',
        name: '캠퍼스 탐험대',
        kind: MissionRoomKind.private,
        code: 'CAMPUS',
        isJoined: true,
        memberCount: 6,
        missions: [campusMission],
      ),
      MissionRoom(
        id: 'room-night',
        name: '밤 산책 크루',
        kind: MissionRoomKind.private,
        code: 'NIGHT7',
        isJoined: false,
        memberCount: 3,
        missions: [nightMission],
      ),
      MissionRoom(
        id: 'room-global',
        name: 'Global Mission Room',
        kind: MissionRoomKind.global,
        isJoined: true,
        memberCount: 1284,
        missions: [globalMission],
      ),
    ]);

    _submissions.addAll([
      MissionSubmission(
        id: 'submission-friends-minji',
        roomId: 'room-friends',
        missionId: friendsMission.id,
        authorUserId: 'seed-user-minji',
        authorName: '민지',
        mediaKind: MissionMediaKind.photo,
        createdAt: now.subtract(const Duration(minutes: 35)),
      ),
      MissionSubmission(
        id: 'submission-campus-jun',
        roomId: 'room-campus',
        missionId: campusMission.id,
        authorUserId: 'seed-user-jun',
        authorName: '준',
        mediaKind: MissionMediaKind.video,
        createdAt: now.subtract(const Duration(minutes: 52)),
      ),
      MissionSubmission(
        id: 'submission-global-sora',
        roomId: 'room-global',
        missionId: globalMission.id,
        authorUserId: 'seed-user-sora',
        authorName: '소라',
        mediaKind: MissionMediaKind.photo,
        createdAt: now.subtract(const Duration(minutes: 18)),
      ),
      MissionSubmission(
        id: 'submission-global-doyun',
        roomId: 'room-global',
        missionId: globalMission.id,
        authorUserId: 'seed-user-doyun',
        authorName: '도윤',
        mediaKind: MissionMediaKind.photo,
        createdAt: now.subtract(const Duration(minutes: 29)),
      ),
    ]);

    _seedVotes(
      'submission-friends-minji',
      accepted: 2,
      notAccepted: 1,
      previewVote: VoteChoice.accepted,
    );
    _seedVotes('submission-campus-jun', accepted: 4);
    _seedVotes('submission-global-sora', accepted: 12, notAccepted: 2);
    _seedVotes('submission-global-doyun', accepted: 8, notAccepted: 1);

    _messages.addAll([
      ChatMessage(
        id: 'message-friends-1',
        roomId: 'room-friends',
        senderUserId: 'seed-user-minji',
        senderName: '민지',
        text: '오늘 미션 생각보다 어렵다 😆',
        createdAt: now.subtract(const Duration(minutes: 44)),
      ),
      ChatMessage(
        id: 'message-friends-2',
        roomId: 'room-friends',
        senderUserId: previewUserId,
        senderName: previewUserName,
        text: '퇴근길에 찾아볼게!',
        createdAt: now.subtract(const Duration(minutes: 40)),
      ),
    ]);
  }
}
