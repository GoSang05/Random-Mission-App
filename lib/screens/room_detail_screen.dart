import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/local_mission_repository.dart';
import '../models/mission_data.dart';
import '../widgets/story_card_stack.dart';
import 'capture_screen.dart';
import 'mission_feed_screen.dart';

class RoomDetailScreen extends StatefulWidget {
  const RoomDetailScreen({
    required this.repository,
    required this.roomId,
    super.key,
  });

  final LocalMissionRepository repository;
  final String roomId;

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openCapture(Mission mission) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => CaptureScreen(
          missionTitle: mission.title,
          onSave: (result, onProgress) async {
            // ponytail: staged local progress; use Storage progress after backend approval.
            onProgress(0.2);
            await Future<void>.delayed(const Duration(milliseconds: 120));
            onProgress(0.7);
            widget.repository.addSubmission(
              roomId: widget.roomId,
              missionId: mission.id,
              localPath: result.path,
              mediaKind: result.kind,
            );
            onProgress(1);
          },
        ),
      ),
    );
    if (saved == true && mounted) _message('미션 인증을 스토리에 저장했어요.');
  }

  void _openStory(List<MissionSubmission> submissions, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissionFeedScreen(
          repository: widget.repository,
          roomId: widget.roomId,
          initialSubmissionId: submissions[index].id,
        ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;
    try {
      widget.repository.sendMessage(widget.roomId, text);
      _messageController.clear();
    } on ArgumentError catch (error) {
      _message(error.message.toString());
    }
  }

  void _showSettings(MissionRoom room) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('방 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              label: '방 코드',
              value: room.code ?? '-',
              onCopy: room.code == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: room.code!));
                      _message('방 코드를 복사했어요.');
                    },
            ),
            const Divider(),
            _InfoRow(label: '참여 인원', value: '${room.memberCount}명'),
          ],
        ),
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final room = widget.repository.roomById(widget.roomId);
        if (room == null) {
          return const Scaffold(body: Center(child: Text('방을 찾을 수 없어요.')));
        }
        final submissions = widget.repository.submissionsForRoom(room.id);
        final messages = widget.repository.messagesForRoom(room.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(room.name),
            actions: [
              IconButton(
                key: const Key('roomSettingsButton'),
                tooltip: '방 설정',
                onPressed: () => _showSettings(room),
                icon: const Icon(Icons.settings_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          _SectionHeader(
                            title: '오늘의 미션',
                            count: room.missions.length,
                          ),
                          const SizedBox(height: 12),
                          if (room.missions.isEmpty)
                            const _EmptyCard(text: '오늘 등록된 미션이 없어요.')
                          else
                            for (final mission in room.missions)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _MissionCard(
                                  mission: mission,
                                  onCamera: () => _openCapture(mission),
                                ),
                              ),
                          const SizedBox(height: 22),
                          _SectionHeader(
                            title: '친구들의 새 사진',
                            count: submissions.length,
                          ),
                          const SizedBox(height: 10),
                          StoryCardStack(
                            submissions: submissions,
                            height: 260,
                            onStoryTap: (index) =>
                                _openStory(submissions, index),
                          ),
                          const SizedBox(height: 26),
                          _SectionHeader(
                            title: 'Room Chat',
                            count: messages.length,
                          ),
                          const SizedBox(height: 12),
                          if (messages.isEmpty)
                            const _EmptyCard(text: '첫 메시지를 남겨보세요.')
                          else
                            for (final message in messages)
                              _MessageBubble(
                                message: message,
                                isMine:
                                    message.senderUserId ==
                                    widget.repository.previewUserId,
                              ),
                        ],
                      ),
                    ),
                    _ChatComposer(
                      controller: _messageController,
                      onSend: _sendMessage,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.onCamera});

  final Mission mission;
  final VoidCallback onCamera;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                mission.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
            IconButton.filledTonal(
              key: Key('roomCamera_${mission.id}'),
              tooltip: '이 미션 인증하기',
              onPressed: onCamera,
              icon: const Icon(Icons.camera_alt_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        Text(
          '$count',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(text, style: const TextStyle(color: Colors.black45)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? colors.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message.senderName, style: const TextStyle(fontSize: 11)),
            const SizedBox(height: 3),
            Text(message.text),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chatMessageField'),
                  controller: controller,
                  maxLength: LocalMissionRepository.maxMessageLength,
                  maxLines: 3,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: '메시지 보내기',
                    counterText: '',
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              IconButton.filled(
                key: const Key('sendChatButton'),
                tooltip: '메시지 전송',
                onPressed: onSend,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 72, child: Text(label)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (onCopy != null)
          IconButton(
            tooltip: '$label 복사',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded),
          ),
      ],
    );
  }
}
