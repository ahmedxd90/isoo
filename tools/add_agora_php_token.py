from pathlib import Path

api = Path('/tmp/api.php')
s = api.read_text()
marker = "if ($action === 'zego_token' && $_SERVER['REQUEST_METHOD'] === 'GET') {"
block = r'''if ($action === 'agora_token' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $channel=trim((string)($_GET['channel_name']??''));
  $uid=(int)($_GET['uid']??0);
  if($channel==='' || strlen($channel)>64 || !preg_match('/^[A-Za-z0-9_\-:.]+$/',$channel)) respond(['ok'=>false,'error'=>'invalid_channel_name'],422);
  if($uid<0) respond(['ok'=>false,'error'=>'invalid_uid'],422);
  try {
    $q=$pdo->prepare('SELECT id,room_id,owner_id,name FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1');
    $q->execute([':r'=>$channel]); $room=$q->fetch(PDO::FETCH_ASSOC);
    if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
    $lib='/home/sakich0563/AccessToken2.php'; $cfg='/home/sakich0563/agora_private.php';
    if(!is_file($lib) || !is_file($cfg)) respond(['ok'=>false,'error'=>'agora_server_not_configured'],500);
    require_once $lib; $config=require $cfg;
    $appId=(string)($config['app_id']??''); $certificate=(string)($config['app_certificate']??'');
    if(!preg_match('/^[A-Fa-f0-9]{32}$/',$appId) || !preg_match('/^[A-Fa-f0-9]{32}$/',$certificate)) respond(['ok'=>false,'error'=>'agora_server_not_configured'],500);
    $ttl=3600; $builder=new AccessToken2($appId,$certificate,$ttl);
    $service=new ServiceRtc($channel,(string)$uid); $expires=$builder->issueTs+$ttl;
    $service->addPrivilege(ServiceRtc::PRIVILEGE_JOIN_CHANNEL,$expires);
    $service->addPrivilege(ServiceRtc::PRIVILEGE_PUBLISH_AUDIO_STREAM,$expires);
    $service->addPrivilege(ServiceRtc::PRIVILEGE_PUBLISH_VIDEO_STREAM,$expires);
    $service->addPrivilege(ServiceRtc::PRIVILEGE_PUBLISH_DATA_STREAM,$expires);
    $builder->addService($service); $token=$builder->build();
    if($token==='') respond(['ok'=>false,'error'=>'agora_token_generation_failed'],500);
    respond(['ok'=>true,'data'=>['appId'=>$appId,'token'=>$token,'channelName'=>$channel,'uid'=>$uid,'expiresAt'=>$expires,'isOwner'=>$room['owner_id']===$u['id'],'roomName'=>$room['name']]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'agora_token_failed:'.$e->getMessage()],500); }
}

'''
if "action === 'agora_token'" not in s:
    if marker not in s: raise SystemExit('zego marker missing')
    s=s.replace(marker,block+marker,1)
api.write_text(s)
