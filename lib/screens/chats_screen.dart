import 'package:flutter/material.dart';

import '../data/chat_repository.dart';
import '../models/chat_data.dart';
import 'conversation_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({
    required this.repository,
    required this.onSignOut,
    super.key,
  });

  final ChatRepository repository;
  final Future<void> Function() onSignOut;

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  late Future<List<ChatConversation>> _directChats;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _directChats = widget.repository.listDirectConversations();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openGlobalChat() async {
    try {
      final id = await widget.repository.globalConversationId();
      if (!mounted) return;
      await _openConversation(
        ChatConversation(
          id: id,
          kind: ChatConversationKind.global,
          title: 'Global Chat',
        ),
      );
    } on ChatRepositoryException catch (error) {
      _showMessage(error.message);
    }
  }

  Future<void> _openConversation(ChatConversation conversation) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(
          repository: widget.repository,
          conversation: conversation,
        ),
      ),
    );
    if (mounted) setState(_refresh);
  }

  Future<void> _startDirectChat() async {
    final profile = await showModalBottomSheet<ChatProfile>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PeoplePicker(repository: widget.repository),
    );
    if (profile == null || !mounted) return;
    try {
      final conversation = await widget.repository.openDirectConversation(
        profile,
      );
      if (mounted) await _openConversation(conversation);
    } on ChatRepositoryException catch (error) {
      _showMessage(error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: '로그아웃',
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('newDirectChatButton'),
        onPressed: _startDirectChat,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('새 메시지'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(_refresh);
            await _directChats;
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 100),
            children: [
              Card(
                child: ListTile(
                  key: const Key('globalChatTile'),
                  onTap: _openGlobalChat,
                  leading: const CircleAvatar(
                    child: Icon(Icons.public_rounded),
                  ),
                  title: const Text(
                    'Global Chat',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('모든 사용자와 이야기해요'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 24, 4, 10),
                child: Text(
                  'PRIVATE MESSAGES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              FutureBuilder<List<ChatConversation>>(
                future: _directChats,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ChatListMessage(
                      message: '개인 채팅을 불러오지 못했어요.',
                      buttonLabel: '다시 시도',
                      onPressed: () => setState(_refresh),
                    );
                  }
                  final chats = snapshot.data ?? const [];
                  if (chats.isEmpty) {
                    return _ChatListMessage(
                      message: '아직 개인 채팅이 없어요.',
                      buttonLabel: '대화 시작하기',
                      onPressed: _startDirectChat,
                    );
                  }
                  return Column(
                    children: [
                      for (final chat in chats)
                        Card(
                          child: ListTile(
                            onTap: () => _openConversation(chat),
                            leading: const CircleAvatar(
                              child: Icon(Icons.person_rounded),
                            ),
                            title: Text(
                              chat.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              chat.lastMessage ?? '새 대화를 시작해 보세요.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({required this.repository});

  final ChatRepository repository;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  final _searchController = TextEditingController();
  late Future<List<ChatProfile>> _profiles;

  @override
  void initState() {
    super.initState();
    _profiles = widget.repository.findPeople('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    setState(() {
      _profiles = widget.repository.findPeople(_searchController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('새 개인 채팅', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextField(
                key: const Key('peopleSearchField'),
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: '표시 이름 검색',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: '검색',
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<ChatProfile>>(
                  future: _profiles,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('사용자를 불러오지 못했어요.'));
                    }
                    final profiles = snapshot.data ?? const [];
                    if (profiles.isEmpty) {
                      return const Center(child: Text('일치하는 사용자가 없어요.'));
                    }
                    return ListView.builder(
                      itemCount: profiles.length,
                      itemBuilder: (context, index) {
                        final profile = profiles[index];
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(profile),
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_rounded),
                          ),
                          title: Text(profile.displayName),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatListMessage extends StatelessWidget {
  const _ChatListMessage({
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        children: [
          Text(message, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          TextButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}
