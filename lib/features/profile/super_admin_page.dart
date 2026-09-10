import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:permission_handler/permission_handler.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import 'admin_trace_modules_page.dart';
import 'admin_room_emojis_page.dart';
import 'admin_banners_page.dart';
import 'admin_redeem_codes_page.dart';
import 'admin_reports_page.dart';
import 'store_pages.dart';

import '../../shared/widgets/custom_toast.dart';

const _blue = Color(0xFF7C5CFF);
const _cyan = Color(0xFF2ED9E6);
const _adminInk = Color(0xFFF8FAFF);

class SuperAdminPage extends StatelessWidget {
  const SuperAdminPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF080A18),
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(78),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_blue, _cyan]),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: false,
          child: Builder(
            builder: (context) => Row(
              children: [
                GestureDetector(
                  onTap: () => Scaffold.of(context).openDrawer(),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SAKI CONTROL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'لوحة السوبر أدمن',
                      style: TextStyle(color: Colors.white70, fontSize: 10),
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BagPage()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    drawer: Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [_blue, _cyan]),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'SAKI SUPER ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_rounded),
              title: const Text('إدارة المستخدمين'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminUsersPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.meeting_room_rounded),
              title: const Text('إدارة الغرف'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminRoomsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard_rounded),
              title: const Text('إدارة الهدايا'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminGiftsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.business_rounded),
              title: const Text('إدارة الوكالات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAgenciesPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.groups_rounded),
              title: const Text('إدارة العائلات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminFamiliesPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.storefront_rounded),
              title: const Text('إدارة المتجر'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminStorePage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number_rounded),
              title: const Text('استرداد كود'),
              subtitle: const Text('إضافة رموز ومكافآت حقيقية للمستخدمين'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminRedeemCodesPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.gif_box_rounded),
              title: const Text('إدارة إيموجي الغرفة'),
              subtitle: const Text('GIF فوق مقعد المستخدم لمدة 4 ثوانٍ'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminRoomEmojisPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_carousel_rounded),
              title: const Text('إدارة البنرات'),
              subtitle: const Text('صور ووجهات البروفايلات والغرف'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminBannersPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_rounded),
              title: const Text('بلاغات المستخدمين'),
              subtitle: const Text('مراجعة البلاغات وفيديوهات الإثبات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminReportsPage()),
                );
              },
            ),
          ],
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(colors: [_blue, _cyan]),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_rounded, color: Colors.white, size: 42),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SUPER ADMIN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'صلاحيات الإدارة محمية من Supabase',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
        FutureBuilder<Map<String, dynamic>>(
          future: SakiService.instance.adminDashboard(),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              );
            }
            final data = snapshot.data ?? const <String, dynamic>{};
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.8,
              children: [
                _MetricCard('المستخدمون', data['users'], Icons.people_alt),
                _MetricCard(
                  'VIP نشط',
                  data['active_vip'],
                  Icons.workspace_premium,
                ),
                _MetricCard('الغرف', data['rooms'], Icons.meeting_room),
                _MetricCard('الرسائل', data['messages'], Icons.forum),
                _MetricCard('الوكالات', data['agencies'], Icons.business),
                _MetricCard('العائلات', data['families'], Icons.groups),
                _MetricCard('المنشورات', data['posts'], Icons.article),
                _MetricCard('الحظر النشط', data['bans'], Icons.block),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _AdminCard(
          icon: Icons.people_alt_rounded,
          title: 'إدارة المستخدمين',
          subtitle: 'Saki ID والذهب وVIP والحظر العام',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminUsersPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.card_giftcard_rounded,
          title: 'إدارة الهدايا',
          subtitle: 'إضافة وتعديل وحذف هدايا صندوق الغرفة',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminGiftsPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.meeting_room_rounded,
          title: 'إدارة الغرف',
          subtitle: 'تغيير Room ID وتعيين الغرفة الرسمية',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminRoomsPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.business_rounded,
          title: 'إدارة الوكالات',
          subtitle: 'عرض الوكالات وتفعيلها أو تعليقها أو إغلاقها',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminAgenciesPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.groups_rounded,
          title: 'إدارة العائلات',
          subtitle: 'عرض العائلات وتغيير الحالة الإدارية',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminFamiliesPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.military_tech_rounded,
          title: 'إدارة المستويات والجوائز',
          subtitle: 'المستويات والنقاط والجوائز المرتبطة بالمستخدمين',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminLevelsPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.view_carousel_rounded,
          title: 'إدارة البنرات',
          subtitle: 'رفع صور حقيقية وتحديد بروفايل أو غرفة كوجهة',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminBannersPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.confirmation_number_rounded,
          title: 'استرداد كود',
          subtitle: 'إنشاء أكواد ومكافآت ذهبية ومتجر وVIP وثروة',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminRedeemCodesPage()),
          ),
        ),
        _AdminCard(
          icon: Icons.flag_rounded,
          title: 'بلاغات المستخدمين',
          subtitle: 'مراجعة الأسباب ومشاهدة فيديو الإثبات وتحديث الحالة',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminReportsPage()),
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value, this.icon);
  final String label;
  final Object? value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF12162A),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _cyan.withValues(alpha: .12)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_blue, _cyan]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${value ?? 0}',
                style: const TextStyle(
                  color: _adminInk,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF9AA4C2), fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12162A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: .05)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _cyan.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _adminInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF9AA4C2),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 14,
            color: Color(0xFF7F8BAB),
          ),
        ],
      ),
    ),
  );
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  bool _loading = false;
  static const roles = <String, String>{
    'user': 'مستخدم',
    'super_admin': 'سوبر أدمن',
    'admin': 'أدمن',
    'bd': 'BD',
    'official_host': 'مذيع SAKI الرسمي',
    'customer_service': 'خدمة عملاء',
  };

  @override
  void initState() {
    super.initState();
    _find();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (mounted) setState(() => _loading = true);
    try {
      final users = await SakiService.instance.adminUsers(_search.text.trim());
      if (mounted) setState(() => _users = users);
    } catch (error) {
      if (mounted) CustomToast.show(context, _cleanError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
  String _role(Map<String, dynamic> user) =>
      user['admin_role']?.toString() ?? 'user';
  String _date(Map<String, dynamic> user) {
    final date = DateTime.tryParse(user['created_at']?.toString() ?? '');
    if (date == null) return 'غير معروف';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _action(Map<String, dynamic> user) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
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
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'إجراءات ${user['username'] ?? 'المستخدم'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF7ED),
                  child: Icon(Icons.block_rounded, color: Colors.redAccent),
                ),
                title: const Text('حظر مستخدم'),
                subtitle: const Text('حظر التطبيق لمدة 7 أيام'),
                onTap: () => Navigator.pop(context, 'ban'),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Color(0xFF0284C7),
                  ),
                ),
                title: const Text('صلاحيات المستخدم'),
                subtitle: Text(roles[_role(user)] ?? 'مستخدم'),
                onTap: () => Navigator.pop(context, 'role'),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF5F3FF),
                  child: Icon(Icons.badge_rounded, color: Color(0xFF7C3AED)),
                ),
                title: const Text('تغيير SAKI ID'),
                subtitle: Text('الحالي: ${user['saki_id'] ?? '—'}'),
                onTap: () => Navigator.pop(context, 'id'),
              ),
            ],
          ),
        ),
      ),
    );
    try {
      if (action == 'ban') {
        await SakiService.instance.adminBanApp(
          (user['saki_id'] as num).toInt(),
          const Duration(days: 7),
          'حظر بواسطة سوبر أدمن',
        );
      } else if (action == 'role') {
        final role = await _selectRole(_role(user));
        if (role != null)
          await SakiService.instance.adminSetUserRole(
            user['id'] as String,
            role,
          );
      } else if (action == 'id') {
        await _changeSakiId(user);
      }
      if (action != null && mounted) await _find();
    } catch (error) {
      if (mounted) CustomToast.show(context, _cleanError(error));
    }
  }

  Future<String?> _selectRole(String current) => showDialog<String>(
    context: context,
    builder: (_) => SimpleDialog(
      title: const Text('تعيين صلاحيات المستخدم'),
      children: roles.entries
          .map(
            (entry) => RadioListTile<String>(
              value: entry.key,
              groupValue: current,
              title: Text(entry.value),
              onChanged: (value) => Navigator.pop(context, value),
            ),
          )
          .toList(),
    ),
  );

  Future<void> _changeSakiId(Map<String, dynamic> user) async {
    final controller = TextEditingController(text: '${user['saki_id'] ?? ''}');
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير SAKI ID'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'SAKI ID الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null)
      await SakiService.instance.adminUpdateUserSakiId(
        user['id'] as String,
        value,
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('إدارة المستخدمين'),
      backgroundColor: Colors.white,
      foregroundColor: _adminInk,
      elevation: 0,
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _find(),
            decoration: InputDecoration(
              hintText: 'بحث باسم المستخدم أو SAKI ID',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                onPressed: _find,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _find,
                  child: _users.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 180),
                            Center(child: Text('لا توجد حسابات مطابقة')),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                          itemCount: _users.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 9),
                          itemBuilder: (_, index) {
                            final user = _users[index];
                            final level =
                                ((user['vip_level'] as num?)?.toInt() ?? 0)
                                    .clamp(0, 10);
                            final banned = user['is_banned'] == true;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SakiAvatar(
                                    url: user['avatar_url'] as String?,
                                    label: user['username'] as String?,
                                    radius: 25,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user['display_name']
                                                            ?.toString()
                                                            .trim()
                                                            .isNotEmpty ==
                                                        true
                                                    ? user['display_name']
                                                          .toString()
                                                    : user['username']
                                                              ?.toString() ??
                                                          'مستخدم',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: _adminInk,
                                                ),
                                              ),
                                            ),
                                            if (level > 0)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFFFF7ED,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'VIP $level',
                                                  style: const TextStyle(
                                                    color: Color(0xFFEA580C),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'SAKI ID: ${user['saki_id'] ?? '—'}  •  ${roles[_role(user)] ?? 'مستخدم'}',
                                          style: const TextStyle(
                                            color: Color(0xFF475569),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'تاريخ الإنشاء: ${_date(user)}${banned ? '  •  محظور' : ''}',
                                          style: TextStyle(
                                            color: banned
                                                ? Colors.redAccent
                                                : const Color(0xFF94A3B8),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _action(user),
                                    tooltip: 'تعديل',
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => _action(user),
                                    tooltip: 'حظر',
                                    icon: Icon(
                                      Icons.block_rounded,
                                      color: banned
                                          ? Colors.redAccent
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
        ),
      ],
    ),
  );
}

