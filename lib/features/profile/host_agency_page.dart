import 'package:flutter/material.dart';

import '../../shared/widgets/custom_toast.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';

class HostAgencyPage extends StatefulWidget {
  const HostAgencyPage({super.key});
  @override
  State<HostAgencyPage> createState() => _HostAgencyPageState();
}

class _HostAgencyPageState extends State<HostAgencyPage> {
  bool _loading = true;
  bool _isHost = false;
  String? _error;
  Map<String, dynamic> _wallet = {};
  Map<String, dynamic> _ownerDashboard = {};
  List<Map<String, dynamic>> _hosts = [];
  List<Map<String, dynamic>> _withdrawals = [];

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
      final isAgencyHost = await SakiService.instance.isHostAgencyMember(
        SakiService.instance.uid,
      );
      if (isAgencyHost) {
        final result = await Future.wait<dynamic>([
          SakiService.instance.hostAgencyHostDashboard(),
          SakiService.instance.hostAgencyWalletDashboard(),
          SakiService.instance.hostAgencyWithdrawals(),
        ]);
        if (!mounted) return;
        setState(() {
          _isHost = true;
          _wallet = Map<String, dynamic>.from(result[1] as Map);
          _withdrawals = List<Map<String, dynamic>>.from(result[2] as List);
        });
      } else {
        final result = await Future.wait<dynamic>([
          SakiService.instance.hostAgencyDashboard(),
          SakiService.instance.hostAgencyHosts(),
        ]);
        if (!mounted) return;
        setState(() {
          _isHost = false;
          _ownerDashboard = Map<String, dynamic>.from(result[0] as Map);
          _hosts = List<Map<String, dynamic>>.from(result[1] as List);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String text) => CustomToast.show(context, text);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: Text(_isHost ? 'لوحة المضيف' : 'وكالة المضيفين'),
      actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
      ],
    ),
    body: _loading
        ? const Center(
            child: CircularProgressIndicator(color: SakiColors.orange),
          )
        : _error != null
        ? _ErrorState(message: _error!)
        : RefreshIndicator(
            color: SakiColors.orange,
            onRefresh: _load,
            child: _isHost
                ? _HostDashboard(
                    data: _wallet,
                    withdrawals: _withdrawals,
                    toast: _toast,
                    onChanged: _load,
                  )
                : _OwnerDashboard(
                    dashboard: _ownerDashboard,
                    hosts: _hosts,
                    toast: _toast,
                    onChanged: _load,
                  ),
          ),
  );
}

class _OwnerDashboard extends StatelessWidget {
  const _OwnerDashboard({
    required this.dashboard,
    required this.hosts,
    required this.toast,
    required this.onChanged,
  });
  final Map<String, dynamic> dashboard;
  final List<Map<String, dynamic>> hosts;
  final void Function(String) toast;
  final VoidCallback onChanged;

  Future<void> _inviteHost(BuildContext context) async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('دعوة مضيف للوكالة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'SAKI ID للمضيف'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('إرسال الدعوة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await SakiService.instance.hostAgencyInviteHost(value);
      toast('تم إرسال الدعوة. سيظهر للمستخدم إشعار للموافقة أو الإلغاء.');
      onChanged();
    } catch (e) {
      toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final agency = dashboard['agency'] is Map
        ? Map<String, dynamic>.from(dashboard['agency'])
        : const <String, dynamic>{};
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _AgencyHeader(
          agency: agency,
          subtitle: 'إدارة المضيفين والدعوات والإحصائيات',
        ),
        const SizedBox(height: 14),
        _Stats(data: dashboard),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'المضيفون التابعون للوكالة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            FilledButton.icon(
              onPressed: () => _inviteHost(context),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('دعوة مضيف'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (hosts.isEmpty)
          const _EmptyPanel(
            text:
                'لا يوجد مضيفون حالياً. أرسل دعوة إلى مستخدم باستخدام SAKI ID.',
          ),
        ...hosts.map(
          (host) => _HostCard(host: host, onChanged: onChanged, toast: toast),
        ),
      ],
    );
  }
}

