import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/saki_widgets.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SakiService.instance.conversationPreviews();
      if (mounted) setState(() => _conversations = data);
    } catch (_) {
      // The empty state remains visible when the account has no conversations.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _newMessage() async {
    final search = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('محادثة جديدة'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'ابحث باسم المستخدم...',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  if (search.text.trim().isNotEmpty)
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: SakiService.instance.searchProfiles(search.text),
                      builder: (_, snapshot) {
                        final users =
                            snapshot.data ?? const <Map<String, dynamic>>[];
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox(
                            height: 120,
                            child: SakiLoading(),
                          );
                        }
                        if (users.isEmpty) {
                          return const SizedBox(
                            height: 120,
                            child: EmptyState(
                              icon: Icons.person_search_outlined,
                              title: 'لا توجد نتائج',
                              subtitle: 'جرّب اسمًا آخر.',
                            ),
                          );
                        }
                        return SizedBox(
                          height: 210,
                          child: ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (_, index) {
                              final user = users[index];
                              final username =
                                  user['username'] as String? ?? 'عضو';
                              return ListTile(
                                leading: SakiAvatar(
                                  url: user['avatar_url'] as String?,
                                  label: username,
                                ),
                                title: VipUsername(profile: user),
                                subtitle: Text(
                                  'SAKI ID ${user['saki_id'] ?? '—'}',
                                ),
                                onTap: () async {
                                  final conversationId = await SakiService
                                      .instance
                                      .createConversation(user['id'] as String);
                                  if (!context.mounted) return;
                                  Navigator.pop(dialogContext);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatPage(
                                        conversationId: conversationId,
                                        participant: user,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
    search.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'الرسائل',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: _newMessage,
            icon: const Icon(Icons.edit_square),
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const SakiLoading(label: 'جاري تحميل المحادثات...')
          : RefreshIndicator(
              onRefresh: _load,
              child: _conversations.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 180),
                        EmptyState(
                          icon: Icons.forum_outlined,
                          title: 'لا توجد محادثات',
                          subtitle: 'ابحث عن مستخدم وابدأ رسالة حقيقية.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final conversation = _conversations[index];
                        final members = List<Map<String, dynamic>>.from(
                          conversation['conversation_members'] ?? const [],
                        );
                        final member = members.firstWhere(
                          (row) => row['user_id'] != SakiService.instance.uid,
                          orElse: () => <String, dynamic>{},
                        );
                        final profile = Map<String, dynamic>.from(
                          member['profiles'] ?? const {},
                        );
                        final username =
                            profile['username'] as String? ?? 'محادثة';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          leading: SakiAvatar(
                            url: profile['avatar_url'] as String?,
                            label: username,
                            radius: 26,
                          ),
                          title: VipUsername(
                            profile: profile,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            (conversation['_last_message']
                                        as Map<String, dynamic>?)?['body']
                                    as String? ??
                                'SAKI ID ${profile['saki_id'] ?? '—'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if ((conversation['_unread_count'] as int? ?? 0) >
                                  0)
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: SakiColors.cyan,
                                  child: Text(
                                    '${conversation['_unread_count']}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              const Icon(Icons.chevron_left_rounded),
                            ],
                          ),
                          onTap: () {
                            SakiService.instance.markConversationRead(
                              conversation['id'] as String,
                            );
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatPage(
                                  conversationId: conversation['id'] as String,
                                  participant: profile,
                                ),
                              ),
                            ).then((_) => _load());
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.participant,
  });
  final String conversationId;
  final Map<String, dynamic> participant;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await SakiService.instance.sendMessage(widget.conversationId, body);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.participant['username'] as String? ?? 'محادثة';
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SakiAvatar(
              url: widget.participant['avatar_url'] as String?,
              label: username,
              radius: 18,
            ),
            const SizedBox(width: 10),
            VipUsername(
              profile: widget.participant,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SakiService.instance.messagesStream(
                widget.conversationId,
              ),
              builder: (_, snapshot) {
                final messages =
                    snapshot.data ?? const <Map<String, dynamic>>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    messages.isEmpty)
                  return const SakiLoading();
                if (messages.isEmpty)
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'ابدأ المحادثة',
                    subtitle: 'رسائلك تصل مباشرة عبر Supabase Realtime.',
                  );
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final mine =
                        message['sender_id'] == SakiService.instance.uid;
                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerStart
                          : AlignmentDirectional.centerEnd,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: mine
                              ? const LinearGradient(
                                  colors: [
                                    SakiColors.royalPurple,
                                    SakiColors.darkPurple,
                                  ],
                                )
                              : null,
                          color: mine ? null : SakiColors.card,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          message['body'] as String? ?? '',
                          style: const TextStyle(height: 1.35),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'اكتب رسالة...',
                      isDense: true,
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded, color: SakiColors.cyan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
