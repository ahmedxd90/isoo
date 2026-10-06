import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

const _pageInk = Color(0xFF090912);
const _gold = Color(0xFFFFD369);
const _silver = Color(0xFFDDE8F7);
const _bronze = Color(0xFFE6A276);

class RankingPage extends StatefulWidget {
  const RankingPage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  late final PageController _pages;
  late final Future<Map<String, dynamic>?> _myProfile;
  late final Future<Map<String, dynamic>?> _myRoom;
  late int _tab;
  String _period = 'daily';
  final Map<String, Future<List<Map<String, dynamic>>>> _loads = {};

  static const _periods = [
    ('daily', 'يومي'),
    ('weekly', 'أسبوعي'),
    ('monthly', 'شهري'),
  ];

  static const _themes = [
    _RankTheme(
      tab: 'الثروة',
      title: 'ترتيب الثروة',
      subtitle: 'الأكثر إرسالًا للهدايا الذهبية',
      icon: Icons.diamond_rounded,
      accent: Color(0xFFFFD369),
      secondary: Color(0xFFC27331),
      background: 'assets/leaderboard_ui/wealth_bg.webp',
    ),
    _RankTheme(
      tab: 'السحر',
      title: 'ترتيب السحر',
      subtitle: 'الأكثر استقبالًا للهدايا الذهبية',
      icon: Icons.auto_awesome_rounded,
      accent: Color(0xFFF2A7FF),
      secondary: Color(0xFF9D4EDD),
      background: 'assets/leaderboard_ui/charm_bg.webp',
    ),
    _RankTheme(
      tab: 'الغرف',
      title: 'ترتيب الغرف',
      subtitle: 'الغرف الأكثر استقبالًا للهدايا الذهبية',
      icon: Icons.graphic_eq_rounded,
      accent: Color(0xFF8BE7F1),
      secondary: Color(0xFF267D9A),
      background: 'assets/leaderboard_ui/rooms_bg.webp',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tab = widget.initialIndex.clamp(0, 2);
    _pages = PageController(initialPage: _tab);
    _myProfile = SakiService.instance.myProfile();
    _myRoom = SakiService.instance.myOwnedRoom();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  _RankTheme get _theme => _themes[_tab];

  Future<List<Map<String, dynamic>>> _loadFor(int tab, String period) {
    final key = '$tab:$period';
    return _loads.putIfAbsent(key, () {
      if (tab == 2) return SakiService.instance.globalRoomRanking(period);
      return SakiService.instance.globalGiftUserLeaderboard(
        period,
        mode: tab == 0 ? 'wealth' : 'charm',
      );
    });
  }

  Future<void> _refresh(int tab) async {
    final key = '$tab:$_period';
    late final Future<List<Map<String, dynamic>>> request;
    setState(() {
      _loads.remove(key);
      request = _loadFor(tab, _period);
    });
    try {
      await request;
    } catch (_) {}
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
    _pages.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _pageInk,
    body: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            _theme.background,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const ColoredBox(color: _pageInk),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _pageInk.withValues(alpha: .66),
                  _pageInk.withValues(alpha: .88),
                  _pageInk,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _RankingHeader(onBack: () => Navigator.pop(context)),
              _CategoryTabs(selected: _tab, onSelected: _selectTab),
              _PeriodTabs(
                selected: _period,
                accent: _theme.accent,
                items: _periods,
                onSelected: (period) => setState(() => _period = period),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _themes.length,
                  onPageChanged: (value) => setState(() => _tab = value),
                  itemBuilder: (context, index) =>
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: _loadFor(index, _period),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const _RankLoading();
                          }
                          if (snapshot.hasError) {
                            return _RankError(onRetry: () => _refresh(index));
                          }
                          return _RankingBody(
                            rows: snapshot.data ?? const [],
                            theme: _themes[index],
                            periodLabel: _periodLabel(_period),
                            onRefresh: () => _refresh(index),
                          );
                        },
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: _CurrentRankBar(
        tab: _tab,
        theme: _theme,
        rows: _loadFor(_tab, _period),
        myProfile: _myProfile,
        myRoom: _myRoom,
      ),
    ),
  );

