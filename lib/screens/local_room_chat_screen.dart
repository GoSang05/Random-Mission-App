import 'package:flutter/material.dart';

import '../data/local_mission_repository.dart';
import '../models/mission_data.dart';
import '../utils/app_snackbar.dart';

class LocalRoomChatScreen extends StatefulWidget {
  const LocalRoomChatScreen({
    required this.repository,
    required this.roomId,
    required this.title,
    super.key,
  });

  final LocalMissionRepository repository;
  final String roomId;
  final String title;

  @override
  State<LocalRoomChatScreen> createState() => _LocalRoomChatScreenState();
}

class _LocalRoomChatScreenState extends State<LocalRoomChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    try {
      widget.repository.sendMessage(widget.roomId, text);
      _controller.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } on ArgumentError catch (error) {
      showAppSnackBar(context, error.message.toString());
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.repository,
      builder: (context, _) {
        final messages = widget.repository.messagesForRoom(widget.roomId);
        return Scaffold(
          appBar: AppBar(title: Text(widget.title)),
          body: Column(
            children: [
              Expanded(
                child: messages.isEmpty
                    ? const Center(child: Text('첫 메시지를 남겨보세요.'))
                    : ListView.builder(
                        key: const Key('localChatMessageList'),
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          return _MessageBubble(
                            message: message,
                            isMine:
                                message.senderUserId ==
                                widget.repository.previewUserId,
                          );
                        },
                      ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 10, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('chatMessageField'),
                          controller: _controller,
                          maxLength: LocalMissionRepository.maxMessageLength,
                          maxLines: 3,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          decoration: const InputDecoration(
                            hintText: '메시지 보내기',
                            counterText: '',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      IconButton.filled(
                        key: const Key('sendChatButton'),
                        onPressed: _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
