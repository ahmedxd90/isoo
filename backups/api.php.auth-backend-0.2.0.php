<?php
$config = require __DIR__ . '/saki-config.php';
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Access-Token');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
function respond(array $payload, int $status = 200): never { http_response_code($status); echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); exit; }
function body(): array { $raw = file_get_contents('php://input'); $data = json_decode($raw ?: '{}', true); return is_array($data) ? $data : []; }
function bearer(): ?string {
  $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
  if ($h === '' && !empty($_SERVER['HTTP_X_ACCESS_TOKEN'])) { $h = 'Bearer ' . $_SERVER['HTTP_X_ACCESS_TOKEN']; }
  if ($h === '' && function_exists('getallheaders')) { $headers = getallheaders(); $h = $headers['Authorization'] ?? $headers['authorization'] ?? ''; }
  return preg_match('/^Bearer\s+(.+)$/i', $h, $m) ? trim($m[1]) : null;
}
try { $pdo = new PDO("mysql:host={$config['db_host']};dbname={$config['db_name']};charset=utf8mb4", $config['db_user'], $config['db_password'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]); }
catch (Throwable $e) { respond(['ok'=>false,'error'=>'database_unavailable'],503); }
function currentUser(PDO $pdo): ?array {
  $raw = bearer(); if (!$raw) return null;
  $hash = hash('sha256', $raw);
  $stmt = $pdo->prepare('SELECT a.id AS session_id, a.user_id, a.expires_at, p.id, p.username, p.display_name, p.avatar_url, p.country, p.gender, p.bio, p.saki_id, p.vip_level, p.wealth_level, p.shipping_agent FROM auth_sessions a JOIN profiles p ON p.id=a.user_id JOIN auth_users u ON u.id=a.user_id WHERE a.token_hash=:hash AND a.expires_at > UTC_TIMESTAMP() AND u.is_active=1 LIMIT 1');
  $stmt->execute([':hash'=>$hash]); $user=$stmt->fetch();
  if ($user) { $pdo->prepare('UPDATE auth_sessions SET last_used_at=UTC_TIMESTAMP() WHERE id=:id')->execute([':id'=>$user['session_id']]); }
  return $user ?: null;
}
$action = $_GET['action'] ?? 'health';
if ($action === 'health') respond(['ok'=>true,'service'=>'saki-api','version'=>'0.2.0','mode'=>'auth_backend']);
if ($action === 'register' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $d=body(); $username=trim((string)($d['username']??'')); $email=trim((string)($d['email']??'')); $password=(string)($d['password']??'');
  if (!preg_match('/^[A-Za-z0-9_]{3,30}$/',$username)) respond(['ok'=>false,'error'=>'invalid_username'],422);
  if ($email !== '' && !filter_var($email,FILTER_VALIDATE_EMAIL)) respond(['ok'=>false,'error'=>'invalid_email'],422);
  if (strlen($password)<8 || strlen($password)>128) respond(['ok'=>false,'error'=>'password_length'],422);
  $id=bin2hex(random_bytes(16)); $sakiId=random_int(964379846,999999999); $hash=password_hash($password,PASSWORD_DEFAULT);
  try { $pdo->beginTransaction(); $pdo->prepare('INSERT INTO auth_users (id,email,username,password_hash) VALUES (:id,:email,:username,:hash)')->execute([':id'=>$id,':email'=>$email!==''?$email:null,':username'=>$username,':hash'=>$hash]); $pdo->prepare('INSERT INTO profiles (id,username,display_name,saki_id) VALUES (:id,:username,:display_name,:saki_id)')->execute([':id'=>$id,':username'=>$username,':display_name'=>$username,':saki_id'=>$sakiId]); $pdo->commit(); respond(['ok'=>true,'data'=>['id'=>$id,'username'=>$username,'saki_id'=>$sakiId]],201); }
  catch (Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); respond(['ok'=>false,'error'=>'username_or_email_exists'],409); }
}
if ($action === 'login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $d=body(); $identity=trim((string)($d['identity']??$d['username']??$d['email']??'')); $password=(string)($d['password']??'');
  $stmt=$pdo->prepare('SELECT * FROM auth_users WHERE (username=:identity OR email=:identity) AND is_active=1 LIMIT 1'); $stmt->execute([':identity'=>$identity]); $account=$stmt->fetch();
  if (!$account || !password_verify($password,$account['password_hash'])) respond(['ok'=>false,'error'=>'invalid_credentials'],401);
  $raw=bin2hex(random_bytes(32)); $expires=(new DateTimeImmutable('now',new DateTimeZone('UTC')))->modify('+30 days')->format('Y-m-d H:i:s');
  $pdo->prepare('INSERT INTO auth_sessions (user_id,token_hash,expires_at,user_agent,ip_address) VALUES (:uid,:hash,:expires,:ua,:ip)')->execute([':uid'=>$account['id'],':hash'=>hash('sha256',$raw),':expires'=>$expires,':ua'=>substr($_SERVER['HTTP_USER_AGENT']??'',0,255),':ip'=>$_SERVER['REMOTE_ADDR']??null]);
  $p=$pdo->prepare('SELECT id,username,display_name,avatar_url,country,gender,bio,saki_id,vip_level,wealth_level,shipping_agent FROM profiles WHERE id=:id'); $p->execute([':id'=>$account['id']]); respond(['ok'=>true,'token'=>$raw,'expires_at'=>$expires,'data'=>$p->fetch()]);
}
if ($action === 'logout' && $_SERVER['REQUEST_METHOD'] === 'POST') { $raw=bearer(); if($raw) $pdo->prepare('DELETE FROM auth_sessions WHERE token_hash=:hash')->execute([':hash'=>hash('sha256',$raw)]); respond(['ok'=>true]); }
if ($action === 'me') { $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); unset($u['session_id'],$u['user_id'],$u['expires_at']); respond(['ok'=>true,'data'=>$u]); }
if ($action === 'profile_me') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);
  unset($u['session_id'],$u['user_id'],$u['expires_at']);
  respond(['ok'=>true,'data'=>$u]);
}
if ($action === 'profile_update' && in_array($_SERVER['REQUEST_METHOD'], ['POST','PATCH'], true)) {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $updates=[]; $params=[':id'=>$u['id']];
  if(array_key_exists('display_name',$d)) { $v=trim((string)$d['display_name']); if(mb_strlen($v)>80)respond(['ok'=>false,'error'=>'display_name_too_long'],422); $updates[]='display_name=:display_name'; $params[':display_name']=$v!==''?$v:null; }
  if(array_key_exists('avatar_url',$d)) { $v=trim((string)$d['avatar_url']); if($v!=='' && !filter_var($v,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'invalid_avatar_url'],422); if(strlen($v)>2000)respond(['ok'=>false,'error'=>'avatar_url_too_long'],422); $updates[]='avatar_url=:avatar_url'; $params[':avatar_url']=$v!==''?$v:null; }
  if(array_key_exists('bio',$d)) { $v=trim((string)$d['bio']); if(mb_strlen($v)>500)respond(['ok'=>false,'error'=>'bio_too_long'],422); $updates[]='bio=:bio'; $params[':bio']=$v!==''?$v:null; }
  if(array_key_exists('country',$d)) { $v=trim((string)$d['country']); if(mb_strlen($v)>80)respond(['ok'=>false,'error'=>'country_too_long'],422); $updates[]='country=:country'; $params[':country']=$v!==''?$v:null; }
  if(array_key_exists('gender',$d)) { $v=trim((string)$d['gender']); if(mb_strlen($v)>30)respond(['ok'=>false,'error'=>'gender_too_long'],422); $updates[]='gender=:gender'; $params[':gender']=$v!==''?$v:null; }
  if(!$updates)respond(['ok'=>false,'error'=>'no_editable_fields'],422);
  $pdo->prepare('UPDATE profiles SET '.implode(', ',$updates).' WHERE id=:id')->execute($params);
  $fresh=currentUser($pdo); unset($fresh['session_id'],$fresh['user_id'],$fresh['expires_at']);
  respond(['ok'=>true,'data'=>$fresh]);
}
if ($action === 'avatar_upload' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);
  if (!isset($_FILES['avatar']) || !is_array($_FILES['avatar'])) respond(['ok'=>false,'error'=>'avatar_required'],422);
  $file=$_FILES['avatar'];
  if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) respond(['ok'=>false,'error'=>'upload_failed'],422);
  if (($file['size'] ?? 0) < 1 || $file['size'] > 5*1024*1024) respond(['ok'=>false,'error'=>'avatar_size_limit'],422);
  $info=@getimagesize($file['tmp_name']);
  $mime=$info['mime'] ?? '';
  $allowed=['image/jpeg'=>'jpg','image/png'=>'png','image/webp'=>'webp'];
  if (!$info || !isset($allowed[$mime])) respond(['ok'=>false,'error'=>'unsupported_image_type'],422);
  $root=__DIR__.'/uploads/avatars';
  if (!is_dir($root) && !mkdir($root,0755,true)) respond(['ok'=>false,'error'=>'upload_storage_unavailable'],503);
  $deny=$root.'/.htaccess';
  if (!is_file($deny)) file_put_contents($deny, "Options -ExecCGI\
RemoveHandler .php .phtml .php3 .php4 .php5 .php7 .php8\
<FilesMatch \\\"\\.(php|phtml|php[0-9]*)$\\\">\
  Require all denied\
</FilesMatch>\
");
  $name=bin2hex(random_bytes(24)).'.'.$allowed[$mime]; $target=$root.'/'.$name;
  if (!move_uploaded_file($file['tmp_name'],$target)) respond(['ok'=>false,'error'=>'upload_store_failed'],503);
  chmod($target,0644);
  $base=((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http').'://'.($_SERVER['HTTP_HOST'] ?? 'sakichat.freecpanel.shop');
  $url=$base.'/uploads/avatars/'.$name;
  $pdo->prepare('UPDATE profiles SET avatar_url=:url WHERE id=:id')->execute([':url'=>$url,':id'=>$u['id']]);
  respond(['ok'=>true,'data'=>['avatar_url'=>$url]]);
}
if ($action === 'rooms') { $limit=min(max((int)($_GET['limit']??20),1),50); $s=$pdo->prepare('SELECT id,owner_id,name,description,room_id,image_url,is_active,created_at FROM rooms WHERE is_active=1 ORDER BY created_at DESC LIMIT :limit'); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->execute(); respond(['ok'=>true,'data'=>$s->fetchAll(),'pagination'=>['limit'=>$limit]]); }
if ($action === 'profile') { $sid=trim((string)($_GET['saki_id']??'')); if($sid===''||!ctype_digit($sid))respond(['ok'=>false,'error'=>'invalid_saki_id'],422); $s=$pdo->prepare('SELECT id,username,display_name,avatar_url,country,gender,bio,saki_id,vip_level,wealth_level,shipping_agent,created_at FROM profiles WHERE saki_id=:sid LIMIT 1'); $s->execute([':sid'=>$sid]); $p=$s->fetch(); if(!$p)respond(['ok'=>false,'error'=>'profile_not_found'],404); respond(['ok'=>true,'data'=>$p]); }
respond(['ok'=>false,'error'=>'unknown_action'],404);

