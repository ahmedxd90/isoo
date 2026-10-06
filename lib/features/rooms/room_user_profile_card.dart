import 'dart:async';

import 'package:flutter/material.dart';

import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';

class RoomUserProfileCard extends StatelessWidget {
  const RoomUserProfileCard({
    super.key,
    required this.profile,
    required this.countryFlag,
    required this.modules,
    required this.roleBadges,
    required this.badges,
    required this.following,
    required this.isSelf,
    required this.onClose,
    required this.onFollow,
    required this.onMessage,
    required this.onOpenProfile,
    required this.onMore,
  });

  final Map<String, dynamic> profile;
  final String countryFlag;
  final Map<String, dynamic> modules;
  final List<Map<String, dynamic>> roleBadges;
  final List<Map<String, dynamic>> badges;
  final bool following;
  final bool isSelf;
  final VoidCallback onClose;
  final FutureOr<void> Function() onFollow;
  final FutureOr<void> Function() onMessage;
  final VoidCallback onOpenProfile;
  final VoidCallback onMore;

  String _number(dynamic value) {
    final number = (value as num?)?.toDouble() ?? 0;
    if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M';
    if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K';
    return number.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    final merged = {...profile, ...modules};
    final vip = activeVipLevel(merged);
    final colors =
        vipNameGradients[vip] ?? const [Color(0xFFE5E7EB), Color(0xFFFFFFFF)];
    final accent = vipAccent(vip);
    final isVip = vip > 0;
    final age = profile['age']?.toString();
    final gender =
        profile['gender']?.toString() == 'male' ||
            profile['gender']?.toString() == 'ذكر'
        ? '♂'
        : '♀';
    final followers = profile['followers_count'] ?? profile['followers'] ?? 0;
    final followingCount =
        profile['following_count'] ?? profile['following'] ?? 0;
    final visitors = profile['visitors_count'] ?? profile['visitors'] ?? 0;
    final frame = profile['frame']?.toString();

    return SafeArea(
      top: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 62, 18, 22),
            decoration: BoxDecoration(
              color: isVip ? null : Colors.white,
              gradient: isVip
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(colors.first, const Color(0xFF111827), .35)!,
                        const Color(0xFF111321),
                      ],
                    )
                  : null,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: isVip
                  ? Border(top: BorderSide(color: accent, width: 1.2))
                  : null,
              boxShadow: [
                BoxShadow(
                  color: isVip ? accent.withValues(alpha: .28) : Colors.black12,
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: IconButton(
                    onPressed: onMore,
                    icon: const Icon(Icons.more_horiz_rounded),
                    color: isVip ? Colors.white70 : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(countryFlag, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: VipNameText(
                        profile: merged,
                        fontSize: 21,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (isVip) ...[
                      const SizedBox(width: 7),
                      VipTitleBadge(profile: merged),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 7,
                  children: [
                    _DetailChip(
                      label: '$gender ${age ?? ''}'.trim(),
                      dark: isVip,
                    ),
                    _DetailChip(
                      label:
                          'ID: ${profile['saki_id'] ?? profile['id'] ?? '—'}',
                      dark: isVip,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (roleBadges.isNotEmpty || badges.isNotEmpty)
                  SizedBox(
                    height: 58,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      shrinkWrap: true,
                      itemCount: [...roleBadges, ...badges].take(8).length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final all = [...roleBadges, ...badges];
                        final item = all[index];
                        final asset = item['asset']?.toString();
                        return Container(
                          width: 58,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isVip
                                ? Colors.white.withValues(alpha: .10)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isVip
                                  ? accent.withValues(alpha: .5)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: asset != null && asset.startsWith('assets/')
                              ? Image.asset(
                                  asset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.workspace_premium_rounded,
                                    color: accent,
                                  ),
                                )
                              : Icon(
                                  Icons.workspace_premium_rounded,
                                  color: accent,
                                ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    _RoomStat(
                      value: _number(visitors),
                      label: 'الزوار',
                      dark: isVip,
                    ),
                    _RoomStat(
                      value: _number(followers),
                      label: 'المتابعون',
                      dark: isVip,
                    ),
                    _RoomStat(
                      value: _number(followingCount),
                      label: 'يتابع',
                      dark: isVip,
                    ),
                    _RoomStat(
                      value: 'LV.${merged['wealth_level'] ?? 0}',
                      label: 'الثروة',
                      dark: isVip,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _RoomAction(
                        label: 'رسالة',
                        icon: Icons.chat_bubble_rounded,
                        color: isVip ? accent : const Color(0xFF6D28D9),
                        onTap: () => onMessage(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!isSelf)
                      Expanded(
                        child: _RoomAction(
                          label: following ? 'متابَع' : 'متابعة',
                          icon: following
                              ? Icons.check_rounded
                              : Icons.favorite_rounded,
                          color: isVip
                              ? Colors.white.withValues(alpha: .15)
                              : Colors.white,
                          foreground: isVip
                              ? Colors.white
                              : const Color(0xFF6D28D9),
                          border: isVip
                              ? Colors.white38
                              : const Color(0xFFDDD6FE),
                          onTap: () => onFollow(),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onOpenProfile,
                  child: Text(
                    'عرض الملف الكامل',
                    style: TextStyle(
                      color: isVip ? Colors.white70 : const Color(0xFF6D28D9),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: -48,
            left: 0,
            right: 0,
            child: GestureDetector(
              onTap: onOpenProfile,
              child: Center(
                child: SizedBox(
                  width: 104,
                  height: 104,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isVip)
                        Image.asset(
                          'assets/room_profile/vip_${vip.toString().padLeft(2, '0')}.png',
                          width: 120,
                          height: 120,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isVip ? const Color(0xFF111321) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isVip ? accent : const Color(0xFFE5E7EB),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isVip
                                  ? accent.withValues(alpha: .55)
                                  : Colors.black26,
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: SakiAvatar(
                          url: profile['avatar_url']?.toString(),
                          label: profile['username']?.toString(),
                          radius: 43,
                          profile: merged,
                        ),
                      ),
                      if (frame != null && frame.isNotEmpty)
                        IgnorePointer(
                          child: Image.network(
                            frame,
                            width: 112,
                            height: 112,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 13,
            right: 14,
            child: IconButton(
              onPressed: onClose,
              icon: Icon(
                Icons.close_rounded,
                color: isVip ? Colors.white70 : const Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.dark});
  final String label;
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: dark
          ? Colors.white.withValues(alpha: .10)
          : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: dark ? Colors.white70 : const Color(0xFF6B7280),
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _RoomStat extends StatelessWidget {
  const _RoomStat({
    required this.value,
    required this.label,
    required this.dark,
  });
  final String value, label;
  final bool dark;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: dark ? Colors.white : const Color(0xFF111827),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: dark ? Colors.white60 : const Color(0xFF9CA3AF),
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class _RoomAction extends StatelessWidget {
  const _RoomAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.foreground = Colors.white,
    this.border,
  });
  final String label;
  final IconData icon;
  final Color color, foreground;
  final Color? border;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foreground,
        elevation: 0,
        side: border == null ? null : BorderSide(color: border!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
  );
}
