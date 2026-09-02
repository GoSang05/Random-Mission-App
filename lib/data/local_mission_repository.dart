import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class MissionRepositoryException implements Exception {
  const MissionRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
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
    this.includePreviewData = false,
    this.store,
    this.supabaseClient,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const maxRoomNameLength = 40;
  static const maxMessageLength = 500;
  static const maxLocalPathLength = 2048;

  final String previewUserId;
  String previewUserName;
  final bool includePreviewData;
  final LocalMissionStore? store;
  final SupabaseClient? supabaseClient;
  final DateTime Function() _now;
  final Random _secureRandom = Random.secure();

  final List<MissionRoom> _rooms = [];
  final List<MissionSubmission> _submissions = [];
  final List<ChatMessage> _messages = [];
  final Map<String, Map<String, VoteChoice>> _votesBySubmission = {};
  Future<void> _writeQueue = Future<void>.value();
  RealtimeChannel? _remoteChannel;
  Timer? _remoteReloadDebounce;
  bool _remoteReloading = false;
  String? _missionDateKey;

  RepositoryStatus _status = RepositoryStatus.idle;
  String? _errorMessage;

  RepositoryStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == RepositoryStatus.loading;
  bool get isRemote => supabaseClient != null;

  Future<void> persistPendingChanges() => _writeQueue;

  void refreshDailyMissionsIfNeeded() {
    if (_status != RepositoryStatus.ready ||
        _missionDateKey == _dateKey(_now())) {
      return;
    }
    if (isRemote) {
      _scheduleRemoteReload();
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
    return List.unmodifiable(recent);
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
      if (isRemote) {
        await _loadRemoteState();
        _subscribeToRemoteChanges();
      } else {
        final saved = await store?.load();
        if (saved != null) {
          _restore(saved);
        } else {
          _seedEmptyProductData();
        }
        _refreshDailyMissions();
        _persist();
      }
      _status = RepositoryStatus.ready;
    } catch (error) {
      _clearData();
      _errorMessage = isRemote
          ? 'Supabase에서 미션 데이터를 불러오지 못했어요. 서버 마이그레이션을 확인해 주세요.'
          : '로컬 데이터를 불러오지 못했어요.';
      _status = RepositoryStatus.error;
      debugPrint('Mission repository initialization failed: $error');
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

  Future<MissionRoom> createRoomPersisted(
    String name, {
    String? password,
  }) async {
    if (!isRemote) return createRoom(name, password: password);
    final cleanName = _requiredText(name, '방 이름', maxRoomNameLength);
    final cleanPassword = password?.trim();
    if (cleanPassword != null && cleanPassword.length > 40) {
      throw ArgumentError('비밀번호는 40자 이하여야 해요.');
    }
    try {
      final result = await supabaseClient!.rpc(
        'create_mission_room',
        params: {'p_name': cleanName, 'p_password': cleanPassword},
      );
      await _loadRemoteState(notify: true);
      final id = (result as Map<String, dynamic>)['id'].toString();
      return _roomById(id) ?? _roomFromRemote(result);
    } on PostgrestException catch (error) {
      throw MissionRepositoryException(_remoteMessage(error));
    }
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

  Future<JoinRoomResult> joinRoomPersisted(
    String code, {
    String? password,
  }) async {
    if (!isRemote) return joinRoom(code, password: password);
    final cleanCode = code.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4,12}$').hasMatch(cleanCode)) {
      return JoinRoomResult.invalidCode;
    }
    if (_rooms.any((room) => room.code == cleanCode && room.isJoined)) {
      return JoinRoomResult.alreadyJoined;
    }
    try {
      await supabaseClient!.rpc(
        'join_mission_room',
        params: {'p_invite_code': cleanCode, 'p_password': password?.trim()},
      );
      await _loadRemoteState(notify: true);
      return JoinRoomResult.joined;
    } on PostgrestException catch (error) {
      if (error.message.contains('wrong_password')) {
        return JoinRoomResult.wrongPassword;
      }
      if (error.message.contains('invalid_invite')) {
        return JoinRoomResult.roomNotFound;
      }
      throw MissionRepositoryException(_remoteMessage(error));
    }
  }

  Future<void> leaveRoomPersisted(String roomId) async {
    final room = _accessibleRoom(roomId);
    if (room.isGlobal) {
      throw const MissionRepositoryException(
        'Global Mission Room에서는 나갈 수 없어요.',
      );
    }
    if (isRemote) {
      try {
        await supabaseClient!.rpc(
          'leave_mission_room',
          params: {'p_room_id': roomId},
        );
        await _loadRemoteState(notify: true);
        return;
      } on PostgrestException catch (error) {
        throw MissionRepositoryException(_remoteMessage(error));
      }
    }

    _messages.add(
      ChatMessage(
        id: _id('message'),
        roomId: roomId,
        senderUserId: 'system',
        senderName: '알림',
        text: '$previewUserName님이 방을 나갔어요.',
        createdAt: _now(),
      ),
    );
    _rooms.removeWhere((item) => item.id == roomId);
    _submissions.removeWhere((item) => item.roomId == roomId);
    notifyListeners();
    _persist();
  }

  Future<void> renameRoomPersisted(String roomId, String name) async {
    final room = _accessibleRoom(roomId);
    if (room.isGlobal) {
      throw const MissionRepositoryException(
        'Global Mission Room 이름은 바꿀 수 없어요.',
      );
    }
    final cleanName = _requiredText(name, '방 이름', maxRoomNameLength);
    if (isRemote) {
      try {
        await supabaseClient!.rpc(
          'rename_mission_room',
          params: {'p_room_id': roomId, 'p_name': cleanName},
        );
        await _loadRemoteState(notify: true);
        return;
      } on PostgrestException catch (error) {
        if (error.message.contains('owner_required')) {
          throw const MissionRepositoryException('방을 만든 사람만 이름을 바꿀 수 있어요.');
        }
        throw MissionRepositoryException(_remoteMessage(error));
      }
    }
    final index = _rooms.indexWhere((item) => item.id == roomId);
    _rooms[index] = room.copyWith(name: cleanName);
    notifyListeners();
    _persist();
  }

  Future<List<MissionRoomMember>> listRoomMembers(String roomId) async {
    final room = _accessibleRoom(roomId);
    if (room.isGlobal) return const [];
    if (!isRemote) {
      return [
        MissionRoomMember(
          userId: previewUserId,
          displayName: previewUserName,
          joinedAt: _now(),
          isOwner: true,
        ),
      ];
    }
    try {
      final result = await supabaseClient!.rpc(
        'list_mission_room_members',
        params: {'p_room_id': roomId},
      );
      return (result as List<dynamic>)
          .map(
            (row) => MissionRoomMember.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw MissionRepositoryException(_remoteMessage(error));
    }
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

  Future<MissionSubmission> addSubmissionPersisted({
    required String roomId,
    required String missionId,
    required String localPath,
    required MissionMediaKind mediaKind,
  }) async {
    if (!isRemote) {
      return addSubmission(
        roomId: roomId,
        missionId: missionId,
        localPath: localPath,
        mediaKind: mediaKind,
      );
    }
    if (mediaKind != MissionMediaKind.photo) {
      throw ArgumentError('사진만 업로드할 수 있어요.');
    }
    _accessibleRoom(roomId);
    if (missionById(roomId, missionId) == null) {
      throw ArgumentError.value(missionId, 'missionId', 'Unknown mission.');
    }
    final client = supabaseClient!;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const MissionRepositoryException('다시 로그인해 주세요.');
    }
    final file = File(localPath);
    if (!await file.exists()) {
      throw const MissionRepositoryException('업로드할 사진 파일을 찾을 수 없어요.');
    }
    final objectName =
        '${DateTime.now().microsecondsSinceEpoch}-${_secureRandom.nextInt(1 << 32)}.jpg';
    final storagePath = '$roomId/${user.id}/$objectName';
    String? submissionId;
    try {
      await client.storage
          .from('mission-photos')
          .upload(
            storagePath,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600',
              upsert: false,
            ),
          );
      final result = await client.rpc(
        'create_mission_submission',
        params: {
          'p_room_id': roomId,
          'p_daily_mission_id': missionId,
          'p_storage_path': storagePath,
        },
      );
      submissionId = result.toString();
      await _loadRemoteState(notify: true);
      return _submissions.firstWhere(
        (submission) => submission.id == submissionId,
      );
    } on Object catch (error) {
      if (submissionId == null) {
        try {
          await client.storage.from('mission-photos').remove([storagePath]);
        } catch (_) {}
      }
      if (error is PostgrestException) {
        throw MissionRepositoryException(_remoteMessage(error));
      }
      if (error is StorageException) {
        throw MissionRepositoryException(
          '사진을 서버에 업로드하지 못했어요: ${error.message}',
        );
      }
      rethrow;
    }
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

  Future<bool> castVotePersisted(String submissionId, VoteChoice choice) async {
    if (!isRemote) return castVote(submissionId, choice);
    final submission = _submissions.firstWhere(
      (item) => item.id == submissionId,
      orElse: () => throw ArgumentError.value(submissionId, 'submissionId'),
    );
    if (submission.currentUserVote == choice) return false;
    try {
      await supabaseClient!.rpc(
        'cast_mission_vote',
        params: {
          'p_submission_id': submissionId,
          'p_choice': choice == VoteChoice.accepted
              ? 'accepted'
              : 'not_accepted',
        },
      );
      await _loadRemoteState(notify: true);
      return true;
    } on PostgrestException catch (error) {
      throw MissionRepositoryException(_remoteMessage(error));
    }
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

  Future<void> _loadRemoteState({bool notify = false}) async {
    final client = supabaseClient;
    if (client == null || _remoteReloading) return;
    _remoteReloading = true;
    try {
      final response = await client.rpc('get_mission_state');
      final root = Map<String, dynamic>.from(response as Map);
      final roomRows = (root['rooms'] as List<dynamic>? ?? const []);
      final submissionRows =
          (root['submissions'] as List<dynamic>? ?? const []);

      final loadedRooms = roomRows
          .map((raw) {
            final row = Map<String, dynamic>.from(raw as Map);
            final missions = (row['missions'] as List<dynamic>? ?? const [])
                .map((rawMission) {
                  final mission = Map<String, dynamic>.from(rawMission as Map);
                  return Mission(
                    id: mission['id'].toString(),
                    title: mission['title'] as String,
                    createdAt: DateTime.parse(
                      mission['createdAt'].toString(),
                    ).toLocal(),
                    createdByUserId: mission['createdByUserId'].toString(),
                  );
                })
                .toList(growable: false);
            return _roomFromRemote(row, missions: missions);
          })
          .toList(growable: false);

      final loadedSubmissions = await Future.wait(
        submissionRows.map((raw) async {
          final row = Map<String, dynamic>.from(raw as Map);
          final storagePath = row['storagePath'].toString();
          String? signedUrl;
          try {
            signedUrl = await client.storage
                .from('mission-photos')
                .createSignedUrl(storagePath, 60 * 60);
          } catch (_) {
            signedUrl = null;
          }
          final rawVote = row['currentUserVote'] as String?;
          return MissionSubmission(
            id: row['id'].toString(),
            roomId: row['roomId'].toString(),
            missionId: row['missionId'].toString(),
            authorUserId: row['authorUserId'].toString(),
            authorName: row['authorName'] as String? ?? '사용자',
            storagePath: storagePath,
            remoteUrl: signedUrl,
            mediaKind: MissionMediaKind.photo,
            createdAt: DateTime.parse(row['createdAt'].toString()).toLocal(),
            acceptedVotes: (row['acceptedVotes'] as num?)?.toInt() ?? 0,
            notAcceptedVotes: (row['notAcceptedVotes'] as num?)?.toInt() ?? 0,
            currentUserVote: switch (rawVote) {
              'accepted' => VoteChoice.accepted,
              'not_accepted' => VoteChoice.notAccepted,
              _ => null,
            },
          );
        }),
      );

      _clearData();
      _rooms.addAll(loadedRooms);
      _submissions.addAll(loadedSubmissions);
      _missionDateKey = _dateKey(_now());
      if (notify) notifyListeners();
    } finally {
      _remoteReloading = false;
    }
  }

  MissionRoom _roomFromRemote(
    Object? raw, {
    List<Mission> missions = const [],
  }) {
    final row = Map<String, dynamic>.from(raw as Map);
    final locked = row['isLocked'] == true;
    return MissionRoom(
      id: row['id'].toString(),
      name: row['name'] as String,
      kind: row['kind'] == 'global'
          ? MissionRoomKind.global
          : MissionRoomKind.private,
      code: row['code'] as String?,
      password: locked ? 'server-protected' : null,
      isJoined: true,
      memberCount: (row['memberCount'] as num?)?.toInt() ?? 0,
      missions: missions,
    );
  }

  String _remoteMessage(PostgrestException error) {
    final message = error.message;
    if (message.contains('wrong_password')) return '방 비밀번호가 일치하지 않아요.';
    if (message.contains('invalid_invite')) return '일치하는 방을 찾지 못했어요.';
    if (message.contains('not_a_room_member')) return '이 방에 접근할 권한이 없어요.';
    if (message.contains('rate_limit')) return '잠시 후 다시 시도해 주세요.';
    return '서버 요청을 처리하지 못했어요.';
  }

  void _subscribeToRemoteChanges() {
    final client = supabaseClient;
    if (client == null || _remoteChannel != null) return;
    _remoteChannel = client
        .channel('mission-state-$previewUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mission_rooms',
          callback: (_) => _scheduleRemoteReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mission_room_members',
          callback: (_) => _scheduleRemoteReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'daily_room_missions',
          callback: (_) => _scheduleRemoteReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mission_submissions',
          callback: (_) => _scheduleRemoteReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mission_votes',
          callback: (_) => _scheduleRemoteReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_profiles',
          callback: (_) => _scheduleRemoteReload(),
        )
        .subscribe();
  }

  void _scheduleRemoteReload() {
    if (!isRemote) return;
    _remoteReloadDebounce?.cancel();
    _remoteReloadDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_loadRemoteState(notify: true));
    });
  }

  @override
  void dispose() {
    _remoteReloadDebounce?.cancel();
    final channel = _remoteChannel;
    final client = supabaseClient;
    if (channel != null && client != null) {
      unawaited(client.removeChannel(channel));
    }
    super.dispose();
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
