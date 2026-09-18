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
p.write_text(s.replace(marker,block+'\n'+marker,1))
print('profile API extended',p.stat().st_size)
