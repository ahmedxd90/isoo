import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';
import 'wallet_page.dart';
import 'vip_page.dart';
import 'super_admin_page.dart';
import 'store_pages.dart';
import 'trace_profile_features_page.dart';
import 'family_square_page.dart';
import '../../shared/widgets/saki_widgets.dart';

const _orange = Color(0xFFF97316);
const _orangeSoft = Color(0xFFFFF7ED);
const _cyan = Color(0xFF06B6D4);
const _cyanSoft = Color(0xFFECFEFF);
const _ink = Color(0xFF1F2937);
const _muted = Color(0xFF9CA3AF);
const _line = Color(0xFFF0F1F5);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  Map<String, int> _stats = {};
  Map<String, dynamic> _modules = {};
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _reels = [];
  int _tab = 0;
  bool _loading = true;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        SakiService.instance.myProfile(),
        SakiService.instance.profileStats(),
        SakiService.instance.userPosts(SakiService.instance.uid),
        SakiService.instance.userReels(SakiService.instance.uid),
        SakiService.instance.accountModules(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _stats = results[1] as Map<String, int>;
        _posts = List<Map<String, dynamic>>.from(results[2] as List);
        _reels = List<Map<String, dynamic>>.from(results[3] as List);
        _modules = Map<String, dynamic>.from(results[4] as Map);
      });
      final isSuperAdmin = await SakiService.instance.isSuperAdmin();
      if (mounted) setState(() => _isSuperAdmin = isSuperAdmin);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحميل بيانات الملف من Supabase')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EditProfileSheet(profile: _profile ?? {}),
    );
    if (updated == true) _load();
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  Future<void> _openModule(String type) async {
    if (type == 'store') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const StorePage()));
      if (mounted) _load();
      return;
    }
    if (type == 'family') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const FamilySquarePage()));
      if (mounted) _load();
      return;
    }
    if (type == 'agency' || type == 'level') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TraceProfileFeaturesPage(feature: type),
        ),
      );
      if (mounted) _load();
      return;
    }
    if (type == 'vip') {
      final changed = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => const VipPage()));
      if (changed == true) _load();
      return;
    }
    if (type == 'wallet') {
      final changed = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => const WalletPage()));
      if (changed == true) _load();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ModuleSheet(type: type, modules: _modules),
    );
  }

  Future<void> _openMenu(String title) async {
    if (title == 'المستوى') {
      await _openModule('level');
      return;
    }
    if (title == 'العائلة') {
      await _openModule('family');
      return;
    }
    if (title == 'لوحة تحكم سوبر أدمن') {
      try {
        if (await SakiService.instance.isSuperAdmin() && mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SuperAdminPage()),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('هذه الصفحة متاحة للسوبر أدمن فقط')),
          );
        }
      } catch (_) {}
      return;
    }
    if (title == 'الإعدادات') {
      final changed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => SettingsSheet(modules: _modules),
      );
      if (changed == true) _load();
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MenuActionSheet(title: title, modules: _modules),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _ProfileLoading();
    final profile = _profile ?? {};
    final username = profile['username'] as String? ?? 'مستخدم SAKI';
    final vipExpires = DateTime.tryParse(
      profile['vip_expires_at']?.toString() ?? '',
    );
    final storedVipLevel = (profile['vip_level'] as num? ?? 0).toInt();
    final vipLevel =
        storedVipLevel > 0 &&
            vipExpires != null &&
            vipExpires.isAfter(DateTime.now())
        ? storedVipLevel
        : 0;
    final wealthLevel = (_modules['wealth_level'] as num? ?? 0).toInt();
    final charmLevel = (_modules['charm_level'] as num? ?? 0).toInt();
    final followers = _stats['followers'] ?? 0;
    final following = _stats['following'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _ProfileHero(
              profile: profile,
              username: username,
              vipLevel: vipLevel,
              wealthLevel: wealthLevel,
              charmLevel: charmLevel,
              followers: followers,
              following: following,
              onBack: () {
                if (Navigator.canPop(context)) Navigator.pop(context);
              },
              onEdit: _edit,
              onCopyId: () {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('تم نسخ SAKI ID')));
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 120),
              child: Column(
                children: [
                  _ProfileQuickActions(
                    onWallet: () => _openModule('wallet'),
                    onVip: () => _openModule('vip'),
                    onStore: () => _openModule('store'),
                  ),
                  const SizedBox(height: 16),
                  _CustomProfileTabs(
                    selected: _tab,
                    onChanged: (value) => setState(() => _tab = value),
                  ),
                  const SizedBox(height: 14),
                  _CustomProfileContent(
                    tab: _tab,
                    posts: _posts,
                    reels: _reels,
                    profile: profile,
                    modules: _modules,
                  ),
                  const SizedBox(height: 16),
                  _ProfileMenuStrip(
                    onTap: _openMenu,
                    isSuperAdmin: _isSuperAdmin,
                    onLogout: _logout,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();
  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFF3F5FA),
    child: Center(child: CircularProgressIndicator(color: _orange)),
  );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.username,
    required this.vipLevel,
    required this.wealthLevel,
    required this.charmLevel,
    required this.followers,
    required this.following,
    required this.onBack,
    required this.onEdit,
    required this.onCopyId,
  });
  final Map<String, dynamic> profile;
  final String username;
  final int vipLevel;
  final int wealthLevel;
  final int charmLevel;
  final int followers;
  final int following;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final VoidCallback onCopyId;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Container(
        height: 285,
        padding: const EdgeInsets.fromLTRB(16, 42, 16, 0),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF0F172A), Color(0xFF312E81), Color(0xFFD97706)],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _ProfilePatternPainter()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HeroIcon(icon: FontAwesomeIcons.arrowRight, onTap: onBack),
                const Text(
                  'SAKI PROFILE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                  ),
                ),
                _HeroIcon(icon: FontAwesomeIcons.penToSquare, onTap: onEdit),
              ],
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 20,
              child: Column(
                children: [
                  Container(
                    width: 94,
                    height: 94,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFC94A),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .28),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _AvatarImage(
                        url: profile['avatar_url'] as String?,
                        label: username,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onCopyId,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.copy_rounded,
                            color: Color(0xFFFFD166),
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'SAKI ID  ${profile['saki_id'] ?? '—'}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      Positioned(
        bottom: -45,
        right: 14,
        left: 14,
        child: _ProfileStatsCard(
          vipLevel: vipLevel,
          wealthLevel: wealthLevel,
          charmLevel: charmLevel,
          followers: followers,
          following: following,
        ),
      ),
    ],
  );
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon, required this.onTap});
  final FaIconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: FaIcon(icon, color: Colors.white, size: 14),
    ),
  );
}

