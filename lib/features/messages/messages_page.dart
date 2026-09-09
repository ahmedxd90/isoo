import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF8B95A7);
const _blue = Color(0xFF5267FF);
const _violet = Color(0xFF7858F5);
const _surface = Color(0xFFF7F8FC);

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  int _section = 0;
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _followers = [];
  List<Map<String, dynamic>> _social = [];
  bool _loading = true;
  StreamSubscription<List<Map<String, dynamic>>>? _events;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _events = SakiService.instance.notificationsStream().listen((_) {
      _refreshTimer?.cancel();
      _refreshTimer = Timer(const Duration(milliseconds: 220), _load);
    });
    _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await Future.wait([
        SakiService.instance.conversationPreviews(),
        SakiService.instance.followers(),
        SakiService.instance.socialNotifications(),
      ]);
      if (!mounted) return;
      setState(() {
        _conversations = List<Map<String, dynamic>>.from(result[0] as List);
        _followers = List<Map<String, dynamic>>.from(result[1] as List);
        _social = List<Map<String, dynamic>>.from(result[2] as List);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            const _InboxHeader(),
            _SectionRail(
              selected: _section,
              followersCount: _followers.where((e) {
                final p = e['profiles'];
                return p is Map && (e['is_read'] != true);
              }).length,
              socialCount: _social.where((e) => e['is_read'] != true).length,
              onChanged: (value) => setState(() => _section = value),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: SakiLoading());
    if (_section == 1) {
      return _FollowersView(rows: _followers, onRefresh: _load);
    }
    if (_section == 2) return _SocialView(rows: _social, onRefresh: _load);
    return _ConversationsView(rows: _conversations, onRefresh: _load);
  }
}

