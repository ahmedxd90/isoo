import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../profile/user_profile_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _query = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;

  void _search(String value) {
    final term = value.trim();
    setState(
      () =>
          _future = term.isEmpty ? null : SakiService.instance.searchAll(term),
    );
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بحث', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _query,
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'ابحث عن أشخاص أو منشورات أو غرف',
              ),
            ),
          ),
          Expanded(
            child: _future == null
                ? const EmptyState(
                    icon: Icons.search_rounded,
                    title: 'ابدأ البحث',
                    subtitle: 'اكتب اسمًا أو كلمة للعثور على محتوى SAKI.',
                  )
                : FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (_, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const SakiLoading(label: 'جاري البحث...');
                      if (snapshot.hasError)
                        return const EmptyState(
                          icon: Icons.cloud_off_rounded,
                          title: 'تعذر تنفيذ البحث',
                          subtitle: 'حاول مرة أخرى.',
                        );
                      final results = snapshot.data ?? [];
                      if (results.isEmpty)
                        return const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'لا توجد نتائج',
                          subtitle: 'جرّب كلمة بحث مختلفة.',
                        );
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: results.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, index) =>
                            _ResultTile(result: results[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.result});
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final kind = result['_kind'] as String?;
    final profile = Map<String, dynamic>.from(result['profiles'] ?? const {});
    final title = kind == 'profile'
        ? result['username'] as String? ?? 'حساب'
        : kind == 'room'
        ? result['name'] as String? ?? 'غرفة'
        : (result['content'] as String? ?? 'منشور');
    final subtitle = kind == 'profile'
        ? 'SAKI ID ${result['saki_id'] ?? '—'}'
        : kind == 'room'
        ? 'Room ID ${result['room_id'] ?? '—'} · ${profile['username'] ?? 'host'}'
        : '${profile['username'] ?? 'مستخدم'} · منشور عام';
    return Card(
      child: ListTile(
        onTap: kind == 'profile' && result['id'] is String
            ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      UserProfilePage(userId: result['id'] as String),
                ),
              )
            : null,
        leading: kind == 'profile'
            ? SakiAvatar(url: result['avatar_url'] as String?, label: title)
            : const GradientIconBadge(icon: Icons.search_rounded),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: SakiColors.muted),
        ),
        trailing: Icon(
          kind == 'room'
              ? Icons.mic_rounded
              : kind == 'post'
              ? Icons.article_outlined
              : Icons.person_outline_rounded,
          color: SakiColors.cyan,
        ),
      ),
    );
  }
}
