import 'package:flutter/material.dart';

class VipDesign {
  static const bg = Color(0xFF080606);
  static const panel = Color(0xFF17110C);
  static const border = Color(0xFF3D2C1C);
  static const gold = Color(0xFFE5A11A);
  static const goldLight = Color(0xFFFCE08B);
  static const text = Color(0xFFF5E7C1);
  static const muted = Color(0xFF9D9285);
}

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
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
      decoration: const BoxDecoration(
        color: Color(0xEE080606),
        border: Border(bottom: BorderSide(color: Color(0xFF221810))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: List.generate(7, (index) {
            final level = index + 1;
            final selectedNow = selected == level;
            return GestureDetector(
              onTap: () => onSelected(level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                padding: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selectedNow ? VipDesign.gold : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  'VIP $level',
                  style: TextStyle(
                    color: selectedNow ? VipDesign.goldLight : VipDesign.muted,
                    fontSize: selectedNow ? 15 : 13,
                    fontWeight: selectedNow ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class VipBadgeHero extends StatelessWidget {
  const VipBadgeHero({super.key, required this.level, required this.imageUrl});
  final int level;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 238,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VipDesign.gold.withValues(alpha: .10),
                  boxShadow: [
                    BoxShadow(
                      color: VipDesign.gold.withValues(alpha: .18),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
              Image.network(
                imageUrl,
                width: 210,
                height: 210,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.workspace_premium_rounded,
                  size: 150,
                  color: VipDesign.gold,
                ),
              ),
            ],
          ),
        ),
        Text(
          'VIP $level',
          style: const TextStyle(
            color: VipDesign.goldLight,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
      ],
    );
  }
}

class VipStatusBanner extends StatelessWidget {
  const VipStatusBanner({super.key, required this.level, required this.active});
  final int level;
  final int active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C2016), Color(0xFF18110B)],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF4A3622)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            active >= level ? 'مفعل حتى الآن' : 'لم يتم التفعيل بعد',
            style: const TextStyle(
              color: VipDesign.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'VIP $level',
            style: const TextStyle(
              color: VipDesign.goldLight,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class VipSectionTitle extends StatelessWidget {
  const VipSectionTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: VipDesign.gold.withValues(alpha: .35),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFE2B746),
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: VipDesign.gold.withValues(alpha: .35),
            ),
          ),
        ],
      ),
    );
  }
}

class VipDefinitionGrid extends StatelessWidget {
  const VipDefinitionGrid({super.key});
  static const items = <(IconData, String)>[
    (Icons.chat_bubble_outline_rounded, 'فقاعة حصرية'),
    (Icons.workspace_premium_rounded, 'أغطية الرأس الحصرية'),
    (Icons.label_rounded, 'تسمية VIP'),
    (Icons.mic_rounded, 'موجة صوتية للميكروفون'),
    (Icons.badge_rounded, 'بطاقة عرض الغرفة'),
    (Icons.auto_awesome_rounded, 'تأثير حصري'),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: .83,
      ),
      itemBuilder: (_, index) => VipFeatureCard(
        icon: items[index].$1,
        title: items[index].$2,
        enabled: true,
      ),
    );
  }
}

class VipPrivilegesGrid extends StatelessWidget {
  const VipPrivilegesGrid({
    super.key,
    required this.selectedLevel,
    required this.benefits,
  });
  final int selectedLevel;
  final List<VipBenefit> benefits;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: benefits.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 9,
        mainAxisSpacing: 9,
        childAspectRatio: .83,
      ),
      itemBuilder: (_, index) {
        final benefit = benefits[index];
        return VipFeatureCard(
          icon: benefit.icon,
          title: benefit.title,
          enabled: selectedLevel >= benefit.requiredLevel,
        );
      },
    );
  }
}

class VipFeatureCard extends StatelessWidget {
  const VipFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.enabled,
  });
  final IconData icon;
  final String title;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: enabled ? 1 : .35,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: VipDesign.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled ? const Color(0xFF7A5A2E) : VipDesign.border,
          ),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2A1E14), Color(0xFF120D09)],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A3824)),
              ),
              child: Icon(
                enabled ? icon : Icons.lock_outline_rounded,
                color: enabled ? VipDesign.goldLight : VipDesign.muted,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(
                color: VipDesign.text,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VipOrnament extends StatelessWidget {
  const VipOrnament({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(
      child: Container(
        width: 130,
        height: 1,
        color: VipDesign.gold.withValues(alpha: .5),
      ),
    ),
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
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: VipDesign.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VipDesign.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.monetization_on_rounded, color: VipDesign.gold),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'عضوية VIP لمدة 30 يومًا',
                  style: TextStyle(
                    color: VipDesign.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$price 🪙',
                style: const TextStyle(
                  color: VipDesign.goldLight,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'رصيدك الحالي: $coins عملة ذهبية',
            style: const TextStyle(color: VipDesign.muted, fontSize: 11),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: working || active > level ? null : onBuy,
              style: ElevatedButton.styleFrom(
                backgroundColor: VipDesign.gold,
                foregroundColor: const Color(0xFF1A1005),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: Text(
                working
                    ? 'جارٍ التفعيل...'
                    : active >= level
                    ? 'VIP $level مفعل'
                    : 'تفعيل VIP $level',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
