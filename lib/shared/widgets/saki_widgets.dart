import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class SakiAvatar extends StatelessWidget {
  const SakiAvatar({super.key, this.url, this.radius = 22, this.label});
  final String? url;
  final double radius;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
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
  }
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
    final superAdmin =
        widget.profile['is_super_admin'] == true ||
        (widget.profile['saki_id'] as num?)?.toInt() == 1000;
    final level = (widget.profile['vip_level'] as num?)?.toInt() ?? 0;
    final expires = DateTime.tryParse(
      widget.profile['vip_expires_at']?.toString() ?? '',
    );
    final active =
        level > 0 && (expires == null || expires.isAfter(DateTime.now()));
    final text = widget.profile['username'] as String? ?? 'مستخدم';
    final base =
        widget.style ??
        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700);
    if (!active && !superAdmin) {
      return Text(
        text,
        style: base,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
      );
    }
    if (superAdmin) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF312E81), Color(0xFF06B6D4), Color(0xFFF59E0B)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x6606B6D4), blurRadius: 8)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 13,
            ),
            const SizedBox(width: 4),
            Text(
              'SUPER ADMIN',
              style: base.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
              maxLines: 1,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                style: base.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    final colors = level >= 6
        ? const [Colors.red, Colors.amber, Colors.blue, Colors.red]
        : const [Color(0xFFFFE082), Color(0xFFD4AF37)];
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => ShaderMask(
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
    );
  }
}
