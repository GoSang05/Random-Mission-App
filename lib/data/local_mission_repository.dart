import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/mission_data.dart';
import 'default_missions.dart';
import 'local_mission_store.dart';

enum RepositoryStatus { idle, loading, ready, error }

enum JoinRoomResult {
  joined,
  alreadyJoined,
  invalidCode,
  wrongPassword,
  roomNotFound,
}

/// In-memory data for the non-production MVP preview.
///
/// This intentionally provides no persistence, authentication, uploads, or
/// authorization. Replace it with the approved Supabase repository before
/// treating any private-room boundary as secure.
class LocalMissionRepository extends ChangeNotifier {
  LocalMissionRepository({
    this.previewUserId = 'preview-user',
    this.previewUserName = '나',
    this.includePreviewData = true,
    this.store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const maxRoomNameLength = 40;
  static const maxMessageLength = 500;
  static const maxLocalPathLength = 2048;

  final String previewUserId;
  String previewUserName;
  final bool includePreviewData;
  final LocalMissionStore? store;
  final DateTime Function() _now;
  final Random _secureRandom = Random.secure();

  final List<MissionRoom> _rooms = [];
  final List<MissionSubmission> _submissions = [];
  final List<ChatMessage> _messages = [];
  final Map<String, Map<String, VoteChoice>> _votesBySubmission = {};
  Future<void> _writeQueue = Future<void>.value();
  String? _missionDateKey;

  RepositoryStatus _status = RepositoryStatus.idle;
  String? _errorMessage;

  RepositoryStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RepositoryStatus.loading;

  Future<void> persistPendingChanges() => _writeQueue;

  void refreshDailyMissionsIfNeeded() {
    if (_status != RepositoryStatus.ready ||
        _missionDateKey == _dateKey(_now())) {
      return;
    }
    _refreshDailyMissions();
    notifyListeners();
    _persist();
  }

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
            .where(
              (submission) =>
                  joinedIds.contains(submission.roomId) &&
                  _isCurrentDay(submission.createdAt) &&
                  submission.mediaKind == MissionMediaKind.photo,
            )
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
      final saved = await store?.load();
      if (saved != null) {
        _restore(saved);
      } else if (includePreviewData) {
        _seedPreviewData();
      } else {
        _seedEmptyProductData();
      }
      _refreshDailyMissions();
      _status = RepositoryStatus.ready;
      _persist();
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
        _submissions
            .where(
              (submission) =>
                  submission.roomId == roomId &&
                  submission.mediaKind == MissionMediaKind.photo &&
                  _isCurrentDay(submission.createdAt),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(submissions);
  }

  List<MissionSubmission> submissionHistoryForRoom(String roomId) {
    final room = roomById(roomId);
    if (room == null || room.isGlobal) return const [];
    final submissions =
        _submissions
            .where(
              (submission) =>
                  submission.roomId == roomId &&
                  submission.mediaKind == MissionMediaKind.photo &&
                  !_isCurrentDay(submission.createdAt),
            )
            .toList()
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

  MissionRoom createRoom(String name, {String? password}) {
    _requireReady();
    final cleanName = _requiredText(name, '방 이름', maxRoomNameLength);
    final cleanPassword = password?.trim();
    if (cleanPassword != null && cleanPassword.length > 40) {
      throw ArgumentError('비밀번호는 40자 이하여야 해요.');
    }
    final code = _roomCode();
    final room = MissionRoom(
      id: _id('room'),
      name: cleanName,
      kind: MissionRoomKind.private,
      code: code,
      password: cleanPassword == null || cleanPassword.isEmpty
          ? null
          : cleanPassword,
      isJoined: true,
      memberCount: 1,
      missions: _dailyMissions(code),
    );
    _rooms.insert(0, room);
    notifyListeners();
    _persist();
    return room;
  }

  JoinRoomResult joinRoom(String code, {String? password}) {
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
    if (_rooms[index].isLocked && _rooms[index].password != password?.trim()) {
      return JoinRoomResult.wrongPassword;
    }

    _rooms[index] = _rooms[index].copyWith(
      isJoined: true,
      memberCount: _rooms[index].memberCount + 1,
    );
    notifyListeners();
    _persist();
    return JoinRoomResult.joined;
  }

  MissionRoom importJoinedRoom({
    required String id,
    required String name,
    required String code,
    required int memberCount,
  }) {
    _requireReady();
    final existingIndex = _rooms.indexWhere((room) => room.id == id);
    if (existingIndex != -1) {
      final existing = _rooms[existingIndex];
      _rooms[existingIndex] = MissionRoom(
        id: existing.id,
        name: existing.name,
        kind: MissionRoomKind.private,
        code: existing.code ?? code,
        password: existing.password,
        isJoined: true,
        memberCount: memberCount,
        missions: _dailyMissions(existing.code ?? code),
      );
      notifyListeners();
      _persist();
      return _rooms[existingIndex];
    }

    final room = MissionRoom(
      id: id,
      name: _requiredText(name, '방 이름', maxRoomNameLength),
      kind: MissionRoomKind.private,
      code: code,
      isJoined: true,
      memberCount: memberCount,
      missions: _dailyMissions(code),
    );
    _rooms.insert(0, room);
    notifyListeners();
    _persist();
    return room;
  }

  MissionSubmission addSubmission({
    required String roomId,
    required String missionId,
    required String localPath,
    required MissionMediaKind mediaKind,
  }) {
    _requireReady();
    if (mediaKind != MissionMediaKind.photo) {
      throw ArgumentError('사진만 업로드할 수 있어요.');
    }
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
      createdAt: _now(),
    );
    _submissions.insert(0, submission);
    _votesBySubmission[submission.id] = {};
    notifyListeners();
    _persist();
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
    _persist();
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
      createdAt: _now(),
    );
    _messages.add(message);
    notifyListeners();
    _persist();
    return message;
  }

  void updatePreviewUserName(String value) {
    previewUserName = _requiredText(value, '닉네임', 40);
    notifyListeners();
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

  String _id(String prefix) {
    const hex = '0123456789abcdef';
    final entropy = List.generate(
      16,
      (_) => hex[_secureRandom.nextInt(hex.length)],
    ).join();
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }

  String _roomCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    do {
      code = List.generate(
        6,
        (_) => alphabet[_secureRandom.nextInt(alphabet.length)],
      ).join();
    } while (_rooms.any((room) => room.code == code));
    return code;
  }

  void _refreshDailyMissions() {
    for (var index = 0; index < _rooms.length; index++) {
      final room = _rooms[index];
      final scope = room.isGlobal ? 'global' : (room.code ?? room.id);
      _rooms[index] = room.copyWith(missions: _dailyMissions(scope));
    }
    _missionDateKey = _dateKey(_now());
  }

  List<Mission> _dailyMissions(String scope) {
    if (missionPool.isEmpty) return const [];
    final date = _dateKey(_now());
    final indexes = List<int>.generate(missionPool.length, (index) => index);
    indexes.shuffle(Random(_stableSeed('$scope|$date')));
    final count = min(dailyMissionCount, indexes.length);
    return List.generate(count, (position) {
      final poolIndex = indexes[position];
      return Mission(
        id: 'daily-$scope-$date-$poolIndex',
        title: missionPool[poolIndex],
        createdAt: _koreaTime(_now()),
        createdByUserId: 'system-daily',
      );
    });
  }

  int _stableSeed(String value) {
    var hash = 0x811C9DC5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  DateTime _koreaTime(DateTime value) =>
      value.toUtc().add(const Duration(hours: 9));

  String _dateKey(DateTime value) {
    final korea = _koreaTime(value);
    return '${korea.year.toString().padLeft(4, '0')}'
        '${korea.month.toString().padLeft(2, '0')}'
        '${korea.day.toString().padLeft(2, '0')}';
  }

  bool _isCurrentDay(DateTime value) => _dateKey(value) == _dateKey(_now());

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

  void _restore(LocalMissionSnapshot snapshot) {
    _clearData();
    _rooms.addAll(snapshot.rooms);
    _submissions.addAll(
      snapshot.submissions.where(
        (submission) => submission.mediaKind == MissionMediaKind.photo,
      ),
    );
    _messages.addAll(snapshot.messages);
    for (final entry in snapshot.votesBySubmission.entries) {
      _votesBySubmission[entry.key] = Map<String, VoteChoice>.from(entry.value);
    }
  }

  void _persist() {
    final destination = store;
    if (destination == null) return;
    final snapshot = LocalMissionSnapshot(
      rooms: List<MissionRoom>.from(_rooms),
      submissions: List<MissionSubmission>.from(_submissions),
      messages: List<ChatMessage>.from(_messages),
      votesBySubmission: _votesBySubmission.map(
        (key, value) => MapEntry(key, Map<String, VoteChoice>.from(value)),
      ),
    );
    _writeQueue = _writeQueue
        .then((_) => destination.save(snapshot))
        .catchError((Object _) {});
    unawaited(_writeQueue);
  }

  void _seedPreviewData() {
    _clearData();
    final now = _now();
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
        createdAt: now,
      ),
      MissionSubmission(
        id: 'submission-campus-jun',
        roomId: 'room-campus',
        missionId: campusMission.id,
        authorUserId: 'seed-user-jun',
        authorName: '준',
        mediaKind: MissionMediaKind.photo,
        createdAt: now,
      ),
      MissionSubmission(
        id: 'submission-global-sora',
        roomId: 'room-global',
        missionId: globalMission.id,
        authorUserId: 'seed-user-sora',
        authorName: '소라',
        mediaKind: MissionMediaKind.photo,
        createdAt: now,
      ),
      MissionSubmission(
        id: 'submission-global-doyun',
        roomId: 'room-global',
        missionId: globalMission.id,
        authorUserId: 'seed-user-doyun',
        authorName: '도윤',
        mediaKind: MissionMediaKind.photo,
        createdAt: now,
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

  void _seedEmptyProductData() {
    _clearData();
    _rooms.add(
      MissionRoom(
        id: 'room-global',
        name: 'Global Mission Room',
        kind: MissionRoomKind.global,
        isJoined: true,
        memberCount: 0,
        missions: _dailyMissions('global'),
      ),
    );
  }
}
