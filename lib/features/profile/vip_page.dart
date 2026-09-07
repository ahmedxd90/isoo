import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

const _bg = Color(0xFFF7F5FA);
const _ink = Color(0xFF21152E);
const _muted = Color(0xFF8A8194);
const _purple = Color(0xFF7D16B5);
const _violet = Color(0xFFA823DA);
const _gold = Color(0xFFFFB51B);

class VipPage extends StatefulWidget {
  const VipPage({super.key});
  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  static const _bg = Color(0xFFF7F5FA);
  static const _ink = Color(0xFF21152E);
  static const _muted = Color(0xFF8A8194);
  static const _purple = Color(0xFF7D16B5);
  static const _violet = Color(0xFFA823DA);
  static const _gold = Color(0xFFFFB51B);
  static const _prices = <int, int>{
    1: 60000,
    2: 200000,
    3: 500000,
    4: 1000000,
    5: 2000000,
    6: 4000000,
    7: 8000000,
  };
  static const _required = <int>[
    10000,
    50000,
    100000,
    200000,
    500000,
    1000000,
    2000000,
  ];
  static const _icons = <String>[
    'https://i.top4top.io/p_39027a3a40.png',
    'https://g.top4top.io/p_39020jo2e1.png',
    'https://f.top4top.io/p_39028t7ba0.png',
    'https://h.top4top.io/p_3902xn2xq0.png',
    'https://k.top4top.io/p_3902ysy8o0.png',
    'https://c.top4top.io/p_3902j4t7t0.png',
    'https://e.top4top.io/p_390251hsl0.png',
  ];
  static const _benefits = <String>[
    'شارة مميزة',
    'إطار خاص',
    'دخوليات حصرية',
    'مؤثرات لامعة',
    'بطاقة اسم',
    'غرفة خاصة',
    'هدايا VIP',
    'خصوصية مميزة',
  ];

  final _service = SakiService.instance;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _account = {};
  int _selected = 1;
  bool _loading = true;
  bool _working = false;

