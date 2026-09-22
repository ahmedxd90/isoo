from pathlib import Path
p=Path('/tmp/api.php'); s=p.read_text()
# Enrich feed fields.
s=s.replace("SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.image_url,r.is_active,r.created_at,p.username", "SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.country,r.room_type,r.image_url,r.background_url,r.seat_count,r.announcement,r.category,r.theme_key,r.mic_permission,r.is_active,r.created_at,p.username", 1)
# Add details endpoint once.
anchor="if ($action === 'room_settings_update' && $_SERVER['REQUEST_METHOD'] === 'POST') {"
block="""if ($action === 'room_details' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??'')); $q=$pdo->prepare('SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.country,r.room_type,r.image_url,r.background_url,r.seat_count,r.announcement,r.category,r.theme_key,r.membership_fee,r.reward_rate,r.mic_permission,r.is_active,r.created_at,p.username,p.display_name,p.avatar_url,p.vip_level FROM rooms r LEFT JOIN profiles p ON p.id=r.owner_id WHERE (r.id=:r OR r.room_id=:r) AND r.is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $row=$q->fetch(PDO::FETCH_ASSOC); if(!$row) respond(['ok'=>false,'error'=>'room_not_found'],404); respond(['ok'=>true,'data'=>$row]);
}
"""
if "action === 'room_details'" not in s: s=s.replace(anchor,block+anchor,1)
# Normalize presence occurrences.
old="if ($action === 'room_presence' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$room=(string)(body()['room_id']??'');$pdo->prepare('UPDATE room_members SET joined_at=joined_at WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);respond(['ok'=>true]); }"
new="if ($action === 'room_presence' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$requested=trim((string)(body()['room_id']??''));$q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1');$q->execute([':r'=>$requested]);$room=$q->fetchColumn();if(!$room)respond(['ok'=>false,'error'=>'room_not_found'],404);$pdo->prepare('UPDATE room_members SET joined_at=UTC_TIMESTAMP() WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);respond(['ok'=>true]); }"
s=s.replace(old,new)
p.write_text(s)

p=Path('lib/core/data/saki_service.dart'); s=p.read_text()
old="""  Stream<List<Map<String, dynamic>>> roomSettingsStream(String roomId) =>
      client.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).limit(1);"""
new="""  Stream<List<Map<String, dynamic>>> roomSettingsStream(String roomId) {
    if (apiToken != null) {
      return Stream.periodic(const Duration(seconds: 4)).asyncMap((_) async {
        try {
          final row = await _apiMap('room_details', query: {'room_id': roomId});
          return [row];
        } catch (_) {
          return const <Map<String, dynamic>>[];
        }
      });
    }
    return client.from('rooms').stream(primaryKey: ['id']).eq('id', roomId).limit(1);
  }"""
if old not in s: raise SystemExit('settings stream missing')
s=s.replace(old,new,1)
p.write_text(s)
