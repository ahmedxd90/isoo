import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/saki_widgets.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, this.title = 'الإشعارات', this.filter});
  final String title;
  final String? filter;

  bool _matches(Map<String, dynamic> row) {
    final type = row['type'] as String? ?? '';
    if (filter == null) return true;
    if (filter == 'system') {
      return type == 'system' ||
          type == 'announcement' ||
          type == 'agency_invite';
    }
    if (filter == 'follow') return type == 'follow' || type == 'friend_request';
    return type == 'like' ||
        type == 'comment' ||
        type == 'social' ||
        type == 'message';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: StreamBuilder<List<Map<String, dynamic>>>(
      stream: SakiService.instance.notificationsStream(),
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SakiLoading(label: 'جاري تحميل الإشعارات...');
        }
        final rows = (snapshot.data ?? <Map<String, dynamic>>[])
            .where(_matches)
            .toList();
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'لا توجد إشعارات',
            subtitle: 'ستظهر تفاعلاتك الجديدة هنا من Supabase.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) =>
              _NotificationTile(notification: rows[index]),
        );
      },
    ),
  );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final Map<String, dynamic> notification;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      notification['profiles'] ?? const {},
    );
    final actor = profile['username'] as String? ?? 'النظام';
    final type = notification['type'] as String? ?? 'activity';
    final text = switch (type) {
      'like' => '$actor أعجب بمنشورك',
      'comment' => '$actor علّق على منشورك',
      'follow' || 'friend_request' => '$actor بدأ بمتابعتك',
      'message' => 'لديك رسالة جديدة من $actor',
      'system' || 'announcement' => 'إشعار جديد من النظام',
      _ => 'لديك نشاط جديد من $actor',
    };
    final read = notification['is_read'] == true;
    final data = notification['data'] is Map
        ? Map<String, dynamic>.from(notification['data'] as Map)
        : const <String, dynamic>{};
    if (type == 'agency_invite') {
      return _AgencyInviteTile(
        notification: notification,
        data: data,
        actor: actor,
        read: read,
      );
    }
    return Card(
      color: read ? null : SakiColors.darkPurple.withValues(alpha: .35),
      child: ListTile(
        onTap: () => SakiService.instance.markNotificationRead(
          notification['id'] as String,
        ),
        leading: type == 'system' || type == 'announcement'
            ? const CircleAvatar(
                backgroundColor: Color(0xFFFF758C),
                child: Icon(Icons.notifications, color: Colors.white),
              )
            : SakiAvatar(url: profile['avatar_url'] as String?, label: actor),
        title: Text(
          text,
          style: TextStyle(
            fontWeight: read ? FontWeight.w500 : FontWeight.w800,
          ),
        ),
        subtitle: Text(
          (notification['created_at'] as String? ?? '').replaceFirst('T', ' '),
          style: const TextStyle(color: SakiColors.muted),
        ),
        trailing: read
            ? null
            : const Icon(Icons.circle, size: 10, color: SakiColors.cyan),
      ),
    );
  }
}

class _AgencyInviteTile extends StatefulWidget {
  const _AgencyInviteTile({
    required this.notification,
    required this.data,
    required this.actor,
    required this.read,
  });
  final Map<String, dynamic> notification;
  final Map<String, dynamic> data;
  final String actor;
  final bool read;

  @override
  State<_AgencyInviteTile> createState() => _AgencyInviteTileState();
}

class _AgencyInviteTileState extends State<_AgencyInviteTile> {
  bool _working = false;
  bool _responded = false;

  Future<void> _respond(bool accept) async {
    final inviteId = widget.notification['entity_id']?.toString();
    if (inviteId == null || inviteId.isEmpty) return;
    final action = accept ? 'قبول دعوة الوكالة' : 'إلغاء دعوة الوكالة';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(action),
        content: Text(
          accept
              ? 'هل تريد الانضمام إلى وكالة ${widget.data['agency_name'] ?? 'المضيفين'}؟'
              : 'هل تريد إلغاء الانضمام إلى وكالة ${widget.data['agency_name'] ?? 'المضيفين'}؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept ? 'موافق' : 'إلغاء الدعوة'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      if (accept) {
        await SakiService.instance.hostAgencyAcceptInvite(inviteId);
      } else {
        await SakiService.instance.hostAgencyDeclineInvite(inviteId);
      }
      if (mounted) {
        setState(() {
          _working = false;
          _responded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accept ? 'تم قبول الدعوة والانضمام للوكالة.' : 'تم إلغاء الدعوة.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _working = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final agency = widget.data['agency_name']?.toString() ?? 'وكالة المضيفين';
    final agent =
        widget.data['agent_name']?.toString().trim().isNotEmpty == true
        ? widget.data['agent_name'].toString()
        : widget.actor;
    final response = widget.data['response']?.toString();
    final completed =
        _responded || response == 'accepted' || response == 'declined';
    return Card(
      color: widget.read ? null : SakiColors.darkPurple.withValues(alpha: .35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: SakiColors.orange,
                  child: Icon(
                    Icons.business_center_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'دعوة من $agent للانضمام إلى وكالة $agency',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (completed)
              Text(
                response == 'accepted' || _responded
                    ? 'تم قبول الدعوة والانضمام إلى الوكالة.'
                    : 'تم إلغاء دعوة الوكالة.',
                style: const TextStyle(
                  color: SakiColors.cyan,
                  fontWeight: FontWeight.w800,
                ),
              )
            else ...[
              const Text(
                'تمت دعوتك كمضيف. اختر موافق للانضمام أو إلغاء لرفض الدعوة.',
                style: TextStyle(color: SakiColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _working ? null : () => _respond(true),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('موافق'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _working ? null : () => _respond(false),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('إلغاء'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
