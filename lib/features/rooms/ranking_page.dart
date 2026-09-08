import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

const _ink = Color(0xFF171426);
const _violet = Color(0xFF6D4AFF);
const _gold = Color(0xFFF3B83F);
const _pink = Color(0xFFE9578F);
const _cyan = Color(0xFF22C7D7);

class RankingPage extends StatefulWidget {
  const RankingPage({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  late final PageController _pages;
  late int _tab;
  String _period = 'daily';

  @override
  void initState() {
    super.initState();
    _tab = widget.initialIndex.clamp(0, 2);
    _pages = PageController(initialPage: _tab);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<Object> _load() {
    if (_tab == 0) return SakiService.instance.globalWealthRanking(_period);
    if (_tab == 1) return SakiService.instance.globalCharmRanking(_period);
    return SakiService.instance.globalRoomRanking(_period);
  }

  String get _periodLabel => switch (_period) {
    'weekly' => 'هذا الأسبوع',
    'monthly' => 'هذا الشهر',
    _ => 'اليوم',
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _ink,
    body: SafeArea(
      child: Column(
        children: [
          _RankingHeader(onBack: () => Navigator.pop(context)),
          _CustomTabs(selected: _tab, onSelected: _selectTab),
          _PeriodTabs(
            selected: _period,
            onSelected: (value) => setState(() => _period = value),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              physics: const BouncingScrollPhysics(),
              itemCount: 3,
              onPageChanged: (value) => setState(() => _tab = value),
              itemBuilder: (_, index) => FutureBuilder<Object>(
                future: _load(),
                builder: (_, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const _RankLoading();
                  }
                  if (snapshot.hasError) {
                    return _RankEmpty(onRetry: () => setState(() {}));
                  }
                  final rows = snapshot.data is List
                      ? List<Map<String, dynamic>>.from(snapshot.data as List)
                      : const <Map<String, dynamic>>[];
                  return _RankingBody(
                    rows: rows,
                    tab: _tab,
                    periodLabel: _periodLabel,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RankingHeader extends StatelessWidget {
  const _RankingHeader({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        const Expanded(
          child: Column(
            children: [
              Text(
                'لوحة المتصدرين',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'إنجازات مجتمع SAKI',
                style: TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: .13),
            shape: BoxShape.circle,
            border: Border.all(color: _gold.withValues(alpha: .35)),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: _gold, size: 18),
        ),
      ],
    ),
  );
}

class _CustomTabs extends StatelessWidget {
  const _CustomTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;
  static const _items = [
    ('الثروة', Icons.bolt_rounded, _gold),
    ('السحر', Icons.favorite_rounded, _pink),
    ('الغرف', Icons.mic_external_on_rounded, _cyan),
  ];
  @override
  Widget build(BuildContext context) => Container(
    height: 62,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: Row(
      children: List.generate(_items.length, (index) {
        final item = _items[index];
        final active = selected == index;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: active
                    ? item.$3.withValues(alpha: .18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: active
                      ? item.$3.withValues(alpha: .6)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.$2,
                    color: active ? item.$3 : Colors.white38,
                    size: 17,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.$1,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ),
  );
}

class _PeriodTabs extends StatelessWidget {
  const _PeriodTabs({required this.selected, required this.onSelected});
  final String selected;
  final ValueChanged<String> onSelected;
  static const _items = [
    ('daily', 'يومي'),
    ('weekly', 'أسبوعي'),
    ('monthly', 'شهري'),
  ];
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
    child: Row(
      children: _items.map((item) {
        final active = selected == item.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(item.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white
                    : Colors.white.withValues(alpha: .045),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  color: active ? _ink : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

class _RankingBody extends StatelessWidget {
  const _RankingBody({
    required this.rows,
    required this.tab,
    required this.periodLabel,
  });
  final List<Map<String, dynamic>> rows;
  final int tab;
  final String periodLabel;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _RankEmpty();
    final top = rows.take(3).toList();
    final rest = rows.length > 3
        ? rows.sublist(3)
        : const <Map<String, dynamic>>[];
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _HeroPodium(rows: top, tab: tab, periodLabel: periodLabel),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, index) =>
                  _RankRow(row: rest[index], rank: index + 4, tab: tab),
              childCount: rest.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroPodium extends StatelessWidget {
  const _HeroPodium({
    required this.rows,
    required this.tab,
    required this.periodLabel,
  });
  final List<Map<String, dynamic>> rows;
  final int tab;
  final String periodLabel;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF31245D), Color(0xFF171329)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: _gold.withValues(alpha: .24)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'المتصدرون الآن',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              periodLabel,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 188,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _PodiumTile(
                row: rows.length > 1 ? rows[1] : null,
                rank: 2,
                tab: tab,
                height: 128,
              ),
              const SizedBox(width: 8),
              _PodiumTile(
                row: rows.isNotEmpty ? rows[0] : null,
                rank: 1,
                tab: tab,
                height: 164,
              ),
              const SizedBox(width: 8),
              _PodiumTile(
                row: rows.length > 2 ? rows[2] : null,
                rank: 3,
                tab: tab,
                height: 112,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PodiumTile extends StatelessWidget {
  const _PodiumTile({
    required this.row,
    required this.rank,
    required this.tab,
    required this.height,
  });
  final Map<String, dynamic>? row;
  final int rank;
  final int tab;
  final double height;
  @override
  Widget build(BuildContext context) {
    final profile = Map<String, dynamic>.from(
      row?['profiles'] ?? row ?? const {},
    );
    final accent = rank == 1
        ? _gold
        : rank == 2
        ? const Color(0xFFD9E2F2)
        : const Color(0xFFCD8A57);
    return SizedBox(
      width: 94,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rank == 1)
            const Icon(Icons.workspace_premium_rounded, color: _gold, size: 22),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              SakiAvatar(
                url: profile['avatar_url'] as String?,
                label: profile['username'] as String?,
                radius: rank == 1 ? 34 : 27,
              ),
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: _ink, width: 2),
                ),
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            profile['username'] as String? ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _value(row, tab),
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.row, required this.rank, required this.tab});
  final Map<String, dynamic> row;
  final int rank;
  final int tab;
  @override
  Widget build(BuildContext context) {
    final isRoom = tab == 2;
    final profile = isRoom
        ? row
        : Map<String, dynamic>.from(row['profiles'] ?? row);
    final title = isRoom
        ? (row['name'] as String? ?? 'غرفة SAKI')
        : (profile['username'] as String? ?? 'مستخدم');
    final image = isRoom
        ? row['image_url'] as String?
        : profile['avatar_url'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 27,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 9),
          isRoom
              ? _RoomAvatar(url: image)
              : SakiAvatar(url: image, label: title, radius: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isRoom
                      ? 'أعلى إرسال هدايا في الغرف'
                      : tab == 0
                      ? 'أعلى إرسال هدايا ذهبية'
                      : 'أعلى استقبال هدايا ذهبية',
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            _value(row, tab),
            style: TextStyle(
              color: tab == 0
                  ? _gold
                  : tab == 1
                  ? _pink
                  : _cyan,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({this.url});
  final String? url;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(15),
      color: _cyan.withValues(alpha: .15),
    ),
    child: url != null && url!.startsWith('http')
        ? ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.network(url!, fit: BoxFit.cover),
          )
        : const Icon(Icons.meeting_room_rounded, color: _cyan),
  );
}

class _RankLoading extends StatelessWidget {
  const _RankLoading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: _gold));
}

class _RankEmpty extends StatelessWidget {
  const _RankEmpty({this.onRetry});
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 62),
        const SizedBox(height: 12),
        const Text(
          'لا توجد بيانات ترتيب بعد',
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(color: _gold, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ],
    ),
  );
}

String _value(Map<String, dynamic>? row, int tab) {
  final value = row == null ? 0 : (row['total_gold'] ?? 0);
  final number = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  if (number >= 1000000) return '${(number / 1000000).toStringAsFixed(1)}M ذهب';
  if (number >= 1000) return '${(number / 1000).toStringAsFixed(1)}K ذهب';
  return '${number.toInt()} ذهب';
}