  String _periodLabel(String value) => switch (value) {
    'weekly' => 'آخر 7 أيام',
    'monthly' => 'آخر 30 يومًا',
    _ => 'اليوم',
  };
}

class _RankTheme {
  const _RankTheme({
    required this.tab,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.secondary,
    required this.background,
  });

  final String tab;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Color secondary;
  final String background;
}

class _RankingHeader extends StatelessWidget {
  const _RankingHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      children: [
        _CircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
        const Expanded(
          child: Column(
            children: [
              Text(
                'لوحة الترتيب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'متصدرون حقيقيون من هدايا الغرف',
                style: TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 40),
      ],
    ),
  );
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .08),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    ),
  );
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  static const _items = [
    ('الثروة', Icons.diamond_rounded, Color(0xFFFFD369)),
    ('السحر', Icons.auto_awesome_rounded, Color(0xFFF2A7FF)),
    ('الغرف', Icons.graphic_eq_rounded, Color(0xFF8BE7F1)),
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xCC11111D),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white12),
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
                    ? item.$3.withValues(alpha: .17)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active
                      ? item.$3.withValues(alpha: .65)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.$2,
                    color: active ? item.$3 : Colors.white54,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.$1,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white60,
                      fontSize: 11,
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
  const _PeriodTabs({
    required this.selected,
    required this.accent,
    required this.items,
    required this.onSelected,
  });

  final String selected;
  final Color accent;
  final List<(String, String)> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 5),
    child: Row(
      children: items.map((item) {
        final active = selected == item.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelected(item.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? accent : Colors.white.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? Colors.white.withValues(alpha: .65)
                      : Colors.white10,
                ),
              ),
              child: Text(
                item.$2,
                style: TextStyle(
                  color: active ? _pageInk : Colors.white70,
                  fontSize: 10,
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
    required this.theme,
    required this.periodLabel,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> rows;
  final _RankTheme theme;
  final String periodLabel;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final ranked = rows.where((row) => _rank(row) <= 100).toList()
      ..sort((a, b) => _rank(a).compareTo(_rank(b)));
    if (ranked.isEmpty) {
      return RefreshIndicator(
        color: theme.accent,
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyRanking(theme: theme),
            ),
          ],
        ),
      );
    }
    final top = ranked.take(3).toList(growable: false);
    final rest = ranked.where((row) => _rank(row) > 3).toList(growable: false);
    return RefreshIndicator(
      color: theme.accent,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _PodiumHero(
              top: top,
              theme: theme,
              periodLabel: periodLabel,
            ),
          ),
          if (rest.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _RankRow(
                    row: rest[index],
                    theme: theme,
                    isRoom: theme.tab == 'الغرف',
                  ),
                  childCount: rest.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
        ],
      ),
    );
  }
}

class _PodiumHero extends StatelessWidget {
  const _PodiumHero({
    required this.top,
    required this.theme,
    required this.periodLabel,
  });

  final List<Map<String, dynamic>> top;
  final _RankTheme theme;
  final String periodLabel;

