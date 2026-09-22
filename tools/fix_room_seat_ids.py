from pathlib import Path
import re
p=Path('/tmp/api.php'); s=p.read_text()
seat="""if ($action === 'seat_claim' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT user_id FROM room_seats WHERE room_id=:r AND seat_no=:s'); $q->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0)]); $x=$q->fetch(); if($x&&$x['user_id']!==$u['id']) respond(['ok'=>false,'error'=>'seat_taken'],409);
  $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); $pdo->prepare('INSERT INTO room_seats(room_id,seat_no,user_id,joined_at,is_speaking) VALUES(:r,:s,:u,UTC_TIMESTAMP(),0) ON DUPLICATE KEY UPDATE user_id=:u,joined_at=UTC_TIMESTAMP()')->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0),':u'=>$u['id']]); respond(['ok'=>true]);
}
"""
leave="""if ($action === 'seat_leave' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)(body()['room_id']??'')); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404); $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); respond(['ok'=>true]);
}
"""
# replace every duplicate action block through next action line
for action,block in [('seat_claim',seat),('seat_leave',leave)]:
    pattern=r"if \(\$action === '"+action+r"'.*?(?=\nif \(\$action === )"
    s,n=re.subn(pattern,block,s,flags=re.S)
    if n==0: raise SystemExit(action+' missing')
p.write_text(s)
