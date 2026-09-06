import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

const _adminBlue = Color(0xFF4F46E5);
const _adminCyan = Color(0xFF06B6D4);

class AdminAgenciesPage extends StatefulWidget {
  const AdminAgenciesPage({super.key});
  @override
  State<AdminAgenciesPage> createState() => _AdminAgenciesPageState();
}

class _AdminAgenciesPageState extends State<AdminAgenciesPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = SakiService.instance.adminAgencies();
  }

  void _reload() =>
      setState(() => _future = SakiService.instance.adminAgencies());
  @override
  Widget build(BuildContext context) => _AdminRecordsScaffold(
    title: 'إدارة الوكالات',
    icon: Icons.business_rounded,
    future: _future,
    empty: 'لا توجد وكالات مسجلة حاليًا.',
    onRefresh: _reload,
    itemBuilder: (row) => _AdminRecordCard(
      icon: Icons.business_rounded,
      title: row['name'] as String? ?? 'وكالة',
      subtitle:
          'كود الوكالة: ${row['agent_code'] ?? '—'}\nالحالة: ${row['status'] ?? '—'}',
      status: row['status'] as String?,
      onStatus: (status) async {
        await SakiService.instance.adminSetAgencyStatus(
          row['id'] as String,
          status,
        );
        _reload();
      },
    ),
  );
}

class AdminFamiliesPage extends StatefulWidget {
  const AdminFamiliesPage({super.key});
  @override
  State<AdminFamiliesPage> createState() => _AdminFamiliesPageState();
}

class _AdminFamiliesPageState extends State<AdminFamiliesPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = SakiService.instance.adminFamilies();
  }

  void _reload() =>
      setState(() => _future = SakiService.instance.adminFamilies());
  @override
  Widget build(BuildContext context) => _AdminRecordsScaffold(
    title: 'إدارة العائلات',
    icon: Icons.groups_rounded,
    future: _future,
    empty: 'لا توجد عائلات مسجلة حاليًا.',
    onRefresh: _reload,
    itemBuilder: (row) => _AdminRecordCard(
      icon: Icons.groups_rounded,
      title: row['name'] as String? ?? 'عائلة',
      subtitle:
          'كود الدعوة: ${row['invite_code'] ?? '—'}\nالحالة: ${row['status'] ?? '—'}',
      status: row['status'] as String?,
      onStatus: (status) async {
        await SakiService.instance.adminSetFamilyStatus(
          row['id'] as String,
          status,
        );
        _reload();
      },
    ),
  );
}

class AdminLevelsPage extends StatefulWidget {
  const AdminLevelsPage({super.key});
  @override
  State<AdminLevelsPage> createState() => _AdminLevelsPageState();
}

class _AdminLevelsPageState extends State<AdminLevelsPage> {
  late Future<List<Map<String, dynamic>>> _future;
  @override
  void initState() {
    super.initState();
    _future = SakiService.instance.adminLevels();
  }

  @override
  Widget build(BuildContext context) => _AdminRecordsScaffold(
    title: 'إدارة المستويات والجوائز',
    icon: Icons.military_tech_rounded,
    future: _future,
    empty: 'لا توجد جوائز مستويات.',
    onRefresh: () =>
        setState(() => _future = SakiService.instance.adminLevels()),
    itemBuilder: (row) => _AdminRecordCard(
      icon: Icons.military_tech_rounded,
      title: 'المستوى ${row['level'] ?? '—'} — ${row['title'] ?? ''}',
      subtitle:
          '${row['description'] ?? ''}\n${row['reward_type'] ?? ''}: ${row['reward_value'] ?? ''}',
      status: null,
    ),
  );
}

class _AdminRecordsScaffold extends StatelessWidget {
  const _AdminRecordsScaffold({
    required this.title,
    required this.icon,
    required this.future,
    required this.empty,
    required this.itemBuilder,
    required this.onRefresh,
  });
  final String title, empty;
  final IconData icon;
  final Future<List<Map<String, dynamic>>> future;
  final Widget Function(Map<String, dynamic>) itemBuilder;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        IconButton(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (_, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('تعذر تحميل البيانات: ${snapshot.error}'),
            ),
          );
        final rows = snapshot.data ?? const <Map<String, dynamic>>[];
        if (rows.isEmpty) return Center(child: Text(empty));
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => itemBuilder(rows[i]),
        );
      },
    ),
  );
}

class _AdminRecordCard extends StatelessWidget {
  const _AdminRecordCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.onStatus,
  });
  final IconData icon;
  final String title, subtitle;
  final String? status;
  final Future<void> Function(String status)? onStatus;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: _adminCyan.withValues(alpha: .14),
            child: Icon(icon, color: _adminBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          if (onStatus != null)
            PopupMenuButton<String>(
              onSelected: onStatus,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'active', child: Text('تفعيل')),
                PopupMenuItem(value: 'suspended', child: Text('تعليق')),
                PopupMenuItem(value: 'closed', child: Text('إغلاق')),
              ],
            ),
        ],
      ),
    ),
  );
}
