import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import 'custom_toast.dart';
import 'saki_widgets.dart';
import 'vip_identity.dart';

class ProfilePostCard extends StatefulWidget {
  const ProfilePostCard({super.key, required this.post});
  final Map<String, dynamic> post;
  @override
  State<ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<ProfilePostCard> {
  bool _busy = false;
  Map<String, dynamic> get post => widget.post;
  Map<String, dynamic> get author => post['profiles'] is Map
      ? Map<String, dynamic>.from(post['profiles'])
      : {};
  List<Map<String, dynamic>> get media =>
      List<Map<String, dynamic>>.from(post['_media'] ?? const []);

  Future<void> _like() async {
    if (_busy) return;
    final old = post['_liked'] == true;
    setState(() => _busy = true);
    try {
      await SakiService.instance.togglePostLike(post['id'].toString(), old);
      setState(() {
        post['_liked'] = !old;
        post['_likes_count'] =
            (post['_likes_count'] as int? ?? 0) + (old ? -1 : 1);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    await SakiService.instance.sharePost(post['id'].toString());
    if (!mounted) return;
    setState(
      () => post['_shares_count'] = (post['_shares_count'] as int? ?? 0) + 1,
    );
    CustomToast.show(context, 'تمت مشاركة المنشور');
  }

  Future<void> _comments() async {
    final controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          18,
          16,
          MediaQuery.viewInsetsOf(ctx).bottom + 18,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  hintText: 'اكتب تعليقًا...',
                  filled: true,
                  fillColor: Color(0xFFF4F5F7),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                if (controller.text.trim().isEmpty) return;
                await SakiService.instance.addComment(
                  post['id'].toString(),
                  controller.text.trim(),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  setState(
                    () => post['_comments_count'] =
                        (post['_comments_count'] as int? ?? 0) + 1,
                  );
                  CustomToast.show(context, 'تم إضافة التعليق');
                }
              },
              icon: const Icon(Icons.send_rounded, color: Color(0xFF10B981)),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final liked = post['_liked'] == true;
    final content = post['content']?.toString() ?? '';
    final username = author['username']?.toString() ?? 'مستخدم SAKI';
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 10, 9),
            child: Row(
              children: [
                SakiAvatar(
                  url: author['avatar_url']?.toString(),
                  label: username,
                  profile: author,
                  radius: 23,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 5,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          VipNameText(profile: author, fontSize: 14),
                          WealthLevelBadge(profile: author, compact: true),
                          VipTitleBadge(profile: author, compact: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post['created_at']?.toString().substring(0, 10) ??
                            'الآن',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.more_horiz_rounded, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
          if (content.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 11),
              child: Text(
                content,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 13,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          for (final item in media)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                color: const Color(0xFFF1F5F9),
                constraints: const BoxConstraints(
                  minHeight: 180,
                  maxHeight: 440,
                ),
                width: double.infinity,
                child: Image.network(
                  SakiService.instance.postMediaUrl(
                    item['storage_path'].toString(),
                  ),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Color(0xFF94A3B8),
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
            child: Row(
              children: [
                _Action(
                  icon: liked
                      ? Icons.local_fire_department_rounded
                      : Icons.local_fire_department_outlined,
                  color: liked
                      ? const Color(0xFFF97316)
                      : const Color(0xFF64748B),
                  label: '${post['_likes_count'] ?? 0}',
                  onTap: _like,
                ),
                const SizedBox(width: 18),
                _Action(
                  icon: Icons.chat_bubble_outline_rounded,
                  color: const Color(0xFF64748B),
                  label: '${post['_comments_count'] ?? 0}',
                  onTap: _comments,
                ),
                const SizedBox(width: 18),
                _Action(
                  icon: Icons.share_outlined,
                  color: const Color(0xFF64748B),
                  label: '${post['_shares_count'] ?? 0}',
                  onTap: _share,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
