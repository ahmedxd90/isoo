import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import 'vip_widgets.dart';

import '../../shared/widgets/custom_toast.dart';

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
    11: 500000000,
  };
  static const benefits = <VipBenefit>[
    VipBenefit(Icons.crop_rounded, 'إطار وصورة VIP', 1),
    VipBenefit(Icons.directions_walk_rounded, 'دخول VIP متحرك', 1),
    VipBenefit(Icons.gradient_rounded, 'اسم ملون متحرك', 2),
    VipBenefit(Icons.badge_rounded, 'بطاقة ملف VIP', 3),
    VipBenefit(Icons.auto_awesome_rounded, 'مؤثر دخول متقدم', 4),
    VipBenefit(Icons.wallpaper_rounded, 'خلفية غرفة مخصصة', 5),
    VipBenefit(Icons.perm_identity_rounded, 'SAKI ID متدرج', 6),
    VipBenefit(Icons.gif_box_rounded, 'صورة GIF للملف', 7),
    VipBenefit(Icons.graphic_eq_rounded, 'موجة صوت VIP8', 8),
    VipBenefit(Icons.workspace_premium_rounded, 'شارة VIP9 وVIP10', 9),
    VipBenefit(Icons.workspace_premium_rounded, 'شارة وإطار ملكي VIP11', 11),
    VipBenefit(Icons.color_lens_rounded, 'اسم VIP11 بتدرج حصري', 11),
    VipBenefit(Icons.auto_awesome_rounded, 'دخول VIP11 ملكي', 11),
  ];

  final _service = SakiService.instance;
  final _pages = PageController();
  Map<String, dynamic> _profile = {}, _account = {};
  int _selected = 1;
  bool _loading = true, _working = false;
  Map<String, dynamic> _privacy = {};

  int get _active {
    final level = (_profile['vip_level'] as num?)?.toInt() ?? 0;
    final expiry = DateTime.tryParse(
      _profile['vip_expires_at']?.toString() ?? '',
    );
    return expiry != null && expiry.isAfter(DateTime.now())
        ? level.clamp(0, 11)
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
      Map<String, dynamic> privacy = {};
      try {
        account = await _service.accountModules();
        privacy = await _service.profilePrivacySettings();
      } catch (_) {}
      if (!mounted) return;
      final level = (_activeFrom(profile));
      setState(() {
        _profile = profile;
        _account = account;
        _privacy = privacy;
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
        ? ((profile['vip_level'] as num?)?.toInt() ?? 0).clamp(1, 11)
        : 0;
  }

  Future<void> _togglePrivacy(String setting, bool enabled) async {
    final previous = _privacy[setting] == true;
    setState(() => _privacy = {..._privacy, setting: enabled});
    try {
      final updated = await _service.setProfilePrivacySetting(setting, enabled);
      if (mounted && updated.isNotEmpty) setState(() => _privacy = updated);
      if (mounted) _toast(enabled ? 'تم تفعيل الميزة' : 'تم تعطيل الميزة');
    } catch (error) {
      if (mounted) setState(() => _privacy = {..._privacy, setting: previous});
      if (mounted) {
        final text = error.toString().contains('vip_level_required')
            ? 'هذه الميزة تحتاج إلى مستوى VIP أعلى'
            : 'تعذر تحديث الميزة';
        _toast(text);
      }
    }
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

  void _toast(String text) => CustomToast.show(context, text);

  @override
  Widget build(BuildContext context) {
    final active = _active;
    final coins = (_account['gold_coins'] as num?)?.toInt() ?? 0;
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
                itemCount: 11,
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
                          activeLevel: active,
                          benefits: benefits,
                          color: color,
                        ),
                        const SizedBox(height: 18),
                        _VipPrivacyCard(
                          activeLevel: active,
                          values: _privacy,
                          working: _working,
                          onChanged: _togglePrivacy,
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: VipStickyPurchaseBar(
          level: _selected,
          price: prices[_selected]!,
          coins: coins,
          active: active,
          working: _working,
          onBuy: _buy,
        ),
      ),
    );
  }
}

class _VipPrivacyCard extends StatelessWidget {
  const _VipPrivacyCard({
    required this.activeLevel,
    required this.values,
    required this.working,
    required this.onChanged,
  });
  final int activeLevel;
  final Map<String, dynamic> values;
  final bool working;
  final Future<void> Function(String, bool) onChanged;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 15, 14, 8),
    decoration: BoxDecoration(
      color: VipDesign.panel,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'خصوصية VIP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'تُحفظ الإعدادات في حسابك وتُرفض التغييرات غير المسموحة من الخادم.',
          style: TextStyle(color: VipDesign.muted, fontSize: 10),
        ),
        const SizedBox(height: 8),
        _VipPrivacyRow(
          icon: Icons.circle_outlined,
          title: 'إخفاء حالة متصل الآن',
          requiredLevel: 4,
          enabled: values['hide_online'] == true,
          activeLevel: activeLevel,
          onChanged: (v) => onChanged('hide_online', v),
        ),
        _VipPrivacyRow(
          icon: Icons.flag_outlined,
          title: 'إخفاء علم الدولة',
          requiredLevel: 5,
          enabled: values['hide_country'] == true,
          activeLevel: activeLevel,
          onChanged: (v) => onChanged('hide_country', v),
        ),
        _VipPrivacyRow(
          icon: Icons.gif_box_outlined,
          title: 'الصورة المتحركة للملف',
          requiredLevel: 8,
          enabled: values['animated_avatar_enabled'] == true,
          activeLevel: activeLevel,
          onChanged: (v) => onChanged('animated_avatar_enabled', v),
        ),
        _VipPrivacyRow(
          icon: Icons.visibility_off_outlined,
          title: 'الهوية المخفية بالكامل',
          requiredLevel: 11,
          enabled: values['identity_hidden'] == true,
          activeLevel: activeLevel,
          onChanged: (v) => onChanged('identity_hidden', v),
        ),
        if (working)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2, color: VipDesign.gold),
          ),
      ],
    ),
  );
}

class _VipPrivacyRow extends StatelessWidget {
  const _VipPrivacyRow({
    required this.icon,
    required this.title,
    required this.requiredLevel,
    required this.enabled,
    required this.activeLevel,
    required this.onChanged,
  });
  final IconData icon;
  final String title;
  final int requiredLevel;
  final bool enabled;
  final int activeLevel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final unlocked = activeLevel >= requiredLevel;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: unlocked ? VipDesign.gold : VipDesign.muted),
      title: Text(
        title,
        style: TextStyle(
          color: unlocked ? Colors.white : VipDesign.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        unlocked ? 'متاح الآن' : 'يتطلب VIP $requiredLevel',
        style: const TextStyle(color: VipDesign.muted, fontSize: 10),
      ),
      trailing: Switch.adaptive(
        value: unlocked && enabled,
        onChanged: unlocked ? onChanged : null,
        activeThumbColor: VipDesign.gold,
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
