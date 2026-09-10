import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

class AdminShippingAgentsPage extends StatefulWidget {
  const AdminShippingAgentsPage({super.key});
  @override
  State<AdminShippingAgentsPage> createState() =>
      _AdminShippingAgentsPageState();
}

class _AdminShippingAgentsPageState extends State<AdminShippingAgentsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = SakiService.instance.adminShippingAgents();

  Future<void> _assign() async {
    final controller = TextEditingController();
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _IdSheet(controller: controller, title: 'تعيين وكيل شحن'),
    );
    controller.dispose();
    if (id == null) return;
    try {
      await SakiService.instance.adminAssignShippingAgent(id);
      setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _addCoins(Map<String, dynamic> row) async {
    final controller = TextEditingController();
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة عملة ساكي'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'الكمية'),
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
    if (amount == null || amount <= 0) return;
    try {
      await SakiService.instance.adminAddSakiCoins(
        row['user_id'].toString(),
        amount,
      );
      setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'إدارة وكلاء الشحن',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      actions: [
        IconButton(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _assign,
      icon: const Icon(Icons.add_rounded),
      label: const Text('إضافة وكيل شحن'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: SakiLoading());
        }
        if (snap.hasError) {
          return Center(child: Text('تعذر التحميل: ${snap.error}'));
        }
        final rows = snap.data ?? [];
        if (rows.isEmpty) {
          return const Center(child: Text('لا يوجد وكلاء شحن معيّنون'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final row = rows[i];
            return Card(
              child: ListTile(
                leading: SakiAvatar(
                  url: row['avatar_url'] as String?,
                  label: row['username']?.toString() ?? 'وكيل',
                ),
                title: Text(
                  row['username']?.toString() ?? 'وكيل شحن',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Saki ID: ${row['saki_id']}\nعملة ساكي: ${row['saki_coins']}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'add') await _addCoins(row);
                    if (v == 'remove') {
                      await SakiService.instance.adminRemoveShippingAgent(
                        row['user_id'].toString(),
                      );
                      setState(_reload);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'add', child: Text('إضافة عملة ساكي')),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        'حذف/إلغاء التعيين',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _IdSheet extends StatelessWidget {
  const _IdSheet({required this.controller, required this.title});
  final TextEditingController controller;
  final String title;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        18,
        18,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Saki ID الحقيقي',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('تعيين وكيل الشحن'),
          ),
        ],
      ),
    ),
  );
}
