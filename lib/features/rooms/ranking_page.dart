import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key, required this.initialIndex});
  final int initialIndex;
  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialIndex,
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F7),
    appBar: AppBar(
      title: const Text('الترتيب'),
      bottom: TabBar(
        controller: _tabs,
        tabs: const [
          Tab(text: 'الثروة'),
          Tab(text: 'السحر'),
          Tab(text: 'الغرف'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        _userRanking('gold_coins', SakiService.instance.wealthRanking()),
        _userRanking('diamonds', SakiService.instance.charmRanking()),
        _roomRanking(),
      ],
    ),
  );

  Widget _userRanking(
    String field,
    Future<List<Map<String, dynamic>>> future,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (_, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final profile = Map<String, dynamic>.from(
            rows[index]['profiles'] ?? const <String, dynamic>{},
          );
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: VipUsername(profile: profile),
              subtitle: Text(
                field == 'gold_coins' ? 'ترتيب الثروة' : 'ترتيب السحر',
              ),
              trailing: Text(
                '${rows[index][field] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          );
        },
      );
    },
  );

  Widget _roomRanking() => FutureBuilder<List<Map<String, dynamic>>>(
    future: SakiService.instance.roomRanking(),
    builder: (_, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      final rows = snapshot.data ?? const <Map<String, dynamic>>[];
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final members = rows[index]['room_members'];
          final count = members is List && members.isNotEmpty
              ? (members.first['count'] ?? 0)
              : 0;
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(rows[index]['name'] as String? ?? 'غرفة'),
              subtitle: Text('Room ID: ${rows[index]['room_id'] ?? ''}'),
              trailing: Text(
                '$count متصل',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          );
        },
      );
    },
  );
}
