import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../notifications/notifications_page.dart';

const _messagesBg = Color(0xFFFAFCFF);
const _blue = Color(0xFF2575FC);
const _pink = Color(0xFFFF758C);
const _orange = Color(0xFFFFB347);

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _conversations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final rows = await SakiService.instance.conversationPreviews();
      if (mounted) setState(() => _conversations = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _activity(String title, String? filter) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => NotificationsPage(title: title, filter: filter),
    ),
  );

  Future<void> _newMessage() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('محادثة جديدة', textAlign: TextAlign.right),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textDirection: TextDirection.rtl,
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم المستخدم أو ID...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                if (controller.text.trim().isNotEmpty)
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: SakiService.instance.searchProfiles(
                      controller.text,
                    ),
                    builder: (_, snapshot) {
                      final users = snapshot.data ?? <Map<String, dynamic>>[];
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 100,
                          child: SakiLoading(),
                        );
                      }
                      return SizedBox(
                        height: 220,
                        child: ListView.builder(
                          itemCount: users.length,
                          itemBuilder: (_, index) => _userTile(
                            users[index],
                            dialogContext: dialogContext,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }

  Widget _userTile(Map<String, dynamic> user, {BuildContext? dialogContext}) {
    final name = user['username'] as String? ?? 'عضو';
    return ListTile(
      leading: SakiAvatar(url: user['avatar_url'] as String?, label: name),
      title: VipUsername(profile: user),
      subtitle: Text('SAKI ID ${user['saki_id'] ?? '—'}'),
      onTap: () async {
        final id = await SakiService.instance.createConversation(
          user['id'] as String,
        );
        if (!mounted) return;
        if (dialogContext != null) Navigator.pop(dialogContext);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(conversationId: id, participant: user),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _messagesBg,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelColor: const Color(0xFF1E293B),
        unselectedLabelColor: const Color(0xFF94A3B8),
        labelStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: _blue,
        indicatorWeight: 4,
        tabs: const [
          Tab(text: 'الرسائل'),
          Tab(text: 'الأصدقاء'),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _newMessage,
          icon: const Icon(Icons.edit_rounded, color: _blue),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: TabBarView(
      controller: _tabs,
      children: [_messagesTab(), _friendsTab()],
    ),
  );

  Widget _messagesTab() {
    if (_loading) return const SakiLoading(label: 'جاري تحميل الرسائل...');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ActionCard(
                icon: Icons.person_add_alt_1_rounded,
                label: 'طلبات الصداقة',
                color: _blue,
                onTap: () => _activity('طلبات الصداقة', 'follow'),
              ),
              _ActionCard(
                icon: Icons.notifications_rounded,
                label: 'النظام',
                color: _pink,
                onTap: () => _activity('إشعارات النظام', 'system'),
              ),
              _ActionCard(
                icon: Icons.explore_rounded,
                label: 'الاجتماعية',
                color: _orange,
                onTap: () => _activity('الأنشطة الاجتماعية', 'social'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_conversations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'لا توجد دردشات حالية',
                subtitle: 'يمكنك مراسلة أصدقائك من تبويب الأصدقاء.',
              ),
            )
          else ...[
            const Text(
              'المحادثات الأخيرة',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 8),
            ..._conversations.map(_conversationTile),
          ],
        ],
      ),
    );
  }

  Widget _conversationTile(Map<String, dynamic> conversation) {
    final members = List<Map<String, dynamic>>.from(
      conversation['conversation_members'] ?? const [],
    );
    final member = members.firstWhere(
      (row) => row['user_id'] != SakiService.instance.uid,
      orElse: () => <String, dynamic>{},
    );
    final profile = Map<String, dynamic>.from(member['profiles'] ?? const {});
    final name = profile['username'] as String? ?? 'محادثة';
    final last = Map<String, dynamic>.from(
      conversation['_last_message'] ?? const {},
    );
    final unread = conversation['_unread_count'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        leading: SakiAvatar(
          url: profile['avatar_url'] as String?,
          label: name,
          radius: 27,
        ),
        title: VipUsername(
          profile: profile,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          last['body'] as String? ?? 'ابدأ محادثة خاصة',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: unread > 0
            ? CircleAvatar(
                radius: 11,
                backgroundColor: _blue,
                child: Text(
                  '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.chevron_left_rounded, color: Color(0xFFCBD5E1)),
        onTap: () async {
          await SakiService.instance.markConversationRead(
            conversation['id'] as String,
          );
          if (!mounted) return;
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                conversationId: conversation['id'] as String,
                participant: profile,
              ),
            ),
          );
          _load();
        },
      ),
    );
  }

  Widget _friendsTab() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
    children: [
      TextField(
        controller: _search,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'البحث عن صديق بالاسم أو ID...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 16),
      if (_search.text.trim().isEmpty)
        const EmptyState(
          icon: Icons.people_outline_rounded,
          title: 'ابحث عن صديق',
          subtitle: 'اكتب اسم المستخدم أو SAKI ID لبدء محادثة.',
        )
      else
        FutureBuilder<List<Map<String, dynamic>>>(
          future: SakiService.instance.searchProfiles(_search.text),
          builder: (_, snapshot) {
            final users = snapshot.data ?? <Map<String, dynamic>>[];
            if (snapshot.connectionState == ConnectionState.waiting)
              return const SakiLoading();
            if (users.isEmpty)
              return const EmptyState(
                icon: Icons.person_search_outlined,
                title: 'لا توجد نتائج',
                subtitle: 'جرّب اسمًا أو ID آخر.',
              );
            return Column(children: users.map(_friendTile).toList());
          },
        ),
    ],
  );

  Widget _friendTile(Map<String, dynamic> user) {
    final name = user['username'] as String? ?? 'مستخدم';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        leading: SakiAvatar(
          url: user['avatar_url'] as String?,
          label: name,
          radius: 25,
        ),
        title: VipUsername(profile: user),
        subtitle: Text('SAKI ID ${user['saki_id'] ?? '—'}'),
        trailing: TextButton(
          onPressed: () async {
            final id = await SakiService.instance.createConversation(
              user['id'] as String,
            );
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(conversationId: id, participant: user),
              ),
            );
          },
          child: const Text(
            'مراسلة',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 96,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .25),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    ),
  );
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
    final name = widget.participant['username'] as String? ?? 'محادثة';
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        titleSpacing: 0,
        title: Row(
          children: [
            SakiAvatar(
              url: widget.participant['avatar_url'] as String?,
              label: name,
              radius: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VipUsername(
                profile: widget.participant,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: const [
          Icon(Icons.phone_outlined),
          SizedBox(width: 16),
          Icon(Icons.more_vert_rounded),
          SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: SakiService.instance.messagesStream(
                widget.conversationId,
              ),
              builder: (_, snapshot) {
                final rows = snapshot.data ?? <Map<String, dynamic>>[];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    rows.isEmpty)
                  return const SakiLoading();
                if (rows.isEmpty)
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline_rounded,
                    title: 'ابدأ المحادثة',
                    subtitle: 'أرسل أول رسالة خاصة الآن.',
                  );
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                  itemCount: rows.length,
                  itemBuilder: (_, index) {
                    final row = rows[index];
                    final mine = row['sender_id'] == SakiService.instance.uid;
                    return Align(
                      alignment: mine
                          ? AlignmentDirectional.centerStart
                          : AlignmentDirectional.centerEnd,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 310),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: mine ? _blue : Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(mine ? 4 : 20),
                            bottomRight: Radius.circular(mine ? 20 : 4),
                          ),
                          boxShadow: const [
                            BoxShadow(color: Color(0x08000000), blurRadius: 5),
                          ],
                        ),
                        child: Text(
                          row['body'] as String? ?? '',
                          style: TextStyle(
                            color: mine
                                ? Colors.white
                                : const Color(0xFF334155),
                            height: 1.35,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.image_outlined,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textDirection: TextDirection.rtl,
                      decoration: InputDecoration(
                        hintText: 'اكتب رسالتك...',
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: _blue),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
