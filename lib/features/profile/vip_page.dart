import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import 'vip_widgets.dart';

class VipPage extends StatefulWidget {
  const VipPage({super.key});
  @override
  State<VipPage> createState() => _VipPageState();
}

class _VipPageState extends State<VipPage> {
  static const prices = <int, int>{
    1: 60000,
    2: 200000,
    3: 500000,
    4: 1000000,
    5: 2000000,
    6: 4000000,
    7: 8000000,
  };
  static const badges = <String>[
    'https://i.top4top.io/p_39027a3a40.png',
    'https://g.top4top.io/p_39020jo2e1.png',
    'https://f.top4top.io/p_39028t7ba0.png',
    'https://h.top4top.io/p_3902xn2xq0.png',
    'https://k.top4top.io/p_3902ysy8o0.png',
    'https://c.top4top.io/p_3902j4t7t0.png',
    'https://e.top4top.io/p_390251hsl0.png',
  ];
  static const benefits = <VipBenefit>[
    VipBenefit(Icons.verified_rounded, 'شارة VIP', 1),
    VipBenefit(Icons.card_giftcard_rounded, 'هدية VIP', 1),
    VipBenefit(Icons.auto_awesome_rounded, 'مقعد VIP', 2),
    VipBenefit(Icons.directions_walk_rounded, 'مكافحة ركلة', 3),
    VipBenefit(Icons.shield_rounded, 'مكافحة الأسود', 4),
    VipBenefit(Icons.badge_rounded, 'اسم التدرج اللوني', 5),
  ];
  final _service = SakiService.instance;
  final _pages = PageController();
  Map<String, dynamic> _profile = {}, _account = {};
  int _selected = 1;
  bool _loading = true, _working = false;

  int get _active {
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

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _service.myProfile() ?? <String, dynamic>{};
      Map<String, dynamic> account = {};
      // بيانات الملف هي الأساس لعرض VIP. تعطل وحدة الحساب لا يجب أن يمنع
      // فتح الصفحة، خصوصًا للمستخدمين الذين لم يُنشأ لهم سجل الحساب بعد.
      try {
        account = await _service.accountModules();
      } catch (_) {
        account = {};
      }
      if (!mounted) return;
      final expiry = DateTime.tryParse(
        profile['vip_expires_at']?.toString() ?? '',
      );
      final active = expiry != null && expiry.isAfter(DateTime.now())
          ? (profile['vip_level'] as num?)?.toInt() ?? 0
          : 0;
      setState(() {
        _profile = profile;
        _account = account;
        _selected = active.clamp(1, 7);
        _loading = false;
      });
      _pages.jumpToPage(_selected - 1);
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _toast('تعذر تحميل بيانات VIP');
      }
    }
  }

  String _format(int value) => value >= 1000000
      ? '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M'
      : value >= 1000
      ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K'
      : '$value';
  Future<void> _buy() async {
    final active = _active,
        price = prices[_selected]!,
        balance = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    if (active > _selected) {
      return _toast('لا يمكنك شراء مستوى أقل من VIP $active');
    }
    if (balance < price) return _toast('رصيد العملات الذهبية غير كافٍ');
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('تفعيل VIP $_selected'),
            content: Text(
              'سيتم خصم ${_format(price)} عملة ذهبية لمدة 30 يومًا.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تأكيد'),
              ),
            ],
          ),
        ) ??
        false;
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

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final active = _active,
        coins = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    if (_loading) {
      return const Scaffold(
        backgroundColor: VipDesign.bg,
        body: Center(child: CircularProgressIndicator(color: VipDesign.gold)),
      );
    }
    return Scaffold(
      backgroundColor: VipDesign.bg,
      body: SafeArea(
        child: Column(
          children: [
            VipTabBar(
              selected: _selected,
              active: active,
              onSelected: (level) {
                setState(() => _selected = level);
                _pages.animateToPage(
                  level - 1,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: 7,
                onPageChanged: (i) => setState(() => _selected = i + 1),
                itemBuilder: (_, index) => RefreshIndicator(
                  color: VipDesign.gold,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                    children: [
                      VipBadgeHero(level: index + 1, imageUrl: badges[index]),
                      VipStatusBanner(level: index + 1, active: active),
                      VipSectionTitle(title: 'تعريف'),
                      const VipDefinitionGrid(),
                      VipSectionTitle(title: 'امتيازات حصرية'),
                      VipPrivilegesGrid(
                        selectedLevel: index + 1,
                        benefits: benefits,
                      ),
                      const VipOrnament(),
                      VipPurchaseCard(
                        level: index + 1,
                        price: prices[index + 1]!,
                        coins: coins,
                        active: active,
                        working: _working && _selected == index + 1,
                        onBuy: () {
                          setState(() => _selected = index + 1);
                          _buy();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