class _ProfileStatsCard extends StatelessWidget {
  const _ProfileStatsCard({
    required this.vipLevel,
    required this.wealthLevel,
    required this.charmLevel,
    required this.followers,
    required this.following,
  });
  final int vipLevel;
  final int wealthLevel;
  final int charmLevel;
  final int followers;
  final int following;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x180F172A),
          blurRadius: 22,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        _StatCell(value: '$followers', label: 'متابعون'),
        _StatDivider(),
        _StatCell(value: '$following', label: 'متابعة'),
        _StatDivider(),
        _StatCell(value: 'VIP $vipLevel', label: 'العضوية', accent: _orange),
        _StatDivider(),
        _StatCell(
          value: 'LV $wealthLevel',
          label: 'الثروة',
          accent: const Color(0xFF16A34A),
        ),
      ],
    ),
  );
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, this.accent});
  final String value;
  final String label;
  final Color? accent;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: accent ?? _ink,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: _line);
}

class _ProfileQuickActions extends StatelessWidget {
  const _ProfileQuickActions({
    required this.onWallet,
    required this.onVip,
    required this.onStore,
  });
  final VoidCallback onWallet;
  final VoidCallback onVip;
  final VoidCallback onStore;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      _QuickAction(
        icon: FontAwesomeIcons.wallet,
        label: 'المحفظة',
        color: _orange,
        onTap: onWallet,
      ),
      const SizedBox(width: 8),
      _QuickAction(
        icon: FontAwesomeIcons.crown,
        label: 'عضوية VIP',
        color: const Color(0xFFD97706),
        onTap: onVip,
      ),
      const SizedBox(width: 8),
      _QuickAction(
        icon: FontAwesomeIcons.store,
        label: 'المتجر',
        color: const Color(0xFF2563EB),
        onTap: onStore,
      ),
    ],
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final FaIconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _line),
        ),
        child: Column(
          children: [
            FaIcon(icon, color: color, size: 16),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CustomProfileTabs extends StatelessWidget {
  const _CustomProfileTabs({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;
  static const labels = ['اللحظات', 'الأوسمة', 'الملف الشخصي', 'الهدايا'];
  @override
  Widget build(BuildContext context) => Container(
    height: 49,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFFE8EBF3),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == i ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selected == i
                      ? const [
                          BoxShadow(color: Color(0x120F172A), blurRadius: 8),
                        ]
                      : null,
                ),
                child: Text(
                  labels[i],
                  style: TextStyle(
                    color: selected == i ? _orange : _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CustomProfileContent extends StatelessWidget {
  const _CustomProfileContent({
    required this.tab,
    required this.posts,
    required this.reels,
    required this.profile,
    required this.modules,
  });
  final int tab;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> reels;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> modules;
  @override
  Widget build(BuildContext context) {
    if (tab == 0) return _ProfileGrid(posts: posts, reels: reels, tab: 2);
    if (tab == 1)
      return _BadgesPanel(
        vipLevel: (profile['vip_level'] as num? ?? 0).toInt(),
      );
    if (tab == 2) return _IdentityPanel(profile: profile, modules: modules);
    return const _EmptyProfilePanel(
      icon: FontAwesomeIcons.gift,
      title: 'لا توجد هدايا بعد',
      caption: 'ستظهر الهدايا المرسلة إلى هذا الحساب هنا.',
    );
  }
}

class _BadgesPanel extends StatelessWidget {
  const _BadgesPanel({required this.vipLevel});
  final int vipLevel;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
    title: 'الأوسمة والإنجازات',
    icon: FontAwesomeIcons.medal,
    child: Wrap(
      spacing: 9,
      runSpacing: 9,
      children: [
        _BadgeTile(
          icon: FontAwesomeIcons.crown,
          title: 'VIP $vipLevel',
          color: const Color(0xFFD97706),
        ),
        _BadgeTile(
          icon: FontAwesomeIcons.gem,
          title: 'مميز',
          color: const Color(0xFF2563EB),
        ),
        _BadgeTile(icon: FontAwesomeIcons.bolt, title: 'نشط', color: _orange),
      ],
    ),
  );
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.icon,
    required this.title,
    required this.color,
  });
  final FaIconData icon;
  final String title;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 92,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: .22)),
    ),
    child: Column(
      children: [
        FaIcon(icon, color: color, size: 22),
        const SizedBox(height: 7),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel({required this.profile, required this.modules});
  final Map<String, dynamic> profile;
  final Map<String, dynamic> modules;
  @override
  Widget build(BuildContext context) => _ProfilePanel(
    title: 'بيانات الحساب',
    icon: FontAwesomeIcons.idCard,
    child: Column(
      children: [
        _IdentityRow(
          icon: FontAwesomeIcons.locationDot,
          label: 'الدولة',
          value: profile['country']?.toString() ?? 'غير محدد',
        ),
        _IdentityRow(
          icon: FontAwesomeIcons.signature,
          label: 'النبذة',
          value: profile['bio']?.toString().isNotEmpty == true
              ? profile['bio'].toString()
              : 'لم تتم إضافة نبذة بعد',
        ),
        _IdentityRow(
          icon: FontAwesomeIcons.coins,
          label: 'العملات',
          value:
              '${modules['gold_coins'] ?? 0} ذهب  •  ${modules['diamonds'] ?? 0} ألماس',
        ),
      ],
    ),
  );
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final FaIconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        FaIcon(icon, color: _orange, size: 14),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProfilePanel extends StatelessWidget {
  const _ProfilePanel({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final FaIconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080F172A),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, color: _orange, size: 15),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        child,
      ],
    ),
  );
}

