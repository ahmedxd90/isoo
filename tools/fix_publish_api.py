from pathlib import Path
p=Path('/tmp/api.php'); s=p.read_text()
if "action === 'post_create'" not in s:
    marker="if ($action === 'upload_asset' && $_SERVER['REQUEST_METHOD'] === 'POST') {"
    block=r'''if ($action === 'post_create' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$content=trim((string)($d['content']??''));$visibility=(string)($d['visibility']??'public');$media=$d['media']??[];if(!is_array($media))$media=[];if(($content===''&&count($media)===0)||mb_strlen($content)>5000)respond(['ok'=>false,'error'=>'content_or_media_required'],422);if(!in_array($visibility,['public','followers'],true))respond(['ok'=>false,'error'=>'invalid_visibility'],422);$id=bin2hex(random_bytes(16));$pdo->beginTransaction();try{$pdo->prepare('INSERT INTO posts(id,author_id,content,visibility,created_at,updated_at) VALUES(:id,:u,:c,:v,UTC_TIMESTAMP(),UTC_TIMESTAMP())')->execute([':id'=>$id,':u'=>$u['id'],':c'=>$content===''?null:$content,':v'=>$visibility]);$m=$pdo->prepare('INSERT INTO post_media(id,post_id,storage_path,sort_order) VALUES(:id,:p,:s,:o)');foreach(array_slice($media,0,10) as $i=>$url){if(is_string($url)&&filter_var($url,FILTER_VALIDATE_URL))$m->execute([':id'=>bin2hex(random_bytes(16)),':p'=>$id,':s'=>$url,':o'=>$i]);}$pdo->commit();respond(['ok'=>true,'data'=>['id'=>$id]],201);}catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();respond(['ok'=>false,'error'=>'post_create_database_error','detail'=>$e->getMessage()],422);} }
+'''
    if marker not in s: raise SystemExit('upload marker missing')
    s=s.replace(marker,block+marker,1)
p.write_text(s);print('publish api fixed')
