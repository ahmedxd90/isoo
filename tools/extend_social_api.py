from pathlib import Path

path = Path('/tmp/api.php')
text = path.read_text()
marker = "respond(['ok'=>false,'error'=>'unknown_action'],404);"
if marker not in text:
    raise SystemExit('marker not found')
block = r'''
if ($action === 'posts_feed' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $limit=min(max((int)($_GET['limit']??20),1),50); $offset=max((int)($_GET['offset']??0),0);
  $sql='SELECT p.id,p.author_id,p.content,p.visibility,p.created_at,p.updated_at,
    pr.username,pr.display_name,pr.avatar_url,pr.saki_id,
    (SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.id) AS likes_count,
    (SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.id) AS comments_count,
    (SELECT COUNT(*) FROM post_shares sh WHERE sh.post_id=p.id) AS shares_count
    FROM posts p JOIN profiles pr ON pr.id=p.author_id
    WHERE p.visibility IN (\'public\',\'followers\') ORDER BY p.created_at DESC LIMIT :limit OFFSET :offset';
  $s=$pdo->prepare($sql); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->bindValue(':offset',$offset,PDO::PARAM_INT); $s->execute();
  respond(['ok'=>true,'data'=>$s->fetchAll(),'pagination'=>['limit'=>$limit,'offset'=>$offset]]);
}
if ($action === 'post_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body();
  $content=trim((string)($d['content']??'')); $visibility=(string)($d['visibility']??'public');
  if($content==='' || mb_strlen($content)>5000)respond(['ok'=>false,'error'=>'invalid_content'],422);
  if(!in_array($visibility,['public','followers'],true))respond(['ok'=>false,'error'=>'invalid_visibility'],422);
  $id=bin2hex(random_bytes(16)); $s=$pdo->prepare('INSERT INTO posts (id,author_id,content,visibility,created_at,updated_at) VALUES (:id,:author,:content,:visibility,UTC_TIMESTAMP(),UTC_TIMESTAMP())');
  $s->execute([':id'=>$id,':author'=>$u['id'],':content'=>$content,':visibility'=>$visibility]);
  respond(['ok'=>true,'data'=>['id'=>$id,'author_id'=>$u['id'],'content'=>$content,'visibility'=>$visibility]],201);
}
if ($action === 'post_like_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $post=trim((string)($d['post_id']??'')); if($post==='')respond(['ok'=>false,'error'=>'post_id_required'],422);
  $q=$pdo->prepare('SELECT 1 FROM post_likes WHERE post_id=:post AND user_id=:user LIMIT 1'); $q->execute([':post'=>$post,':user'=>$u['id']]);
  if($q->fetch()) { $pdo->prepare('DELETE FROM post_likes WHERE post_id=:post AND user_id=:user')->execute([':post'=>$post,':user'=>$u['id']]); $liked=false; }
  else { $pdo->prepare('INSERT INTO post_likes (post_id,user_id,created_at) VALUES (:post,:user,UTC_TIMESTAMP())')->execute([':post'=>$post,':user'=>$u['id']]); $liked=true; }
  $q=$pdo->prepare('SELECT COUNT(*) AS count FROM post_likes WHERE post_id=:post'); $q->execute([':post'=>$post]); respond(['ok'=>true,'data'=>['liked'=>$liked,'likes_count'=>(int)$q->fetchColumn()] ]);
}
if ($action === 'post_comments' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $post=trim((string)($_GET['post_id']??'')); if($post==='')respond(['ok'=>false,'error'=>'post_id_required'],422); $limit=min(max((int)($_GET['limit']??50),1),100);
  $s=$pdo->prepare('SELECT c.id,c.post_id,c.user_id,c.content,c.created_at,p.username,p.display_name,p.avatar_url FROM post_comments c JOIN profiles p ON p.id=c.user_id WHERE c.post_id=:post ORDER BY c.created_at ASC LIMIT :limit'); $s->bindValue(':post',$post); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->execute(); respond(['ok'=>true,'data'=>$s->fetchAll()]);
}
if ($action === 'post_comment_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $post=trim((string)($d['post_id']??'')); $content=trim((string)($d['content']??'')); if($post===''||$content===''||mb_strlen($content)>2000)respond(['ok'=>false,'error'=>'invalid_comment'],422);
  $id=bin2hex(random_bytes(16)); $pdo->prepare('INSERT INTO post_comments (id,post_id,user_id,content,created_at) VALUES (:id,:post,:user,:content,UTC_TIMESTAMP())')->execute([':id'=>$id,':post'=>$post,':user'=>$u['id'],':content'=>$content]); respond(['ok'=>true,'data'=>['id'=>$id,'post_id'=>$post,'user_id'=>$u['id'],'content'=>$content]],201);
}
if ($action === 'follow_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $target=trim((string)($d['user_id']??'')); if($target===''||$target===$u['id'])respond(['ok'=>false,'error'=>'invalid_target'],422);
  $q=$pdo->prepare('SELECT 1 FROM follows WHERE follower_id=:f AND following_id=:t LIMIT 1'); $q->execute([':f'=>$u['id'],':t'=>$target]);
  if($q->fetch()) { $pdo->prepare('DELETE FROM follows WHERE follower_id=:f AND following_id=:t')->execute([':f'=>$u['id'],':t'=>$target]); $following=false; }
  else { $pdo->prepare('INSERT INTO follows (follower_id,following_id,created_at) VALUES (:f,:t,UTC_TIMESTAMP())')->execute([':f'=>$u['id'],':t'=>$target]); $following=true; }
  respond(['ok'=>true,'data'=>['following'=>$following]]);
}
if ($action === 'notifications' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $limit=min(max((int)($_GET['limit']??50),1),100);
  $s=$pdo->prepare('SELECT n.id,n.user_id,n.actor_id,n.type,n.entity_id,n.is_read,n.created_at,n.badge_key,n.badge_asset_path,n.data,p.username,p.display_name,p.avatar_url FROM notifications n LEFT JOIN profiles p ON p.id=n.actor_id WHERE n.user_id=:uid ORDER BY n.created_at DESC LIMIT :limit'); $s->bindValue(':uid',$u['id']); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->execute(); respond(['ok'=>true,'data'=>$s->fetchAll()]);
}
'''
path.write_text(text.replace(marker, block + '\n' + marker, 1))
print('extended', path, 'bytes', path.stat().st_size)
