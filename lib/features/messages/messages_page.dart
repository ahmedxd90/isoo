import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../profile/user_profile_page.dart';

import '../../shared/widgets/custom_toast.dart';

const _ink = Color(0xFF111827);
const _muted = Color(0xFF8B95A7);
const _blue = Color(0xFF5267FF);
const _violet = Color(0xFF7858F5);
const _surface = Color(0xFFF7F8FC);
const _chatOrange = Color(0xFFFF7A45);
const _chatCyan = Color(0xFF16B8C8);
const _chatPale = Color(0xFFFFF4EE);

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _conversations = [];
  StreamSubscription<List<Map<String, dynamic>>>? _inboxEvents;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _inboxEvents = SakiService.instance.inboxMessagesStream().listen((_) {
      _loadConversations();
    });
  }

  @override
  void dispose() {
    _inboxEvents?.cancel();
    super.dispose();
  }

  Future<void> _loadConversations() async {
    try {
      final rows = await SakiService.instance.conversationPreviews();
      if (mounted) setState(() => _conversations = rows);
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
            _SectionRail(onChanged: _openSection),
            Expanded(
              child: _loading
                  ? const Center(child: SakiLoading())
                  : _conversations.isEmpty
                  ? const _MessagesLanding()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      itemCount: _conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (_, index) =>
                          _ConversationTile(row: _conversations[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSection(int value) {
    final page = switch (value) {
      0 => const SystemMessagesPage(),
      1 => const FollowingMessagesPage(),
      _ => const SocialMessagesPage(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _MessagesLanding extends StatelessWidget {
  const _MessagesLanding();

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'اختر قسمًا لعرض رسائلك',
      style: TextStyle(
        color: _muted.withValues(alpha: .75),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final members = List<Map<String, dynamic>>.from(
      row['conversation_members'] ?? const [],
    );
    Map<String, dynamic> user = {};
    for (final member in members) {
      final profile = member['profiles'];
      if (profile is Map && profile['id'] != SakiService.instance.uid) {
        user = Map<String, dynamic>.from(profile);
        break;
      }
    }
    final name = user['username']?.toString() ?? 'مستخدم';
    final id = row['id']?.toString() ?? '';
    return GestureDetector(
      onTap: id.isEmpty || user['id'] == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(conversationId: id, participant: user),
              ),
            ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _chatCyan.withValues(alpha: .16)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D16B8C8),
              blurRadius: 18,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          children: [
            SakiAvatar(
              url: user['avatar_url'] as String?,
              label: name,
              radius: 27,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: _vipNameColor(user),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'محادثة خاصة • اضغط للفتح',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded, color: _chatOrange),
          ],
        ),
      ),
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.onChanged});
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
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        assets[index],
                        width: 38,
                        height: 38,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[index],
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
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
  StreamSubscription<List<Map<String, dynamic>>>? _messageEvents;
  String? _lastNotifiedMessage;
  bool _messageStreamReady = false;
  String get _peerId => widget.participant['id'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    SakiService.instance.markConversationRead(widget.conversationId);
    _loadBlockState();
    _messageEvents = SakiService.instance
        .messagesStream(widget.conversationId)
        .listen(_notifyForIncomingMessage);
  }

  Future<void> _notifyForIncomingMessage(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;
    final row = rows.last;
    final id = row['id']?.toString();
    if (!_messageStreamReady) {
      _messageStreamReady = true;
      _lastNotifiedMessage = id;
      return;
    }
    if (id == null ||
        id == _lastNotifiedMessage ||
        row['sender_id'] == SakiService.instance.uid) {
      return;
    }
    _lastNotifiedMessage = id;
    await SakiNotificationService.instance.showMessage(
      sender: widget.participant['username']?.toString() ?? 'مستخدم',
      body: row['body']?.toString() ?? '',
    );
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
        CustomToast.show(context, '$error');
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
              CustomToast.show(context, '$error');
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
                    CustomToast.show(context, 'تم إرسال البلاغ بنجاح');
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
    _messageEvents?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.participant['username'] as String? ?? 'محادثة';
    return Scaffold(
      backgroundColor: _chatPale,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              name: name,
              participant: widget.participant,
              onMenu: _menu,
              onAvatarTap: () {
                if (_peerId.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserProfilePage(userId: _peerId),
                    ),
                  );
                }
              },
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: SakiService.instance.messagesStream(
                  widget.conversationId,
                ),
                builder: (_, snapshot) {
                  final remote = snapshot.data ?? <Map<String, dynamic>>[];
                  final rows =
                      <Map<String, dynamic>>[
                        ...remote,
                        ..._pending.where(
                          (p) => !remote.any(
                            (r) =>
                                r['body'] == p['body'] &&
                                r['sender_id'] == p['sender_id'],
                          ),
                        ),
                      ]..sort((a, b) {
                        final first =
                            DateTime.tryParse(
                              a['created_at']?.toString() ?? '',
                            ) ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final second =
                            DateTime.tryParse(
                              b['created_at']?.toString() ?? '',
                            ) ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return first.compareTo(second);
                      });
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
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: SakiService.instance.messageReactionsStream(
                      widget.conversationId,
                    ),
                    builder: (_, reactionSnapshot) {
                      final reactions = reactionSnapshot.data ?? const [];
                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 16),
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final row = rows[rows.length - 1 - i];
                          return _Bubble(
                            row: row,
                            conversationId: widget.conversationId,
                            reactions: reactions
                                .where(
                                  (reaction) =>
                                      reaction['message_id']?.toString() ==
                                      row['id']?.toString(),
                                )
                                .toList(),
                          );
                        },
                      );
                    },
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

Color _vipNameColor(Map<String, dynamic> participant) {
  final level = (participant['vip_level'] as num?)?.toInt() ?? 0;
  if (level >= 10) return const Color(0xFFE19B2D);
  if (level >= 7) return const Color(0xFF9C55E8);
  if (level >= 4) return const Color(0xFF427BFF);
  if (level > 0) return const Color(0xFF159DAB);
  return _ink;
}

bool _isParticipantOnline(Map<String, dynamic> participant) {
  if (participant['is_online'] == true) return true;
  final raw = participant['last_seen'] ?? participant['last_seen_at'];
  final last = DateTime.tryParse(raw?.toString() ?? '')?.toUtc();
  return last != null && DateTime.now().toUtc().difference(last).inSeconds < 90;
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.name,
    required this.participant,
    required this.onMenu,
    required this.onAvatarTap,
  });
  final String name;
  final Map<String, dynamic> participant;
  final VoidCallback onMenu;
  final VoidCallback onAvatarTap;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 14, 16, 13),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xFFFFE1D5))),
      boxShadow: [
        BoxShadow(
          color: Color(0x0DFF7A45),
          blurRadius: 15,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_forward_rounded, color: _ink),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onAvatarTap,
          child: SakiAvatar(
            url: participant['avatar_url'] as String?,
            label: name,
            radius: 21,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: _vipNameColor(participant),
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _isParticipantOnline(participant)
                          ? const Color(0xFF25C78B)
                          : _muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _isParticipantOnline(participant)
                        ? 'متصل الآن'
                        : 'غير متصل',
                    style: const TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
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
  const _Bubble({
    required this.row,
    required this.conversationId,
    required this.reactions,
  });
  final Map<String, dynamic> row;
  final String conversationId;
  final List<Map<String, dynamic>> reactions;

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
        onTap: () => _handleBubbleTap(context, row, image, conversationId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: const BoxConstraints(maxWidth: 300),
          padding: image == null
              ? const EdgeInsets.symmetric(horizontal: 15, vertical: 11)
              : const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: mine ? _chatOrange : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(19),
              topRight: const Radius.circular(19),
              bottomLeft: Radius.circular(mine ? 5 : 19),
              bottomRight: Radius.circular(mine ? 19 : 5),
            ),
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              content,
              if (reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 3,
                  children: reactions
                      .map(
                        (reaction) => Text(
                          reaction['emoji']?.toString() ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                      .toList(),
                ),
              ],
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
        border: Border(top: BorderSide(color: Color(0xFFD8F5F7))),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D16B8C8),
            blurRadius: 15,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: disabled ? null : onImage,
            child: Icon(
              Icons.image_outlined,
              color: disabled ? _muted : _chatCyan,
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
                color: _chatOrange,
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

class SystemMessagesPage extends StatefulWidget {
  const SystemMessagesPage({super.key});
  @override
  State<SystemMessagesPage> createState() => _SystemMessagesPageState();
}

class _SystemMessagesPageState extends State<SystemMessagesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SakiService.instance.systemNotifications();
      if (!mounted) return;
      setState(() => _rows = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FullMessagesScaffold(
    title: 'رسائل النظام',
    icon: 'assets/messages/icons/system.png',
    onRefresh: _load,
    loading: _loading,
    child: _rows.isEmpty
        ? const _PremiumEmpty(
            icon: Icons.notifications_none_rounded,
            title: 'لا توجد رسائل نظام',
            subtitle: 'ستظهر هنا المكافآت والمشتريات وترقياتك وأحداث الغرف.',
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _SystemMessageBubble(row: _rows[index]),
          ),
  );
}

class FollowingMessagesPage extends StatefulWidget {
  const FollowingMessagesPage({super.key});
  @override
  State<FollowingMessagesPage> createState() => _FollowingMessagesPageState();
}

class _FollowingMessagesPageState extends State<FollowingMessagesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SakiService.instance.followers();
      if (!mounted) return;
      setState(() => _rows = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FullMessagesScaffold(
    title: 'المتابعة',
    icon: 'assets/messages/icons/following.png',
    onRefresh: _load,
    loading: _loading,
    child: _rows.isEmpty
        ? const _PremiumEmpty(
            icon: Icons.people_outline_rounded,
            title: 'لا يوجد متابعون جدد',
            subtitle: 'ستظهر هنا الحسابات التي بدأت بمتابعتك.',
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) =>
                _FollowingMessageBubble(row: _rows[index]),
          ),
  );
}

class SocialMessagesPage extends StatefulWidget {
  const SocialMessagesPage({super.key});
  @override
  State<SocialMessagesPage> createState() => _SocialMessagesPageState();
}

class _SocialMessagesPageState extends State<SocialMessagesPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await SakiService.instance.socialNotifications();
      if (!mounted) return;
      setState(() => _rows = rows);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _FullMessagesScaffold(
    title: 'الاجتماعية',
    icon: 'assets/messages/icons/social.png',
    onRefresh: _load,
    loading: _loading,
    child: _rows.isEmpty
        ? const _PremiumEmpty(
            icon: Icons.auto_awesome_outlined,
            title: 'لا توجد تفاعلات بعد',
            subtitle: 'ستظهر هنا إعجابات وتعليقات المنشورات والريلز.',
          )
        : ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, index) => _SocialMessageBubble(row: _rows[index]),
          ),
  );
}

