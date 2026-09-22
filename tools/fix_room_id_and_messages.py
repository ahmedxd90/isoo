from pathlib import Path

p=Path('/tmp/api.php')
s=p.read_text()
start=s.index("if ($action === 'room_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {")
end=s.index("if ($action === 'rooms_feed'", start)
room_create="""if ($action === 'room_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $name=trim((string)($d['name']??''));
  if($name==='') respond(['ok'=>false,'error'=>'room_name_required'],422);
  try {
    $pdo->beginTransaction();
    $q=$pdo->query(\"SELECT room_id FROM rooms WHERE room_id REGEXP '^[0-9]{9}$' ORDER BY CAST(room_id AS UNSIGNED) DESC LIMIT 1 FOR UPDATE\");
    $last=$q->fetchColumn(); $next=max(649874536, ((int)$last)+1);
    if($next>999999999) throw new Exception('room_id_space_exhausted');
    $code=(string)$next; $id=bin2hex(random_bytes(16));
    $q=$pdo->prepare('INSERT INTO rooms(id,room_id,owner_id,name,description,country,room_type,image_url,is_active,seat_count,category,theme_key,membership_fee,reward_rate,mic_permission,created_at) VALUES(:id,:code,:u,:n,:d,:c,:t,NULL,1,10,:cat,:theme,0,0,\'everyone\',UTC_TIMESTAMP())');
    $q->execute([':id'=>$id,':code'=>$code,':u'=>$u['id'],':n'=>$name,':d'=>trim((string)($d['description']??'')),':c'=>trim((string)($d['country']??'الأردن')),':t'=>trim((string)($d['type']??'audio')),':cat'=>trim((string)($d['category']??'Cp')),':theme'=>'default']);
    $pdo->prepare('INSERT INTO room_members(room_id,user_id,joined_at) VALUES(:r,:u,UTC_TIMESTAMP())')->execute([':r'=>$id,':u'=>$u['id']]);
    $pdo->commit();
    respond(['ok'=>true,'data'=>['id'=>$id,'room_id'=>$code,'owner_id'=>$u['id'],'name'=>$name,'description'=>$d['description']??'','country'=>$d['country']??'الأردن','room_type'=>$d['type']??'audio','seat_count'=>10,'category'=>$d['category']??'Cp','is_active'=>1,'_members_count'=>1]],201);
  } catch(Throwable $e) { if($pdo->inTransaction()) $pdo->rollBack(); respond(['ok'=>false,'error'=>'room_create_sql:'.$e->getMessage()],500); }
}
"""
s=s[:start]+room_create+s[end:]
start=s.index("if ($action === 'room_message_send' && $_SERVER['REQUEST_METHOD'] === 'POST') {")
end=s.index("if ($action === 'families'", start)
message="""if ($action === 'room_message_send' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $requested=trim((string)($d['room_id']??'')); $body=trim((string)($d['body']??''));
  if($requested==='') respond(['ok'=>false,'error'=>'room_id_required'],422);
  if($body==='') respond(['ok'=>false,'error'=>'message_body_required'],422);
  try {
    $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn();
    if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
    $q=$pdo->prepare('SELECT mute_chat,expires_at FROM room_mutes WHERE room_id=:r AND user_id=:u'); $q->execute([':r'=>$room,':u'=>$u['id']]); $m=$q->fetch();
    if($m && $m['mute_chat'] && (empty($m['expires_at']) || strtotime($m['expires_at'])>time())) respond(['ok'=>false,'error'=>'muted'],403);
    $id=bin2hex(random_bytes(16)); $type=trim((string)($d['type']??'chat')); $payload=json_encode($d['payload']??[],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES);
    $pdo->prepare('INSERT INTO room_messages(id,room_id,sender_id,body,created_at,message_type,payload) VALUES(:id,:r,:u,:b,UTC_TIMESTAMP(),:t,:p)')->execute([':id'=>$id,':r'=>$room,':u'=>$u['id'],':b'=>$body,':t'=>$type,':p'=>$payload]);
    respond(['ok'=>true,'data'=>['id'=>$id,'room_id'=>$room,'body'=>$body,'message_type'=>$type]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'room_message_sql:'.$e->getMessage()],500); }
}
"""
s=s[:start]+message+s[end:]
p.write_text(s)

p=Path('lib/core/data/saki_service.dart')
s=p.read_text()
old="""        if ((await r.close()).statusCode >= 400) {
          throw StateError('room_message_send_failed');
        }
"""
new="""        final response = await r.close();
        final raw = await response.transform(utf8.decoder).join();
        late final dynamic decoded;
        try {
          decoded = jsonDecode(raw);
        } catch (_) {
          throw StateError('room_message_send_failed http=${response.statusCode} body=$raw');
        }
        if (response.statusCode >= 400 || decoded['ok'] != true) {
          throw StateError(
            'room_message_send_failed http=${response.statusCode} ${decoded['error'] ?? raw}',
          );
        }
"""
if old not in s: raise SystemExit('message client block missing')
p.write_text(s.replace(old,new,1))
