import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

class VipDesign {
  static const bg = Color(0xFF0F0F1A);
  static const panel = Color(0xFF181825);
  static const text = Color(0xFFFFFFFF);
  static const muted = Color(0xFFA0A0B0);
  static const gold = Color(0xFFFFC107);
}

const vipLevelColors = <int, Color>{
  1: Color(0xFFC47C73),
  2: Color(0xFFA8B1C2),
  3: Color(0xFF65B8A6),
  4: Color(0xFF4CD964),
  5: Color(0xFF0088FF),
  6: Color(0xFFD95319),
  7: Color(0xFFB145E9),
  8: Color(0xFF26C6DA),
  9: Color(0xFFFFC107),
  10: Color(0xFFFF4500),
};

class VipBenefit {
  const VipBenefit(this.icon, this.title, this.requiredLevel);
  final IconData icon;
  final String title;
  final int requiredLevel;
}

class VipTabBar extends StatelessWidget {
  const VipTabBar({
    super.key,
    required this.selected,
    required this.active,
    required this.onSelected,
  });
  final int selected;
  final int active;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
    decoration: const BoxDecoration(
      color: Color(0xF20F0F1A),
      border: Border(bottom: BorderSide(color: Color(0x22FFFFFF))),
    ),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: List.generate(10, (index) {
          final level = index + 1;
          final selectedNow = selected == level;
          final color = vipLevelColors[level]!;
          return GestureDetector(
            onTap: () => onSelected(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: selectedNow
                    ? color.withValues(alpha: .16)
                    : Colors.white.withValues(alpha: .03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedNow
                      ? color
                      : Colors.white.withValues(alpha: .10),
                ),
                boxShadow: selectedNow
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: .28),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                'VIP $level',
                style: TextStyle(
                  color: selectedNow ? color : VipDesign.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }),
      ),
    ),
  );
}

class VipBadgeHero extends StatelessWidget {
  const VipBadgeHero({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final color = vipLevelColors[level]!;
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .28),
                      blurRadius: 70,
                      spreadRadius: 18,
                    ),
                  ],
                ),
              ),
              VipSvgaAsset(
                assetPath: 'assets/vip/icon_svip${level}_medal.svga',
                fallbackAsset: 'assets/vip/vip$level.webp',
                size: 220,
              ),
            ],
          ),
        ),
        Text(
          'VIP $level',
          style: TextStyle(
            color: color,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [
              Shadow(color: color.withValues(alpha: .5), blurRadius: 18),
            ],
          ),
        ),
      ],
    );
  }
}

class VipSvgaAsset extends StatefulWidget {
  const VipSvgaAsset({
    super.key,
    required this.assetPath,
    required this.fallbackAsset,
    required this.size,
    this.loop = false,
  });
  final String assetPath;
  final String fallbackAsset;
  final double size;
  final bool loop;
  @override
  State<VipSvgaAsset> createState() => _VipSvgaAssetState();
}

class _VipSvgaAssetState extends State<VipSvgaAsset>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _controller = SVGAAnimationController(
    vsync: this,
  );
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final movie = await SVGAParser.shared.decodeFromAssets(widget.assetPath);
      if (!mounted) return;
      _controller.videoItem = movie;
      setState(() {});
      if (widget.loop) {
        _controller.repeat();
      } else {
        _controller.forward(from: 0);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.size,
    height: widget.size,
    child: _failed || _controller.videoItem == null
        ? Image.asset(
            widget.fallbackAsset,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.workspace_premium_rounded,
              color: vipLevelColors[1],
              size: widget.size * .65,
            ),
          )
        : SVGAImage(_controller, fit: BoxFit.contain),
  );
}

class VipStatusBanner extends StatelessWidget {
  const VipStatusBanner({
    super.key,
    required this.level,
    required this.active,
    required this.expiry,
  });
  final int level;
  final int active;
  final DateTime? expiry;
  @override
  Widget build(BuildContext context) {
    final color = vipLevelColors[level]!;
    final enabled = active >= level;
    final expiryText = expiry;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .18), VipDesign.panel],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: enabled ? Colors.greenAccent : color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color, blurRadius: 8)],
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              enabled
                  ? 'مفعل حاليًا${expiryText == null ? '' : ' • حتى ${expiryText.day}/${expiryText.month}'}'
                  : 'متاح للترقية',
              style: const TextStyle(
                color: VipDesign.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            'VIP $level',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class VipSectionTitle extends StatelessWidget {
  const VipSectionTitle({super.key, required this.title, required this.color});
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
    child: Row(
      children: [
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: .35)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            title,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: .35)),
        ),
      ],
    ),
  );
}

