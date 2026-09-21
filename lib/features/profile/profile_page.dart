import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/profile_post_card.dart';
import 'wallet_page.dart';
import 'vip_page.dart';
import 'user_settings_page.dart';
import 'super_admin_page.dart';
import 'shipping_agent_page.dart';
import 'store_pages.dart';
import 'trace_profile_features_page.dart';
import 'family_square_page.dart';
import 'tasks_page.dart';
import 'redeem_code_page.dart';
import 'user_profile_page.dart';
import '../../shared/widgets/vip_identity.dart';

import '../../shared/widgets/custom_toast.dart';

const _orange = Color(0xFFFF6B35);
const _orangeSoft = Color(0x14FF6B35);
const _cyan = Color(0xFF06B6D4);
const _ink = Color(0xFF111827);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);

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
  List<Map<String, dynamic>> _gifts = [];
  List<Map<String, dynamic>> _badges = [];
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
        SakiService.instance.familyBadgeForUser(SakiService.instance.uid),
        SakiService.instance.isShippingAgent(SakiService.instance.uid),
        SakiService.instance.userReceivedGifts(SakiService.instance.uid),
        SakiService.instance.userBadges(SakiService.instance.uid),
      ]);
      if (!mounted) return;
      setState(() {
        final base = results[0] is Map
            ? Map<String, dynamic>.from(results[0] as Map)
            : null;
        _profile = base == null
            ? null
            : {
                ...base,
                'family_badge': results[5] as Map<String, dynamic>?,
                'shipping_agent': results[6] == true,
              };
        _stats = results[1] is Map
            ? Map<String, int>.from(
                (results[1] as Map).map(
                  (key, value) =>
                      MapEntry(key.toString(), (value as num).toInt()),
                ),
              )
            : <String, int>{};
        _modules = results[4] is Map
            ? Map<String, dynamic>.from(results[4] as Map)
            : <String, dynamic>{};
        _posts = results[2] is List
            ? List<Map<String, dynamic>>.from(results[2] as List)
            : [];
        _reels = results[3] is List
            ? List<Map<String, dynamic>>.from(results[3] as List)
            : [];
        _gifts = results[7] is List
            ? List<Map<String, dynamic>>.from(results[7] as List)
            : [];
        _badges = results[8] is List
            ? List<Map<String, dynamic>>.from(results[8] as List)
            : [];
      });
      final isSuperAdmin = await SakiService.instance.isSuperAdmin();
      if (mounted) setState(() => _isSuperAdmin = isSuperAdmin);
    } catch (error) {
      if (mounted) {
        CustomToast.show(context, 'تعذر تحميل بيانات الملف: $error');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(profile: _profile ?? {}),
      ),
    );
    if (updated == true) _load();
  }

  Future<void> _logout() async {
    await SakiService.instance.logout();
    if (mounted) context.go('/login');
  }

  Future<void> _openModule(String type) async {
    if (type == 'store') {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: .92,
          minChildSize: .60,
          maxChildSize: .98,
          expand: false,
          builder: (context, _) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: const StorePage(),
          ),
        ),
      );
      if (mounted) _load();
      return;
    }
    if (type == 'family') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const FamilySquarePage()));
      if (mounted) _load();
      return;
    }
    if (type == 'shipping_agent') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ShippingAgentPage()));
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
    if (title == 'كود الاسترداد') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RedeemCodePage()));
      return;
    }
    if (title == 'المهام') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const TasksPage()));
      return;
    }
    if (title == 'المستوى') {
      await _openModule('level');
      return;
    }
    if (title == 'العائلة') {
      await _openModule('family');
      return;
    }
    if (title == 'وكالة الشحن') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ShippingAgentPage()));
      if (mounted) _load();
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
          CustomToast.show(context, 'هذه الصفحة متاحة للسوبر أدمن فقط');
        }
      } catch (_) {}
      return;
    }
    if (title == 'الإعدادات') {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => UserSettingsPage(profile: _profile ?? const {}),
        ),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    final profile = _profile ?? {};
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

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.cairoTextTheme(Theme.of(context).textTheme),
      ),
      child: _MyHtmlProfileView(
        profile: profile,
        stats: _stats,
        posts: _posts,
        reels: _reels,
        gifts: _gifts,
        badges: _badges,
        wealthLevel: wealthLevel,
        vipLevel: vipLevel,
        isSuperAdmin: _isSuperAdmin,
        isShippingAgent: profile['shipping_agent'] == true,
        onBack: () {
          if (context.canPop()) context.pop();
        },
        onEdit: _edit,
        onAvatarTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfilePage(userId: SakiService.instance.uid),
          ),
        ),
        onModule: _openModule,
        onMenu: _openMenu,
        onLogout: _logout,
      ),
    );
  }
}

