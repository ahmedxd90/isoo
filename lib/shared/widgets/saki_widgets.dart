import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SakiAvatar extends StatelessWidget {
  const SakiAvatar({
    super.key,
    this.url,
    this.radius = 22,
    this.label,
    this.profile,
  });
  final String? url;
  final double radius;
  final String? label;
  final Map<String, dynamic>? profile;

  @override
  Widget build(BuildContext context) {
    final level = _activeVipLevel(profile);
    final activeFrameUrl = profile?['active_frame_url']?.toString();
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: SakiColors.royalPurple.withValues(alpha: .25),
      backgroundImage: url == null || url!.isEmpty
          ? null
          : CachedNetworkImageProvider(url!),
      child: url == null || url!.isEmpty
          ? Text(
              (label?.isNotEmpty ?? false) ? label![0].toUpperCase() : 'S',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: radius * .65,
              ),
            )
          : null,
    );
    if (activeFrameUrl != null && activeFrameUrl.isNotEmpty) {
      return SizedBox(
        width: radius * 2 + 14,
        height: radius * 2 + 14,
        child: Stack(
          alignment: Alignment.center,
          children: [
            avatar,
            IgnorePointer(
              child: Image.network(
                activeFrameUrl,
                width: radius * 2 + 14,
                height: radius * 2 + 14,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      );
    }
    if (level == 0 || profile?['vip_frame_enabled'] == false) return avatar;
    return SizedBox(
      width: radius * 2 + 14,
      height: radius * 2 + 14,
      child: Stack(
        alignment: Alignment.center,
        children: [
          avatar,
          IgnorePointer(
            child: Image.asset(
              'assets/vip/frame_vip$level.png',
              width: radius * 2 + 14,
              height: radius * 2 + 14,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

int _activeVipLevel(Map<String, dynamic>? profile) {
  if (profile == null) return 0;
  final level = ((profile['vip_level'] as num?)?.toInt() ?? 0).clamp(0, 10);
  final expires = DateTime.tryParse(
    profile['vip_expires_at']?.toString() ?? '',
  );
  if (level < 1 || expires == null || !expires.isAfter(DateTime.now())) {
    return 0;
  }
  return level;
}

class GradientIconBadge extends StatelessWidget {
  const GradientIconBadge({super.key, required this.icon, this.size = 42});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: SakiTheme.gradient,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(icon, color: Colors.white, size: size * .48),
    );
  }
}

class FamilyTitleBadge extends StatelessWidget {
  const FamilyTitleBadge({
    super.key,
    required this.family,
    this.compact = false,
  });
  final Map<String, dynamic>? family;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (family == null) return const SizedBox.shrink();
    final name = family!['name']?.toString().trim();
    if (name == null || name.isEmpty) return const SizedBox.shrink();
    final owner = family!['role']?.toString() == 'owner';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB938), Color(0xFFE87918)],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFE7A3), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55E87918),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            owner ? Icons.workspace_premium_rounded : Icons.shield_rounded,
            color: Colors.white,
            size: compact ? 12 : 15,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'عائلة $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 10 : 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SakiLoading extends StatelessWidget {
  const SakiLoading({super.key, this.label = 'جاري التحميل...'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: SakiColors.cyan),
            const SizedBox(height: 14),
            Text(label, style: const TextStyle(color: SakiColors.muted)),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 54, color: SakiColors.royalPurple),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SakiColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class VipUsername extends StatefulWidget {
  const VipUsername({
    super.key,
    required this.profile,
    this.style,
    this.maxLines = 1,
  });
  final Map<String, dynamic> profile;
  final TextStyle? style;
  final int maxLines;

  @override
  State<VipUsername> createState() => _VipUsernameState();
}

class _VipUsernameState extends State<VipUsername>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = (widget.profile['vip_level'] as num?)?.toInt() ?? 0;
    final expires = DateTime.tryParse(
      widget.profile['vip_expires_at']?.toString() ?? '',
    );
    final active =
        level > 0 && (expires == null || expires.isAfter(DateTime.now()));
    final text =
        widget.profile['display_name']?.toString().trim().isNotEmpty == true
        ? widget.profile['display_name'].toString()
        : widget.profile['username'] as String? ?? 'مستخدم';
    final base =
        widget.style ??
        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    if (!active) {
      return Text(
        text,
        style: base,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    final colors =
        <int, List<Color>>{
          1: const [Color(0xFFFFC4B9), Color(0xFFFF806D), Color(0xFFFFE1D8)],
          2: const [Color(0xFFE8F0FF), Color(0xFF9DB7E7), Colors.white],
          3: const [Color(0xFFB7FFE9), Color(0xFF4CC9A4), Color(0xFFE2FFF7)],
          4: const [Color(0xFFB9FFD0), Color(0xFF35D878), Colors.white],
          5: const [Color(0xFFB8E7FF), Color(0xFF248BFF), Color(0xFFE4F6FF)],
          6: const [Color(0xFFFFC5A2), Color(0xFFFF6A2A), Color(0xFFFFE8D9)],
          7: const [Color(0xFFE9B8FF), Color(0xFFB145E9), Color(0xFFFFE7FF)],
          8: const [Color(0xFFA8FBFF), Color(0xFF26C6DA), Colors.white],
          9: const [Color(0xFFFFF0A3), Color(0xFFFFB300), Colors.white],
          10: const [
            Color(0xFFFFB4A6),
            Color(0xFFFF4500),
            Color(0xFFFFF1D0),
            Color(0xFFB145E9),
          ],
        }[level] ??
        const [Color(0xFFFFE082), Color(0xFFD4AF37)];
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ShaderMask(
              shaderCallback: (rect) {
                final shift = (_controller.value * 2) - 1;
                return LinearGradient(
                  colors: colors,
                  begin: Alignment(shift, 0),
                  end: Alignment(shift + 2, 0),
                ).createShader(rect);
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                style: base.copyWith(color: Colors.white),
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Image.asset(
            'assets/trace_vip/images/ic_vip_$level.png',
            width: 46,
            height: 18,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class SuperAdminBadge extends StatelessWidget {
  const SuperAdminBadge({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/saki_super_admin_badge.png',
    width: 132,
    height: 54,
    fit: BoxFit.contain,
  );
}
