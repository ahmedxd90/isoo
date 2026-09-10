import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';
import 'wallet_page.dart';
import 'vip_page.dart';
import 'user_settings_page.dart';
import 'super_admin_page.dart';
import 'role_admin_page.dart';
import 'host_agency_page.dart';
import 'vip_widgets.dart';
import 'store_pages.dart';
import 'trace_profile_features_page.dart';
import 'family_square_page.dart';
import 'tasks_page.dart';
import 'redeem_code_page.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/vip_identity.dart';

import '../../shared/widgets/custom_toast.dart';

const _orange = Color(0xFFFF6B35);
const _orangeSoft = Color(0x14FF6B35);
const _cyan = Color(0xFF06B6D4);
const _cyanSoft = Color(0x1406B6D4);
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
  bool _loading = true;
  bool _isSuperAdmin = false;
  String _adminRole = 'user';

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
        SakiService.instance.isHostAgencyOwner(SakiService.instance.uid),
      ]);
      if (!mounted) return;
      setState(() {
        final base = results[0] as Map<String, dynamic>?;
        _profile = base == null
            ? null
            : {
                ...base,
                'family_badge': results[5] as Map<String, dynamic>?,
                'host_agency_owner': results[6] == true,
              };
        _stats = results[1] as Map<String, int>;
        _modules = Map<String, dynamic>.from(results[4] as Map);
        _adminRole = base?['is_super_admin'] == true
            ? 'super_admin'
            : (base?['admin_role']?.toString() ?? 'user');
      });
      final isSuperAdmin = await SakiService.instance.isSuperAdmin();
      if (mounted) setState(() => _isSuperAdmin = isSuperAdmin);
    } catch (_) {
      if (mounted) {
        CustomToast.show(context, 'تعذر تحميل بيانات الملف من Supabase');
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
    if (type == 'host_agency') {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const HostAgencyPage()));
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            if (Navigator.canPop(context)) Navigator.pop(context);
          },
          icon: const FaIcon(
            FontAwesomeIcons.arrowRight,
            size: 17,
            color: _ink,
          ),
        ),
        centerTitle: true,
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 14),
            child: TextButton.icon(
              onPressed: _edit,
              style: TextButton.styleFrom(
                backgroundColor: _orangeSoft,
                foregroundColor: _orange,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 13),
              label: const Text(
                'تعديل',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: _orange,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _ProfileCard(
              profile: profile,
              username: username,
              familyBadge: profile['family_badge'] is Map
                  ? Map<String, dynamic>.from(profile['family_badge'])
                  : null,
              vipLevel: vipLevel,
              wealthLevel: wealthLevel,
              charmLevel: charmLevel,
              followers: followers,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: FontAwesomeIcons.wallet,
                    label: 'المحفظة',
                    color: _orange,
                    background: _orangeSoft,
                    onTap: () => _openModule('wallet'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ActionTile(
                    icon: FontAwesomeIcons.crown,
                    label: 'VIP',
                    color: const Color(0xFFD97706),
                    background: const Color(0xFFFFFBEB),
                    onTap: () => _openModule('vip'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: _ActionTile(
                    icon: FontAwesomeIcons.store,
                    label: 'المتجر',
                    color: const Color(0xFF2563EB),
                    background: const Color(0xFFEFF6FF),
                    onTap: () => _openModule('store'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: FontAwesomeIcons.building,
                    label: 'وكالة المضيفين',
                    color: _cyan,
                    background: _cyanSoft,
                    onTap: () => _openModule('host_agency'),
                  ),
                ),
                const SizedBox(width: 9),
                const Expanded(child: SizedBox()),
                const SizedBox(width: 9),
                const Expanded(child: SizedBox()),
              ],
            ),
            if (_adminRole != 'user') ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  if (_adminRole == 'super_admin') {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SuperAdminPage()),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoleAdminPage(role: _adminRole),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: SakiTheme.gradient,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _adminRole == 'bd'
                            ? Icons.handshake_rounded
                            : Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _adminRole == 'super_admin'
                              ? 'لوحة Super Admin'
                              : 'لوحة ${_adminRole.toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      RoleBadge(role: _adminRole, light: true),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            _MenuCard(onTap: _openMenu, isSuperAdmin: _isSuperAdmin),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const FaIcon(FontAwesomeIcons.rightFromBracket, size: 14),
              label: const Text('تسجيل الخروج'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.username,
    required this.familyBadge,
    required this.vipLevel,
    required this.wealthLevel,
    required this.charmLevel,
    required this.followers,
  });
  final Map<String, dynamic> profile;
  final String username;
  final Map<String, dynamic>? familyBadge;
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
                if (familyBadge != null) ...[
                  const SizedBox(height: 6),
                  FamilyTitleBadge(family: familyBadge, compact: true),
                ],
                if ((profile['admin_role']?.toString() ?? 'user') != 'user' ||
                    profile['is_super_admin'] == true) ...[
                  const SizedBox(height: 6),
                  RoleBadge(
                    role: profile['is_super_admin'] == true
                        ? 'super_admin'
                        : profile['admin_role']?.toString() ?? 'user',
                    compact: true,
                  ),
                ],
                if (profile['host_agency_owner'] == true) ...[
                  const SizedBox(height: 6),
                  const HostAgencyTitleBadge(compact: true),
                ],
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
                      VipTitleBadge(
                        profile: {...profile, 'vip_level': vipLevel},
                        compact: true,
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
    if (url == null || url!.isEmpty) {
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
    }
    return Image.network(
      url!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
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
      if (i != rows.length - 1) {
        children.add(const Divider(height: 1, color: _line));
      }
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