class _HostDashboard extends StatefulWidget {
  const _HostDashboard({
    required this.data,
    required this.withdrawals,
    required this.toast,
    required this.onChanged,
  });
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> withdrawals;
  final void Function(String) toast;
  final VoidCallback onChanged;
  @override
  State<_HostDashboard> createState() => _HostDashboardState();
}

class _HostDashboardState extends State<_HostDashboard> {
  final _diamonds = TextEditingController();
  final _usd = TextEditingController();
  bool _working = false;

  @override
  void dispose() {
    _diamonds.dispose();
    _usd.dispose();
    super.dispose();
  }

  Future<void> _convertDiamonds() async {
    final amount = int.tryParse(_diamonds.text.trim()) ?? 0;
    if (amount < 250000) {
      widget.toast('الحد الأدنى للتحويل هو 250,000 ماسة.');
      return;
    }
    setState(() => _working = true);
    try {
      await SakiService.instance.hostAgencyConvertDiamondsToUsd(amount);
      _diamonds.clear();
      widget.toast('تم تحويل الماس إلى رصيد دولار حقيقي داخل محفظة المضيف.');
      widget.onChanged();
    } catch (e) {
      widget.toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _convertUsdToGold() async {
    final amount = double.tryParse(_usd.text.trim()) ?? 0;
    if (amount <= 0) {
      widget.toast('أدخل قيمة دولار صحيحة.');
      return;
    }
    setState(() => _working = true);
    try {
      await SakiService.instance.hostAgencyConvertUsdToGold(amount);
      _usd.clear();
      widget.toast(
        'تم تحويل الدولار إلى عملات ذهبية. لا ينتج عن ذلك ماس أو دولار إضافي.',
      );
      widget.onChanged();
    } catch (e) {
      widget.toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _requestWithdrawal() async {
    final amount = double.tryParse(_usd.text.trim()) ?? 0;
    if (amount <= 0) {
      widget.toast('أدخل قيمة الدولار المطلوب سحبها.');
      return;
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تأكيد طلب السحب'),
        content: Text(
          'سيتم حجز ${amount.toStringAsFixed(2)} دولار وإرسال الطلب إلى وكيل الشحن للمراجعة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد السحب'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    setState(() => _working = true);
    try {
      await SakiService.instance.hostAgencyRequestUsdWithdrawal(amount);
      _usd.clear();
      widget.toast('تم إنشاء طلب السحب وتحويله إلى وكيل الشحن.');
      widget.onChanged();
    } catch (e) {
      widget.toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agency = widget.data['agency'] is Map
        ? Map<String, dynamic>.from(widget.data['agency'])
        : const <String, dynamic>{};
    final diamonds = (widget.data['diamonds'] as num?)?.toInt() ?? 0;
    final gold = (widget.data['gold_coins'] as num?)?.toInt() ?? 0;
    final usd = (widget.data['usd_balance'] as num?)?.toDouble() ?? 0;
    final reserved = (widget.data['usd_reserved'] as num?)?.toDouble() ?? 0;
    final earned = (widget.data['total_usd_earned'] as num?)?.toDouble() ?? 0;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        _AgencyHeader(
          agency: agency,
          subtitle: 'لوحة المضيف • إحصائياتك وأرباحك محفوظة في Supabase',
        ),
        const SizedBox(height: 14),
        _HostMetricGrid(
          diamonds: diamonds,
          usd: usd,
          reserved: reserved,
          gold: gold,
          earned: earned,
        ),
        const SizedBox(height: 18),
        _FinanceCard(
          title: 'تحويل الماس إلى دولار',
          subtitle: 'الماس الموجود في المحفظة فقط هو القابل للتحويل. العملات الذهبية لا تنشئ دولاراً.',
          controller: _diamonds,
          keyboard: TextInputType.number,
          hint: 'مثال: 250000',
          button: 'تحويل إلى دولار',
          icon: Icons.diamond_rounded,
          onPressed: _working ? null : _convertDiamonds,
        ),
        const SizedBox(height: 12),
        _RateCard(),
        const SizedBox(height: 12),
        _FinanceCard(
          title: 'إدارة رصيد الدولار',
          subtitle:
              'كل 1 دولار = 7,500 عملة ذهبية. أو اطلب سحباً إلى وكيل الشحن.',
          controller: _usd,
          keyboard: const TextInputType.numberWithOptions(decimal: true),
          hint: 'مثال: 13',
          button: 'تحويل للذهبيات',
          icon: Icons.account_balance_wallet_rounded,
          onPressed: _working ? null : _convertUsdToGold,
          secondaryButton: 'طلب سحب لوكيل الشحن',
          onSecondaryPressed: _working ? null : _requestWithdrawal,
        ),
        const SizedBox(height: 18),
        const Text(
          'سجل طلبات السحب',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (widget.withdrawals.isEmpty)
          const _EmptyPanel(text: 'لا توجد طلبات سحب حتى الآن.'),
        ...widget.withdrawals.map((row) => _WithdrawalTile(row: row)),
      ],
    );
  }
}

class _AgencyHeader extends StatelessWidget {
  const _AgencyHeader({required this.agency, required this.subtitle});
  final Map<String, dynamic> agency;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: SakiTheme.gradient,
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A7C3AED),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.business_center_rounded,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agency['name']?.toString() ?? 'وكالة المضيفين',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              const SizedBox(height: 4),
              Text(
                'الدولة: ${agency['country'] ?? '—'}  •  كود: ${agency['agent_code'] ?? '—'}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.7,
    children: [
      _Stat('المضيفون', data['host_count'], Icons.people_alt_rounded),
      _Stat(
        'دعوات معلقة',
        data['pending_count'],
        Icons.pending_actions_rounded,
      ),
      _Stat('الغرف النشطة', data['active_rooms'], Icons.mic_rounded),
      _Stat('ماس الهدايا', data['gift_gold'], Icons.diamond_rounded),
    ],
  );
}

class _HostMetricGrid extends StatelessWidget {
  const _HostMetricGrid({
    required this.diamonds,
    required this.usd,
    required this.reserved,
    required this.gold,
    required this.earned,
  });
  final int diamonds;
  final double usd;
  final double reserved;
  final int gold;
  final double earned;
  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    crossAxisSpacing: 10,
    mainAxisSpacing: 10,
    childAspectRatio: 1.35,
    children: [
      _MetricCard(
        'الماس',
        _compact(diamonds),
        Icons.diamond_rounded,
        const Color(0xFF06B6D4),
      ),
      _MetricCard(
        'الدولار المتاح',
        '\$${usd.toStringAsFixed(2)}',
        Icons.attach_money_rounded,
        const Color(0xFF16A34A),
      ),
      _MetricCard(
        'محجوز للسحب',
        '\$${reserved.toStringAsFixed(2)}',
        Icons.lock_clock_rounded,
        const Color(0xFFF59E0B),
      ),
      _MetricCard(
        'ذهبيات',
        _compact(gold),
        Icons.monetization_on_rounded,
        const Color(0xFFF97316),
      ),
      _MetricCard(
        'إجمالي المكتسب',
        '\$${earned.toStringAsFixed(2)}',
        Icons.insights_rounded,
        const Color(0xFF7C3AED),
      ),
    ],
  );
  static String _compact(int value) => value >= 1000000
      ? '${(value / 1000000).toStringAsFixed(1)}M'
      : value >= 1000
      ? '${(value / 1000).toStringAsFixed(1)}K'
      : '$value';
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.title, this.value, this.icon, this.color);
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: color.withValues(alpha: .16)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: SakiColors.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _FinanceCard extends StatelessWidget {
  const _FinanceCard({
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.keyboard,
    required this.hint,
    required this.button,
    required this.icon,
    required this.onPressed,
    this.secondaryButton,
    this.onSecondaryPressed,
  });
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final TextInputType keyboard;
  final String hint;
  final String button;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? secondaryButton;
  final VoidCallback? onSecondaryPressed;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: SakiColors.cyan.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: SakiColors.cyan),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          style: const TextStyle(
            color: SakiColors.muted,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(13),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton(onPressed: onPressed, child: Text(button)),
            ),
            if (secondaryButton != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondaryPressed,
                  child: Text(secondaryButton!, textAlign: TextAlign.center),
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

class _RateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'جدول التحويل الرسمي',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Rate('250K', '\$13'),
            _Rate('500K', '\$26'),
            _Rate('1M', '\$52'),
            _Rate('2M', '\$102'),
          ],
        ),
      ],
    ),
  );
}