  Map<String, dynamic>? _rowFor(int rank) {
    for (final row in top) {
      if (_rank(row) == rank) return row;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 306,
    margin: const EdgeInsets.fromLTRB(14, 12, 14, 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: theme.accent.withValues(alpha: .45)),
      boxShadow: [
        BoxShadow(
          color: theme.accent.withValues(alpha: .10),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(theme.background, fit: BoxFit.cover),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xAA080812),
                  const Color(0x66100D1A),
                  const Color(0xF2090912),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(theme.icon, color: theme.accent, size: 19),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        theme.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      periodLabel,
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    theme.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 9),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 232,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PodiumTile(
                        row: _rowFor(2),
                        rank: 2,
                        theme: theme,
                        isRoom: theme.tab == 'الغرف',
                        height: 194,
                      ),
                      const SizedBox(width: 4),
                      _PodiumTile(
                        row: _rowFor(1),
                        rank: 1,
                        theme: theme,
                        isRoom: theme.tab == 'الغرف',
                        height: 222,
                      ),
                      const SizedBox(width: 4),
                      _PodiumTile(
                        row: _rowFor(3),
                        rank: 3,
                        theme: theme,
                        isRoom: theme.tab == 'الغرف',
                        height: 180,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PodiumTile extends StatelessWidget {
  const _PodiumTile({
    required this.row,
    required this.rank,
    required this.theme,
    required this.isRoom,
    required this.height,
  });

  final Map<String, dynamic>? row;
  final int rank;
  final _RankTheme theme;
  final bool isRoom;
  final double height;

  @override
  Widget build(BuildContext context) {
    final medal = switch (rank) {
      1 => _gold,
      2 => _silver,
      _ => _bronze,
    };
    final entry = row;
    final title = entry == null ? '—' : _title(entry, isRoom);
    final image = entry == null
        ? null
        : (isRoom
              ? entry['image_url']?.toString()
              : entry['avatar_url']?.toString());
    final vip = _integer(entry?['vip_level']);
    final wealth = _integer(entry?['wealth_level']);
    return SizedBox(
      width: 102,
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (rank == 1)
            Icon(Icons.workspace_premium_rounded, color: medal, size: 19),
          _FramedAvatar(
            imageUrl: image,
            label: title,
            rank: rank,
            isRoom: isRoom,
            size: rank == 1 ? 72 : 62,
          ),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (row != null && !isRoom)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'VIP $vip • ثروة LV$wealth',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 7),
              ),
            ),
          if (row != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${_fullGold(row!['total_gold'])} ذهب',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: medal,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'بانتظار التفاعل',
                style: TextStyle(color: Colors.white38, fontSize: 7),
              ),
            ),
          const Spacer(),
          Container(
            width: 90,
            height: rank == 1 ? 48 : 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  medal.withValues(alpha: .82),
                  medal.withValues(alpha: .28),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border.all(color: medal.withValues(alpha: .75)),
            ),
            child: Text(
              '#$rank',
              style: TextStyle(
                color: Colors.white,
                fontSize: rank == 1 ? 18 : 15,
                fontWeight: FontWeight.w900,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 5)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FramedAvatar extends StatelessWidget {
  const _FramedAvatar({
    required this.imageUrl,
    required this.label,
    required this.rank,
    required this.isRoom,
    required this.size,
  });

  final String? imageUrl;
  final String label;
  final int rank;
  final bool isRoom;
  final double size;

  @override
  Widget build(BuildContext context) {
    final frame = switch (rank) {
      1 => 'assets/leaderboard_ui/rank_frame_gold.webp',
      2 => 'assets/leaderboard_ui/rank_frame_silver.webp',
      _ => 'assets/leaderboard_ui/rank_frame_bronze.webp',
    };
    final avatarSize = size * .67;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: avatarSize,
            height: avatarSize,
            child: isRoom
                ? _RoomAvatar(url: imageUrl, label: label)
                : SakiAvatar(
                    url: imageUrl,
                    label: label,
                    radius: avatarSize / 2,
                  ),
          ),
          Image.asset(
            frame,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.row,
    required this.theme,
    required this.isRoom,
  });

  final Map<String, dynamic> row;
  final _RankTheme theme;
  final bool isRoom;

  @override
  Widget build(BuildContext context) {
    final rank = _rank(row);
    final title = _title(row, isRoom);
    final image = isRoom
        ? row['image_url']?.toString()
        : row['avatar_url']?.toString();
    final isMine = row['is_current_user'] == true || row['is_my_room'] == true;
    final vip = _integer(row['vip_level']);
    final wealth = _integer(row['wealth_level']);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: isMine
            ? theme.accent.withValues(alpha: .12)
            : Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: isMine ? theme.accent.withValues(alpha: .62) : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rank <= 10 ? theme.accent : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 7),
          if (isRoom)
            _RoomAvatar(url: image, label: title, size: 46)
          else
            SakiAvatar(url: image, label: title, radius: 23),
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
                      ? 'غرفة • هدايا ذهبية'
                      : 'VIP $vip • مستوى الثروة LV$wealth',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _compactGold(row['total_gold']),
                style: TextStyle(
                  color: theme.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'ذهب',
                style: TextStyle(color: Colors.white54, fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({this.url, required this.label, this.size = 48});

  final String? url;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = url != null && url!.startsWith('http')
        ? Image.network(
            url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(),
          )
        : _fallback();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: SizedBox(width: size, height: size, child: image),
    );
  }

  Widget _fallback() => ColoredBox(
    color: const Color(0xFF153B4D),
    child: Center(
      child: Icon(
        Icons.meeting_room_rounded,
        color: const Color(0xFF8BE7F1),
        size: size * .48,
      ),
    ),
  );
}

class _CurrentRankBar extends StatelessWidget {
  const _CurrentRankBar({
    required this.tab,
    required this.theme,
    required this.rows,
    required this.myProfile,
    required this.myRoom,
  });

  final int tab;
  final _RankTheme theme;
  final Future<List<Map<String, dynamic>>> rows;
  final Future<Map<String, dynamic>?> myProfile;
  final Future<Map<String, dynamic>?> myRoom;

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: rows,
    builder: (context, rowsSnapshot) {
      final data = rowsSnapshot.data ?? const <Map<String, dynamic>>[];
      final isRoom = tab == 2;
      Map<String, dynamic>? mine;
      for (final row in data) {
        if (row[isRoom ? 'is_my_room' : 'is_current_user'] == true) {
          mine = row;
          break;
        }
      }
      return FutureBuilder<Map<String, dynamic>?>(
        future: isRoom ? myRoom : myProfile,
        builder: (context, identitySnapshot) {
          final identity =
              mine ?? identitySnapshot.data ?? const <String, dynamic>{};
          final label = _title(
            identity,
            isRoom,
            fallback: isRoom ? 'غرفتي' : 'حسابي',
          );
          final image = isRoom
              ? identity['image_url']?.toString()
              : identity['avatar_url']?.toString();
          final rank = mine == null ? null : _rank(mine);
          final amount = mine == null ? 0 : _integer(mine['total_gold']);
          final vip = _integer(identity['vip_level']);
          final wealth = _integer(identity['wealth_level']);
          return Container(
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
            decoration: BoxDecoration(
              color: const Color(0xF20C0B15),
              border: Border(
                top: BorderSide(color: theme.accent.withValues(alpha: .38)),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 18,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                if (isRoom)
                  _RoomAvatar(url: image, label: label, size: 43)
                else
                  SakiAvatar(url: image, label: label, radius: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
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
                        isRoom
                            ? (rank == null
                                  ? 'لا ترتيب لهذه الغرفة في الفترة'
                                  : 'مركز الغرفة #$rank')
                            : (rank == null
                                  ? 'لا ترتيب لك في الفترة'
                                  : 'مركزك #$rank  •  VIP $vip  •  ثروة LV$wealth'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fullGold(amount),
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'عملة ذهبية',
                      style: TextStyle(color: Colors.white54, fontSize: 7.5),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking({required this.theme});

  final _RankTheme theme;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.icon, color: theme.accent.withValues(alpha: .8), size: 48),
          const SizedBox(height: 12),
          const Text(
            'لا توجد هدايا مسجلة لهذه الفترة',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          const Text(
            'ستظهر النتائج هنا عند تسجيل هدايا حقيقية في الغرف.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    ),
  );
}

class _RankLoading extends StatelessWidget {
  const _RankLoading();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(color: _gold),
        SizedBox(height: 12),
        Text(
          'جارٍ تحميل النتائج الحقيقية…',
          style: TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    ),
  );
}

class _RankError extends StatelessWidget {
  const _RankError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_rounded, color: Colors.white54, size: 42),
        const SizedBox(height: 10),
        const Text(
          'تعذر تحميل الترتيب',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('إعادة المحاولة'),
          style: TextButton.styleFrom(foregroundColor: _gold),
        ),
      ],
    ),
  );
}

String _title(
  Map<String, dynamic> row,
  bool isRoom, {
  String fallback = 'مستخدم',
}) {
  final value = (isRoom ? row['name'] : row['username'])?.toString().trim();
  return value == null || value.isEmpty ? fallback : value;
}

int _rank(Map<String, dynamic> row) => _integer(row['rank_position']);

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

String _compactGold(dynamic value) {
  final amount = _integer(value);
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
  return '$amount';
}

String _fullGold(int amount) {
  final digits = amount.toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    out.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) out.write(',');
  }
  return out.toString();
}
