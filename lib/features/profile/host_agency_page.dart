import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';

class HostAgencyPage extends StatefulWidget {
  const HostAgencyPage({super.key});
  @override
  State<HostAgencyPage> createState() => _HostAgencyPageState();
}

class _HostAgencyPageState extends State<HostAgencyPage> {
  Map<String, dynamic>? _dashboard;
  List<Map<String, dynamic>> _hosts = [];
  bool _loading = true;
  String? _error;

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
      final result = await Future.wait<dynamic>([
        SakiService.instance.hostAgencyDashboard(),
        SakiService.instance.hostAgencyHosts(),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = Map<String, dynamic>.from(result[0] as Map);
        _hosts = List<Map<String, dynamic>>.from(result[1] as List);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addHost() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة مضيف'),
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
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await SakiService.instance.hostAgencyAddHost(value);
      await _load();
      if (mounted) _toast('تمت إضافة المضيف بنجاح');
    } catch (e) {
      if (mounted) _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final agency = _dashboard?['agency'] is Map
        ? Map<String, dynamic>.from(_dashboard!['agency'])
        : const <String, dynamic>{};
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('وكالة المضيفين'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: _error == null && !_loading
          ? FloatingActionButton.extended(
              onPressed: _addHost,
              backgroundColor: SakiColors.orange,
              icon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'إضافة مضيف',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SakiColors.orange),
            )
          : _error != null
          ? _ErrorState(message: _error!)
          : RefreshIndicator(
              color: SakiColors.orange,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  _AgencyHeader(agency: agency),
                  const SizedBox(height: 14),
                  _Stats(data: _dashboard ?? const {}),
                  const SizedBox(height: 20),
                  const Text(
                    'المضيفون التابعون للوكالة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  if (_hosts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                        child: Text(
                          'لم تتم إضافة مضيفين بعد. اضغط إضافة مضيف للبدء.',
                        ),
                      ),
                    ),
                  ..._hosts.map(
                    (host) =>
                        _HostCard(host: host, onChanged: _load, toast: _toast),
                  ),
                ],
              ),
            ),
    );
  }
}

class _AgencyHeader extends StatelessWidget {
  const _AgencyHeader({required this.agency});
  final Map<String, dynamic> agency;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: SakiTheme.gradient,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        const Icon(Icons.business_rounded, color: Colors.white, size: 42),
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
              const SizedBox(height: 6),
              Text(
                'الدولة: ${agency['country'] ?? '—'}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'كود الوكالة: ${agency['agent_code'] ?? '—'}',
                style: const TextStyle(color: Colors.white70),
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
        'قيد المراجعة',
        data['pending_count'],
        Icons.pending_actions_rounded,
      ),
      _Stat('الغرف النشطة', data['active_rooms'], Icons.mic_rounded),
      _Stat('ذهب الهدايا', data['gift_gold'], Icons.diamond_rounded),
    ],
  );
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: (host['avatar_url']?.toString().isNotEmpty ?? false)
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
          'SAKI ID: ${host['saki_id'] ?? '—'} • ${host['country'] ?? '—'}\nالحالة: $status • VIP ${host['vip_level'] ?? 0}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            try {
              await SakiService.instance.hostAgencySetHostStatus(
                host['user_id'].toString(),
                value,
              );
              onChanged();
            } catch (e) {
              toast(e.toString().replaceFirst('Exception: ', ''));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'active', child: Text('تفعيل')),
            PopupMenuItem(value: 'suspended', child: Text('تعليق')),
            PopupMenuItem(value: 'left', child: Text('إزالة من الوكالة')),
          ],
        ),
      ),
    );
  }
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
