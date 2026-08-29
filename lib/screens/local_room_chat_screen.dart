import 'package:flutter/material.dart';

import '../data/local_mission_repository.dart';
import '../models/mission_data.dart';
import '../utils/app_snackbar.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';

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
          backgroundColor: playfulCream,
          body: SafeArea(
            child: PlayfulBackground(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                              child: PlayfulHeader(title: widget.title),
                            ),
                            Expanded(
                              child: messages.isEmpty
                                  ? const Center(
                                      child: Text(
                                        '첫 메시지를 남겨보세요.',
                                        style: TextStyle(
                                          color: Colors.black45,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      key: const Key('localChatMessageList'),
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        22,
                                        18,
                                        12,
                                      ),
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
                            _LocalChatComposer(
                              controller: _controller,
                              onSend: _send,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LocalChatComposer extends StatelessWidget {
  const _LocalChatComposer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(18, 8, 18, 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: playfulPurple, width: 3),
          boxShadow: const [BoxShadow(color: playfulInk, offset: Offset(0, 5))],
        ),
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
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: playfulPurple,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(color: playfulInk, width: 2.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('sendChatButton'),
                  onTap: onSend,
                  borderRadius: BorderRadius.circular(16),
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 31,
                  ),
                ),
              ),
            ),
          ],
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
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMine
              ? const LinearGradient(
                  colors: [Color(0xFFD8C4FF), Color(0xFFF0E8FF)],
                )
              : null,
          color: isMine ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isMine ? 22 : 5),
            bottomRight: Radius.circular(isMine ? 5 : 22),
          ),
          border: Border.all(color: playfulInk, width: 2.5),
          boxShadow: const [BoxShadow(color: playfulInk, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.senderName,
              style: const TextStyle(
                color: playfulPurple,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              message.text,
              style: const TextStyle(
                color: playfulInk,
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
