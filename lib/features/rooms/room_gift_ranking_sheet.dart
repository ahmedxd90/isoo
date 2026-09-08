import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

import '../../core/data/saki_service.dart';
import '../../shared/widgets/saki_widgets.dart';
import '../../shared/widgets/vip_identity.dart';

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
      if (mounted) {
        setState(() {
          _rows = result.rows;
          _total = result.total;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _short(int value) {
    if (value >= 1000000000000) {
      return '${(value / 1000000000000).toStringAsFixed(1)}T';
    }
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
              profile: profile,
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

class RoomEntranceBanner extends StatefulWidget {
  const RoomEntranceBanner({super.key, required this.profile});
  final Map<String, dynamic> profile;
  @override
  State<RoomEntranceBanner> createState() => _RoomEntranceBannerState();
}

class _RoomEntranceBannerState extends State<RoomEntranceBanner>
    with SingleTickerProviderStateMixin {
  late final SVGAAnimationController _svga = SVGAAnimationController(
    vsync: this,
  );
  int get _vip =>
      ((widget.profile['vip_level'] as num?)?.toInt() ?? 0).clamp(0, 10);
  Color get _color => vipEntranceColors[_vip] ?? const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_vip < 1) return;
    try {
      final movie = await SVGAParser.shared.decodeFromAssets(
        'assets/vip/broadcast_gift_bg_svip_lv$_vip.svga',
      );
      if (!mounted) return;
      _svga.videoItem = movie;
      setState(() {});
      _svga.repeat();
    } catch (_) {}
  }

  @override
  void dispose() {
    _svga.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final premium = _vip >= 6;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF24232B),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _color.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: .30),
            blurRadius: premium ? 20 : 12,
          ),
        ],
      ),
      child: Stack(
        children: [
          if (_svga.videoItem != null)
            Positioned.fill(
              child: Opacity(
                opacity: .72,
                child: SVGAImage(_svga, fit: BoxFit.cover),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: .55),
                    _color.withValues(alpha: .28),
                    Colors.black.withValues(alpha: .60),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _color, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: .65),
                        blurRadius: 9,
                      ),
                    ],
                  ),
                  child: SakiAvatar(
                    url: widget.profile['avatar_url'] as String?,
                    label: widget.profile['username'] as String?,
                    profile: widget.profile,
                    radius: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      VipNameText(
                        profile: widget.profile,
                        fontSize: 13,
                        maxLines: 1,
                      ),
                      Text(
                        _vip > 0
                            ? 'VIP $_vip • دخل إلى الغرفة'
                            : 'انضم إلى الغرفة',
                        style: TextStyle(
                          color: _vip > 0 ? _color : Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_vip > 0)
                  Text(
                    'VIP $_vip',
                    style: TextStyle(
                      color: _color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                else
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const vipEntranceColors = <int, Color>{
  0: Color(0xFF64748B),
  1: Color(0xFFC47C73),
  2: Color(0xFFA8B1C2),
  3: Color(0xFF65B8A6),
  4: Color(0xFF4CD964),
  5: Color(0xFF0088FF),
  6: Color(0xFFD95319),
  7: Color(0xFFB145E9),
  8: Color(0xFF26C6DA),
  9: Color(0xFFFFC107),
  10: Color(0xFFFF4500),
};

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