class _MyHtmlProfileView extends StatefulWidget {
  const _MyHtmlProfileView({
    required this.profile,
    required this.stats,
    required this.posts,
    required this.reels,
    required this.gifts,
    required this.badges,
    required this.wealthLevel,
    required this.vipLevel,
    required this.isSuperAdmin,
    required this.isShippingAgent,
    required this.onBack,
    required this.onEdit,
    required this.onAvatarTap,
    required this.onModule,
    required this.onMenu,
    required this.onLogout,
  });
  final Map<String, dynamic> profile;
  final Map<String, int> stats;
  final List<Map<String, dynamic>> posts, reels, gifts, badges;
  final int wealthLevel, vipLevel;
  final bool isSuperAdmin, isShippingAgent;
  final VoidCallback onBack, onEdit, onAvatarTap, onLogout;
  final Future<void> Function(String) onModule;
  final Future<void> Function(String) onMenu;

  @override
  State<_MyHtmlProfileView> createState() => _MyHtmlProfileViewState();
}

class _MyHtmlProfileViewState extends State<_MyHtmlProfileView> {
  int tab = 0;

  Future<void> _more() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.settings_rounded,
                color: Color(0xFF475569),
              ),
              title: const Text('الإعدادات'),
              onTap: () {
                Navigator.pop(context);
                widget.onMenu('الإعدادات');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: const Text('تسجيل الخروج'),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.profile['username']?.toString() ?? 'مستخدم SAKI';
    final avatar = widget.profile['avatar_url']?.toString();
    final family = widget.profile['family_badge'] is Map
        ? Map<String, dynamic>.from(widget.profile['family_badge'] as Map)
        : null;
    final content = switch (tab) {
      1 => _MyMomentsContent(
        key: const ValueKey('moments'),
        posts: widget.posts,
        reels: widget.reels,
      ),
      2 => _MyCollectionContent(
        key: const ValueKey('badges'),
        title: 'الأوسمة المكتسبة',
        items: widget.badges,
        kind: 'badge',
      ),
      3 => _MyCollectionContent(
        key: const ValueKey('gifts'),
        title: 'الهدايا المستلمة',
        items: widget.gifts,
        kind: 'gift',
      ),
      _ => _MyAboutContent(
        key: const ValueKey('about'),
        profile: widget.profile,
        family: family,
        onEdit: widget.onEdit,
      ),
    };
    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _MyProfileCover(
                profile: widget.profile,
                username: username,
                avatar: avatar,
                wealthLevel: widget.wealthLevel,
                vipLevel: widget.vipLevel,
                stats: widget.stats,
                onBack: widget.onBack,
                onEdit: widget.onEdit,
                onAvatarTap: widget.onAvatarTap,
                onMore: _more,
                onAdmin: widget.isSuperAdmin
                    ? () => widget.onMenu('لوحة تحكم سوبر أدمن')
                    : null,
                onShipping: widget.isShippingAgent
                    ? () => widget.onModule('shipping_agent')
                    : null,
              ),
            ),
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 40),
                  child: Column(
                    children: [
                      _MyShortcutGrid(
                        onTap: widget.onModule,
                        onMenu: widget.onMenu,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          _MyTab(
                            label: 'ملف التعريف',
                            active: tab == 0,
                            onTap: () => setState(() => tab = 0),
                          ),
                          _MyTab(
                            label: 'اللحظات',
                            active: tab == 1,
                            onTap: () => setState(() => tab = 1),
                          ),
                          _MyTab(
                            label: 'الأوسمة',
                            active: tab == 2,
                            onTap: () => setState(() => tab = 2),
                          ),
                          _MyTab(
                            label: 'الهدايا',
                            active: tab == 3,
                            onTap: () => setState(() => tab = 3),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: content,
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

class _MyProfileCover extends StatelessWidget {
  const _MyProfileCover({
    required this.profile,
    required this.username,
    required this.avatar,
    required this.wealthLevel,
    required this.vipLevel,
    required this.stats,
    required this.onBack,
    required this.onEdit,
    required this.onAvatarTap,
    required this.onMore,
    this.onAdmin,
    this.onShipping,
  });
  final Map<String, dynamic> profile;
  final String username;
  final String? avatar;
  final int wealthLevel, vipLevel;
  final Map<String, int> stats;
  final VoidCallback onBack, onEdit, onAvatarTap, onMore;
  final VoidCallback? onAdmin, onShipping;
  @override
  Widget build(BuildContext context) {
    final cover = avatar == null || avatar!.isEmpty
        ? null
        : NetworkImage(avatar!);
    final gender = profile['gender']?.toString() ?? '';
    return Container(
      constraints: const BoxConstraints(minHeight: 360),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        image: cover == null
            ? null
            : DecorationImage(
                image: cover,
                fit: BoxFit.cover,
                alignment: Alignment.bottomCenter,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: .48),
                  BlendMode.darken,
                ),
              ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xE6000000)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onAdmin != null)
                    _GlassIcon(
                      icon: Icons.admin_panel_settings_rounded,
                      onTap: onAdmin!,
                    ),
                  if (onShipping != null) ...[
                    const SizedBox(width: 10),
                    _GlassIcon(
                      icon: Icons.monetization_on_rounded,
                      onTap: onShipping!,
                    ),
                  ],
                  const Spacer(),
                  _GlassIcon(icon: Icons.more_vert_rounded, onTap: onMore),
                  const SizedBox(width: 8),
                  _GlassIcon(icon: Icons.chevron_right_rounded, onTap: onBack),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white38),
                  ),
                  child: SakiAvatar(
                    url: avatar,
                    label: username,
                    radius: 36,
                    profile: profile,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    child: VipNameText(
                      profile: {...profile, 'display_name': username},
                      fontSize: 19,
                      textAlign: TextAlign.start,
                    ),
                  ),
                  const SizedBox(height: 4),
                  WealthVipLabels(profile: profile, compact: true),
                  if (gender.isNotEmpty) ...[
                    const SizedBox(width: 7),
                    Container(
                      width: 17,
                      height: 17,
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        gender == 'أنثى'
                            ? Icons.female_rounded
                            : Icons.male_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'ID: ${profile['saki_id'] ?? '—'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: '${profile['saki_id'] ?? ''}'),
                      );
                      if (context.mounted) {
                        CustomToast.show(context, 'تم نسخ SAKI ID');
                      }
                    },
                    icon: const Icon(
                      Icons.copy_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _MyHeroStat(
                    value: '${stats['followers'] ?? 0}',
                    label: 'المتابعون',
                  ),
                  _MyHeroDivider(),
                  _MyHeroStat(
                    value: '${stats['following'] ?? 0}',
                    label: 'الذين تتابعهم',
                  ),
                  _MyHeroDivider(),
                  _MyHeroStat(
                    value: '${stats['posts'] ?? 0}',
                    label: 'اللحظات',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(99),
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .32),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _MyHeroStat extends StatelessWidget {
  const _MyHeroStat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    ),
  );
}

class _MyHeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(height: 28, width: 1, color: Colors.white38);
}