class _EmptyProfilePanel extends StatelessWidget {
  const _EmptyProfilePanel({
    required this.icon,
    required this.title,
    required this.caption,
  });
  final FaIconData icon;
  final String title;
  final String caption;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _line),
    ),
    child: Column(
      children: [
        FaIcon(icon, color: _muted, size: 28),
        const SizedBox(height: 11),
        Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          caption,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, fontSize: 10, height: 1.5),
        ),
      ],
    ),
  );
}

class _ProfileMenuStrip extends StatelessWidget {
  const _ProfileMenuStrip({
    required this.onTap,
    required this.isSuperAdmin,
    required this.onLogout,
  });
  final Future<void> Function(String) onTap;
  final bool isSuperAdmin;
  final Future<void> Function() onLogout;
  @override
  Widget build(BuildContext context) {
    final items = <(String, FaIconData)>[
      ('المستوى', FontAwesomeIcons.chartLine),
      ('المهام', FontAwesomeIcons.listCheck),
      ('العائلة', FontAwesomeIcons.peopleGroup),
      ('الإعدادات', FontAwesomeIcons.gear),
    ];
    if (isSuperAdmin)
      items.add(('لوحة تحكم سوبر أدمن', FontAwesomeIcons.userGear));
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                GestureDetector(
                  onTap: () => onTap(items[i].$1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    child: Row(
                      children: [
                        FaIcon(items[i].$2, color: _orange, size: 14),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            items[i].$1,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const FaIcon(
                          FontAwesomeIcons.chevronLeft,
                          color: _muted,
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onLogout,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFFECACA)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.rightFromBracket,
                  color: Color(0xFFE11D48),
                  size: 13,
                ),
                SizedBox(width: 8),
                Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfilePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width + size.height; x += 22) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.username,
    required this.vipLevel,
    required this.wealthLevel,
    required this.charmLevel,
    required this.followers,
  });
  final Map<String, dynamic> profile;
  final String username;
  final int vipLevel;
  final int wealthLevel;
  final int charmLevel;
  final int followers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 68,
                height: 68,
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_orange, Color(0xFFEC4899)],
                  ),
                ),
                child: ClipOval(
                  child: _AvatarImage(
                    url: profile['avatar_url'] as String?,
                    label: username,
                  ),
                ),
              ),
              Positioned(
                bottom: -1,
                right: -1,
                child: Container(
                  width: 23,
                  height: 23,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.crown,
                    size: 10,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VipUsername(
                  profile: profile,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${profile['saki_id'] ?? '—'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (vipLevel > 0)
                      Container(
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: Image.asset(
                          'assets/trace_vip/images/ic_vip_$vipLevel.png',
                          width: 66,
                          fit: BoxFit.contain,
                        ),
                      ),
                    _LevelChip(
                      label: 'ثروة LV $wealthLevel',
                      color: const Color(0xFF22C55E),
                    ),
                    _LevelChip(
                      label: 'سحر LV $charmLevel',
                      color: const Color(0xFFA855F7),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$followers متابع',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
    ),
  );
}

class _AvatarImage extends StatelessWidget {
  const _AvatarImage({required this.url, required this.label});
  final String? url;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty)
      return Container(
        color: _orangeSoft,
        alignment: Alignment.center,
        child: Text(
          label.characters.first.toUpperCase(),
          style: const TextStyle(
            color: _orange,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: _orangeSoft,
        alignment: Alignment.center,
        child: Text(
          label.characters.first.toUpperCase(),
          style: const TextStyle(
            color: _orange,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });
  final FaIconData icon;
  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.background,
    required this.onTap,
  });
  final FaIconData icon;
  final String label;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _line),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: FaIcon(icon, size: 16, color: color)),
              ),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.onTap, required this.isSuperAdmin});
  final Future<void> Function(String) onTap;
  final bool isSuperAdmin;

  @override
  Widget build(BuildContext context) {
    const rows = [
      (
        'المستوى',
        FontAwesomeIcons.chartLine,
        Color(0xFFDC2626),
        Color(0xFFFEF2F2),
      ),
      (
        'المهام',
        FontAwesomeIcons.listCheck,
        Color(0xFF16A34A),
        Color(0xFFF0FDF4),
      ),
      (
        'العائلة',
        FontAwesomeIcons.peopleGroup,
        Color(0xFF7C3AED),
        Color(0xFFF5F3FF),
      ),
      (
        'لوحة تحكم سوبر أدمن',
        FontAwesomeIcons.userGear,
        Color(0xFF4F46E5),
        Color(0xFFEEF2FF),
      ),
      ('كود الاسترداد', FontAwesomeIcons.ticket, _cyan, _cyanSoft),
      (
        'الإعدادات',
        FontAwesomeIcons.gear,
        Color(0xFF4B5563),
        Color(0xFFF3F4F6),
      ),
    ];
    final visibleRows = rows
        .where((row) => row.$1 != 'لوحة تحكم سوبر أدمن' || isSuperAdmin)
        .toList();
    final children = <Widget>[];
    for (var i = 0; i < visibleRows.length; i++) {
      final row = visibleRows[i];
      children.add(
        InkWell(
          onTap: () => onTap(row.$1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: row.$4,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(child: FaIcon(row.$2, size: 14, color: row.$3)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.$1,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                ),
                const FaIcon(
                  FontAwesomeIcons.chevronLeft,
                  size: 11,
                  color: Color(0xFFD1D5DB),
                ),
              ],
            ),
          ),
        ),
      );
      if (i != rows.length - 1)
        children.add(const Divider(height: 1, color: _line));
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _orangeSoft,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: selected ? _orange : _muted,
      ),
      side: BorderSide(
        color: selected ? _orange.withValues(alpha: .25) : _line,
      ),
    ),
  );
}

