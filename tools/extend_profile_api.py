from pathlib import Path
p=Path('/tmp/api.php')
s=p.read_text()
marker="if ($action === 'google_login' && $_SERVER['REQUEST_METHOD'] === 'POST') {"
block=r'''
if ($action === 'countries' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $rows=$pdo->query("SELECT code,name_ar,flag FROM countries ORDER BY name_ar LIMIT 250")->fetchAll();
  respond(['ok'=>true,'data'=>$rows]);
}
if ($action === 'profile_complete' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body();
  $username=trim((string)($d['username']??'')); $country=trim((string)($d['country']??'')); $gender=trim((string)($d['gender']??''));
  if(!preg_match('/^[A-Za-z0-9_\x{0600}-\x{06FF}]{3,30}$/u',$username))respond(['ok'=>false,'error'=>'invalid_username'],422);
  if($country===''||mb_strlen($country)>80||!in_array($gender,['ذكر','أنثى'],true))respond(['ok'=>false,'error'=>'profile_fields_invalid'],422);
  $avatarUrl=trim((string)($d['avatar_url']??'')); if($avatarUrl!=='' && !filter_var($avatarUrl,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'invalid_avatar_url'],422);
  try{$q=$pdo->prepare('UPDATE profiles SET username=:username,display_name=:username,country=:country,gender=:gender,avatar_url=COALESCE(NULLIF(:avatar_url,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:id');$q->execute([':username'=>$username,':country'=>$country,':gender'=>$gender,':avatar_url'=>$avatarUrl,':id'=>$u['id']]);}catch(Throwable $e){respond(['ok'=>false,'error'=>'username_already_exists'],409);}
  $fresh=currentUser($pdo); if(!$fresh) respond(['ok'=>false,'error'=>'profile_session_refresh_failed'],500); unset($fresh['session_id'],$fresh['user_id'],$fresh['expires_at']); respond(['ok'=>true,'data'=>$fresh]);
}
'''
if marker not in s: raise SystemExit('marker missing')
p.write_text(s.replace(marker,block+r'''
if ($action === 'profile_posts' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=trim((string)($_GET['user_id']??$u['id']));$q=$pdo->prepare("SELECT p.id,p.author_id,p.content,p.visibility,p.created_at,pr.username,pr.display_name,pr.avatar_url,pr.saki_id,pr.vip_level,pr.wealth_level,(SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.id) likes_count,(SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.id) comments_count,(SELECT COUNT(*) FROM post_shares sh WHERE sh.post_id=p.id) shares_count FROM posts p JOIN profiles pr ON pr.id=p.author_id WHERE p.author_id=:id ORDER BY p.created_at DESC LIMIT 60");$q->execute([':id'=>$id]);$rows=$q->fetchAll();$m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order');foreach($rows as &$row){$m->execute([':id'=>$row['id']]);$row['_media']=array_map(fn($x)=>['id'=>$x['id'],'storage_path'=>$x['storage_path'],'url'=>$x['storage_path'],'sort_order'=>(int)$x['sort_order']],$m->fetchAll());$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];$row['_shares_count']=(int)$row['shares_count'];}$row=null;respond(['ok'=>true,'data'=>$rows]); }
if ($action === 'profile_reels' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=trim((string)($_GET['user_id']??$u['id']));$q=$pdo->prepare("SELECT r.id,r.author_id,r.video_url,r.description,r.visibility,r.created_at,p.username,p.avatar_url,p.saki_id,p.vip_level,p.wealth_level,(SELECT COUNT(*) FROM reel_likes l WHERE l.reel_id=r.id) likes_count,(SELECT COUNT(*) FROM reel_comments c WHERE c.reel_id=r.id) comments_count FROM reels r JOIN profiles p ON p.id=r.author_id WHERE r.author_id=:id ORDER BY r.created_at DESC LIMIT 60");$q->execute([':id'=>$id]);$rows=$q->fetchAll();foreach($rows as &$row){$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];}$row=null;respond(['ok'=>true,'data'=>$rows]); }
'''+marker,1))
print('profile API extended',p.stat().st_size)