class AdminGiftsPage extends StatefulWidget {
  const AdminGiftsPage({super.key});
  @override
  State<AdminGiftsPage> createState() => _AdminGiftsPageState();
}

class _AdminGiftsPageState extends State<AdminGiftsPage> {
  List<Map<String, dynamic>> _gifts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _gifts = await SakiService.instance.adminGiftCatalog();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) _snack(error.toString());
    }
  }

  void _snack(String value) =>
      CustomToast.show(context, value.replaceFirst('Exception: ', ''));

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminGiftUploadPage()),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B0914),
    appBar: AppBar(
      backgroundColor: const Color(0xFF130F24),
      title: const Text('متجر الهدايا التفاعلية'),
      actions: [
        FilledButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.cloud_upload_outlined),
          label: const Text('رفع هدية'),
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gifts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: .78,
      ),
      itemBuilder: (_, i) {
        final g = _gifts[i];
        final icon = g['icon'] as String? ?? '🎁';
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.purple.withValues(alpha: .35)),
          ),
          child: Column(
            children: [
              Expanded(
                child: icon.startsWith('http')
                    ? Image.network(icon, fit: BoxFit.contain)
                    : Center(
                        child: Text(icon, style: const TextStyle(fontSize: 35)),
                      ),
              ),
              Text(
                g['name'] as String? ?? 'هدية',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${g['price'] ?? 0} ذهب',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
              ),
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('حذف الهدية نهائيًا؟'),
                      content: Text(
                        'سيتم حذف ${g['name'] ?? 'الهدية'} من الكتالوج وسجل الهدايا ومخزون المستخدمين.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('حذف نهائي'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  try {
                    await SakiService.instance.adminDeleteGift(
                      g['id'] as String,
                    );
                    await _load();
                    if (!context.mounted) return;
                    CustomToast.show(
                      context,
                      'تم حذف الهدية من قاعدة البيانات بنجاح',
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    CustomToast.show(context, 'تعذر حذف الهدية: $error');
                  }
                },
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class AdminGiftUploadPage extends StatefulWidget {
  const AdminGiftUploadPage({super.key});
  @override
  State<AdminGiftUploadPage> createState() => _AdminGiftUploadPageState();
}

class _AdminGiftUploadPageState extends State<AdminGiftUploadPage> {
  static const categories = {
    'عامة': 'general',
    'هدايا الحظ': 'luck',
    'المشاهير': 'famous',
    'والدول': 'countries',
    'CP': 'cp',
    'VIP فقط': 'vip',
  };
  final name = TextEditingController();
  final price = TextEditingController();
  PlatformFile? thumbnail;
  PlatformFile? media;
  String category = 'general';
  String mediaType = 'mp4';
  bool saving = false;

  @override
  void dispose() {
    name.dispose();
    price.dispose();
    super.dispose();
  }

  Future<PlatformFile?> _pick(List<String> allowed) async {
    await [Permission.photos, Permission.videos, Permission.storage].request();
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    final ext = file.extension?.toLowerCase();
    if (ext == null || !allowed.contains(ext)) {
      _message('الامتداد غير مدعوم. المسموح: ${allowed.join('، ')}');
      return null;
    }
    return file;
  }

  void _message(String value) =>
      CustomToast.show(context, value.replaceFirst('Exception: ', ''));

  Future<void> _save() async {
    if (name.text.trim().isEmpty || int.tryParse(price.text) == null) {
      _message('أدخل اسم الهدية والسعر بشكل صحيح.');
      return;
    }
    if (thumbnail?.path == null || media?.path == null) {
      _message('اختر الصورة المصغرة وملف الهدية قبل الحفظ.');
      return;
    }
    setState(() => saving = true);
    try {
      final thumbUrl = await SakiService.instance.adminUploadGift(
        XFile(thumbnail!.path!),
      );
      final mediaUrl = await SakiService.instance.adminUploadGift(
        XFile(media!.path!),
      );
      await SakiService.instance.adminCreateGift(
        name: name.text.trim(),
        icon: thumbUrl,
        category: category,
        price: int.parse(price.text),
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );
      if (mounted) {
        _message('تم حفظ الهدية ونشرها في شبكة الهدايا.');
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) _message(error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: const Color(0xFFA855F7)),
    filled: true,
    fillColor: Colors.black.withValues(alpha: .28),
    labelStyle: const TextStyle(color: Colors.white60),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.purple.withValues(alpha: .35)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: Colors.purple.withValues(alpha: .35)),
    ),
  );

  Widget _fileTile({
    required String title,
    required String hint,
    required PlatformFile? file,
    required VoidCallback onTap,
    required IconData icon,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFA855F7).withValues(alpha: .35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFA855F7).withValues(alpha: .15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.purpleAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  file?.name ?? hint,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.upload_file_rounded, color: Colors.amberAccent),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF090713),
    appBar: AppBar(
      backgroundColor: const Color(0xFF0D091A),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'استوديو رفع الهدايا',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          Text(
            'تصميم ونشر هدايا البث المباشر',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsetsDirectional.only(
            end: 14,
            top: 12,
            bottom: 12,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, size: 8, color: Colors.greenAccent),
              SizedBox(width: 6),
              Text(
                'النظام جاهز',
                style: TextStyle(fontSize: 11, color: Colors.greenAccent),
              ),
            ],
          ),
        ),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF170F26).withValues(alpha: .86),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.purple.withValues(alpha: .28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'بيانات الهدية الجديدة',
                      style: TextStyle(
                        color: Color(0xFFE9D5FF),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: name,
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        'اسم الهدية',
                        Icons.card_giftcard,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: price,
                      style: const TextStyle(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: _decoration(
                        'السعر بالذهب',
                        Icons.monetization_on_outlined,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      dropdownColor: const Color(0xFF21163B),
                      style: const TextStyle(color: Colors.white),
                      decoration: _decoration(
                        'فئة الهدية',
                        Icons.category_outlined,
                      ),
                      items: categories.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.value,
                              child: Text(e.key),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 18),
                    _fileTile(
                      title: 'الصورة المصغرة للمتجر PNG',
                      hint: 'اضغط لاختيار صورة PNG من ملفات جهازك',
                      file: thumbnail,
                      icon: Icons.image_outlined,
                      onTap: () async {
                        final picked = await _pick(['png']);
                        if (mounted) setState(() => thumbnail = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ملف التأثير الحقيقي للهدية',
                      style: TextStyle(
                        color: Color(0xFFE9D5FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['mp4', 'svga', 'gif', 'png']
                          .map(
                            (type) => ChoiceChip(
                              label: Text(type.toUpperCase()),
                              selected: mediaType == type,
                              onSelected: (_) =>
                                  setState(() => mediaType = type),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    _fileTile(
                      title: 'رفع ملف الهدية $mediaType',
                      hint: 'اضغط لاختيار الملف من جهازك',
                      file: media,
                      icon: Icons.movie_creation_outlined,
                      onTap: () async {
                        final picked = await _pick([
                          'mp4',
                          'svga',
                          'gif',
                          'png',
                        ]);
                        if (mounted) {
                          setState(() {
                            media = picked;
                            if (picked?.extension != null) {
                              mediaType = picked!.extension!.toLowerCase();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: saving ? null : _save,
                        icon: saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          saving ? 'جاري الرفع والحفظ...' : 'حفظ ونشر الهدية',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF9333EA),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'يتم رفع الملفات من مدير ملفات الجهاز مباشرة، ثم تظهر الهدية في الغرف بعد الحفظ.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class AdminRoomsPage extends StatefulWidget {
  const AdminRoomsPage({super.key});
  @override
  State<AdminRoomsPage> createState() => _AdminRoomsPageState();
}

class _AdminRoomsPageState extends State<AdminRoomsPage> {
  List<Map<String, dynamic>> _rooms = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _rooms = await SakiService.instance.adminRooms();
    if (mounted) setState(() {});
  }

  Future<void> _edit(Map<String, dynamic> room) async {
    final id = TextEditingController(text: room['room_id'] as String? ?? '');
    bool official = room['is_official'] == true;
    bool pinned = room['is_pinned'] == true;
    final priority = TextEditingController(
      text: '${room['pin_priority'] as int? ?? 0}',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('إدارة الغرفة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: id,
                keyboardType: TextInputType.number,
                maxLength: 9,
                decoration: const InputDecoration(
                  labelText: 'Room ID - 9 أرقام',
                ),
              ),
              SwitchListTile(
                value: official,
                onChanged: (v) => set(() => official = v),
                title: const Text('غرفة رسمية'),
              ),
              SwitchListTile(
                value: pinned,
                onChanged: (v) => set(() => pinned = v),
                title: const Text('تثبيت في TOP'),
              ),
              if (pinned)
                TextField(
                  controller: priority,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'أولوية التثبيت (الأعلى أولاً)',
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      await SakiService.instance.adminSetRoomId(
        room['id'] as String,
        id.text,
        official,
      );
      await SakiService.instance.adminSetRoomPresentation(
        room['id'] as String,
        official: official,
        pinned: pinned,
        priority: int.tryParse(priority.text) ?? 0,
      );
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('إدارة الغرف')),
    body: ListView.builder(
      itemCount: _rooms.length,
      itemBuilder: (_, i) {
        final r = _rooms[i];
        return ListTile(
          title: Text(r['name'] as String? ?? 'غرفة'),
          subtitle: Text('Room ID: ${r['room_id'] ?? '—'}'),
          trailing: IconButton(
            onPressed: () => _edit(r),
            icon: const Icon(Icons.edit),
          ),
        );
      },
    ),
  );
}