class _ProfileGrid extends StatelessWidget {
  const _ProfileGrid({
    required this.posts,
    required this.reels,
    required this.tab,
  });
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> reels;
  final int tab;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    if (tab == 0 || tab == 2) {
      for (final post in posts) {
        final media = List<Map<String, dynamic>>.from(
          post['post_media'] ?? const [],
        );
        final path = media.isEmpty
            ? null
            : media.first['storage_path'] as String?;
        final url = path == null
            ? null
            : SakiService.instance.client.storage
                  .from('posts')
                  .getPublicUrl(path);
        tiles.add(_MediaTile(url: url, icon: FontAwesomeIcons.fileLines));
      }
    }
    if (tab == 1 || tab == 2) {
      for (final reel in reels)
        tiles.add(
          _MediaTile(
            url: reel['video_url'] as String?,
            icon: FontAwesomeIcons.play,
          ),
        );
    }
    if (tiles.isEmpty)
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: const Column(
          children: [
            FaIcon(FontAwesomeIcons.images, color: _muted, size: 24),
            SizedBox(height: 8),
            Text(
              'لا توجد وسائط بعد',
              style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
            ),
            SizedBox(height: 4),
            Text(
              'ستظهر منشوراتك وReels هنا.',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      );
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: .86,
      children: tiles,
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.url, required this.icon});
  final String? url;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url!.isNotEmpty)
          Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: _orangeSoft),
          )
        else
          const ColoredBox(color: _orangeSoft),
        Center(child: FaIcon(icon, color: _orange, size: 22)),
      ],
    ),
  );
}

