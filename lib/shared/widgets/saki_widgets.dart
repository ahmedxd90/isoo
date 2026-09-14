import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svga/flutter_svga.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/data/saki_service.dart';

class WealthLevelBadge extends StatelessWidget {
  const WealthLevelBadge({
    super.key,
    required this.profile,
    this.compact = true,
  });
  final Map<String, dynamic> profile;
  final bool compact;
  int get level => (profile['wealth_level'] as num? ?? 0).toInt().clamp(0, 500);
  int get tier => (level ~/ 20).clamp(0, 7);
  List<Color> get colors => switch (tier) {
    0 => const [Color(0xFF64748B), Color(0xFF94A3B8)],
    1 => const [Color(0xFF0891B2), Color(0xFF67E8F9)],
    2 => const [Color(0xFF7C3AED), Color(0xFFE879F9)],
    3 => const [Color(0xFFB45309), Color(0xFFFDE68A)],
    4 => const [Color(0xFF2563EB), Color(0xFFA855F7)],
    5 => const [Color(0xFF0E7490), Color(0xFF8B5CF6)],
    6 => const [Color(0xFFDB2777), Color(0xFFFDE68A)],
    _ => const [Color(0xFF312E81), Color(0xFFF9A8D4)],
  };
  @override
  Widget build(BuildContext context) {
    final size = compact ? 22.0 : 28.0;
    return Container(
      height: size,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: .72),
          width: .7,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: .38),
            blurRadius: compact ? 5 : 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(compact ? 14 : 18, compact ? 14 : 18),
            painter: _WealthMiniEmblemPainter(colors: colors, tier: tier),
          ),
          const SizedBox(width: 3),
          Text(
            'LV$level',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WealthMiniEmblemPainter extends CustomPainter {
  const _WealthMiniEmblemPainter({required this.colors, required this.tier});
  final List<Color> colors;
  final int tier;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * .42;
    final ring = Paint()
      ..shader = SweepGradient(colors: [...colors, colors.first])
          .createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, r, ring);
    final p = Path()
      ..moveTo(c.dx, c.dy - r * .7)
      ..lineTo(c.dx + r * .7, c.dy - r * .2)
      ..lineTo(c.dx + r * .45, c.dy + r * .55)
      ..lineTo(c.dx, c.dy + r * .8)
      ..lineTo(c.dx - r * .45, c.dy + r * .55)
      ..lineTo(c.dx - r * .7, c.dy - r * .2)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(colors: colors.reversed.toList())
            .createShader(Offset.zero & size),
    );
    final star = <Offset>[];
    for (var i = 0; i < 10; i++) {
      final a = -math.pi / 2 + i * math.pi / 5;
      final rr = i.isEven ? r * .35 : r * .15;
      star.add(c + Offset(math.cos(a) * rr, math.sin(a) * rr));
    }
    canvas.drawPath(
      Path()..addPolygon(star, true),
      Paint()..color = Colors.white.withValues(alpha: tier == 0 ? .75 : .95),
    );
  }

  @override
  bool shouldRepaint(covariant _WealthMiniEmblemPainter oldDelegate) =>
      oldDelegate.tier != tier;
}

class SakiAvatar extends StatefulWidget {
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
  State<SakiAvatar> createState() => _SakiAvatarState();
}

class _SakiAvatarState extends State<SakiAvatar>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _frame;
  late final SVGAAnimationController _svga = SVGAAnimationController(
    vsync: this,
  );
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _loadFrame();
  }

  @override
  void didUpdateWidget(covariant SakiAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile?['active_frame_url']?.toString() !=
            widget.profile?['active_frame_url']?.toString() ||
        oldWidget.profile?['id']?.toString() !=
            widget.profile?['id']?.toString()) {
      _loadFrame();
    }
  }

  Future<void> _loadFrame() async {
    final direct = widget.profile?['active_frame_url']?.toString();
    if (direct != null && direct.isNotEmpty) {
      if (mounted) {
        setState(
          () => _frame = {
            'media_url': direct,
            'media_type': widget.profile?['active_frame_media_type'] ?? 'png',
          },
        );
      }
      return;
    }
    final userId = widget.profile?['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    final frame = await SakiService.instance.activeProfileFrame(userId);
    if (!mounted || frame == null) return;
    setState(() => _frame = frame);
  }

  @override
  void dispose() {
    _svga.dispose();
    super.dispose();
  }

  Widget _frameWidget(double size) {
    final frame = _frame;
    if (frame == null) return const SizedBox.shrink();
    final url =
        frame['media_url']?.toString() ?? frame['thumbnail_url']?.toString();
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final type = frame['media_type']?.toString().toLowerCase();
    if (type == 'svga') {
      if (_loadedUrl != url) {
        _loadedUrl = url;
        SVGAParser.shared
            .decodeFromURL(url)
            .then((movie) {
              if (!mounted || _loadedUrl != url) return;
              _svga.videoItem = movie;
              _svga.forward(from: 0);
              setState(() {});
            })
            .catchError((_) {});
      }
      return _svga.videoItem == null
          ? const SizedBox.shrink()
          : SVGAImage(_svga, fit: BoxFit.contain);
    }
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFrameUrl = _frame?['media_url']?.toString();
    final avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor: SakiColors.royalPurple.withValues(alpha: .25),
      backgroundImage: widget.url == null || widget.url!.isEmpty
          ? null
          : CachedNetworkImageProvider(widget.url!),
      child: widget.url == null || widget.url!.isEmpty
          ? Text(
              (widget.label?.isNotEmpty ?? false)
                  ? widget.label![0].toUpperCase()
                  : 'S',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: widget.radius * .65,
              ),
            )
          : null,
    );
    if (activeFrameUrl != null && activeFrameUrl.isNotEmpty) {
      final frameSize = widget.radius * 2 + 18;
      return SizedBox(
        width: frameSize,
        height: frameSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            avatar,
            IgnorePointer(child: _frameWidget(frameSize)),
          ],
        ),
      );
    }
    return avatar;
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SakiColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class SakiSectionHeader extends StatelessWidget {
  const SakiSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 28,
        decoration: BoxDecoration(
          gradient: SakiTheme.gradient,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(color: SakiColors.muted, fontSize: 11),
              ),
          ],
        ),
      ),
      if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
    ],
  );
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
        const TextStyle(color: SakiColors.ink, fontWeight: FontWeight.w700);
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
