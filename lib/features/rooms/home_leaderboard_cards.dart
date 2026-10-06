import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';

class HomeLeaderboardCards extends StatefulWidget {
  const HomeLeaderboardCards({super.key, required this.onOpenRanking});

  final ValueChanged<int> onOpenRanking;

  @override
  State<HomeLeaderboardCards> createState() => _HomeLeaderboardCardsState();
}

class _HomeLeaderboardCardsState extends State<HomeLeaderboardCards> {
  late Future<_YesterdayBoards> _boards;

  @override
  void initState() {
    super.initState();
    _boards = _load();
  }

  Future<_YesterdayBoards> _load() async {
    final service = SakiService.instance;
    final result = await Future.wait<List<Map<String, dynamic>>>([
      service.globalGiftUserLeaderboard('yesterday', mode: 'wealth'),
      service.globalGiftUserLeaderboard('yesterday', mode: 'charm'),
      service.globalRoomRanking('yesterday'),
    ]);
    return _YesterdayBoards(
      wealth: result[0],
      charm: result[1],
      rooms: result[2],
    );
  }

  void _retry() => setState(() => _boards = _load());

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
    child: SizedBox(
      height: 154,
      child: FutureBuilder<_YesterdayBoards>(
        future: _boards,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(
              children: List.generate(
                3,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      end: index == 2 ? 0 : 7,
                    ),
                    child: _loadingCard(),
                  ),
                ),
              ),
            );
          }
          final data = snapshot.data;
          if (data == null) {
            return Center(
              child: TextButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('تعذر تحميل الترتيب'),
              ),
            );
          }
          return Row(
            children: [
              Expanded(
                child: _YesterdayRankingCard(
                  title: 'ترتيب الثروة',
                  image: 'assets/leaderboard_ui/wealth_bg.webp',
                  accent: const Color(0xFFFFD369),
                  icon: Icons.diamond_rounded,
                  rows: data.wealth,
                  isRoom: false,
                  onTap: () => widget.onOpenRanking(0),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _YesterdayRankingCard(
                  title: 'ترتيب السحر',
                  image: 'assets/leaderboard_ui/charm_bg.webp',
                  accent: const Color(0xFFF5A7FF),
                  icon: Icons.auto_awesome_rounded,
                  rows: data.charm,
                  isRoom: false,
                  onTap: () => widget.onOpenRanking(1),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _YesterdayRankingCard(
                  title: 'ترتيب الغرف',
                  image: 'assets/leaderboard_ui/rooms_bg.webp',
                  accent: const Color(0xFF8BE7F1),
                  icon: Icons.graphic_eq_rounded,
                  rows: data.rooms,
                  isRoom: true,
                  onTap: () => widget.onOpenRanking(2),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _loadingCard() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF171426),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white10),
    ),
    child: const Center(
      child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
      ),
    ),
  );
}

class _YesterdayBoards {
  const _YesterdayBoards({
    required this.wealth,
    required this.charm,
    required this.rooms,
  });

  final List<Map<String, dynamic>> wealth;
  final List<Map<String, dynamic>> charm;
  final List<Map<String, dynamic>> rooms;
}

class _YesterdayRankingCard extends StatelessWidget {
  const _YesterdayRankingCard({
    required this.title,
    required this.image,
    required this.accent,
    required this.icon,
    required this.rows,
    required this.isRoom,
    required this.onTap,
  });

  final String title;
  final String image;
  final Color accent;
  final IconData icon;
  final List<Map<String, dynamic>> rows;
  final bool isRoom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final top = rows
        .where((row) => _rank(row) <= 100)
        .take(3)
        .toList(growable: false);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF171426), Color(0xFF31245D)],
                    ),
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x55100D1B), Color(0xEE100D1B)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 8, 7, 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 13, color: accent),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'أفضل 3 • أمس',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (top.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text(
                            'لا توجد نتائج أمس',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(top.length, (index) {
                          final row = top[index];
                          final name = isRoom
                              ? row['name']?.toString() ?? 'غرفة'
                              : row['username']?.toString() ?? 'مستخدم';
                          return Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MiniRankAvatar(
                                  row: row,
                                  label: name,
                                  isRoom: isRoom,
                                  accent: accent,
                                  rank: _rank(row),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${_compactGold(row['total_gold'])} ذهب',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 6.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniRankAvatar extends StatelessWidget {
  const _MiniRankAvatar({
    required this.row,
    required this.label,
    required this.isRoom,
    required this.accent,
    required this.rank,
  });

  final Map<String, dynamic> row;
  final String label;
  final bool isRoom;
  final Color accent;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final url = (isRoom ? row['image_url'] : row['avatar_url'])?.toString();
    final image = url != null && url.startsWith('http')
        ? Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _fallback(label),
          )
        : _fallback(label);
    return SizedBox(
      width: 27,
      height: 27,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 1.2),
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 6),
              ],
            ),
            child: ClipOval(child: image),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 11,
              height: 11,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF171426), width: 1),
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Color(0xFF171426),
                  fontSize: 6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback(String label) => ColoredBox(
    color: accent.withValues(alpha: .2),
    child: Center(
      child: Text(
        label.isEmpty ? '•' : label.characters.first,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );
}

int _rank(Map<String, dynamic> row) {
  final value = row['rank_position'];
  return value is num ? value.toInt() : int.tryParse('$value') ?? 999999;
}

String _compactGold(dynamic value) {
  final amount = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M';
  if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
  return '$amount';
}
