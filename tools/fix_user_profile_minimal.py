from pathlib import Path
import re
p = Path('/tmp/api.php')
s = p.read_text()
minimal = """if ($action === 'user_profile' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $id=trim((string)($_GET['user_id']??''));
  if($id==='') respond(['ok'=>false,'error'=>'user_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id,username,display_name,avatar_url,bio,saki_id,vip_level,wealth_level FROM profiles WHERE id=:id LIMIT 1');
    $q->execute([':id'=>$id]);
    $row=$q->fetch(PDO::FETCH_ASSOC);
    respond(['ok'=>true,'data'=>$row ? [$row] : []]);
  } catch(Throwable $e) {
    respond(['ok'=>false,'error'=>'user_profile_sql:'.$e->getMessage()],500);
  }
}"""
s, n = re.subn(r"if \(\$action === 'user_profile'.*?(?=\nif \(\$action ===)", minimal, s, flags=re.S)
if n < 1:
    raise SystemExit('user_profile blocks not found')
p.write_text(s)
print('replaced', n)
