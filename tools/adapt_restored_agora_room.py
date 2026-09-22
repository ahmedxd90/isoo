from pathlib import Path
p=Path('lib/features/rooms/rooms_page.dart')
s=p.read_text()
s=s.replace("import 'zego_live_audio_room_page.dart';\n", "")
start=s.find('Widget _zegoRoomDestination(')
end=s.find('const _roomPrimary', start)
if start >= 0 and end >= 0:
    s=s[:start]+s[end:]
s=s.replace('MaterialPageRoute(builder: (_) => _zegoRoomDestination(owned))','MaterialPageRoute(builder: (_) => RoomDetailPage(room: owned))')
s=s.replace('MaterialPageRoute(builder: (_) => _zegoRoomDestination(created))','MaterialPageRoute(builder: (_) => RoomDetailPage(room: created))')
s=s.replace('MaterialPageRoute(builder: (_) => _zegoRoomDestination(room))','MaterialPageRoute(builder: (_) => RoomDetailPage(room: room))')
old="""    _roomPresenceSubscription = _service.client
        .from('room_members')
        .stream(primaryKey: ['room_id', 'user_id'])
        .listen((_) => _scheduleRoomRefresh());"""
new="""    _roomPresenceSubscription = Stream<void>.periodic(
      const Duration(seconds: 8),
    ).listen((_) => _scheduleRoomRefresh());"""
if old not in s: raise SystemExit('presence block missing')
s=s.replace(old,new,1)
s=s.replace("CustomToast.show(context, 'تعذر تحميل الغرف من Supabase');", "CustomToast.show(context, 'تعذر تحميل الغرف من الخادم');")
s=s.replace('late final RealtimeChannel _roomChatChannel;', 'late final _NoopRoomBroadcastChannel _roomChatChannel;')
s=s.replace("""    _roomChatChannel = _service.client.channel('room-chat:$_roomId')
      ..onBroadcast(
        event: 'clear',
        callback: (payload) {
          if (!mounted) return;
          final clearedAt = DateTime.tryParse(
            payload['clearedAt']?.toString() ?? '',
          );
          _applyChatClear(clearedAt ?? DateTime.now().toUtc());
        },
      )
      ..onBroadcast(
        event: 'music',
        callback: (payload) =>
            _handleMusicEvent(Map<String, dynamic>.from(payload as Map)),
      )
      ..subscribe();""", """    _roomChatChannel = _NoopRoomBroadcastChannel();""")
s=s.replace("""      final response = await _service.client.functions.invoke(
        'agora-token',
        body: {'channelName': _roomId, 'uid': uid},
      );
      final data = Map<String, dynamic>.from(response.data as Map);""", """      final data = await _service.agoraRoomToken(_roomId, uid);""")
s=s.replace("""    final response = await _service.client.functions.invoke(
      'agora-token',
      body: {'channelName': _roomId, 'uid': uid},
    );
    final data = Map<String, dynamic>.from(response.data as Map);""", """    final data = await _service.agoraRoomToken(_roomId, uid);""")
s=s.replace('    _service.client.removeChannel(_roomChatChannel);', '    _roomChatChannel.dispose();')
p.write_text(s)

p=Path('lib/core/data/saki_service.dart')
s=p.read_text()
marker='  Future<Map<String, dynamic>> zegoRoomToken('
method="""  Future<Map<String, dynamic>> agoraRoomToken(String channelName, int uid) async {
    return _apiMap(
      'agora_token',
      query: {'channel_name': channelName, 'uid': uid.toString()},
    );
  }

"""
if 'Future<Map<String, dynamic>> agoraRoomToken' not in s:
    s=s.replace(marker,method+marker,1)
p.write_text(s)

p=Path('lib/features/rooms/rooms_page.dart')
s=p.read_text()
insert="""
class _NoopRoomBroadcastChannel {
  _NoopRoomBroadcastChannel onBroadcast({required String event, required Function callback}) => this;
  _NoopRoomBroadcastChannel subscribe() => this;
  Future<void> sendBroadcastMessage({required String event, Map<String, dynamic>? payload}) async {}
  void dispose() {}
}

"""
anchor='const _roomPrimary = Color(0xFFFF6B35);'
if 'class _NoopRoomBroadcastChannel' not in s:
    s=s.replace(anchor,insert+anchor,1)
p.write_text(s)
