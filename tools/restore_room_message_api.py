from pathlib import Path
p=Path('/tmp/api.php'); s=p.read_text()
if "action === 'room_message_send'" not in s:
    anchor="if ($action === 'room_settings_update' && $_SERVER['REQUEST_METHOD'] === 'POST') {"
    block="""if ($action === 'room_message_send' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??'')); $message=trim((string)($d['body']??'')); if($requested==='') respond(['ok'=>false,'error'=>'room_id_required'],422); if($message==='') respond(['ok'=>false,'error'=>'message_body_required'],422);
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT 1 FROM room_members WHERE room_id=:r AND user_id=:u LIMIT 1'); $q->execute([':r'=>$room,':u'=>$u['id']]); if(!$q->fetch()) respond(['ok'=>false,'error'=>'room_membership_required'],403);
  $type=trim((string)($d['type']??'chat')); $payload=json_encode($d['payload']??new stdClass(),JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); $id=bin2hex(random_bytes(16));
  $pdo->prepare('INSERT INTO room_messages(id,room_id,sender_id,body,created_at,message_type,payload) VALUES(:id,:r,:u,:b,UTC_TIMESTAMP(),:t,:p)')->execute([':id'=>$id,':r'=>$room,':u'=>$u['id'],':b'=>$message,':t'=>$type!==''?$type:'chat',':p'=>$payload]); respond(['ok'=>true,'data'=>['id'=>$id,'room_id'=>$room,'sender_id'=>$u['id'],'body'=>$message,'message_type'=>$type,'payload'=>$d['payload']??new stdClass()] ]);
}
"""
    if anchor not in s: raise SystemExit('settings anchor missing')
    s=s.replace(anchor,block+anchor,1)
p.write_text(s)
