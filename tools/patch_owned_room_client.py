from pathlib import Path
p=Path('lib/core/data/saki_service.dart')
s=p.read_text()
start=s.index('  Future<Map<String, dynamic>?> myOwnedRoom() async {')
end=s.index('\n  Future<Map<String, dynamic>> startLiveBroadcast', start)
new="""  Future<Map<String, dynamic>?> myOwnedRoom() async {
    if (apiToken != null) {
      final rows = await _apiList('room_owned');
      return rows.isEmpty ? null : rows.first;
    }
    throw StateError('unauthorized');
  }
"""
p.write_text(s[:start]+new+s[end:])

p=Path('lib/features/rooms/rooms_page.dart')
s=p.read_text()
old="""  Future<void> _create() async {
    final owned = await _service.myOwnedRoom();
    if (!mounted) return;
    if (owned != null) {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => _zegoRoomDestination(owned)));
      return;
    }
    final created = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const CreateRoomPage()),
    );
    if (!mounted || created == null) return;
    await _load();
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => _zegoRoomDestination(created)));
  }
"""
new="""  Future<void> _create() async {
    try {
      final owned = await _service.myOwnedRoom();
      if (!mounted) return;
      if (owned != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _zegoRoomDestination(owned)),
        );
        return;
      }
      final created = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const CreateRoomPage()),
      );
      if (!mounted || created == null) return;
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _zegoRoomDestination(created)),
      );
    } catch (error) {
      if (mounted) CustomToast.show(context, 'تعذر فتح إنشاء الغرفة: $error');
    }
  }
"""
if old not in s: raise SystemExit('rooms _create block not found')
p.write_text(s.replace(old,new,1))
