from pathlib import Path

api=Path('/tmp/api.php')
s=api.read_text()
# Normalize room references in read endpoints.
old="if ($action === 'room_messages' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT m.*,p.username,p.display_name,p.avatar_url,p.vip_level FROM room_messages m LEFT JOIN profiles p ON p.id=m.sender_id WHERE m.room_id=:r ORDER BY m.created_at DESC LIMIT 100');$q->execute([':r'=>$_GET['room_id']??'']);$rows=array_reverse($q->fetchAll());respond(['ok'=>true,'data'=>$rows]); }"
new="""if ($action === 'room_messages' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $requested=trim((string)($_GET['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn();
  if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT m.*,p.username,p.display_name,p.avatar_url,p.vip_level FROM room_messages m LEFT JOIN profiles p ON p.id=m.sender_id WHERE m.room_id=:r ORDER BY m.created_at DESC LIMIT 100'); $q->execute([':r'=>$room]); $rows=array_reverse($q->fetchAll()); respond(['ok'=>true,'data'=>$rows]);
}"""
if old not in s: raise SystemExit('room_messages block missing')
s=s.replace(old,new,1)
old="if ($action === 'room_seats' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$room=trim((string)($_GET['room_id']??''));$q=$pdo->prepare(\"SELECT rs.seat_no,rs.user_id,rs.joined_at,rs.is_speaking,pr.id,pr.username,pr.display_name,pr.avatar_url,pr.vip_level FROM room_seats rs LEFT JOIN profiles pr ON pr.id=rs.user_id WHERE rs.room_id=:r ORDER BY rs.seat_no\");$q->execute([':r'=>$room]);respond(['ok'=>true,'data'=>$q->fetchAll()]); }"
new="""if ($action === 'room_seats' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare(\"SELECT rs.seat_no,rs.user_id,rs.joined_at,rs.is_speaking,pr.id,pr.username,pr.display_name,pr.avatar_url,pr.vip_level FROM room_seats rs LEFT JOIN profiles pr ON pr.id=rs.user_id WHERE rs.room_id=:r ORDER BY rs.seat_no\"); $q->execute([':r'=>$room]); respond(['ok'=>true,'data'=>$q->fetchAll()]);
}"""
if old not in s: raise SystemExit('room_seats block missing')
s=s.replace(old,new,1)
# Add owner settings and backgrounds actions before room_messages.
anchor="if ($action === 'room_messages' && $_SERVER['REQUEST_METHOD'] === 'GET') {"
block="""if ($action === 'room_settings_update' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND owner_id=:u AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested,':u'=>$u['id']]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_owner_required'],403);
  $allowed=['seat_count','image_url','background_url','name','announcement','category','theme_key','membership_fee','reward_rate','mic_permission']; $set=[]; $params=[':r'=>$room]; foreach($allowed as $key){ if(array_key_exists($key,$d)){ $set[]="`$key`=:$key"; $params[":$key"]=$d[$key]; }} if(!$set) respond(['ok'=>false,'error'=>'no_settings'],422); $pdo->prepare('UPDATE rooms SET '.implode(',',$set).' WHERE id=:r')->execute($params); respond(['ok'=>true,'data'=>['room_id'=>$room]]);
}
if ($action === 'room_backgrounds' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??'')); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404); $q=$pdo->prepare('SELECT id,image_url,created_at FROM room_backgrounds WHERE room_id=:r AND owner_id=:u ORDER BY created_at DESC LIMIT 100'); $q->execute([':r'=>$room,':u'=>$u['id']]); respond(['ok'=>true,'data'=>$q->fetchAll()]);
}
if ($action === 'room_background_save' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??'')); $url=trim((string)($d['image_url']??'')); if($url==='') respond(['ok'=>false,'error'=>'image_url_required'],422); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND owner_id=:u LIMIT 1'); $q->execute([':r'=>$requested,':u'=>$u['id']]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_owner_required'],403); $pdo->prepare('INSERT INTO room_backgrounds(id,room_id,owner_id,image_url,created_at) VALUES(:id,:r,:u,:url,UTC_TIMESTAMP())')->execute([':id'=>bin2hex(random_bytes(16)),':r'=>$room,':u'=>$u['id'],':url'=>$url]); respond(['ok'=>true]);
}
"""
if "action === 'room_settings_update'" not in s: s=s.replace(anchor,block+anchor,1)
api.write_text(s)

p=Path('lib/core/data/saki_service.dart')
s=p.read_text()
# Update settings API branch.
needle="""  }) async {
    final values = <String, dynamic>{}
    if (seatCount != null) values['seat_count'] = seatCount;"""
replacement="""  }) async {
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
    final values = <String, dynamic>{}
    if (seatCount != null) values['seat_count'] = seatCount;"""
if needle not in s: raise SystemExit('settings needle missing')
s=s.replace(needle,replacement,1)
# Replace upload room funcs with API path while retaining Supabase fallback.
needle="""  Future<String> uploadRoomImage(String roomId, XFile image) async {
    final bytes = await File(image.path).readAsBytes();"""
repl="""  Future<String> uploadRoomImage(String roomId, XFile image) async {
    if (apiToken != null) return _uploadApi(image, 'rooms');
    final bytes = await File(image.path).readAsBytes();"""
s=s.replace(needle,repl,1)
needle="""  Future<String> uploadRoomBackground(String roomId, XFile image) async {
    final bytes = await File(image.path).readAsBytes();"""
repl="""  Future<String> uploadRoomBackground(String roomId, XFile image) async {
    if (apiToken != null) return _uploadApi(image, 'room-backgrounds');
    final bytes = await File(image.path).readAsBytes();"""
s=s.replace(needle,repl,1)
needle="""  Future<List<Map<String, dynamic>>> roomBackgrounds(String roomId) async {
    final rows = await client"""
repl="""  Future<List<Map<String, dynamic>>> roomBackgrounds(String roomId) async {
    if (apiToken != null) return _apiList('room_backgrounds', query: {'room_id': roomId});
    final rows = await client"""
s=s.replace(needle,repl,1)
needle="""  Future<void> saveRoomBackground(String roomId, String imageUrl) async {
    await client.from('room_backgrounds').insert({"""
repl="""  Future<void> saveRoomBackground(String roomId, String imageUrl) async {
    if (apiToken != null) {
      await _apiPost('room_background_save', {'room_id': roomId, 'image_url': imageUrl});
      return;
    }
    await client.from('room_backgrounds').insert({"""
s=s.replace(needle,repl,1)
# Create image upload + update after API create.
needle="""        return Map<String, dynamic>.from(d['data'] as Map);
      } finally {"""
repl="""        final created = Map<String, dynamic>.from(d['data'] as Map);
        if (image != null) {
          final url = await uploadRoomImage(created['id'].toString(), image);
          await updateRoomSettings(created['id'].toString(), imageUrl: url);
          created['image_url'] = url;
        }
        return created;
      } finally {"""
if needle not in s: raise SystemExit('create return needle missing')
s=s.replace(needle,repl,1)
p.write_text(s)
