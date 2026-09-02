import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../models/chat_data.dart';
import '../utils/app_snackbar.dart';
import '../widgets/playful_illustrations.dart';
import '../widgets/playful_ui.dart';

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    required this.repository,
    required this.conversation,
    super.key,
  });

  final ChatRepository repository;
  final ChatConversation conversation;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  var _isSending = false;
  var _visibleMessageCount = -1;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    showAppSnackBar(context, message);
  }

  Future<void> _sendMessage() async {
    if (_isSending || _messageController.text.trim().isEmpty) return;
    setState(() => _isSending = true);
    try {
      await widget.repository.sendMessage(
        widget.conversation.id,
        _messageController.text,
      );
      _messageController.clear();
      _scrollToEnd();
    } on ChatRepositoryException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showActions(RemoteChatMessage message) async {
    final blocked = await showChatMessageActions(
      context,
      repository: widget.repository,
      message: message,
    );
    if (blocked && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: playfulCream,
      body: SafeArea(
        child: PlayfulBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
                    child: PlayfulHeader(title: widget.conversation.title),
                  ),
                  Expanded(
                    child: StreamBuilder<List<RemoteChatMessage>>(
                      stream: widget.repository.watchMessages(
                        widget.conversation.id,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const _ChatStatus(
                            icon: Icons.cloud_off_rounded,
                            message: '메시지를 불러오지 못했어요.',
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final messages = [...snapshot.data!]
                          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                        if (messages.isEmpty) {
                          return const _ChatStatus(
                            icon: Icons.forum_outlined,
                            message: '첫 메시지를 보내보세요.',
                          );
                        }
                        if (_visibleMessageCount != messages.length) {
                          _visibleMessageCount = messages.length;
                          _scrollToEnd();
                        }
                        return ListView.builder(
                          key: const Key('conversationMessages'),
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            if (message.isSystem) {
                              return _SystemMessage(message: message.text);
                            }
                            return ChatMessageBubble(
                              message: message,
                              isMine:
                                  message.senderUserId ==
                                  widget.repository.currentUserId,
                              onLongPress:
                                  message.senderUserId ==
                                      widget.repository.currentUserId
                                  ? null
                                  : () => _showActions(message),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  ChatComposer(
                    controller: _messageController,
                    isSending: _isSending,
                    onSend: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('chatSystemMessage'),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE9DEFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: playfulInk, width: 2),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: playfulInk,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.isMine,
    this.onLongPress,
    super.key,
  });

  final RemoteChatMessage message;
  final bool isMine;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.only(bottom: 10),
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
            boxShadow: const [
              BoxShadow(color: playfulInk, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                Text(
                  message.senderName,
                  style: const TextStyle(
                    color: playfulPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
              ],
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
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
    super.key,
  });

  final TextEditingController controller;
  final bool isSending;
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
                key: const Key('remoteChatMessageField'),
                controller: controller,
                enabled: !isSending,
                maxLength: ChatRepository.maxMessageLength,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: '메시지 보내기',
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
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
                  key: const Key('remoteSendChatButton'),
                  onTap: isSending ? null : onSend,
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: isSending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 31,
                          ),
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

Future<bool> showChatMessageActions(
  BuildContext context, {
  required ChatRepository repository,
  required RemoteChatMessage message,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('메시지 신고'),
            onTap: () => Navigator.of(sheetContext).pop('report'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: Text('${message.senderName}님 차단'),
            onTap: () => Navigator.of(sheetContext).pop('block'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted || action == null) return false;

  try {
    if (action == 'report') {
      await repository.reportMessage(message.id);
      if (context.mounted) {
        showAppSnackBar(context, '메시지를 신고했어요.');
      }
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${message.senderName}님을 차단할까요?'),
        content: const Text('서로의 메시지가 보이지 않고 개인 메시지를 주고받을 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('차단'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    await repository.blockUser(message.senderUserId);
    if (context.mounted) {
      showAppSnackBar(context, '사용자를 차단했어요.');
    }
    return true;
  } on ChatRepositoryException catch (error) {
    if (context.mounted) {
      showAppSnackBar(context, error.message);
    }
    return false;
  }
}

class _ChatStatus extends StatelessWidget {
  const _ChatStatus({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Colors.black38),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
