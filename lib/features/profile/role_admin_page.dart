import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/saki_widgets.dart';
import 'admin_reports_page.dart';
import 'admin_trace_modules_page.dart';
import 'super_admin_page.dart';

class RoleAdminPage extends StatefulWidget {
  const RoleAdminPage({super.key, required this.role});
  final String role;

  @override
  State<RoleAdminPage> createState() => _RoleAdminPageState();
}

class _RoleAdminPageState extends State<RoleAdminPage> {
  Map<String, dynamic>? _access;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  static const _labels = <String, String>{
    'admin': 'ADMIN',
    'bd': 'BD',
    'official_host': 'SAKI OFFICIAL HOST',
    'customer_service': 'CUSTOMER SERVICE',
  };

  static const _descriptions = <String, String>{
    'admin': 'إدارة تشغيلية للمستخدمين والغرف والبلاغات والمحتوى.',
    'bd': 'إدارة الشراكات والوكالات والعائلات والمضيفين والتقارير.',
    'official_host': 'إدارة الغرف الرسمية والبث والمهام الخاصة بالمذيع.',
    'customer_service': 'دعم المستخدمين والبلاغات ومتابعة الحالات.',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final access = await SakiService.instance.adminAccess();
      final dashboard = await SakiService.instance.adminDashboard();
      if (!mounted) return;
      setState(() {
        _access = access;
        _dashboard = dashboard;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _can(String permission) {
    final permissions = _access?['permissions'];
    return permissions is List &&
        permissions.map((e) => e.toString()).contains(permission);
  }

  String get _role => (_access?['role']?.toString() ?? widget.role);
  String get _title => _labels[_role] ?? _role.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('لوحة $_title'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SakiColors.orange),
            )
          : _error != null
          ? EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'لا يمكن فتح اللوحة',
              subtitle: _error!,
            )
          : RefreshIndicator(
              color: SakiColors.orange,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _RoleHero(
                    role: _role,
                    title: _title,
                    description: _descriptions[_role] ?? '',
                  ),
                  const SizedBox(height: 16),
                  _Metrics(data: _dashboard ?? const {}),
                  const SizedBox(height: 16),
                  _sectionTitle('الأدوات المسموحة'),
                  const SizedBox(height: 8),
                  if (_can('view_users'))
                    _ToolCard(
                      icon: Icons.people_alt_rounded,
                      title: 'المستخدمون',
                      subtitle: _can('manage_users')
                          ? 'بحث ومتابعة وإجراءات التشغيل المسموحة'
                          : 'عرض بيانات المستخدمين للدعم والمتابعة',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminUsersPage(
                            canBanUsers: _can('ban_users'),
                            canManageRoles: _can('manage_user_roles'),
                            canChangeSakiId: _can('manage_system'),
                          ),
                        ),
                      ),
                    ),
                  if (_can('manage_rooms') || _can('manage_official_broadcast'))
                    _ToolCard(
                      icon: Icons.meeting_room_rounded,
                      title: 'الغرف والبث الرسمي',
                      subtitle: 'الوصول إلى أدوات الغرف المتاحة للدور',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminRoomsPage(),
                        ),
                      ),
                    ),
                  if (_can('manage_agencies'))
                    _ToolCard(
                      icon: Icons.business_rounded,
                      title: 'الوكالات والشراكات',
                      subtitle: 'متابعة الوكالات وحالاتها وتقارير الأداء',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminAgenciesPage(),
                        ),
                      ),
                    ),
                  if (_can('manage_families'))
                    _ToolCard(
                      icon: Icons.groups_rounded,
                      title: 'العائلات',
                      subtitle: 'متابعة العائلات وحالاتها الإدارية',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminFamiliesPage(),
                        ),
                      ),
                    ),
                  if (_can('manage_reports') || _can('support_users'))
                    _ToolCard(
                      icon: Icons.flag_rounded,
                      title: 'البلاغات وخدمة العملاء',
                      subtitle: 'مراجعة البلاغات ومتابعة حالات المستخدمين',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminReportsPage(),
                        ),
                      ),
                    ),
                  if (_can('manage_system'))
                    _ToolCard(
                      icon: Icons.fact_check_rounded,
                      title: 'سجل التدقيق',
                      subtitle: 'كل تغيير إداري مع المنفذ والوقت والهدف',
                      onTap: () => _showAuditLog(context),
                    ),
                  if (!_can('manage_system'))
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text(
                        'إدارة الأدوار والرصيد وVIP وإعدادات الأمان متاحة لـ Super Admin فقط.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: SakiColors.muted, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: 17,
      color: SakiColors.ink,
    ),
  );

  Future<void> _showAuditLog(BuildContext context) async {
    final logs = await SakiService.instance.adminAuditLog();
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (_, _) => const Divider(height: 20),
            itemBuilder: (_, index) {
              final row = logs[index];
              return ListTile(
                leading: const Icon(
                  Icons.history_rounded,
                  color: SakiColors.orange,
                ),
                title: Text(row['action']?.toString() ?? 'إجراء إداري'),
                subtitle: Text(
                  '${row['actor_username'] ?? '—'} • ${row['created_at'] ?? '—'}',
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RoleHero extends StatelessWidget {
  const _RoleHero({
    required this.role,
    required this.title,
    required this.description,
  });
  final String role;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: SakiTheme.gradient,
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1AFF6B35),
          blurRadius: 18,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Row(
      children: [
        RoleBadge(role: role, compact: false, light: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.8,
    children: [
      _Metric('المستخدمون', data['users'], Icons.people_alt_rounded),
      _Metric('الغرف', data['rooms'], Icons.meeting_room_rounded),
      _Metric('البلاغات/الرسائل', data['messages'], Icons.forum_rounded),
      _Metric('الوكالات', data['agencies'], Icons.business_rounded),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric(this.title, this.value, this.icon);
  final String title;
  final dynamic value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: SakiColors.line),
    ),
    child: Row(
      children: [
        Icon(icon, color: SakiColors.orange),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: SakiColors.ink,
                ),
              ),
              Text(
                title,
                style: const TextStyle(fontSize: 11, color: SakiColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      onTap: onTap,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: SakiColors.orange.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: SakiColors.orange),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_left_rounded),
    ),
  );
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
    this.compact = true,
    this.light = false,
  });
  final String role;
  final bool compact;
  final bool light;
  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'admin' => 'ADMIN',
      'bd' => 'BD',
      'official_host' => 'OFFICIAL',
      'customer_service' => 'SUPPORT',
      'super_admin' => 'SUPER ADMIN',
      _ => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    final color = role == 'bd' ? SakiColors.cyan : SakiColors.orange;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: light
            ? Colors.white.withValues(alpha: .2)
            : color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: light ? Colors.white70 : color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            role == 'bd' ? Icons.handshake_rounded : Icons.verified_rounded,
            size: compact ? 12 : 19,
            color: light ? Colors.white : color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: light ? Colors.white : color,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}