class _MyShortcutGrid extends StatelessWidget {
  const _MyShortcutGrid({required this.onTap, required this.onMenu});
  final Future<void> Function(String) onTap;
  final Future<void> Function(String) onMenu;
  @override
  Widget build(BuildContext context) {
    final items = <(String, String, IconData, Color, bool)>[
      (
        'المحفظة',
        'wallet',
        Icons.account_balance_wallet_rounded,
        const Color(0xFFF59E0B),
        true,
      ),
      (
        'VIP',
        'vip',
        Icons.workspace_premium_rounded,
        const Color(0xFF9333EA),
        true,
      ),
      (
        'المتجر',
        'store',
        Icons.shopping_bag_rounded,
        const Color(0xFF2563EB),
        true,
      ),
      (
        'العائلة',
        'family',
        Icons.groups_rounded,
        const Color(0xFF4F46E5),
        true,
      ),
      (
        'المستوى',
        'level',
        Icons.show_chart_rounded,
        const Color(0xFF10B981),
        true,
      ),
      (
        'المهام',
        'المهام',
        Icons.checklist_rounded,
        const Color(0xFFF97316),
        false,
      ),
      (
        'كود الاسترداد',
        'كود الاسترداد',
        Icons.confirmation_number_rounded,
        const Color(0xFFF43F5E),
        false,
      ),
      (
        'الإعدادات',
        'الإعدادات',
        Icons.settings_rounded,
        const Color(0xFF475569),
        false,
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 17,
      crossAxisSpacing: 8,
      childAspectRatio: .78,
      children: items
          .map(
            (item) => _ShortcutItem(
              label: item.$1,
              icon: item.$3,
              color: item.$4,
              onTap: () => item.$5 ? onTap(item.$2) : onMenu(item.$2),
            ),
          )
          .toList(),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(13),
    child: Column(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: .25)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: .08), blurRadius: 7),
            ],
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF374151),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MyTab extends StatelessWidget {
  const _MyTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
              width: active ? 3 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? const Color(0xFF111827) : const Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    ),
  );
}

