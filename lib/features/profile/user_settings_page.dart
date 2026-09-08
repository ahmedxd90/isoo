import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/saki_service.dart';

class UserSettingsPage extends StatefulWidget {
  const UserSettingsPage({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<UserSettingsPage> createState() => _UserSettingsPageState();
}

class _UserSettingsPageState extends State<UserSettingsPage> {
  static const _cyan = Color(0xFF26C6DA);
  static const _ink = Color(0xFF20212A);
  static const _muted = Color(0xFF8B8D98);
  static const _line = Color(0xFFF0F0F4);
  static const _page = Color(0xFFF7F7F9);

  final _service = SakiService.instance;
  bool _notifications = true;
  bool _privateProfile = false;
  bool _saving = false;
  bool _loading = true;
  List<Map<String, dynamic>> _blocked = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final account = await _service.accountModules();
      final settings = Map<String, dynamic>.from(
        account['settings'] as Map? ?? const {},
      );
      final blocked = await _service.blockedUsers();
      if (!mounted) return;
      setState(() {
        _notifications = settings['notifications_enabled'] != false;
        _privateProfile = settings['private_profile'] == true;
        _blocked = blocked;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _toast('تعذر تحميل بعض إعدادات الحساب');
    }
  }

  Future<void> _saveSettings() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _service.accountModules();
      await _service.updateAccountSettings({
        'notifications_enabled': _notifications,
        'private_profile': _privateProfile,
      });
      if (mounted) _toast('تم حفظ إعدادات الحساب بنجاح');
    } catch (_) {
      if (mounted) _toast('تعذر حفظ إعدادات الحساب');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notifications = value);
    await _saveSettings();
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() => _privateProfile = value);
    await _saveSettings();
  }

  Future<void> _unblock(Map<String, dynamic> row) async {
    final id = row['blocked_id']?.toString();
    if (id == null) return;
    try {
      await _service.unblockUser(id);
      if (mounted) {
        setState(() => _blocked.remove(row));
        _toast('تم إلغاء حظر المستخدم');
      }
    } catch (_) {
      _toast('تعذر إلغاء الحظر');
    }
  }

  Future<void> _clearCache() async {
    imageCache.clear();
    imageCache.clearLiveImages();
    _toast('تم تنظيف الذاكرة المؤقتة من الجهاز');
  }

  Future<void> _checkNetwork() async {
    _toast('جارٍ فحص الاتصال...');
    try {
      await InternetAddress.lookup('supabase.co');
      if (mounted) _toast('الاتصال بالخادم يعمل بشكل طبيعي');
    } catch (_) {
      if (mounted) _toast('تعذر الوصول إلى الخادم، تحقق من الإنترنت');
    }
  }

  Future<void> _deleteChatRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف سجلات الدردشة؟'),
        content: const Text(
          'سيتم حذف الرسائل التي أرسلتها فقط. هذا الإجراء لا يمكن التراجع عنه.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteOwnChatMessages();
      _toast('تم حذف سجلات الدردشة الخاصة بك');
    } catch (_) {
      _toast('تعذر حذف سجلات الدردشة من الخادم');
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.of(context).pop(true);
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text, textDirection: TextDirection.rtl),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.profile['username'] as String? ?? 'مستخدم SAKI';
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                _Header(onBack: () => Navigator.pop(context)),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _cyan),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 34),
                          children: [
                            _AccountBanner(username: username),
                            const SizedBox(height: 18),
                            _Section(
                              children: [
                                _SettingRow(
                                  icon: Icons.person_outline_rounded,
                                  title: 'حسابي',
                                  subtitle: 'البيانات الشخصية والملف العام',
                                  onTap: () => _toast(
                                    'بيانات الحساب محفوظة في Supabase',
                                  ),
                                ),
                                _SettingSwitch(
                                  icon: Icons.notifications_none_rounded,
                                  title: 'الإشعارات',
                                  value: _notifications,
                                  onChanged: _toggleNotifications,
                                ),
                                _SettingSwitch(
                                  icon: Icons.lock_outline_rounded,
                                  title: 'الخصوصية',
                                  subtitle:
                                      'إخفاء الملف عن المستخدمين غير المتابعين',
                                  value: _privateProfile,
                                  onChanged: _togglePrivacy,
                                ),
                                _SettingRow(
                                  icon: Icons.block_outlined,
                                  title: 'قائمة الحظر',
                                  trailing: _blocked.isEmpty
                                      ? null
                                      : '${_blocked.length}',
                                  onTap: _showBlocked,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              children: [
                                _SettingRow(
                                  icon: Icons.cleaning_services_outlined,
                                  title: 'تنظيف الذاكرة',
                                  subtitle: 'إزالة الصور المؤقتة من الجهاز',
                                  onTap: _clearCache,
                                ),
                                _SettingRow(
                                  icon: Icons.delete_sweep_outlined,
                                  title: 'حذف سجلات الدردشة',
                                  subtitle: 'حذف رسائلك الخاصة فقط',
                                  onTap: _deleteChatRecords,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              children: [
                                _SettingRow(
                                  icon: Icons.wifi_rounded,
                                  title: 'فحص الشبكة',
                                  subtitle: 'التحقق من الاتصال بخوادم SAKI',
                                  onTap: _checkNetwork,
                                ),
                                _SettingRow(
                                  icon: Icons.info_outline_rounded,
                                  title: 'حول التطبيق',
                                  subtitle: 'SAKI • الإصدار الحالي',
                                  onTap: () => _showAbout(username),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              children: [
                                _SettingRow(
                                  icon: Icons.save_outlined,
                                  title: 'حفظ كل الإعدادات',
                                  trailingWidget: _saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: _cyan,
                                          ),
                                        )
                                      : null,
                                  onTap: _saving ? null : _saveSettings,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _LogoutButton(onTap: _logout),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBlocked() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: _blocked.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text('قائمة الحظر فارغة')),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'قائمة الحظر',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._blocked.map(
                      (row) => ListTile(
                        title: Text(
                          (row['profiles'] as Map?)?['username']?.toString() ??
                              'مستخدم',
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.person_outline),
                        ),
                        trailing: TextButton(
                          onPressed: () => _unblock(row),
                          child: const Text(
                            'إلغاء الحظر',
                            style: TextStyle(color: _cyan),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showAbout(String username) {
    _toast('$username • SAKI اجتماعيًا أقرب');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Row(
      children: [
        _IconButton(icon: Icons.arrow_forward_ios_rounded, onTap: onBack),
        const Expanded(
          child: Center(
            child: Text(
              'الإعدادات',
              style: TextStyle(
                color: _UserSettingsPageState._ink,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 42),
      ],
    ),
  );
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 16, color: _UserSettingsPageState._ink),
    ),
  );
}

class _AccountBanner extends StatelessWidget {
  const _AccountBanner({required this.username});
  final String username;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFFDAFBFF), Colors.white]),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDDF4F7)),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _UserSettingsPageState._cyan,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  color: _UserSettingsPageState._ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'إدارة حسابك وبياناتك بأمان',
                style: TextStyle(
                  color: _UserSettingsPageState._muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.verified_rounded,
          color: _UserSettingsPageState._cyan,
          size: 20,
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(
                height: 1,
                indent: 58,
                color: _UserSettingsPageState._line,
              ),
          ],
        ],
      ),
    ),
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.trailingWidget,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final Widget? trailingWidget;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: _UserSettingsPageState._cyan, size: 21),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _UserSettingsPageState._ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: _UserSettingsPageState._muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailingWidget ?? const SizedBox.shrink(),
          if (trailing case final value?) ...[
            Text(
              value,
              style: const TextStyle(
                color: _UserSettingsPageState._cyan,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
          ],
          const Icon(
            Icons.chevron_left_rounded,
            color: Color(0xFFC4C4C6),
            size: 20,
          ),
        ],
      ),
    ),
  );
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(
      children: [
        Icon(icon, color: _UserSettingsPageState._cyan, size: 21),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _UserSettingsPageState._ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: _UserSettingsPageState._muted,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          activeThumbColor: _UserSettingsPageState._cyan,
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        'خروج',
        style: TextStyle(
          color: _UserSettingsPageState._cyan,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}
