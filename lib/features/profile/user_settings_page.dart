import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/custom_toast.dart';
import 'account_page.dart';
import 'vip_page.dart';

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
  bool _privateProfile = false;
  bool _loading = true;
  bool _loggingOut = false;
  String _language = 'العربية';
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
      final preferences = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _privateProfile = settings['private_profile'] == true;
        _language = preferences.getString('saki_profile_language') ?? 'العربية';
        _blocked = blocked;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _toast('تعذر تحميل بعض إعدادات الحساب');
    }
  }

  Future<void> _togglePrivacy(bool value) async {
    setState(() => _privateProfile = value);
    try {
      await _service.updateAccountSettings({'private_profile': value});
      _toast('تم تحديث إعدادات الخصوصية');
    } catch (_) {
      if (mounted) setState(() => _privateProfile = !value);
      _toast('تعذر حفظ إعدادات الخصوصية');
    }
  }

  Future<void> _chooseLanguage() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'اختر اللغة',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (final language in const ['العربية', 'English', 'Türkçe'])
                ListTile(
                  title: Text(language),
                  trailing: language == _language
                      ? const Icon(Icons.check_circle_rounded, color: _cyan)
                      : null,
                  onTap: () => Navigator.pop(sheetContext, language),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('saki_profile_language', selected);
    if (mounted) {
      setState(() => _language = selected);
      _toast('تم تغيير اللغة إلى $selected');
    }
  }

  Future<void> _showBlocked() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxHeight: 560),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: _blocked.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: Text('قائمة المحظورين فارغة')),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    const Text(
                      'قائمة المحظورين',
                      textAlign: TextAlign.center,
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

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    try {
      await _service.logout();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        setState(() => _loggingOut = false);
        _toast('تعذر تسجيل الخروج');
      }
    }
  }

  void _openAccount() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AccountPage()));
  }

  void _toast(String text) {
    if (mounted) CustomToast.show(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.profile['username']?.toString() ?? 'مستخدم SAKI';
    return Scaffold(
      backgroundColor: _page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              children: [
                const _Header(),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(color: _cyan),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          children: [
                            _AccountBanner(username: username),
                            const SizedBox(height: 18),
                            _Section(
                              title: 'الحساب',
                              children: [
                                _SettingRow(
                                  icon: Icons.person_outline_rounded,
                                  title: 'حسابي',
                                  subtitle: 'عرض ملفك وبيانات حسابك',
                                  onTap: _openAccount,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: 'الخصوصية والأمان',
                              children: [
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
                                  title: 'قائمة المحظورين',
                                  subtitle: 'إدارة المستخدمين الذين حظرتهم',
                                  trailing: _blocked.isEmpty
                                      ? null
                                      : '${_blocked.length}',
                                  onTap: _showBlocked,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: 'مميزات VIP',
                              children: [
                                _SettingRow(
                                  icon: Icons.workspace_premium_outlined,
                                  title: 'مميزات VIP',
                                  subtitle: 'الباقات والمزايا والترقية',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const VipPage(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: 'التفضيلات',
                              children: [
                                _SettingRow(
                                  icon: Icons.language_rounded,
                                  title: 'اللغة',
                                  subtitle: 'لغة التطبيق',
                                  trailing: _language,
                                  onTap: _chooseLanguage,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _LogoutButton(loading: _loggingOut, onTap: _logout),
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
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: Row(
      children: [
        IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
        ),
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
        const SizedBox(width: 48),
      ],
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
                'إعدادات حسابك في مكان واحد',
                style: TextStyle(
                  color: _UserSettingsPageState._muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.settings_rounded,
          color: _UserSettingsPageState._cyan,
          size: 20,
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
        child: Text(
          title,
          style: const TextStyle(
            color: _UserSettingsPageState._muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      Container(
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
      ),
    ],
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
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
          if (trailing != null) ...[
            Text(
              trailing!,
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
  const _LogoutButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: loading ? null : onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD5DA)),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFE11D48),
              ),
            )
          : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 19),
                SizedBox(width: 8),
                Text(
                  'تسجيل الخروج',
                  style: TextStyle(
                    color: Color(0xFFE11D48),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
    ),
  );
}