class _MyAboutContent extends StatelessWidget {
  const _MyAboutContent({
    super.key,
    required this.profile,
    required this.family,
    required this.onEdit,
  });
  final Map<String, dynamic> profile;
  final Map<String, dynamic>? family;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      _MySection(
        title: 'عني',
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    profile['bio']?.toString().isNotEmpty == true
                        ? profile['bio'].toString()
                        : 'تحرير',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.edit_rounded,
                  color: Color(0xFF10B981),
                  size: 15,
                ),
              ],
            ),
          ),
        ),
      ),
      _MySection(
        title: 'عائلة',
        child: _MyFamilyCard(family: family),
      ),
      const _MySection(title: 'CP', child: _MyCpCard()),
    ],
  );
}

class _MySection extends StatelessWidget {
  const _MySection({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _MyFamilyCard extends StatelessWidget {
  const _MyFamilyCard({required this.family});
  final Map<String, dynamic>? family;
  @override
  Widget build(BuildContext context) {
    final image = family?['avatar_url']?.toString();
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF071739), Color(0xFF1868D9), Color(0xFF0A2552)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: .35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x441868D9),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
              ),
            ),
            child: ClipOval(
              child: image == null || image.isEmpty
                  ? const Icon(Icons.groups_rounded, color: Colors.white)
                  : Image.network(image, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family?['name']?.toString() ?? 'لا توجد عائلة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  family == null
                      ? 'لم يتم الانضمام إلى عائلة بعد'
                      : 'Lv.${family?['level'] ?? 0}  •  ${family?['role'] ?? 'عضو'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.shield_rounded, color: Color(0xFFFBBF24)),
        ],
      ),
    );
  }
}

class _MyCpCard extends StatefulWidget {
  const _MyCpCard();
  @override
  State<_MyCpCard> createState() => _MyCpCardState();
}

class _MyCpCardState extends State<_MyCpCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, _) {
        final rings = <Widget>[];
        for (final scale in [.7, 1.0, 1.3]) {
          rings.add(
            Transform.scale(
              scale: scale + controller.value * .35,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.pinkAccent.withValues(
                      alpha: .28 * (1 - controller.value),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B020D), Color(0xFFB91C1C), Color(0xFF4C0519)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x66FB7185)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x66F43F5E)
                    .withValues(alpha: .2 + controller.value * .25),
                blurRadius: 12 + controller.value * 10,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              ...rings,
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFF43F5E),
                size: 40,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MyCollectionContent extends StatelessWidget {
  const _MyCollectionContent({
    super.key,
    required this.title,
    required this.items,
    required this.kind,
  });
  final String title, kind;
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: Color(0xFF111827),
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      if (items.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 48),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F5F7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            kind == 'gift'
                ? 'لم يتم تلقي أي هدايا حتى الآن.'
                : 'لم يتم الحصول على أي أوسمة بعد.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 9,
            childAspectRatio: .92,
          ),
          itemBuilder: (_, i) => _MyCollectionTile(item: items[i], kind: kind),
        ),
    ],
  );
}

