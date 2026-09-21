from pathlib import Path
api = Path('/tmp/api.php')
s = api.read_text()
new_block = """if ($action === 'room_join' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $requested=trim((string)(body()['room_id']??''));
  if($requested==='') respond(['ok'=>false,'error'=>'room_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1');
    $q->execute([':r'=>$requested]); $room=$q->fetchColumn();
    if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
    $q=$pdo->prepare('INSERT INTO room_members(room_id,user_id,joined_at) VALUES(:r,:u,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE joined_at=VALUES(joined_at)');
    $q->execute([':r'=>$room,':u'=>$u['id']]);
    respond(['ok'=>true,'data'=>['room_id'=>$room]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'room_join_sql:'.$e->getMessage()],500); }
} """
start = s.find("if ($action === 'room_join' && $_SERVER['REQUEST_METHOD'] === 'POST')")
end = s.find("if ($action === 'room_leave'", start)
if start < 0 or end < 0:
    raise SystemExit('room_join block not found')
api.write_text(s[:start] + new_block + "\n" + s[end:])

p = Path('/home/ubuntu/isoo/lib/core/data/saki_service.dart')
s = p.read_text()
old = """        r.write(jsonEncode({'room_id': roomId}));
        if ((await r.close()).statusCode >= 400) {
          throw StateError('room_join_failed');
        }
"""
new = """        r.write(jsonEncode({'room_id': roomId}));
        final response = await r.close();
        final responseBody = await response.transform(utf8.decoder).join();
        if (response.statusCode >= 400) {
          throw StateError(
            'room_join_failed http=${response.statusCode} ${responseBody.trim()}',
          );
        }
"""
if old not in s:
    raise SystemExit('client join block not found')
p.write_text(s.replace(old, new, 1))