  int _active() {
    final level = (_profile['vip_level'] as num?)?.toInt() ?? 0;
    final expiry = DateTime.tryParse(
      _profile['vip_expires_at']?.toString() ?? '',
    );
    return expiry != null && expiry.isAfter(DateTime.now()) ? level : 0;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait<dynamic>([
        _service.myProfile(),
        _service.accountModules(),
      ]);
      if (!mounted) return;
      final profile = result[0] as Map<String, dynamic>? ?? {};
      final active = (() {
        final l = (profile['vip_level'] as num?)?.toInt() ?? 0;
        final e = DateTime.tryParse(
          profile['vip_expires_at']?.toString() ?? '',
        );
        return e != null && e.isAfter(DateTime.now()) ? l : 0;
      })();
      setState(() {
        _profile = profile;
        _account = Map<String, dynamic>.from(result[1] as Map);
        _selected = active.clamp(1, 7);
      });
    } catch (_) {
      if (mounted) _toast('تعذر تحميل بيانات VIP');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _format(int value) {
    if (value >= 1000000)
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    if (value >= 1000)
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
    return '$value';
  }

  Future<void> _buy() async {
    final active = _active();
    final price = _prices[_selected]!;
    final balance = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    if (active > _selected)
      return _toast('لا يمكنك شراء مستوى أقل من VIP $active');
    if (balance < price) return _toast('رصيد العملات الذهبية غير كافٍ');
    final ok = await _confirmPurchase();
    if (!ok || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.purchaseVip(_selected);
      await _load();
      if (mounted) _toast('تم تفعيل VIP $_selected لمدة 30 يومًا');
    } catch (_) {
      if (mounted) _toast('تعذر تنفيذ شراء VIP');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<bool> _confirmPurchase() async =>
      await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'تأكيد شراء VIP',
        barrierColor: Colors.black54,
        pageBuilder: (_, __, ___) => Center(
          child: _PurchaseDialog(
            level: _selected,
            price: _prices[_selected]!,
            icon: _icons[_selected - 1],
          ),
        ),
        transitionBuilder: (_, animation, __, child) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      ) ??
      false;

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final active = _active();
    final coins = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : SafeArea(
              child: Column(
                children: [
                  _VipHeader(
                    active: active,
                    onHelp: () => _toast('اختر مستوى VIP ثم اضغط شراء'),
                  ),
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _Hero(
                            profile: _profile,
                            active: active,
                            coins: coins,
                            icon: active > 0 ? _icons[active - 1] : null,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _SectionTitle(
                            title: 'اختر مستوى VIP',
                            caption: 'كل مستوى يفتح مزايا أكثر',
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: 210,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: 7,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (_, i) => _LevelCard(
                                level: i + 1,
                                selected: _selected == i + 1,
                                coins: coins,
                                onTap: () => setState(() => _selected = i + 1),
                              ),
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _SectionTitle(
                            title: 'مزايا VIP $_selected',
                            caption: 'مزايا مصممة لتجربة اجتماعية أرقى',
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (_, i) => _BenefitTile(
                                title: _benefits[i],
                                level: (i % 4) + 1,
                                enabled: _selected >= (i % 4) + 1,
                                icon: Icons.auto_awesome_rounded,
                              ),
                              childCount: _benefits.length,
                            ),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: .72,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PurchaseBar(
                    level: _selected,
                    price: _prices[_selected]!,
                    working: _working,
                    onBuy: _buy,
                  ),
                ],
              ),
            ),
    );
  }
}

class _VipHeader extends StatelessWidget {
  const _VipHeader({required this.active, required this.onHelp});
  final int active;
  final VoidCallback onHelp;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFFA823DA), Color(0xFF600C88)]),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'عضوية VIP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        if (active > 0) _SmallPill(text: 'VIP $active'),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onHelp,
          child: const Icon(Icons.help_outline_rounded, color: Colors.white),
        ),
      ],
    ),
  );
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.profile,
    required this.active,
    required this.coins,
    required this.icon,
  });
  final Map<String, dynamic> profile;
  final int active;
  final int coins;
  final String? icon;
  @override
  Widget build(BuildContext context) {
    final name = profile['display_name'] ?? profile['username'] ?? 'عضو SAKI';
    final avatar = profile['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_gold, _violet]),
                ),
                child: ClipOval(
                  child: avatar == null
                      ? const ColoredBox(
                          color: Color(0xFFF2E7F8),
                          child: Icon(Icons.person, color: _purple, size: 34),
                        )
                      : Image.network(
                          avatar,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person, color: _purple),
                        ),
                ),
              ),
              if (icon != null)
                Positioned(
                  bottom: -8,
                  right: -8,
                  child: Container(
                    width: 38,
                    height: 30,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Color(0x22000000), blurRadius: 8),
                      ],
                    ),
                    child: Image.network(icon!, fit: BoxFit.contain),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toString(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  active > 0
                      ? 'عضويتك الحالية VIP $active'
                      : 'ابدأ عضويتك المميزة الآن',
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _MiniStat(
                      label: 'المستوى',
                      value: active > 0 ? 'VIP $active' : '—',
                    ),
                    const SizedBox(width: 18),
                    _MiniStat(
                      label: 'العملات',
                      value: coins >= 1000
                          ? '${(coins / 1000).toStringAsFixed(0)}K'
                          : '$coins',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10)),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.caption});
  final String title, caption;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 22, 16, 11),
    child: Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(caption, style: const TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
        const Spacer(),
        const Icon(Icons.arrow_forward_ios_rounded, color: _muted, size: 13),
      ],
    ),
  );
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({
    required this.level,
    required this.selected,
    required this.coins,
    required this.onTap,
  });
  final int level, coins;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final progress = (coins / _VipPageState._required[level - 1]).clamp(
      0.0,
      1.0,
    );
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 178,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: selected
                ? [const Color(0xFFA823DA), const Color(0xFF600C88)]
                : [const Color(0xFF33223E), const Color(0xFF201A2B)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _gold : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? _purple.withValues(alpha: .25) : Colors.black12,
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.network(
                  _VipPageState._icons[level - 1],
                  width: 74,
                  height: 45,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                Text(
                  'VIP $level',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${_VipPageState._prices[level]} عملة ذهبية',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.white24,
                color: _gold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'لمدة 30 يومًا',
              style: TextStyle(
                color: Colors.white.withValues(alpha: .72),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.title,
    required this.level,
    required this.enabled,
    required this.icon,
  });
  final String title;
  final int level;
  final bool enabled;
  final IconData icon;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: enabled
                ? const LinearGradient(colors: [_violet, _purple])
                : null,
            color: enabled ? null : const Color(0xFFE9E4ED),
          ),
          child: Icon(
            enabled ? icon : Icons.lock_outline_rounded,
            color: enabled ? Colors.white : _muted,
            size: 23,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'VIP $level\n$title',
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: enabled ? _ink : _muted,
            fontSize: 9,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({
    required this.level,
    required this.price,
    required this.working,
    required this.onBuy,
  });
  final int level, price;
  final bool working;
  final VoidCallback onBuy;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x18000000),
          blurRadius: 16,
          offset: Offset(0, -5),
        ),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'VIP $level',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$price عملة ذهبية',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: working ? null : onBuy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 13),
              decoration: BoxDecoration(
                gradient: working
                    ? null
                    : const LinearGradient(colors: [_gold, Color(0xFFFF8F00)]),
                color: working ? Colors.black12 : null,
                borderRadius: BorderRadius.circular(15),
              ),
              child: working
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'شراء VIP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PurchaseDialog extends StatelessWidget {
  const _PurchaseDialog({
    required this.level,
    required this.price,
    required this.icon,
  });
  final int level, price;
  final String icon;

  @override
  Widget build(BuildContext context) => Container(
    width: MediaQuery.sizeOf(context).width * .82,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 24)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 60,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF7E9FC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.network(icon, fit: BoxFit.contain),
        ),
        const SizedBox(height: 12),
        Text(
          'تفعيل VIP $level',
          style: const TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'هل تريد شراء VIP $level لمدة 30 يومًا؟',
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Text(
          '$price عملة ذهبية',
          style: const TextStyle(color: _purple, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Text(
                    'إلغاء',
                    style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gold, Color(0xFFFF8F00)],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(13)),
                  ),
                  child: const Text(
                    'تأكيد الشراء',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