class _MyCollectionTile extends StatelessWidget {
  const _MyCollectionTile({required this.item, required this.kind});
  final Map<String, dynamic> item;
  final String kind;
  @override
  Widget build(BuildContext context) {
    final image = item['media_url']?.toString().isNotEmpty == true
        ? item['media_url'].toString()
        : item['asset_path']?.toString();
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Expanded(
            child: kind == 'gift' && (image == null || image.isEmpty)
                ? Text(
                    item['icon']?.toString() ?? '🎁',
                    style: const TextStyle(fontSize: 30),
                  )
                : image == null
                ? Icon(
                    kind == 'gift'
                        ? Icons.card_giftcard_rounded
                        : Icons.workspace_premium_rounded,
                    color: kind == 'gift'
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF7C3AED),
                    size: 30,
                  )
                : image.startsWith('assets/')
                ? Image.asset(image, fit: BoxFit.contain)
                : Image.network(image, fit: BoxFit.cover),
          ),
          const SizedBox(height: 4),
          Text(
            item['name']?.toString() ?? (kind == 'gift' ? 'هدية' : 'وسام'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (kind == 'gift')
            Text(
              item['room_name']?.toString() ?? 'غرفة SAKI',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          if (kind == 'gift')
            Text(
              '×${item['received_count'] ?? 0}',
              style: const TextStyle(
                color: Color(0xFFF59E0B),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
        ],
      ),
    );
  }
}

class _MyMomentsContent extends StatelessWidget {
  const _MyMomentsContent({
    super.key,
    required this.posts,
    required this.reels,
  });
  final List<Map<String, dynamic>> posts, reels;
  @override
  Widget build(BuildContext context) {
    final count = posts.length + reels.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'لحظاتي  •  $count',
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (count == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'لا توجد لحظات مسجلة حتى الآن.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          Column(
            children: [
              for (final post in posts.take(12)) _MyMomentTile(post: post),
            ],
          ),
      ],
    );
  }
}

class _MyMomentTile extends StatelessWidget {
  const _MyMomentTile({required this.post});
  final Map<String, dynamic> post;
  @override
  Widget build(BuildContext context) => ProfilePostCard(post: post);
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
        'VIP ${modules['vip_level'] ?? 0}',
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
      _ => 'هذه الميزة غير متاحة لهذا الحساب حاليًا.',
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
          activeThumbColor: _orange,
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
          activeThumbColor: _cyan,
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

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final _username = TextEditingController(
    text: widget.profile['username'] as String? ?? '',
  );
  late final _bio = TextEditingController(
    text: widget.profile['bio'] as String? ?? '',
  );
  final _picker = ImagePicker();
  XFile? _avatar;
  List<Map<String, dynamic>> _countries = const [];
  String? _country;
  String? _countryCode;
  bool _loading = false;
  bool _loadingCountries = true;
  String? _error;

  int get _vipLevel => (widget.profile['vip_level'] as num?)?.toInt() ?? 0;
  bool get _canUseGif => _vipLevel >= 7;
  DateTime? get _countryChangedAt =>
      DateTime.tryParse(widget.profile['country_updated_at']?.toString() ?? '');
  bool get _canChangeCountry {
    final changed = _countryChangedAt;
    return changed == null ||
        DateTime.now().toUtc().difference(changed.toUtc()).inDays >= 30;
  }

  @override
  void initState() {
    super.initState();
    _country = widget.profile['country'] as String?;
    _countryCode = widget.profile['country_code'] as String?;
    _loadCountries();
  }

  @override
  void dispose() {
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final rows = await SakiService.instance.countries();
      if (!mounted) return;
      setState(() {
        _countries = rows;
        _loadingCountries = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingCountries = false);
    }
  }

