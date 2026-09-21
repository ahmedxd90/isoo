from pathlib import Path
p = Path('/tmp/api.php')
s = p.read_text()
marker = "if ($action === 'rooms_feed'"
block = r'''if ($action === 'conversation_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $other=trim((string)($d['user_id']??''));
  if($other==='' || $other===$u['id']) respond(['ok'=>false,'error'=>'invalid_other_user'],422);
  try {
    $q=$pdo->prepare('SELECT c.id FROM conversations c JOIN conversation_members a ON a.conversation_id=c.id AND a.user_id=:u JOIN conversation_members b ON b.conversation_id=c.id AND b.user_id=:o LIMIT 1');
    $q->execute([':u'=>$u['id'],':o'=>$other]); $existing=$q->fetchColumn();
    if($existing) respond(['ok'=>true,'data'=>['id'=>$existing]]);
    $check=$pdo->prepare('SELECT id FROM profiles WHERE id=:id LIMIT 1'); $check->execute([':id'=>$other]);
    if(!$check->fetchColumn()) respond(['ok'=>false,'error'=>'user_not_found'],404);
    $id=bin2hex(random_bytes(16)); $pdo->beginTransaction();
    $pdo->prepare('INSERT INTO conversations(id,created_at,created_by,updated_at) VALUES(:id,UTC_TIMESTAMP(),:u,UTC_TIMESTAMP())')->execute([':id'=>$id,':u'=>$u['id']]);
    $m=$pdo->prepare('INSERT INTO conversation_members(conversation_id,user_id) VALUES(:c,:u)');
    $m->execute([':c'=>$id,':u'=>$u['id']]); $m->execute([':c'=>$id,':u'=>$other]);
    $pdo->commit(); respond(['ok'=>true,'data'=>['id'=>$id]],201);
  } catch(Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); respond(['ok'=>false,'error'=>'conversation_sql:'.$e->getMessage()],500); }
}
'''
if marker not in s: raise SystemExit('marker missing')
s=s.replace(marker, block+marker, 1)
p.write_text(s)
