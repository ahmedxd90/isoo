import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/saki_widgets.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'الإشعارات',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SakiService.instance.notificationsStream(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData)
            return const SakiLoading(label: 'جاري تحميل الإشعارات...');
          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
          if (rows.isEmpty)
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'لا توجد إشعارات',
              subtitle: 'ستظهر تفاعلاتك الجديدة هنا.',
            );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) =>
                _NotificationTile(notification: rows[index]),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final Map<String, dynamic> notification;

  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      notification['profiles'] ?? const {},
    );
    final actor = profile['username'] as String? ?? 'مستخدم';
    final type = notification['type'] as String? ?? 'activity';
    final text = switch (type) {
      'like' => '$actor أعجب بمنشورك',
      'comment' => '$actor علّق على منشورك',
      'follow' => '$actor بدأ بمتابعتك',
      'message' => 'لديك رسالة جديدة من $actor',
      _ => 'لديك نشاط جديد من $actor',
    };
    final read = notification['is_read'] == true;
    return Card(
      color: read ? null : SakiColors.darkPurple.withValues(alpha: .35),
      child: ListTile(
        onTap: () => SakiService.instance.markNotificationRead(
          notification['id'] as String,
        ),
        leading: SakiAvatar(
          url: profile['avatar_url'] as String?,
          label: actor,
        ),
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
