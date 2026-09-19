from pathlib import Path
p=Path('/tmp/api.php'); s=p.read_text()
old="""  $id=bin2hex(random_bytes(16)); $s=$pdo->prepare('INSERT INTO posts (id,author_id,content,visibility,created_at,updated_at) VALUES (:id,:author,:content,:visibility,UTC_TIMESTAMP(),UTC_TIMESTAMP())');
  $s->execute([':id'=>$id,':author'=>$u['id'],':content'=>$content,':visibility'=>$visibility]);
  respond(['ok'=>true,'data'=>['id'=>$id,'author_id'=>$u['id'],'content'=>$content,'visibility'=>$visibility]],201);"""
new="""  $id=bin2hex(random_bytes(16)); $s=$pdo->prepare('INSERT INTO posts (id,author_id,content,visibility,created_at,updated_at) VALUES (:id,:author,:content,:visibility,UTC_TIMESTAMP(),UTC_TIMESTAMP())');
  $s->execute([':id'=>$id,':author'=>$u['id'],':content'=>$content,':visibility'=>$visibility]);
  $media=$d['media']??[]; if(is_array($media)){ $m=$pdo->prepare('INSERT INTO post_media(id,post_id,storage_path,sort_order) VALUES(:id,:post,:path,:sort)'); foreach(array_slice($media,0,10) as $i=>$url){ if(is_string($url)&&filter_var($url,FILTER_VALIDATE_URL)) $m->execute([':id'=>bin2hex(random_bytes(16)),':post'=>$id,':path'=>$url,':sort'=>$i]); } }
  respond(['ok'=>true,'data'=>['id'=>$id,'author_id'=>$u['id'],'content'=>$content,'visibility'=>$visibility]],201);"""
if old not in s: raise SystemExit('post block missing')
s=s.replace(old,new,1)
old="  if($content==='' || mb_strlen($content)>5000)respond(['ok'=>false,'error'=>'invalid_content'],422);"
new="  $media=$d['media']??[]; if(!is_array($media))$media=[]; if(($content==='' && count($media)===0) || mb_strlen($content)>5000)respond(['ok'=>false,'error'=>'content_or_media_required'],422);"
if old in s: s=s.replace(old,new,1)
old="  $media=$d['media']??[]; if(is_array($media)){"
new="  if(is_array($media)){"
s=s.replace(old,new,1)
old="""  $s=$pdo->prepare($sql); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->bindValue(':offset',$offset,PDO::PARAM_INT); $s->execute();
  respond(['ok'=>true,'data'=>$s->fetchAll(),'pagination'=>['limit'=>$limit,'offset'=>$offset]]);"""
new="""  $s=$pdo->prepare($sql); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->bindValue(':offset',$offset,PDO::PARAM_INT); $s->execute(); $rows=$s->fetchAll();
  $m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order'); foreach($rows as &$row){$m->execute([':id'=>$row['id']]);$row['_media']=array_map(fn($x)=>['id'=>$x['id'],'storage_path'=>$x['storage_path'],'url'=>$x['storage_path'],'sort_order'=>(int)$x['sort_order']],$m->fetchAll());}$row=null;
  respond(['ok'=>true,'data'=>$rows,'pagination'=>['limit'=>$limit,'offset'=>$offset]]);"""
if old not in s: raise SystemExit('feed block missing')
s=s.replace(old,new,1)
marker="if ($action === 'reel_like_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') {"
block="""if ($action === 'reel_create' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$url=trim((string)($d['video_url']??''));if($url===''||!filter_var($url,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'video_url_required'],422);$id=bin2hex(random_bytes(16));$pdo->prepare('INSERT INTO reels(id,author_id,video_url,description,visibility,created_at,updated_at,video_path) VALUES(:id,:u,:url,:d,:v,UTC_TIMESTAMP(),UTC_TIMESTAMP(),:path)')->execute([':id'=>$id,':u'=>$u['id'],':url'=>$url,':d'=>trim((string)($d['description']??'')),':v'=>in_array($d['visibility']??'public',['public','followers'],true)?$d['visibility']:'public',':path'=>$url]);respond(['ok'=>true,'data'=>['id'=>$id,'video_url'=>$url]]); }
"""
if marker not in s: raise SystemExit('reel marker missing')
s=s.replace(marker,block+marker,1)
old="""ORDER BY r.created_at DESC LIMIT 50");respond(['ok'=>true,'data'=>$q->fetchAll()]); }"""
new="""ORDER BY r.created_at DESC LIMIT 50");$rows=$q->fetchAll();foreach($rows as &$row){$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];}$row=null;respond(['ok'=>true,'data'=>$rows]); }"""
if old not in s: raise SystemExit('reel feed block missing')
s=s.replace(old,new,1)
p.write_text(s); print('media api extended')