class ModuleSheet extends StatelessWidget {
  const ModuleSheet({super.key, required this.type, required this.modules});
  final String type;
  final Map<String, dynamic> modules;

  @override
  Widget build(BuildContext context) {
    final data = switch (type) {
      'wallet' => (
        'المحفظة',
        FontAwesomeIcons.wallet,
        _orange,
        'الرصيد المتاح: ${modules['wallet_balance'] ?? 0} ${modules['wallet_currency'] ?? 'USD'}\nرصيد المتجر: ${modules['store_credit'] ?? 0}',
      ),
      'vip' => (
        'عضوية VIP',
        FontAwesomeIcons.crown,
        const Color(0xFFD97706),
        'مستوى VIP الحالي: ${modules['vip_level'] ?? 0}\n${modules['vip_label'] ?? 'عضو جديد'}',
      ),
      _ => (
        'المتجر',
        FontAwesomeIcons.store,
        const Color(0xFF2563EB),
        'رصيد المتجر: ${modules['store_credit'] ?? 0}\nلا توجد عمليات شراء مسجلة حاليًا.',
      ),
    };
    return _SheetShell(
      title: data.$1,
      icon: data.$2,
      color: data.$3,
      child: Text(
        data.$4,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ink,
          fontSize: 15,
          height: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MenuActionSheet extends StatelessWidget {
  const MenuActionSheet({
    super.key,
    required this.title,
    required this.modules,
  });
  final String title;
  final Map<String, dynamic> modules;

  @override
  Widget build(BuildContext context) {
    final copy = switch (title) {
      'المستوى' => 'المستوى الحالي مرتبط بتفاعلات الحساب في Supabase. لا توجد بيانات مستوى مسجلة بعد.',
      'المهام' => 'لا توجد مهام مكتملة مسجلة لهذا الحساب حاليًا.',
      'وكالة الشحن' => 'لا توجد وكالة شحن مرتبطة بالحساب حاليًا.',
      'لوحة تحكم سوبر أدمن' => 'صلاحيات الإدارة تتحقق من بيانات الحساب. الوصول غير متاح لهذا المستخدم حاليًا.',
      _ => 'أدخل كودًا صالحًا من لوحة الإدارة لاسترداد الرصيد.',
    };
    return _SheetShell(
      title: title,
      icon: FontAwesomeIcons.circleInfo,
      color: _cyan,
      child: Text(
        copy,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ink,
          fontSize: 14,
          height: 1.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key, required this.modules});
  final Map<String, dynamic> modules;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late bool _notifications;
  late bool _privacy;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final settings = Map<String, dynamic>.from(
      widget.modules['settings'] ?? const {},
    );
    _notifications = settings['notifications_enabled'] != false;
    _privacy = settings['private_profile'] == true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await SakiService.instance.updateAccountSettings({
      'notifications_enabled': _notifications,
      'private_profile': _privacy,
    });
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => _SheetShell(
    title: 'الإعدادات',
    icon: FontAwesomeIcons.gear,
    color: const Color(0xFF4B5563),
    child: Column(
      children: [
        SwitchListTile.adaptive(
          value: _notifications,
          onChanged: (value) => setState(() => _notifications = value),
          activeColor: _orange,
          title: const Text(
            'الإشعارات',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'حفظ الإعداد الحقيقي في Supabase',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        SwitchListTile.adaptive(
          value: _privacy,
          onChanged: (value) => setState(() => _privacy = value),
          activeColor: _cyan,
          title: const Text(
            'حساب خاص',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            'تطبيق الإعداد على الحساب عند توفر سياسة المتابعة',
            style: TextStyle(color: _muted, fontSize: 11),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _saving
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text(
                    'حفظ الإعدادات',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ],
    ),
  );
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });
  final String title;
  final FaIconData icon;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    padding: EdgeInsets.fromLTRB(
      20,
      14,
      20,
      MediaQuery.of(context).viewInsets.bottom + 24,
    ),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: _line,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(child: FaIcon(icon, color: color)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          child,
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final _username = TextEditingController(
    text: widget.profile['username'] as String? ?? '',
  );
  late final _bio = TextEditingController(
    text: widget.profile['bio'] as String? ?? '',
  );
  final _picker = ImagePicker();
  XFile? _avatar;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
    );
    if (image != null && mounted) setState(() => _avatar = image);
  }

  Future<void> _save() async {
    if (_username.text.trim().length < 3) {
      setState(() => _error = 'اسم المستخدم قصير جدًا.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SakiService.instance.updateProfile(
        username: _username.text,
        bio: _bio.text,
        avatar: _avatar,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر حفظ التعديلات في Supabase.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    padding: EdgeInsets.fromLTRB(
      20,
      14,
      20,
      MediaQuery.of(context).viewInsets.bottom + 20,
    ),
    child: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _line,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'تعديل الملف الشخصي',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pick,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: _orangeSoft,
                  backgroundImage: _avatar == null
                      ? null
                      : FileImage(File(_avatar!.path)),
                  child: _avatar == null
                      ? const FaIcon(FontAwesomeIcons.camera, color: _orange)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bio,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'النبذة'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _loading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'حفظ التعديلات',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
