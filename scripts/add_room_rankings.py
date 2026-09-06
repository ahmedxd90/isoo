from pathlib import Path

service = Path('/home/ubuntu/isoo/lib/core/data/saki_service.dart')
text = service.read_text()
needle = "  Future<void> claimRoomSeat(String roomId, int seatNo) async {"
insert = r'''  Future<List<Map<String, dynamic>>> roomMembers(String roomId) async {
    final rows = await client
        .from('room_members')
        .select('user_id,joined_at,profiles:user_id(id,username,avatar_url,vip_level,vip_expires_at)')
        .eq('room_id', roomId)
        .order('joined_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows)
        .map((row) => Map<String, dynamic>.from(row['profiles'] ?? {}))
        .where((profile) => profile['id'] != null)
        .toList();
  }

  Future<RoomGiftRankingResult> roomGiftRanking(String roomId, String period) async {
    final now = DateTime.now().toUtc();
    final days = period == 'شهري' ? 30 : period == 'أسبوعي' ? 7 : 1;
    final since = now.subtract(Duration(days: days)).toIso8601String();
    final rows = await client
        .from('room_gifts')
        .select('sender_id,total_price,created_at,profiles:sender_id(id,username,avatar_url,vip_level,vip_expires_at)')
        .eq('room_id', roomId)
        .gte('created_at', since)
        .limit(1000);
    final grouped = <String, Map<String, dynamic>>{};
    for (final raw in List<Map<String, dynamic>>.from(rows)) {
      final profile = Map<String, dynamic>.from(raw['profiles'] ?? {});
      final id = raw['sender_id']?.toString();
      if (id == null || id.isEmpty) continue;
      final item = grouped.putIfAbsent(id, () => {'gold': 0, 'profile': profile});
      item['gold'] = (item['gold'] as int) + ((raw['total_price'] as num?)?.toInt() ?? 0);
    }
    final result = grouped.values.toList()
      ..sort((a, b) => (b['gold'] as int).compareTo(a['gold'] as int));
    return RoomGiftRankingResult(result, result.fold<int>(0, (sum, row) => sum + (row['gold'] as int)));
  }

'''
if needle not in text:
    raise SystemExit('service insertion point not found')
if 'RoomGiftRankingResult roomGiftRanking' not in text:
    text = text.replace(needle, insert + needle, 1)
text += r'''

class RoomGiftRankingResult {
  const RoomGiftRankingResult(this.rows, this.total);
  final List<Map<String, dynamic>> rows;
  final int total;
}
'''
service.write_text(text)

room = Path('/home/ubuntu/isoo/lib/features/rooms/agora_live_room_page.dart')
text = room.read_text()
text = text.replace("import 'room_gifts_sheet.dart';", "import 'room_gifts_sheet.dart';\nimport 'room_gift_ranking_sheet.dart';")
text = text.replace("  final _comment = TextEditingController();", "  final _comment = TextEditingController();\n  List<Map<String, dynamic>> _members = [];\n  int _goldTotal = 0;\n  Map<String, dynamic>? _entranceProfile;\n  DateTime? _entranceAt;")
text = text.replace("    _start();\n  }", "    _start();\n    _loadRoomOverlays();\n  }", 1)
needle = "  Future<void> _renewToken() async {"
insert = r'''  Future<void> _loadRoomOverlays() async {
    try {
      final members = await SakiService.instance.roomMembers(widget.roomId);
      final ranking = await SakiService.instance.roomGiftRanking(widget.roomId, 'يومي');
      if (mounted) setState(() { _members = members; _goldTotal = ranking.total; });
    } catch (_) {}
  }

  void _showRanking() => showRoomGiftRanking(context, SakiService.instance, widget.roomId);

'''
if needle not in text:
    raise SystemExit('room insertion point not found')
text = text.replace(needle, insert + needle, 1)
text = text.replace("          if (!_joined && _error == null)", "          if (_entranceProfile != null && _entranceAt != null && DateTime.now().difference(_entranceAt!).inSeconds < 5)\n            Positioned(top: 92, left: 0, right: 0, child: RoomEntranceBanner(profile: _entranceProfile!)),\n          if (!_joined && _error == null)")
text = text.replace("          Positioned(\n            bottom: 22,", "          Positioned(\n            bottom: 78,\n            left: 16,\n            right: 16,\n            child: Row(children: [\n              RoomConnectedStrip(members: _members, total: _members.length, onTap: _loadRoomOverlays),\n              const Spacer(),\n              GiftGoldBadge(total: _goldTotal, onTap: _showRanking),\n            ]),\n          ),\n          Positioned(\n            bottom: 22,")
room.write_text(text)
