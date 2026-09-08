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
    8: 10000000,
    9: 12000000,
    10: 20000000,
  };
  static const benefits = <VipBenefit>[
    VipBenefit(Icons.directions_walk_rounded, 'مؤثر دخول', 1),
    VipBenefit(Icons.crop_rounded, 'إطار خاص', 1),
    VipBenefit(Icons.card_giftcard_rounded, 'صندوق أسبوعي', 1),
    VipBenefit(Icons.comment_rounded, 'فقاعة دردشة', 2),
    VipBenefit(Icons.auto_delete_rounded, 'مسح الدردشة', 2),
    VipBenefit(Icons.send_rounded, 'رسائل طائرة', 3),
    VipBenefit(Icons.person_rounded, 'صورة متحركة', 4),
    VipBenefit(Icons.do_not_disturb_on_rounded, 'منع الإزعاج', 5),
    VipBenefit(Icons.public_rounded, 'إعلان عالمي', 6),
    VipBenefit(Icons.block_rounded, 'حظر الغرباء', 7),
    VipBenefit(Icons.admin_panel_settings_rounded, 'منع الطرد', 8),
    VipBenefit(Icons.push_pin_rounded, 'تثبيت الغرفة', 9),
    VipBenefit(Icons.note_alt_rounded, 'بطاقة منشور', 10),
    VipBenefit(Icons.workspace_premium_rounded, 'إشراف خارق', 10),
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
    return expiry != null && expiry.isAfter(DateTime.now())
        ? level.clamp(0, 10)
        : 0;
  }

  DateTime? get _expiry =>
      DateTime.tryParse(_profile['vip_expires_at']?.toString() ?? '');

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
      try {
        account = await _service.accountModules();
      } catch (_) {}
      if (!mounted) return;
      final level = (_activeFrom(profile));
      setState(() {
        _profile = profile;
        _account = account;
        _selected = level > 0 ? level : 1;
        _loading = false;
      });
      if (_pages.hasClients) _pages.jumpToPage(_selected - 1);
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _toast('تعذر تحميل بيانات VIP');
      }
    }
  }

  int _activeFrom(Map<String, dynamic> profile) {
    final expiry = DateTime.tryParse(
      profile['vip_expires_at']?.toString() ?? '',
    );
    return expiry != null && expiry.isAfter(DateTime.now())
        ? ((_profile['vip_level'] as num?)?.toInt() ??
                  (profile['vip_level'] as num?)?.toInt() ??
                  0)
              .clamp(1, 10)
        : 0;
  }

  Future<void> _buy() async {
    final active = _active;
    final price = prices[_selected]!;
    final balance = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    if (active > _selected) {
      _toast('لا يمكنك شراء مستوى أقل من VIP $active');
      return;
    }
    if (balance < price) {
      _toast('رصيد العملات الذهبية غير كافٍ');
      return;
    }
    final color = vipLevelColors[_selected]!;
    final confirm =
        await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (sheet) => Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: const BoxDecoration(
              color: VipDesign.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'تفعيل VIP $_selected',
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم خصم ${formatVipPrice(price)} عملة ذهبية لمدة 30 يومًا.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: VipDesign.muted),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _VipActionButton(
                        label: 'إلغاء',
                        color: Colors.white12,
                        onTap: () => Navigator.pop(sheet, false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _VipActionButton(
                        label: 'تأكيد الشراء',
                        color: color,
                        dark: true,
                        onTap: () => Navigator.pop(sheet, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirm || !mounted) return;
    setState(() => _working = true);
    try {
      await _service.purchaseVip(_selected);
      await _load();
      if (mounted) _toast('تم تفعيل VIP $_selected لمدة 30 يومًا');
    } catch (error) {
      if (mounted) _toast('تعذر تنفيذ شراء VIP: $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final coins = (_account['gold_coins'] as num?)?.toInt() ?? 0;
    if (_loading)
      return const Scaffold(
        backgroundColor: VipDesign.bg,
        body: Center(child: CircularProgressIndicator(color: VipDesign.gold)),
      );
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
                itemCount: 10,
                onPageChanged: (i) => setState(() => _selected = i + 1),
                itemBuilder: (_, index) {
                  final level = index + 1;
                  final color = vipLevelColors[level]!;
                  return RefreshIndicator(
                    color: color,
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                      children: [
                        VipBadgeHero(level: level),
                        VipStatusBanner(
                          level: level,
                          active: active,
                          expiry: _expiry,
                        ),
                        VipSectionTitle(
                          title: 'المزايا والخصائص',
                          color: color,
                        ),
                        VipPrivilegesGrid(
                          selectedLevel: level,
                          benefits: benefits,
                          color: color,
                        ),
                        const SizedBox(height: 22),
                        VipPurchaseCard(
                          level: level,
                          price: prices[level]!,
                          coins: coins,
                          active: active,
                          working: _working && _selected == level,
                          onBuy: () {
                            setState(() => _selected = level);
                            _buy();
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VipActionButton extends StatelessWidget {
  const _VipActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.dark = false,
  });
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool dark;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: dark ? Colors.black : Colors.white,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}
