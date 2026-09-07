import 'package:flutter/material.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';

const _orange = Color(0xFFF97316);
const _cyan = Color(0xFF06B6D4);

class RoomGiftRankingSheet extends StatefulWidget {
  const RoomGiftRankingSheet({
    super.key,
    required this.service,
    required this.roomId,
    required this.onProfileTap,
  });
  final SakiService service;
  final String roomId;
  final Future<void> Function(Map<String, dynamic> profile) onProfileTap;
  @override
  State<RoomGiftRankingSheet> createState() => _RoomGiftRankingSheetState();
}

class _RoomGiftRankingSheetState extends State<RoomGiftRankingSheet> {
  String _period = 'يومي';
  bool _loading = true;
  int _total = 0;
  List<Map<String, dynamic>> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await widget.service.roomGiftRanking(
        widget.roomId,
        _period,
      );
      if (mounted)
        setState(() {
          _rows = result.rows;
          _total = result.total;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _short(int value) {
    if (value >= 1000000000000)
      return '${(value / 1000000000000).toStringAsFixed(1)}T';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return '$value';
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Container(
      height: MediaQuery.sizeOf(context).height * .78,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: .13),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: _orange),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ترتيب هدايا الغرفة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'أكثر المرسلين بالعملات الذهبية',
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                '${_short(_total)} ذهب',
                style: const TextStyle(
                  color: _orange,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: ['يومي', 'أسبوعي', 'شهري']
                .map(
                  (p) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: SizedBox(
                          width: double.infinity,
                          child: Text(p, textAlign: TextAlign.center),
                        ),
                        selected: _period == p,
                        selectedColor: _cyan.withValues(alpha: .18),
                        onSelected: (_) {
                          setState(() => _period = p);
                          _load();
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : _rows.isEmpty
                ? const Center(child: Text('لا توجد هدايا في هذه الفترة'))
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (_, index) => _tile(_rows[index], index),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _tile(Map<String, dynamic> row, int index) {
    final profile = Map<String, dynamic>.from(row['profile'] ?? {});
    final vip = (profile['vip_level'] as num?)?.toInt() ?? 0;
    final color = index == 0
        ? _orange
        : index == 1
        ? _cyan
        : index == 2
        ? const Color(0xFFA855F7)
        : Colors.blueGrey;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        widget.onProfileTap(profile);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: index < 3 ? .35 : .1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: index < 3
                  ? Icon(Icons.emoji_events_rounded, color: color, size: 25)
                  : Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.black54,
                      ),
                    ),
            ),
            SakiAvatar(
              url: profile['avatar_url'] as String?,
              label: profile['username'] as String?,
              radius: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile['username'] as String? ?? 'مستخدم',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Row(
                    children: [
                      if (vip > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _orange.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'VIP $vip',
                            style: const TextStyle(
                              color: _orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      const SizedBox(width: 5),
                      Text(
                        index < 3 ? 'TOP ${index + 1}' : 'مرسل نشط',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  color: _orange,
                  size: 18,
                ),
                Text(
                  _short((row['gold'] as num?)?.toInt() ?? 0),
                  style: const TextStyle(
                    color: _orange,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class GiftGoldBadge extends StatelessWidget {
  const GiftGoldBadge({super.key, required this.total, required this.onTap});
  final int total;
  final VoidCallback onTap;
  String _short(int v) {
    if (v >= 1000000000000) return '${(v / 1000000000000).toStringAsFixed(1)}T';
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '$v';
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _orange.withValues(alpha: .7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: Color(0xFFFFC107),
            size: 20,
          ),
          const SizedBox(width: 4),
          Text(
            _short(total),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
          const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: Colors.white70,
            size: 16,
          ),
        ],
      ),
    ),
  );
}

class RoomEntranceBanner extends StatelessWidget {
  const RoomEntranceBanner({super.key, required this.profile});
  final Map<String, dynamic> profile;
  @override
  Widget build(BuildContext context) {
    final vip = (profile['vip_level'] as num?)?.toInt() ?? 0;
    final premium = vip >= 6;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: premium
              ? [
                  const Color(0xFFF97316),
                  const Color(0xFFA855F7),
                  const Color(0xFF06B6D4),
                ]
              : [const Color(0xFF334155), const Color(0xFF64748B)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (premium ? _orange : Colors.black).withValues(alpha: .35),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          SakiAvatar(
            url: profile['avatar_url'] as String?,
            label: profile['username'] as String?,
            radius: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile['username'] as String? ?? 'مستخدم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  vip > 0 ? 'VIP $vip • انضم إلى الغرفة' : 'انضم إلى الغرفة',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
        ],
      ),
    );
  }
}

class RoomConnectedStrip extends StatelessWidget {
  const RoomConnectedStrip({
    super.key,
    required this.members,
    required this.total,
    required this.onTap,
  });
  final List<Map<String, dynamic>> members;
  final int total;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .48),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 32,
            child: Stack(
              children: members
                  .take(5)
                  .toList()
                  .asMap()
                  .entries
                  .map(
                    (e) => PositionedDirectional(
                      start: e.key * 21,
                      child: SakiAvatar(
                        url: e.value['avatar_url'] as String?,
                        label: e.value['username'] as String?,
                        radius: 16,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Icon(Icons.people_alt_rounded, color: _cyan, size: 18),
          const SizedBox(width: 4),
          Text(
            '$total متصل',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showRoomGiftRanking(
  BuildContext context,
  SakiService service,
  String roomId,
  Future<void> Function(Map<String, dynamic> profile) onProfileTap,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => RoomGiftRankingSheet(
    service: service,
    roomId: roomId,
    onProfileTap: onProfileTap,
  ),
);
