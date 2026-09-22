from pathlib import Path

api=Path('/tmp/api.php')
s=api.read_text()
# Replace room_messages action by boundaries.
start=s.index("if ($action === 'room_messages'")
end=s.index("if ($action === 'families'", start)
messages="""if ($action === 'room_messages' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT m.*,p.username,p.display_name,p.avatar_url,p.vip_level FROM room_messages m LEFT JOIN profiles p ON p.id=m.sender_id WHERE m.room_id=:r ORDER BY m.created_at DESC LIMIT 100'); $q->execute([':r'=>$room]); $rows=array_reverse($q->fetchAll()); respond(['ok'=>true,'data'=>$rows]);
}
"""
s=s[:start]+messages+s[end:]
# Replace room_seats action by boundaries.
start=s.index("if ($action === 'room_seats'")
end=s.index("if ($action === 'room_", start+10)
# Find next action after room_seats robustly.
line_end=s.find('\n', start)
next_pos=s.find("\nif ($action ===", line_end+1)
seats="""if ($action === 'room_seats' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare("SELECT rs.seat_no,rs.user_id,rs.joined_at,rs.is_speaking,pr.id,pr.username,pr.display_name,pr.avatar_url,pr.vip_level FROM room_seats rs LEFT JOIN profiles pr ON pr.id=rs.user_id WHERE rs.room_id=:r ORDER BY rs.seat_no"); $q->execute([':r'=>$room]); respond(['ok'=>true,'data'=>$q->fetchAll()]);
}
"""
s=s[:start]+seats+s[next_pos:]
api.write_text(s)

p=Path('lib/core/data/saki_service.dart')
s=p.read_text()
if "await _apiPost('room_settings_update'" not in s:
    needle="    final values = <String, dynamic>{"
    replacement="""    if (apiToken != null) {
    if (apiToken != null) {
      await _apiPost('room_settings_update', {
        'room_id': roomId,
        if (seatCount != null) 'seat_count': seatCount,
        if (imageUrl != null) 'image_url': imageUrl,
        if (backgroundUrl != null) 'background_url': backgroundUrl,
        if (name != null) 'name': name.trim(),
        if (announcement != null) 'announcement': announcement.trim(),
        if (category != null) 'category': category,
        if (themeKey != null) 'theme_key': themeKey,
        'membership_fee': 0,
        'reward_rate': 0,
        if (micPermission != null) 'mic_permission': micPermission,
      });
      return;
    }
    final values = <String, dynamic>{
    if (seatCount != null) values['seat_count'] = seatCount;"""
    if needle not in s: raise SystemExit('settings dart needle missing')
    s=s.replace(needle,replacement,1)
if "if (apiToken != null) return _uploadApi(image, 'rooms');" not in s:
    s=s.replace("Future<String> uploadRoomImage(String roomId, XFile image) async {\n    final bytes", "Future<String> uploadRoomImage(String roomId, XFile image) async {\n    if (apiToken != null) return _uploadApi(image, 'rooms');\n    final bytes",1)
if "if (apiToken != null) return _uploadApi(image, 'room-backgrounds');" not in s:
    s=s.replace("Future<String> uploadRoomBackground(String roomId, XFile image) async {\n    final bytes", "Future<String> uploadRoomBackground(String roomId, XFile image) async {\n    if (apiToken != null) return _uploadApi(image, 'room-backgrounds');\n    final bytes",1)
if "return _apiList('room_backgrounds'" not in s:
    s=s.replace("Future<List<Map<String, dynamic>>> roomBackgrounds(String roomId) async {\n    final rows", "Future<List<Map<String, dynamic>>> roomBackgrounds(String roomId) async {\n    if (apiToken != null) return _apiList('room_backgrounds', query: {'room_id': roomId});\n    final rows",1)
if "_apiPost('room_background_save'" not in s:
    s=s.replace("Future<void> saveRoomBackground(String roomId, String imageUrl) async {\n    await client", "Future<void> saveRoomBackground(String roomId, String imageUrl) async {\n    if (apiToken != null) {\n      await _apiPost('room_background_save', {'room_id': roomId, 'image_url': imageUrl});\n      return;\n    }\n    await client",1)
if "final created = Map<String, dynamic>.from(d['data'] as Map);" not in s:
    s=s.replace("        return Map<String, dynamic>.from(d['data'] as Map);\n      } finally {", "        final created = Map<String, dynamic>.from(d['data'] as Map);\n        if (image != null) {\n          final url = await uploadRoomImage(created['id'].toString(), image);\n          await updateRoomSettings(created['id'].toString(), imageUrl: url);\n          created['image_url'] = url;\n        }\n        return created;\n      } finally {",1)
p.write_text(s)