class _Rate extends StatelessWidget {
  const _Rate(this.diamonds, this.usd);
  final String diamonds;
  final String usd;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        diamonds,
        style: const TextStyle(
          color: Color(0xFF67E8F9),
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        usd,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    ],
  );
}

class _HostCard extends StatelessWidget {
  const _HostCard({
    required this.host,
    required this.onChanged,
    required this.toast,
  });
  final Map<String, dynamic> host;
  final VoidCallback onChanged;
  final void Function(String) toast;
  @override
  Widget build(BuildContext context) {
    final status = host['status']?.toString() ?? 'active';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: host['avatar_url']?.toString().isNotEmpty == true
              ? NetworkImage(host['avatar_url'].toString())
              : null,
          child: host['avatar_url']?.toString().isNotEmpty == true
              ? null
              : const Icon(Icons.person_rounded),
        ),
        title: Text(
          host['display_name']?.toString().isNotEmpty == true
              ? host['display_name'].toString()
              : host['username']?.toString() ?? 'مضيف',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          'SAKI ID: ${host['saki_id'] ?? '—'} • الحالة: $status\nمضيف حقيقي في الوكالة',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            try {
              if (value == 'remove') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('حذف المضيف'),
                    content: const Text(
                      'سيتم إخراج هذا المستخدم من الوكالة فعلياً.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('حذف'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await SakiService.instance.hostAgencyRemoveHost(
                  host['user_id'].toString(),
                );
                toast('تم حذف المضيف من الوكالة.');
              } else {
                await SakiService.instance.hostAgencySetHostStatus(
                  host['user_id'].toString(),
                  value,
                );
                toast(
                  value == 'suspended'
                      ? 'تم تعليق المضيف.'
                      : 'تم تفعيل المضيف.',
                );
              }
              onChanged();
            } catch (e) {
              toast(e.toString().replaceFirst('Exception: ', ''));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'active', child: Text('تفعيل')),
            PopupMenuItem(value: 'suspended', child: Text('تعليق')),
            PopupMenuItem(value: 'remove', child: Text('حذف من الوكالة')),
          ],
        ),
      ),
    );
  }
}

class _WithdrawalTile extends StatelessWidget {
  const _WithdrawalTile({required this.row});
  final Map<String, dynamic> row;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(
        Icons.local_shipping_rounded,
        color: SakiColors.orange,
      ),
      title: Text(
        '\$${row['usd_amount'] ?? 0} إلى وكيل الشحن',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text('الحالة: ${_status(row['status'])}'),
      trailing: Text(
        (row['created_at']?.toString() ?? '').split('T').first,
        style: const TextStyle(fontSize: 10, color: SakiColors.muted),
      ),
    ),
  );
  static String _status(dynamic value) => switch (value?.toString()) {
    'pending' => 'قيد المراجعة',
    'approved' => 'مقبول',
    'paid' => 'تم الدفع',
    'rejected' => 'مرفوض',
    'cancelled' => 'ملغى',
    _ => 'غير معروف',
  };
}

class _Stat extends StatelessWidget {
  const _Stat(this.title, this.value, this.icon);
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
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${value ?? 0}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
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

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: SakiColors.line),
    ),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: SakiColors.muted),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'لا توجد وكالة مضيفين مرتبطة بهذا الحساب.\n$message',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
