class MissionRoom {
  MissionRoom({
    required this.name,
    required this.code,
    required this.emoji,
    required this.mission,
    required this.memberCount,
    this.password,
    this.isJoined = false,
  });

  final String name;
  final String code;
  final String emoji;
  final String mission;
  final String? password;
  int memberCount;
  bool isJoined;

  bool get isLocked => password != null && password!.isNotEmpty;
}