class VipPrivilegesGrid extends StatelessWidget {
  const VipPrivilegesGrid({
    super.key,
    required this.selectedLevel,
    required this.activeLevel,
    required this.benefits,
    required this.color,
  });
  final int selectedLevel;
  final int activeLevel;
  final List<VipBenefit> benefits;
  final Color color;
  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: benefits.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 9,
      mainAxisSpacing: 9,
      childAspectRatio: .82,
    ),
    itemBuilder: (_, index) {
      final b = benefits[index];
      final available = selectedLevel >= b.requiredLevel;
      final enabled = activeLevel >= b.requiredLevel;
      return AnimatedOpacity(
        opacity: available ? 1 : .38,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled
                ? color.withValues(alpha: .20)
                : available
                ? color.withValues(alpha: .08)
                : VipDesign.panel,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: .75)
                  : available
                  ? color.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  available
                      ? (enabled ? b.icon : Icons.lock_clock_rounded)
                      : Icons.lock_outline_rounded,
                  color: enabled
                      ? color
                      : available
                      ? color.withValues(alpha: .75)
                      : VipDesign.muted,
                  size: 24,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                b.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  color: enabled
                      ? Colors.white
                      : available
                      ? Colors.white70
                      : VipDesign.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class VipPurchaseCard extends StatelessWidget {
  const VipPurchaseCard({
    super.key,
    required this.level,
    required this.price,
    required this.coins,
    required this.active,
    required this.working,
    required this.onBuy,
  });
  final int level, price, coins, active;
  final bool working;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) {
    final color = vipLevelColors[level]!;
    final disabled = working || active >= level;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VipDesign.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: color),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'عضوية VIP لمدة 30 يومًا',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${formatVipPrice(price)} ذهب',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'رصيدك الحالي: ${formatVipPrice(coins)} عملة ذهبية',
            style: const TextStyle(color: VipDesign.muted, fontSize: 11),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: disabled ? null : onBuy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: disabled ? Colors.white12 : color,
                borderRadius: BorderRadius.circular(28),
              ),
              alignment: Alignment.center,
              child: Text(
                working
                    ? 'جارٍ التفعيل...'
                    : active >= level
                    ? 'VIP $level مفعل'
                    : 'تفعيل VIP $level',
                style: TextStyle(
                  color: disabled ? VipDesign.muted : Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VipStickyPurchaseBar extends StatelessWidget {
  const VipStickyPurchaseBar({
    super.key,
    required this.level,
    required this.price,
    required this.coins,
    required this.active,
    required this.working,
    required this.onBuy,
  });
  final int level, price, coins, active;
  final bool working;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final color = vipLevelColors[level]!;
    final alreadyActive = active >= level;
    final cannotAfford = coins < price;
    final disabled = working || alreadyActive || cannotAfford;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xF2161624),
        border: Border(top: BorderSide(color: color.withValues(alpha: .55))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: .16),
              border: Border.all(color: color.withValues(alpha: .75)),
            ),
            child: Icon(Icons.workspace_premium_rounded, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VIP $level • 30 يومًا',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'السعر: ${formatVipPrice(price)} ذهب  •  رصيدك: ${formatVipPrice(coins)}',
                  style: const TextStyle(color: VipDesign.muted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: disabled ? null : onBuy,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
              decoration: BoxDecoration(
                color: disabled ? Colors.white12 : color,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                working
                    ? 'جارٍ...'
                    : alreadyActive
                    ? 'مفعل'
                    : cannotAfford
                    ? 'الرصيد غير كافٍ'
                    : 'شراء VIP $level',
                style: TextStyle(
                  color: disabled ? VipDesign.muted : Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String formatVipPrice(int value) => value >= 1000000
    ? '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M'
    : value >= 1000
    ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K'
    : '$value';

class HostAgencyTitleBadge extends StatelessWidget {
  const HostAgencyTitleBadge({
    super.key,
    this.compact = false,
    this.label = 'مضيف',
  });
  final bool compact;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 8 : 12,
      vertical: compact ? 4 : 7,
    ),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF7C3AED)],
      ),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFBAE6FD), width: 1),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0EA5E9).withValues(alpha: .28),
          blurRadius: compact ? 7 : 12,
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mic_external_on_rounded,
          color: Colors.white,
          size: compact ? 12 : 16,
        ),
        SizedBox(width: compact ? 4 : 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 10 : 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}