class _FullMessagesScaffold extends StatelessWidget {
  const _FullMessagesScaffold({
    required this.title,
    required this.icon,
    required this.onRefresh,
    required this.loading,
    required this.child,
  });
  final String title;
  final String icon;
  final Future<void> Function() onRefresh;
  final bool loading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _chatPale,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(icon, width: 30, height: 30),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    ),
    body: loading
        ? const Center(child: SakiLoading())
        : RefreshIndicator(onRefresh: onRefresh, child: child),
  );
}

class _SystemMessageBubble extends StatelessWidget {
  const _SystemMessageBubble({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final type = row['type']?.toString() ?? 'system';
    final title = _systemTitle(type);
    final text = _systemText(row, type);
    final thumb = _notificationImage(row);
    final read = row['is_read'] == true;
    return _NotificationBubble(
      unread: !read,
      leading: Image.asset(
        'assets/messages/icons/system.png',
        width: 42,
        height: 42,
      ),
      title: title,
      text: text,
      time: _messageTime(row['created_at']),
      thumbnail: thumb,
      onTap: () =>
          SakiService.instance.markNotificationRead(row['id'].toString()),
      accent: _blue,
    );
  }
}

class _FollowingMessageBubble extends StatelessWidget {
  const _FollowingMessageBubble({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(row['profiles'] ?? const {});
    final name = profile['display_name']?.toString().trim().isNotEmpty == true
        ? profile['display_name'].toString()
        : profile['username']?.toString() ?? 'مستخدم';
    final following = row['_following'] == true;
    return _NotificationBubble(
      unread: true,
      leading: SakiAvatar(
        url: profile['avatar_url'] as String?,
        label: name,
        radius: 24,
      ),
      title: name,
      text: 'بدأ بمتابعتك',
      time: _messageTime(row['created_at']),
      onTap: () => _openUser(context, profile),
      trailing: GestureDetector(
        onTap: () async {
          await SakiService.instance.toggleFollow(
            profile['id'].toString(),
            following,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: following ? Colors.white : _blue,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: following ? const Color(0xFFE5E7EB) : _blue,
            ),
          ),
          child: Text(
            following ? 'متابَع' : 'رد متابعة',
            style: TextStyle(
              color: following ? _muted : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
      accent: _violet,
    );
  }
}

class _SocialMessageBubble extends StatelessWidget {
  const _SocialMessageBubble({required this.row});
  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(row['profiles'] ?? const {});
    final name = profile['username']?.toString() ?? 'مستخدم';
    final type = row['type']?.toString() ?? 'social';
    final isLike = type == 'like' || type == 'post_like' || type == 'reel_like';
    final isComment =
        type == 'comment' || type == 'post_comment' || type == 'reel_comment';
    final text = isLike
        ? (type.contains('reel') ? 'أعجب بالريلز الخاص بك' : 'أعجب بمنشورك')
        : isComment
        ? (type.contains('reel')
              ? 'علّق على الريلز الخاص بك'
              : 'علّق على منشورك')
        : type == 'follow'
        ? 'بدأ بمتابعتك'
        : 'تفاعل مع محتواك';
    return _NotificationBubble(
      unread: row['is_read'] != true,
      leading: SakiAvatar(
        url: profile['avatar_url'] as String?,
        label: name,
        radius: 24,
      ),
      title: name,
      text: text,
      time: _messageTime(row['created_at']),
      thumbnail: _notificationImage(row),
      onTap: () =>
          SakiService.instance.markNotificationRead(row['id'].toString()),
      accent: isLike ? const Color(0xFFFF5470) : const Color(0xFF06B6D4),
    );
  }
}

class _NotificationBubble extends StatelessWidget {
  const _NotificationBubble({
    required this.unread,
    required this.leading,
    required this.title,
    required this.text,
    required this.time,
    required this.onTap,
    required this.accent,
    this.thumbnail,
    this.trailing,
  });
  final bool unread;
  final Widget leading;
  final String title;
  final String text;
  final String time;
  final VoidCallback onTap;
  final Color accent;
  final String? thumbnail;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: unread ? accent.withValues(alpha: .07) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: unread
              ? accent.withValues(alpha: .35)
              : const Color(0xFFEDEFF5),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  time,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (thumbnail != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _NotificationThumbnail(url: thumbnail!),
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    ),
  );
}

class _NotificationThumbnail extends StatelessWidget {
  const _NotificationThumbnail({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => url.startsWith('assets/')
      ? Image.asset(url, width: 48, height: 48, fit: BoxFit.cover)
      : Image.network(
          url,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox(
            width: 48,
            height: 48,
            child: Icon(Icons.image_not_supported_outlined, color: _muted),
          ),
        );
}

String _systemTitle(String type) => switch (type) {
  'badge_earned' => 'مبروك! حصلت على وسام جديد',
  'daily_login' => 'مكافأة تسجيل الدخول اليومي',
  'coin_purchase' || 'coins_purchase' => 'شراء العملات',
  'vip_purchase' => 'شراء VIP',
  'wealth_upgrade' => 'ترقية مستوى الثروة',
  'level_upgrade' => 'ترقية المستوى',
  'reward' => 'مكافأة جديدة',
  'entrance_purchase' => 'شراء دخولية',
  'frame_purchase' => 'الحصول على إطار',
  'room_kick' => 'تم طردك من الغرفة',
  'room_ban' => 'تم حظرك من الغرفة',
  'announcement' => 'إعلان من النظام',
  _ => 'نظام SAKI',
};

String _systemText(Map<String, dynamic> row, String type) {
  for (final key in ['message', 'body', 'text', 'description', 'content']) {
    final value = row[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  final payload = row['payload'];
  if (payload is Map) {
    for (final key in ['message', 'body', 'text', 'description']) {
      final value = payload[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
  }
  return switch (type) {
    'badge_earned' => 'تهانينا، لقد حققت إنجازًا جديدًا وحصلت على هذا الوسام.',
    'daily_login' => 'تم تسجيل دخولك اليومي وإضافة مكافأتك إلى حسابك.',
    'coin_purchase' || 'coins_purchase' => 'تمت إضافة العملات إلى رصيدك بنجاح.',
    'vip_purchase' => 'تم تفعيل عضوية VIP في حسابك.',
    'wealth_upgrade' => 'مبروك، تمت ترقية مستوى الثروة الخاص بك.',
    'level_upgrade' => 'مبروك، وصلت إلى مستوى جديد.',
    'room_kick' => 'تم إخراجك من الغرفة بواسطة الإدارة.',
    'room_ban' => 'تم حظرك من الغرفة بواسطة الإدارة.',
    _ => 'لديك تحديث جديد من نظام SAKI.',
  };
}

String? _notificationImage(Map<String, dynamic> row) {
  final badgeAsset = row['badge_asset_path']?.toString();
  if (badgeAsset != null && badgeAsset.isNotEmpty) return badgeAsset;
  final badge = row['_badge'];
  if (badge is Map && badge['asset_path']?.toString().isNotEmpty == true) {
    return badge['asset_path'].toString();
  }
  for (final key in [
    'thumbnail_url',
    'image_url',
    'media_url',
    'icon_url',
    'asset_path',
  ]) {
    final value = row[key]?.toString();
    if (value != null && value.isNotEmpty) return value;
  }
  final payload = row['payload'];
  if (payload is Map) {
    for (final key in [
      'thumbnail_url',
      'image_url',
      'media_url',
      'icon_url',
      'asset_path',
    ]) {
      final value = payload[key]?.toString();
      if (value != null && value.isNotEmpty) return value;
    }
  }
  return null;
}

String _messageTime(dynamic value) {
  final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  if (date == null) return '';
  return '${date.day}/${date.month}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

void _openUser(BuildContext context, Map<String, dynamic> profile) {
  final id = profile['id']?.toString();
  if (id == null || id.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => UserProfilePage(userId: id)),
  );
}

// The page keeps the existing private chat flow below this point.

final Map<String, int> _bubbleTapCounts = {};
final Map<String, Timer> _bubbleTapTimers = {};

void _handleBubbleTap(
  BuildContext context,
  Map<String, dynamic> row,
  String? image,
  String conversationId,
) {
  final id = row['id']?.toString() ?? '${row['created_at']}';
  final count = (_bubbleTapCounts[id] ?? 0) + 1;
  _bubbleTapCounts[id] = count;
  _bubbleTapTimers[id]?.cancel();
  _bubbleTapTimers[id] = Timer(const Duration(milliseconds: 650), () {
    _bubbleTapCounts.remove(id);
    _bubbleTapTimers.remove(id);
  });
  if (count == 3) {
    _bubbleTapCounts.remove(id);
    _showReactionPicker(context, row, conversationId);
  } else if (count == 1 && image != null) {
    _openChatImage(context, image);
  }
}

void _showReactionPicker(
  BuildContext context,
  Map<String, dynamic> row,
  String conversationId,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: ['😂', '❤️', '😭', '😮'].map((emoji) {
          return GestureDetector(
            onTap: () async {
              final messageId = row['id']?.toString();
              if (messageId == null || messageId.startsWith('local-')) {
                Navigator.pop(context);
                return;
              }
              await SakiService.instance.reactToMessage(
                messageId: messageId,
                conversationId: conversationId,
                emoji: emoji,
              );
              if (context.mounted) Navigator.pop(context);
            },
            child: Container(
              width: 55,
              height: 55,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

void _openChatImage(BuildContext context, String url) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'image',
    pageBuilder: (_, _, _) => Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(child: Image.network(url, fit: BoxFit.contain)),
      ),
    ),
  );
}
