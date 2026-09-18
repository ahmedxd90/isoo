from pathlib import Path

path=Path('/tmp/api.php')
text=path.read_text()
marker="respond(['ok'=>false,'error'=>'unknown_action'],404);"
if marker not in text: raise SystemExit('marker missing')
block=r'''
if ($action === 'google_login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $d=body(); $idToken=trim((string)($d['id_token']??''));
  if($idToken==='')respond(['ok'=>false,'error'=>'id_token_required'],422);
  $googleClientId='164807497226-k7h6m36u5rphd0th08em1u233nu1hfhq.apps.googleusercontent.com';
  $ctx=stream_context_create(['http'=>['method'=>'GET','timeout'=>10,'ignore_errors'=>true]]);
  $raw=@file_get_contents('https://oauth2.googleapis.com/tokeninfo?id_token='.rawurlencode($idToken),false,$ctx);
  $claims=json_decode($raw?:'',true);
  if(!is_array($claims) || ($claims['aud']??'')!==$googleClientId || empty($claims['sub']) || ($claims['email_verified']??'false')!=='true') respond(['ok'=>false,'error'=>'google_token_invalid'],401);
  $sub=trim((string)$claims['sub']); $email=trim((string)($claims['email']??'')); $name=trim((string)($claims['name']??'')); $picture=trim((string)($claims['picture']??''));
  $q=$pdo->prepare('SELECT * FROM auth_users WHERE google_subject=:sub OR (email=:email AND :email<>\'\') LIMIT 1'); $q->execute([':sub'=>$sub,':email'=>$email]); $account=$q->fetch();
  try {
    $pdo->beginTransaction();
    if($account) {
      $pdo->prepare('UPDATE auth_users SET google_subject=:sub,google_email=:email WHERE id=:id')->execute([':sub'=>$sub,':email'=>$email!==''?$email:null,':id'=>$account['id']]); $uid=$account['id'];
      $pdo->prepare('UPDATE profiles SET display_name=COALESCE(NULLIF(display_name,\'\'),:name),avatar_url=COALESCE(NULLIF(avatar_url,\'\'),:picture) WHERE id=:id')->execute([':name'=>$name!==''?$name:null,':picture'=>$picture!==''?$picture:null,':id'=>$uid]);
    } else {
      $base='google_'.substr(preg_replace('/[^a-zA-Z0-9_]/','',$sub),0,20); $username=$base; $n=0;
      while(true){$c=$pdo->prepare('SELECT 1 FROM auth_users WHERE username=:u LIMIT 1');$c->execute([':u'=>$username]);if(!$c->fetch())break;$n++;$username=$base.'_'.$n;}
      $uid=bin2hex(random_bytes(16)); $sakiId=random_int(964379846,999999999);
      $pdo->prepare('INSERT INTO auth_users (id,email,username,password_hash,google_subject,google_email) VALUES (:id,:email,:username,:hash,:sub,:gemail)')->execute([':id'=>$uid,':email'=>$email!==''?$email:null,':username'=>$username,':hash'=>password_hash(bin2hex(random_bytes(32)),PASSWORD_DEFAULT),':sub'=>$sub,':gemail'=>$email!==''?$email:null]);
      $pdo->prepare('INSERT INTO profiles (id,username,display_name,avatar_url,saki_id) VALUES (:id,:username,:name,:picture,:saki_id)')->execute([':id'=>$uid,':username'=>$username,':name'=>$name!==''?$name:$username,':picture'=>$picture!==''?$picture:null,':saki_id'=>$sakiId]);
    }
    $pdo->commit();
  } catch(Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); respond(['ok'=>false,'error'=>'google_account_save_failed'],500); }
  $rawToken=bin2hex(random_bytes(32)); $expires=(new DateTimeImmutable('now',new DateTimeZone('UTC')))->modify('+30 days')->format('Y-m-d H:i:s');
  $pdo->prepare('INSERT INTO auth_sessions (user_id,token_hash,expires_at,user_agent,ip_address) VALUES (:uid,:hash,:expires,:ua,:ip)')->execute([':uid'=>$uid,':hash'=>hash('sha256',$rawToken),':expires'=>$expires,':ua'=>substr($_SERVER['HTTP_USER_AGENT']??'',0,255),':ip'=>$_SERVER['REMOTE_ADDR']??null]);
  $p=$pdo->prepare('SELECT id,username,display_name,avatar_url,country,gender,bio,saki_id,vip_level,wealth_level,shipping_agent FROM profiles WHERE id=:id LIMIT 1');$p->execute([':id'=>$uid]); respond(['ok'=>true,'token'=>$rawToken,'expires_at'=>$expires,'data'=>$p->fetch()]);
}
'''
path.write_text(text.replace(marker,block+'\n'+marker,1))
print('google API bytes',path.stat().st_size)
