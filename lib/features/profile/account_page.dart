import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final providers =
        user?.identities
            ?.map((identity) => identity.provider)
            .where((provider) => provider.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];
    final email = user?.email?.trim();
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        title: const Text('حسابي'),
        centerTitle: true,
        backgroundColor: const Color(0xFFF7F7F9),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          _AccountHero(email: email),
          const SizedBox(height: 18),
          const _SectionTitle('بيانات الحساب'),
          _AccountCard(
            icon: Icons.email_outlined,
            color: const Color(0xFF2563EB),
            title: 'البريد الإلكتروني',
            value: email?.isNotEmpty == true ? email! : 'غير متوفر',
          ),
          const SizedBox(height: 10),
          _AccountCard(
            icon: Icons.login_rounded,
            color: const Color(0xFF16A34A),
            title: 'طريقة تسجيل الدخول',
            value: _providerLabel(providers),
            leading: providers.contains('google') ? const _GoogleMark() : null,
          ),
          const SizedBox(height: 10),
          _AccountCard(
            icon: Icons.verified_user_outlined,
            color: const Color(0xFF9333EA),
            title: 'حالة الحساب',
            value: user == null ? 'غير مسجل' : 'الحساب متصل وآمن',
          ),
          const SizedBox(height: 18),
          const _InfoBox(
            text: 'لا يتم عرض كلمة المرور داخل التطبيق. يمكنك إدارة أمان حسابك من مزود تسجيل الدخول المرتبط به.',
          ),
        ],
      ),
    );
  }

  static String _providerLabel(List<String> providers) {
    if (providers.contains('google')) return 'Google';
    if (providers.contains('email')) return 'البريد الإلكتروني';
    if (providers.isEmpty) return 'غير معروف';
    return providers.join('، ');
  }
}

class _AccountHero extends StatelessWidget {
  const _AccountHero({required this.email});
  final String? email;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        const CircleAvatar(
          radius: 28,
          backgroundColor: Colors.white24,
          child: Icon(Icons.person_rounded, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'حساب SAKI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email?.isNotEmpty == true ? email! : 'حسابك الشخصي',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8, right: 4),
    child: Text(
      title,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    this.leading,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Row(
      children: [
        leading ??
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF16A34A),
          size: 20,
        ),
      ],
    ),
  );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: Color(0xFFF1F5F9),
      shape: BoxShape.circle,
    ),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4285F4),
        fontSize: 24,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFDBEAFE)),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Color(0xFF1D4ED8),
        fontSize: 11,
        height: 1.5,
      ),
    ),
  );
}
