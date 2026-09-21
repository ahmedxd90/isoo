from pathlib import Path
import re
p=Path('/tmp/api.php')
s=p.read_text()
block=r'''if ($action === 'room_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $name=trim((string)($d['name']??''));
  if($name==='') respond(['ok'=>false,'error'=>'room_name_required'],422);
  try {
    $id=bin2hex(random_bytes(16)); $code=substr($id,0,12);
    $q=$pdo->prepare('INSERT INTO rooms(id,room_id,owner_id,name,description,image_url,is_active,created_at) VALUES(:id,:code,:u,:n,:d,NULL,1,UTC_TIMESTAMP())');
    $q->execute([':id'=>$id,':code'=>$code,':u'=>$u['id'],':n'=>$name,':d'=>trim((string)($d['description']??''))]);
    $pdo->prepare('INSERT INTO room_members(room_id,user_id,joined_at,last_seen) VALUES(:r,:u,UTC_TIMESTAMP(),UTC_TIMESTAMP())')->execute([':r'=>$id,':u'=>$u['id']]);
    respond(['ok'=>true,'data'=>['id'=>$id,'room_id'=>$code,'owner_id'=>$u['id'],'name'=>$name,'description'=>$d['description']??'','is_active'=>1,'_members_count'=>1]],201);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'room_create_sql:'.$e->getMessage()],500); }
}
'''
s,n=re.subn(r"if \(\$action === 'room_create'.*?(?=\nif \(\$action ===)", '', s, flags=re.S)
if n<1: raise SystemExit('room_create not found')
marker="if ($action === 'rooms_feed'"
if marker not in s: raise SystemExit('rooms marker missing')
s=s.replace(marker,block+marker,1)
p.write_text(s)
print('removed',n)
