import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/custom_toast.dart';
import '../../shared/widgets/saki_widgets.dart';

class FamilyDiamondHostPage extends StatefulWidget {
  const FamilyDiamondHostPage({
    super.key,
    required this.family,
    required this.members,
  });
  final Map<String, dynamic> family;
  final List<Map<String, dynamic>> members;

  @override
  State<FamilyDiamondHostPage> createState() => _FamilyDiamondHostPageState();
}

class _FamilyDiamondHostPageState extends State<FamilyDiamondHostPage> {
  final _service = SakiService.instance;
  Map<String, dynamic>? _agent;
  String? _source;
  int? _diamonds;
  bool _busy = false;

  static const packages = <Map<String, int>>[
    {'diamonds': 13000000, 'usd': 10},
    {'diamonds': 26000000, 'usd': 20},
    {'diamonds': 50000000, 'usd': 40},
    {'diamonds': 100000000, 'usd': 80},
    {'diamonds': 200000000, 'usd': 160},
  ];

  String _number(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}M';
    }
    return '$value';
  }

  Future<void> _findAgent() async {
    final controller = TextEditingController();
    var results = <Map<String, dynamic>>[];
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'البحث عن وكيل شحن فقط',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'اسم المستخدم أو Saki ID',
                ),
                onChanged: (value) async {
                  results = await _service.searchShippingAgents(value);
                  if (context.mounted) setSheet(() {});
                },
              ),
              const SizedBox(height: 10),
              if (results.isEmpty)
                const Text(
                  'اكتب للبحث عن الوكلاء النشطين',
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ...results.map(
                (agent) => ListTile(
                  leading: SakiAvatar(
                    url: agent['avatar_url']?.toString(),
                    label: agent['username']?.toString(),
                    radius: 22,
                  ),
                  title: Text(agent['username']?.toString() ?? 'وكيل'),
                  subtitle: Text('Saki ID: ${agent['saki_id'] ?? '—'}'),
                  trailing: const Icon(Icons.verified, color: Colors.blue),
                  onTap: () => Navigator.pop(sheetContext, agent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (selected != null && mounted) setState(() => _agent = selected);
  }

  Future<void> _transfer() async {
    final agent = _agent;
    final source = _source;
    final diamonds = _diamonds;
    if (agent == null || source == null || diamonds == null) {
      CustomToast.show(context, 'اختر العضو والوكيل والباقه أولاً');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _service.transferFamilyDiamondsToAgent(
        familyId: widget.family['id'].toString(),
        sourceUserId: source,
        agentId: agent['user_id'].toString(),
        diamonds: diamonds,
      );
      if (mounted) {
        CustomToast.show(
          context,
          'تم تحويل ${result['usd']} دولار وإضافة ${result['saki_coins']} عملات SAKI للوكيل',
        );
        setState(() {
          _diamonds = null;
          _agent = null;
        });
      }
    } catch (error) {
      if (mounted) {
        CustomToast.show(
          context,
          error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.members
        .where((m) => m['status'] == null || m['status'] == 'active')
        .toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('مضيف العائلة'),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.diamond_rounded),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.family['name']?.toString() ?? 'عائلتي',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'تحويل الماس إلى وكيل الشحن',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _source,
            decoration: const InputDecoration(
              labelText: 'صاحب رصيد الماس',
              border: OutlineInputBorder(),
            ),
            items: active.map((member) {
              final profile = member['profiles'] is Map
                  ? Map<String, dynamic>.from(member['profiles'])
                  : member;
              final id =
                  profile['id']?.toString() ??
                  member['user_id']?.toString() ??
                  '';
              return DropdownMenuItem(
                value: id,
                child: Text(profile['username']?.toString() ?? 'عضو'),
              );
            }).toList(),
            onChanged: (value) => setState(() => _source = value),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _findAgent,
            icon: const Icon(Icons.search),
            label: Text(
              _agent == null
                  ? 'بحث عن وكيل شحن'
                  : 'الوكيل: ${_agent!['username']}',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: packages
                .map(
                  (pack) => ChoiceChip(
                    selected: _diamonds == pack['diamonds'],
                    label: Text(
                      '${_number(pack['diamonds']!)} = ${pack['usd']} دولار',
                    ),
                    onSelected: (_) =>
                        setState(() => _diamonds = pack['diamonds']),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _transfer,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send),
            label: const Text('تحويل الماس وإرسال إشعار'),
          ),
          const SizedBox(height: 12),
          const Text(
            'المسموح للمنظم فقط • يضاف 7٪ لمالك العائلة • 10 دولارات = 10 عملات SAKI للوكيل',
            style: TextStyle(color: Colors.blueGrey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
