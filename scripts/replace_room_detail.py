from pathlib import Path
p = Path('/home/ubuntu/work/repo/lib/features/rooms/rooms_page.dart')
s = p.read_text()
start = s.index('class RoomDetailPage')
end = s.index('class CreateRoomPage')
new = r'''class RoomDetailPage extends StatefulWidget {
  const RoomDetailPage({super.key, required this.room});
  final Map<String, dynamic> room;
  @override State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  final _service = SakiService.instance;
  final _message = TextEditingController();
  late final String _roomId = widget.room['id'] as String;
  late final Stream<List<Map<String, dynamic>>> _seatStream;
  late final Stream<List<Map<String, dynamic>>> _messageStream;
  bool _joined = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seatStream = _service.roomSeatsStream(_roomId);
    _messageStream = _service.roomMessagesStream(_roomId);
    _join();
  }

  Future<void> _join() async {
    try { await _service.joinRoom(_roomId); if (mounted) setState(() => _joined = true); } catch (_) {}
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty) return;
    _message.clear();
    await _service.client.from('room_messages').insert({'room_id': _roomId, 'sender_id': _service.uid, 'body': body});
  }

  Future<bool> _confirmExit() async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF291018),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('مغادرة الغرفة؟', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        content: const Text('يمكنك الخروج من الغرفة أو الاحتفاظ بها مفتوحة أثناء استخدام التطبيق.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(onPressed: () => Navigator.pop(context, false), child: const Text('احتفظ')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(context, true), child: const Text('خروج')),
        ],
      ),
    );
    if (result == true) { await _service.leaveRoom(_roomId); return true; }
    return false;
  }

  Future<void> _seatAction(int seatNo, Map<String, dynamic>? occupied) async {
    if (_busy) return;
    if (occupied != null && occupied['user_id'] != _service.uid) return;
    setState(() => _busy = true);
    try {
      if (occupied?['user_id'] == _service.uid) {
        await _service.leaveRoomSeat(_roomId);
      } else {
        await _service.claimRoomSeat(_roomId, seatNo);
      }
    } finally { if (mounted) setState(() => _busy = false); }
  }

  void _showOnline() async {
    final rows = await _service.client.from('room_members').select('user_id,joined_at,profiles:user_id(username,avatar_url)').eq('room_id', _roomId);
    if (!mounted) return;
    showModalBottomSheet(context: context, backgroundColor: const Color(0xFF3D0B12), builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Padding(padding: EdgeInsets.all(18), child: Text('المتصلون الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))),
      ...List<Map<String, dynamic>>.from(rows).map((row) { final profile = Map<String, dynamic>.from(row['profiles'] ?? const {}); return ListTile(leading: SakiAvatar(url: profile['avatar_url'] as String?, label: profile['username'] as String?), title: Text(profile['username'] as String? ?? 'عضو', style: const TextStyle(color: Colors.white)), trailing: const Icon(Icons.circle, color: Colors.green, size: 10)); }),
      const SizedBox(height: 12),
    ])));
  }

  @override
  void dispose() { _message.dispose(); if (_joined) _service.leaveRoom(_roomId); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final image = widget.room['image_url'] as String?;
    final title = widget.room['name'] as String? ?? 'غرفة SAKI';
    final roomNumber = widget.room['room_id'] as String? ?? '';
    return WillPopScope(
      onWillPop: () async => await _confirmExit(),
      child: Scaffold(
        backgroundColor: const Color(0xFF4A0E17),
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF4A0E17), Color(0xFF8A1C30), Color(0xFF2A080C)])),
          child: SafeArea(child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 6), child: Row(children: [
              ClipRRect(borderRadius: BorderRadius.circular(10), child: image == null ? Container(width: 42, height: 42, color: Colors.white12, child: const Icon(Icons.meeting_room, color: Colors.white)) : Image.network(image, width: 42, height: 42, fit: BoxFit.cover)),
              const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)), Text('ID: $roomNumber', style: const TextStyle(color: Colors.white60, fontSize: 11))])),
              IconButton(onPressed: _showOnline, icon: const Icon(Icons.people_alt_outlined, color: Colors.white)),
              IconButton(onPressed: () async { if (await _confirmExit() && mounted) Navigator.pop(context); }, icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ])),
            StreamBuilder<List<Map<String, dynamic>>>(stream: _seatStream, builder: (_, snap) {
              final seats = {for (final row in (snap.data ?? [])) row['seat_no'] as int: row};
              return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: GridView.builder(shrinkWrap: true, itemCount: 10, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, mainAxisSpacing: 12, crossAxisSpacing: 10, childAspectRatio: .8), itemBuilder: (_, index) {
                final seatNo = index + 1; final row = seats[seatNo]; final profile = Map<String, dynamic>.from(row?['profiles'] ?? const {}); final occupied = row != null;
                return GestureDetector(onTap: () => _seatAction(seatNo, row), child: Column(children: [Container(width: 52, height: 52, decoration: BoxDecoration(shape: BoxShape.circle, color: occupied ? const Color(0xFFEAB308) : Colors.white10, border: Border.all(color: occupied ? Colors.yellowAccent : Colors.white24, width: 1.5), boxShadow: occupied ? const [BoxShadow(color: Colors.amber, blurRadius: 10)] : null), child: occupied ? SakiAvatar(url: profile['avatar_url'] as String?, label: profile['username'] as String?, radius: 25) : const Icon(Icons.mic_none_rounded, color: Colors.white70)), const SizedBox(height: 4), Text(occupied ? (profile['username'] as String? ?? 'متحدث') : '$seatNo', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10))]));
              }));
            }),
            Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(stream: _messageStream, builder: (_, snap) { final messages = snap.data ?? []; return ListView.builder(padding: const EdgeInsets.all(14), itemCount: messages.length + 1, itemBuilder: (_, i) { if (i == 0) return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)), child: const Text('مرحباً بكم في ساكي، نرجو احترام الآخرين', style: TextStyle(color: Colors.amberAccent, fontSize: 12))); final msg = messages[i - 1]; return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)), child: Row(children: [SakiAvatar(label: 'عضو', radius: 16), const SizedBox(width: 8), Expanded(child: Text(msg['body'] as String? ?? '', style: const TextStyle(color: Colors.white)))]); }); })),
            Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [Expanded(child: TextField(controller: _message, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'كتابة رسالة...', hintStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.black38, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)), onSubmitted: (_) => _send())), IconButton(onPressed: _send, icon: const Icon(Icons.send_rounded, color: Colors.white)), IconButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgoraAudioRoomPage(roomName: _roomId, title: title))), icon: const Icon(Icons.mic_rounded, color: Colors.amberAccent))]))
          ])),
        ),
      ),
    );
  }
}

'''
p.write_text(s[:start] + new + s[end:])
print('Replaced RoomDetailPage')
