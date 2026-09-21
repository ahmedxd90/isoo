from pathlib import Path
p=Path('/tmp/api.php')
s=p.read_text()
block=r'''if ($action === 'room_owned' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  try {
    $q=$pdo->prepare('SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.image_url,r.is_active,r.created_at,p.username,p.avatar_url,p.vip_level FROM rooms r JOIN profiles p ON p.id=r.owner_id WHERE r.owner_id=:u AND r.is_active=1 ORDER BY r.created_at DESC LIMIT 1');
    $q->execute([':u'=>$u['id']]); $row=$q->fetch(PDO::FETCH_ASSOC);
    if(!$row) respond(['ok'=>true,'data'=>[]]);
    $row['profiles']=['username'=>$row['username'],'avatar_url'=>$row['avatar_url'],'vip_level'=>(int)$row['vip_level']];
    $row['_members_count']=1;
    respond(['ok'=>true,'data'=>[$row]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'room_owned_sql:'.$e->getMessage()],500); }
}
'''
marker="if ($action === 'room_create'"
if marker not in s: raise SystemExit('room create marker missing')
s=s.replace(marker,block+marker,1)
p.write_text(s)