  Future<void> _chooseAvatar() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
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
              const Text(
                'اختيار صورة المستخدم',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: _orangeSoft,
                  child: FaIcon(
                    FontAwesomeIcons.image,
                    color: _orange,
                    size: 18,
                  ),
                ),
                title: const Text('صورة عادية'),
                subtitle: const Text('JPG أو PNG'),
                onTap: () => Navigator.pop(sheetContext, 'image'),
              ),
              ListTile(
                enabled: _canUseGif,
                leading: CircleAvatar(
                  backgroundColor: _canUseGif
                      ? const Color(0xFFEDE9FE)
                      : const Color(0xFFF3F4F6),
                  child: FaIcon(
                    FontAwesomeIcons.film,
                    color: _canUseGif ? const Color(0xFF7C3AED) : _muted,
                    size: 18,
                  ),
                ),
                title: Text(
                  'صورة GIF متحركة${_canUseGif ? '' : ' (VIP7 فقط)'}',
                ),
                subtitle: Text(
                  _canUseGif
                      ? 'متاحة لأن مستواك VIP هو $_vipLevel'
                      : 'يجب أن يكون مستوى VIP7 أو أعلى',
                ),
                onTap: _canUseGif
                    ? () => Navigator.pop(sheetContext, 'gif')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null || !mounted) return;
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => _avatar = image);
  }

  Future<void> _save() async {
    if (_username.text.trim().length < 3) {
      setState(() => _error = 'اسم المستخدم قصير جدًا.');
      return;
    }
    if (!_canChangeCountry && _country != widget.profile['country']) {
      setState(() => _error = 'يمكن تغيير الدولة مرة واحدة كل 30 يومًا.');
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
        country: _country,
        countryCode: _countryCode,
        avatar: _avatar,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('country_change_cooldown')
          ? 'لا يمكن تغيير الدولة قبل مرور 30 يومًا.'
          : error.toString().contains('vip7_required_for_gif')
          ? 'صور GIF متاحة لمستخدمي VIP7 أو أعلى فقط.'
          : 'تعذر حفظ التعديلات في Supabase.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _avatarPreview() {
    final remote = widget.profile['avatar_url']?.toString();
    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [_orange, _cyan]),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: _avatar != null
            ? Image.file(File(_avatar!.path), fit: BoxFit.cover)
            : remote == null || remote.isEmpty
            ? const ColoredBox(
                color: _orangeSoft,
                child: Icon(Icons.person_rounded, color: _orange, size: 52),
              )
            : Image.network(remote, fit: BoxFit.cover),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text(
        'تعديل الملف الشخصي',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: _ink,
      elevation: 0,
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: _chooseAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _avatarPreview(),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: _orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'اضغط على الصورة لتغييرها',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 26),
            TextField(
              controller: _username,
              decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 14),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'دولة المستخدم',
                prefixIcon: const Icon(Icons.flag_outlined),
                enabled: _canChangeCountry,
              ),
              child: _loadingCountries
                  ? const SizedBox(height: 20, child: LinearProgressIndicator())
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _countries.any((c) => c['name_ar'] == _country)
                            ? _country
                            : null,
                        isExpanded: true,
                        hint: const Text('اختر الدولة'),
                        items: _countries
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['name_ar']?.toString(),
                                child: Text(
                                  '${c['flag'] ?? '🌍'}  ${c['name_ar'] ?? ''}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: !_canChangeCountry
                            ? null
                            : (value) {
                                final row = _countries.firstWhere(
                                  (c) => c['name_ar'] == value,
                                  orElse: () => {},
                                );
                                setState(() {
                                  _country = value;
                                  _countryCode = row['code']?.toString();
                                });
                              },
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              _canChangeCountry
                  ? 'يمكن تغيير الدولة مرة واحدة كل 30 يومًا.'
                  : 'الدولة مقفلة حتى مرور 30 يومًا من آخر تغيير.',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _bio,
              maxLines: 4,
              maxLength: 160,
              decoration: const InputDecoration(
                labelText: 'نبذة عني',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _loading ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
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
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
