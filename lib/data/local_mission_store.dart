import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/mission_data.dart';

class LocalMissionSnapshot {
  const LocalMissionSnapshot({
    required this.rooms,
    required this.submissions,
    required this.messages,
    required this.votesBySubmission,
  });

  final List<MissionRoom> rooms;
  final List<MissionSubmission> submissions;
  final List<ChatMessage> messages;
  final Map<String, Map<String, VoteChoice>> votesBySubmission;
}

abstract interface class LocalMissionStore {
  Future<LocalMissionSnapshot?> load();

  Future<void> save(LocalMissionSnapshot snapshot);
}

class SharedPreferencesMissionStore implements LocalMissionStore {
  SharedPreferencesMissionStore(this.storageKey);

  final String storageKey;

  @override
  Future<LocalMissionSnapshot?> load() async {
    try {
      final encoded = await SharedPreferencesAsync().getString(storageKey);
      if (encoded == null || encoded.isEmpty) return null;
      final root = jsonDecode(encoded) as Map<String, dynamic>;
      if (root['version'] != 1) return null;
      final rooms = (root['rooms'] as List<dynamic>)
          .map((value) => _roomFromJson(value as Map<String, dynamic>))
          .toList();
      final submissions = (root['submissions'] as List<dynamic>)
          .map((value) => _submissionFromJson(value as Map<String, dynamic>))
          .toList();
      final messages = (root['messages'] as List<dynamic>)
          .map((value) => _messageFromJson(value as Map<String, dynamic>))
          .toList();
      final rawVotes = root['votes'] as Map<String, dynamic>? ?? const {};
      final votes = <String, Map<String, VoteChoice>>{};
      for (final entry in rawVotes.entries) {
        votes[entry.key] = (entry.value as Map<String, dynamic>).map(
          (userId, value) =>
              MapEntry(userId, VoteChoice.values.byName(value as String)),
        );
      }
      return LocalMissionSnapshot(
        rooms: rooms,
        submissions: submissions,
        messages: messages,
        votesBySubmission: votes,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(LocalMissionSnapshot snapshot) {
    final payload = <String, dynamic>{
      'version': 1,
      'rooms': snapshot.rooms.map(_roomToJson).toList(),
      'submissions': snapshot.submissions.map(_submissionToJson).toList(),
      'messages': snapshot.messages.map(_messageToJson).toList(),
      'votes': snapshot.votesBySubmission.map(
        (submissionId, votes) => MapEntry(
          submissionId,
          votes.map((userId, vote) => MapEntry(userId, vote.name)),
        ),
      ),
    };
    return SharedPreferencesAsync().setString(storageKey, jsonEncode(payload));
  }

  Map<String, dynamic> _roomToJson(MissionRoom room) => {
    'id': room.id,
    'name': room.name,
    'kind': room.kind.name,
    'code': room.code,
    'password': room.password,
    'isJoined': room.isJoined,
    'memberCount': room.memberCount,
    'missions': room.missions
        .map(
          (mission) => {
            'id': mission.id,
            'title': mission.title,
            'createdAt': mission.createdAt.toIso8601String(),
            'createdByUserId': mission.createdByUserId,
          },
        )
        .toList(),
  };

  MissionRoom _roomFromJson(Map<String, dynamic> json) => MissionRoom(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: MissionRoomKind.values.byName(json['kind'] as String),
    code: json['code'] as String?,
    password: json['password'] as String?,
    isJoined: json['isJoined'] as bool,
    memberCount: json['memberCount'] as int,
    missions: (json['missions'] as List<dynamic>).map((value) {
      final mission = value as Map<String, dynamic>;
      return Mission(
        id: mission['id'] as String,
        title: mission['title'] as String,
        createdAt: DateTime.parse(mission['createdAt'] as String),
        createdByUserId: mission['createdByUserId'] as String,
      );
    }).toList(),
  );

  Map<String, dynamic> _submissionToJson(MissionSubmission submission) => {
    'id': submission.id,
    'roomId': submission.roomId,
    'missionId': submission.missionId,
    'authorUserId': submission.authorUserId,
    'authorName': submission.authorName,
    'localPath': submission.localPath,
    'mediaKind': submission.mediaKind.name,
    'createdAt': submission.createdAt.toIso8601String(),
    'acceptedVotes': submission.acceptedVotes,
    'notAcceptedVotes': submission.notAcceptedVotes,
    'currentUserVote': submission.currentUserVote?.name,
  };

  MissionSubmission _submissionFromJson(Map<String, dynamic> json) =>
      MissionSubmission(
        id: json['id'] as String,
        roomId: json['roomId'] as String,
        missionId: json['missionId'] as String,
        authorUserId: json['authorUserId'] as String,
        authorName: json['authorName'] as String,
        localPath: json['localPath'] as String?,
        mediaKind: MissionMediaKind.values.byName(json['mediaKind'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
        acceptedVotes: json['acceptedVotes'] as int? ?? 0,
        notAcceptedVotes: json['notAcceptedVotes'] as int? ?? 0,
        currentUserVote: json['currentUserVote'] == null
            ? null
            : VoteChoice.values.byName(json['currentUserVote'] as String),
      );

  Map<String, dynamic> _messageToJson(ChatMessage message) => {
    'id': message.id,
    'roomId': message.roomId,
    'senderUserId': message.senderUserId,
    'senderName': message.senderName,
    'text': message.text,
    'createdAt': message.createdAt.toIso8601String(),
  };

  ChatMessage _messageFromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    roomId: json['roomId'] as String,
    senderUserId: json['senderUserId'] as String,
    senderName: json['senderName'] as String,
    text: json['text'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
