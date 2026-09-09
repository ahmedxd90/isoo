import 'package:flutter/material.dart';

import 'saki_widgets.dart';

const vipNameGradients = <int, List<Color>>{
  1: [Color(0xFFFFC4B9), Color(0xFFFF806D), Color(0xFFFFE1D8)],
  2: [Color(0xFFE8F0FF), Color(0xFF9DB7E7), Color(0xFFFFFFFF)],
  3: [Color(0xFFB7FFE9), Color(0xFF4CC9A4), Color(0xFFE2FFF7)],
  4: [Color(0xFFB9FFD0), Color(0xFF35D878), Color(0xFFF0FFF5)],
  5: [Color(0xFFB8E7FF), Color(0xFF248BFF), Color(0xFFE4F6FF)],
  6: [Color(0xFFFFC5A2), Color(0xFFFF6A2A), Color(0xFFFFE8D9)],
  7: [Color(0xFFE9B8FF), Color(0xFFB145E9), Color(0xFFFFE7FF)],
  8: [Color(0xFFA8FBFF), Color(0xFF26C6DA), Color(0xFFEBFFFF)],
  9: [Color(0xFFFFF0A3), Color(0xFFFFB300), Color(0xFFFFFFFF)],
  10: [
    Color(0xFFFFB4A6),
    Color(0xFFFF4500),
    Color(0xFFFFF1D0),
    Color(0xFFB145E9),
  ],
};

Color vipAccent(int level) =>
    <int, Color>{
      1: const Color(0xFFC47C73),
      2: const Color(0xFFA8B1C2),
      3: const Color(0xFF65B8A6),
      4: const Color(0xFF4CD964),
      5: const Color(0xFF0088FF),
      6: const Color(0xFFD95319),
      7: const Color(0xFFB145E9),
      8: const Color(0xFF26C6DA),
      9: const Color(0xFFFFC107),
      10: const Color(0xFFFF4500),
    }[level] ??
    Colors.white70;

int activeVipLevel(Map<String, dynamic> profile) {
  final level = (profile['vip_level'] as num?)?.toInt() ?? 0;
  final expiry = DateTime.tryParse(profile['vip_expires_at']?.toString() ?? '');
  return level > 0 && (expiry == null || expiry.isAfter(DateTime.now()))
      ? level.clamp(0, 10)
      : 0;
}

class VipNameText extends StatefulWidget {
  const VipNameText({
    super.key,
    required this.profile,
    this.fontSize = 14,
    this.maxLines = 1,
    this.textAlign,
  });
  final Map<String, dynamic> profile;
  final double fontSize;
  final int maxLines;
  final TextAlign? textAlign;
  @override
  State<VipNameText> createState() => _VipNameTextState();
}

class _VipNameTextState extends State<VipNameText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = activeVipLevel(widget.profile);
    final name =
        widget.profile['display_name']?.toString().trim().isNotEmpty == true
        ? widget.profile['display_name'].toString()
        : widget.profile['username']?.toString() ?? 'مستخدم';
    if (level == 0)
      return Text(
        name,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: widget.textAlign,
        style: TextStyle(
          color: Colors.white,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w800,
        ),
      );
    final colors = vipNameGradients[level] ?? vipNameGradients[1]!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => ShaderMask(
        shaderCallback: (bounds) {
          final shift = (_controller.value * 2) - 1;
          return LinearGradient(
            begin: Alignment(shift - 1, 0),
            end: Alignment(shift + 1, 0),
            colors: colors,
            stops: List<double>.generate(
              colors.length,
              (i) => i / (colors.length - 1),
            ),
          ).createShader(bounds);
        },
        child: Text(
          name,
          maxLines: widget.maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: widget.textAlign,
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: vipAccent(level).withValues(alpha: .7),
                blurRadius: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VipTitleBadge extends StatelessWidget {
  const VipTitleBadge({super.key, required this.profile, this.compact = false});
  final Map<String, dynamic> profile;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final level = activeVipLevel(profile);
    if (level == 0) return const SizedBox.shrink();
    final color = vipAccent(level);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: .90),
            Colors.black.withValues(alpha: .72),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .85)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .35),
            blurRadius: compact ? 5 : 10,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/vip/title_vip$level.png',
            width: compact ? 18 : 26,
            height: compact ? 18 : 26,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: compact ? 12 : 15,
            ),
          ),
          const SizedBox(width: 3),
          const SizedBox(width: 1),
          Text(
            'VIP $level',
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

class VipIdentity extends StatelessWidget {
  const VipIdentity({
    super.key,
    required this.profile,
    this.radius = 22,
    this.showTitle = true,
    this.compact = false,
  });
  final Map<String, dynamic> profile;
  final double radius;
  final bool showTitle;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final level = activeVipLevel(profile);
    final color = vipAccent(level);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: radius * 2 + 8,
          height: radius * 2 + 8,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: level > 0 ? color : Colors.white24,
              width: level > 0 ? 2 : 1,
            ),
            boxShadow: level > 0
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: .5),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: SakiAvatar(
            url: profile['avatar_url'] as String?,
            label: profile['username'] as String?,
            radius: radius,
            profile: profile,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              VipNameText(profile: profile, fontSize: compact ? 11 : 14),
              if (showTitle) ...[
                const SizedBox(height: 4),
                VipTitleBadge(profile: profile, compact: compact),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class VipSakiId extends StatefulWidget {
  const VipSakiId({super.key, required this.profile, this.fontSize = 12});
  final Map<String, dynamic> profile;
  final double fontSize;

  @override
  State<VipSakiId> createState() => _VipSakiIdState();
}

class _VipSakiIdState extends State<VipSakiId>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = activeVipLevel(widget.profile);
    final value = widget.profile['saki_id']?.toString() ?? '—';
    if (level < 6) {
      return Text(
        'SAKI ID: $value',
        style: TextStyle(
          color: Colors.white60,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    final colors = vipNameGradients[level] ?? vipNameGradients[6]!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => ShaderMask(
        shaderCallback: (bounds) {
          final shift = (_controller.value * 2) - 1;
          return LinearGradient(
            begin: Alignment(shift - 1, 0),
            end: Alignment(shift + 1, 0),
            colors: colors,
          ).createShader(bounds);
        },
        child: Text(
          'SAKI ID: $value',
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: vipAccent(level), blurRadius: 7)],
          ),
        ),
      ),
    );
  }
}