class _InboxHeader extends StatelessWidget {
  const _InboxHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 15),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEFF5))),
      ),
      child: const Align(
        alignment: Alignment.centerRight,
        child: Text(
          'الرسائل',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({
    required this.selected,
    required this.onChanged,
    this.followersCount = 0,
    this.socialCount = 0,
  });
  final int selected;
  final int followersCount;
  final int socialCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['النظام', 'المتابعة', 'الاجتماعية'];
    const assets = [
      'assets/messages/icons/system.png',
      'assets/messages/icons/following.png',
      'assets/messages/icons/social.png',
    ];
    return Container(
      height: 84,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(3, (index) {
          final active = selected == index;
          final count = index == 1
              ? followersCount
              : index == 2
              ? socialCount
              : 0;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFF0F2FF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Opacity(
                            opacity: active ? 1 : .48,
                            child: Image.asset(
                              assets[index],
                              width: 34,
                              height: 34,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            labels[index],
                            style: TextStyle(
                              color: active ? _ink : _muted,
                              fontSize: 11,
                              fontWeight: active
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (count > 0)
                      Positioned(
                        top: 3,
                        right: 17,
                        child: _CountBadge(count: count),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ConversationsView extends StatelessWidget {
  const _ConversationsView({required this.rows, required this.onRefresh});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const _ViewTitle(
          title: 'المحادثات الأخيرة',
          subtitle: 'رسائلك الخاصة في مكان واحد',
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const _PremiumEmpty(
            icon: Icons.forum_outlined,
            title: 'لا توجد محادثات',
            subtitle: 'ابدأ محادثة خاصة من بروفايل أي مستخدم.',
          )
        else
          ...rows.map((row) => _ConversationRow(row: row)),
      ],
    ),
  );
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final members = List<Map<String, dynamic>>.from(
      row['conversation_members'] ?? const [],
    );
    final member = members.firstWhere(
      (e) => e['user_id'] != SakiService.instance.uid,
      orElse: () => <String, dynamic>{},
    );
    final profile = Map<String, dynamic>.from(member['profiles'] ?? const {});
    final name = profile['username'] as String? ?? 'محادثة';
    final last = Map<String, dynamic>.from(row['_last_message'] ?? const {});
    final unread = row['_unread_count'] as int? ?? 0;
    return _GlassRow(
      onTap: () async {
        await SakiService.instance.markConversationRead(row['id'] as String);
        if (!context.mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              conversationId: row['id'] as String,
              participant: profile,
            ),
          ),
        );
      },
      child: Row(
        children: [
          SakiAvatar(
            url: profile['avatar_url'] as String?,
            label: name,
            radius: 27,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VipUsername(
                  profile: profile,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  last['body'] as String? ?? 'ابدأ محادثة خاصة',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0) _CountBadge(count: unread),
        ],
      ),
    );
  }
}

class _FollowersView extends StatelessWidget {
  const _FollowersView({required this.rows, required this.onRefresh});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const _ViewTitle(
          title: 'المتابعين',
          subtitle: 'الأشخاص الذين بدأوا بمتابعتك',
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const _PremiumEmpty(
            icon: Icons.people_outline_rounded,
            title: 'لا يوجد متابعون جدد',
            subtitle: 'سيظهر هنا كل من يتابعك.',
          )
        else
          ...rows.map((row) => _FollowerRow(row: row)),
      ],
    ),
  );
}

class _FollowerRow extends StatelessWidget {
  const _FollowerRow({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(row['profiles'] ?? const {});
    final id = profile['id'] as String? ?? row['follower_id'] as String? ?? '';
    final name = profile['username'] as String? ?? 'مستخدم';
    return _GlassRow(
      onTap: () {},
      child: Row(
        children: [
          SakiAvatar(
            url: profile['avatar_url'] as String?,
            label: name,
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: VipUsername(
              profile: profile,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
          ),
          _FollowBackButton(userId: id),
        ],
      ),
    );
  }
}

class _FollowBackButton extends StatefulWidget {
  const _FollowBackButton({required this.userId});
  final String userId;
  @override
  State<_FollowBackButton> createState() => _FollowBackButtonState();
}

class _FollowBackButtonState extends State<_FollowBackButton> {
  bool _following = false;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    SakiService.instance.isFollowing(widget.userId).then((v) {
      if (mounted) {
        setState(() {
          _following = v;
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _loading
        ? null
        : () async {
            setState(() => _loading = true);
            await SakiService.instance.toggleFollow(widget.userId, _following);
            if (mounted) {
              setState(() {
                _following = !_following;
                _loading = false;
              });
            }
          },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: _following ? const Color(0xFFF1F3F8) : _blue,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        _following ? 'متابَع' : 'رد متابعة',
        style: TextStyle(
          color: _following ? _muted : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

class _SocialView extends StatelessWidget {
  const _SocialView({required this.rows, required this.onRefresh});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        const _ViewTitle(
          title: 'الاجتماعية',
          subtitle: 'كل التفاعلات التي وصلت إليك',
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const _PremiumEmpty(
            icon: Icons.auto_awesome_outlined,
            title: 'لا توجد تفاعلات بعد',
            subtitle: 'سيظهر هنا الإعجاب والتعليق والشعلة والمتابعة.',
          )
        else
          ...rows.map((row) => _SocialRow(row: row)),
      ],
    ),
  );
}

class _SocialRow extends StatelessWidget {
  const _SocialRow({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) {
    final p = Map<String, dynamic>.from(row['profiles'] ?? const {});
    final name = p['username'] as String? ?? 'مستخدم';
    final type = row['type'] as String? ?? '';
    final text = type == 'follow'
        ? 'بدأ بمتابعتك'
        : type == 'like'
        ? 'أعجب بمنشورك أو أرسل شعلة'
        : 'علّق على منشورك أو ريلز';
    final icon = type == 'follow'
        ? Icons.person_add_alt_1_rounded
        : type == 'like'
        ? Icons.local_fire_department_rounded
        : Icons.chat_bubble_rounded;
    return _GlassRow(
      onTap: () {},
      child: Row(
        children: [
          SakiAvatar(url: p['avatar_url'] as String?, label: name, radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              textDirection: TextDirection.rtl,
              text: TextSpan(
                style: const TextStyle(color: _muted, fontSize: 12),
                children: [
                  TextSpan(
                    text: name,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(text: '  $text'),
                ],
              ),
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _blue, size: 18),
          ),
        ],
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
  final _picker = ImagePicker();
  final List<Map<String, dynamic>> _pending = [];
  bool _sending = false;
  bool _blocked = false;
  bool _blockedBy = false;
  String get _peerId => widget.participant['id'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    SakiService.instance.markConversationRead(widget.conversationId);
    _loadBlockState();
  }

  Future<void> _loadBlockState() async {
    final blocked = await SakiService.instance.isUserBlocked(_peerId);
    final blockedBy = await SakiService.instance.isBlockedByUser(_peerId);
    if (mounted) {
      setState(() {
        _blocked = blocked;
        _blockedBy = blockedBy;
      });
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty || _sending || _blocked || _blockedBy) return;
    final local = <String, dynamic>{
      'id': 'local-${DateTime.now().microsecondsSinceEpoch}',
      'sender_id': SakiService.instance.uid,
      'body': body,
      'message_type': 'text',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() {
      _pending.add(local);
      _sending = true;
    });
    _controller.clear();
    try {
      await SakiService.instance.sendMessage(widget.conversationId, body);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _pending.removeWhere((x) => x['id'] == local['id']);
        });
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_blocked || _blockedBy) return;
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 86,
    );
    if (image == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImagePreviewSheet(
        image: image,
        onSend: () async {
          Navigator.pop(context);
          try {
            final url = await SakiService.instance.uploadChatImage(image);
            await SakiService.instance.sendMessage(
              widget.conversationId,
              '',
              messageType: 'image',
              mediaUrl: url,
              mediaName: image.name,
            );
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$error')));
            }
          }
        },
      ),
    );
  }

  Future<void> _menu() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatMenuSheet(
        blocked: _blocked,
        onBlock: () async {
          Navigator.pop(context);
          if (_blocked) {
            await SakiService.instance.unblockUser(_peerId);
          } else {
            await SakiService.instance.blockUser(_peerId);
          }
          await _loadBlockState();
        },
        onReport: () {
          Navigator.pop(context);
          _report();
        },
      ),
    );
  }

  Future<void> _report() async {
    String category = 'abuse';
    final details = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إبلاغ عن مستخدم',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 15),
              for (final item in {
                'sexual': 'محتوى جنسي',
                'advertising': 'إعلان مزعج',
                'abuse': 'إساءة أو تنمر',
                'other': 'أخرى',
              }.entries)
                GestureDetector(
                  onTap: () => setSheet(() => category = item.key),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: category == item.key
                          ? const Color(0xFFF0F2FF)
                          : _surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      item.value,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              TextField(
                controller: details,
                maxLines: 2,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'تفاصيل إضافية (اختياري)',
                  border: InputBorder.none,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  await SakiService.instance.reportUser(
                    _peerId,
                    category,
                    details: details.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إرسال البلاغ بنجاح')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _ink,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'إرسال البلاغ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    details.dispose();
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
      backgroundColor: _surface,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              name: name,
              participant: widget.participant,
              onMenu: _menu,
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: SakiService.instance.messagesStream(
                  widget.conversationId,
                ),
                builder: (_, snapshot) {
                  final remote = snapshot.data ?? <Map<String, dynamic>>[];
                  final rows = [
                    ...remote,
                    ..._pending.where(
                      (p) => !remote.any(
                        (r) =>
                            r['body'] == p['body'] &&
                            r['sender_id'] == p['sender_id'],
                      ),
                    ),
                  ];
                  if (rows.isEmpty &&
                      snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: SakiLoading());
                  }
                  if (rows.isEmpty) {
                    return const _PremiumEmpty(
                      icon: Icons.forum_outlined,
                      title: 'ابدأ المحادثة',
                      subtitle: 'أرسل أول رسالة خاصة الآن.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => _Bubble(row: rows[i]),
                  );
                },
              ),
            ),
            _Composer(
              disabled: _blocked || _blockedBy,
              blockedBy: _blockedBy,
              controller: _controller,
              sending: _sending,
              onImage: _pickAndSendImage,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.name,
    required this.participant,
    required this.onMenu,
  });
  final String name;
  final Map<String, dynamic> participant;
  final VoidCallback onMenu;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFEDEFF5))),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_forward_rounded, color: _ink),
        ),
        const SizedBox(width: 12),
        SakiAvatar(
          url: participant['avatar_url'] as String?,
          label: name,
          radius: 21,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const Text(
                'محادثة خاصة',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onMenu,
          child: const Icon(Icons.more_vert_rounded, color: _ink),
        ),
      ],
    ),
  );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final mine = row['sender_id'] == SakiService.instance.uid;
    final image = row['media_url'] as String?;
    final content = image != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(
              image,
              width: 230,
              height: 230,
              fit: BoxFit.cover,
            ),
          )
        : Text(
            row['body'] as String? ?? '',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              color: mine ? Colors.white : _ink,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          );
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: GestureDetector(
        onTap: image == null ? null : () => _openImage(context, image),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(maxWidth: 300),
          padding: image == null
              ? const EdgeInsets.symmetric(horizontal: 15, vertical: 11)
              : const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: mine ? _blue : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(19),
              topRight: const Radius.circular(19),
              bottomLeft: Radius.circular(mine ? 5 : 19),
              bottomRight: Radius.circular(mine ? 19 : 5),
            ),
          ),
          child: content,
        ),
      ),
    );
  }

  void _openImage(BuildContext context, String url) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'image',
      pageBuilder: (_, _, _) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Center(child: Image.network(url, fit: BoxFit.contain)),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final bytes = await NetworkAssetBundle(Uri.parse(url))
                            .load(url);
                        await Gal.putImageBytes(bytes.buffer.asUint8List());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Text(
                          'حفظ الصورة',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'saki chat',
                      style: TextStyle(
                        color: Colors.white54,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.disabled,
    required this.blockedBy,
    required this.controller,
    required this.sending,
    required this.onImage,
    required this.onSend,
  });
  final bool disabled;
  final bool blockedBy;
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    if (blockedBy) {
      return Container(
        padding: const EdgeInsets.all(18),
        color: Colors.white,
        child: const Text(
          'تم حظرك من إرسال الرسائل إلى هذا المستخدم',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEFF5))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: disabled ? null : onImage,
            child: Icon(
              Icons.image_outlined,
              color: disabled ? _muted : _violet,
              size: 25,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(21),
              ),
              child: TextField(
                controller: controller,
                enabled: !disabled,
                minLines: 1,
                maxLines: 4,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'اكتب رسالة...',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: disabled || sending ? null : onSend,
            child: Container(
              width: 43,
              height: 43,
              decoration: const BoxDecoration(
                color: _blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMenuSheet extends StatelessWidget {
  const _ChatMenuSheet({
    required this.blocked,
    required this.onBlock,
    required this.onReport,
  });
  final bool blocked;
  final VoidCallback onBlock;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(27)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onBlock,
          child: _MenuLine(
            icon: blocked ? Icons.lock_open_rounded : Icons.block_rounded,
            text: blocked ? 'إلغاء حظر المستخدم' : 'حظر المستخدم',
            danger: true,
          ),
        ),
        GestureDetector(
          onTap: onReport,
          child: const _MenuLine(
            icon: Icons.flag_outlined,
            text: 'إبلاغ عن المستخدم',
            danger: false,
          ),
        ),
        const SizedBox(height: 8),
      ],
    ),
  );
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({
    required this.icon,
    required this.text,
    required this.danger,
  });
  final IconData icon;
  final String text;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    margin: const EdgeInsets.only(bottom: 9),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: danger ? Colors.redAccent : _ink),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: danger ? Colors.redAccent : _ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _ImagePreviewSheet extends StatelessWidget {
  const _ImagePreviewSheet({required this.image, required this.onSend});
  final XFile image;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 4,
            width: 45,
            decoration: BoxDecoration(
              color: _muted,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              File(image.path),
              height: 290,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'إرسال الصورة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _NewChatSheet extends StatefulWidget {
  const _NewChatSheet({required this.controller});
  final TextEditingController controller;
  @override
  State<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends State<_NewChatSheet> {
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      18,
      18,
      18,
      MediaQuery.of(context).viewInsets.bottom + 18,
    ),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'محادثة جديدة',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: widget.controller,
          autofocus: true,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: 'ابحث باسم المستخدم أو ID',
            filled: true,
            fillColor: _surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (widget.controller.text.trim().isNotEmpty)
          SizedBox(
            height: 250,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: SakiService.instance.searchProfiles(
                widget.controller.text,
              ),
              builder: (_, snapshot) {
                final users = snapshot.data ?? [];
                return ListView(
                  children: users.map((u) => _SearchUser(user: u)).toList(),
                );
              },
            ),
          ),
      ],
    ),
  );
}

class _SearchUser extends StatelessWidget {
  const _SearchUser({required this.user});
  final Map<String, dynamic> user;
  @override
  Widget build(BuildContext context) {
    final name = user['username'] as String? ?? 'مستخدم';
    return GestureDetector(
      onTap: () async {
        final id = await SakiService.instance.createConversation(
          user['id'] as String,
        );
        if (!context.mounted) return;
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(conversationId: id, participant: user),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            SakiAvatar(
              url: user['avatar_url'] as String?,
              label: name,
              radius: 23,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: VipUsername(
                profile: user,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ),
            const Icon(Icons.arrow_back_ios_rounded, size: 14, color: _muted),
          ],
        ),
      ),
    );
  }
}

class _ViewTitle extends StatelessWidget {
  const _ViewTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        title,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          color: _ink,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        subtitle,
        textDirection: TextDirection.rtl,
        style: const TextStyle(
          color: _muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _GlassRow extends StatelessWidget {
  const _GlassRow({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFEFF1F6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    ),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
    child: Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: const BoxDecoration(
        color: Color(0xFFFF4E70),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ),
  );
}

class _PremiumEmpty extends StatelessWidget {
  const _PremiumEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 85),
    child: Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _blue, size: 32),
        ),
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
      ],
    ),
  );
}
