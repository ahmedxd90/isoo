from pathlib import Path

api = Path('/tmp/api.php')
s = api.read_text()
marker = "if ($action === 'room_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {"
block = r'''if ($action === 'zego_token' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $requested=trim((string)($_GET['room_id']??''));
  if($requested==='') respond(['ok'=>false,'error'=>'room_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id,room_id,owner_id,name FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1');
    $q->execute([':r'=>$requested]); $room=$q->fetch(PDO::FETCH_ASSOC);
    if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
    $configFile='/home/sakich0563/zego_private.php';
    if(!is_file($configFile)) respond(['ok'=>false,'error'=>'zego_server_not_configured'],500);
    $config=require $configFile;
    $appId=(int)($config['app_id']??0); $secret=(string)($config['server_secret']??'');
    if($appId<=0 || strlen($secret)!==32) respond(['ok'=>false,'error'=>'zego_server_not_configured'],500);
    $userId=preg_replace('/[^A-Za-z0-9_]/','_', (string)$u['id']);
    if($userId==='') respond(['ok'=>false,'error'=>'invalid_user_id'],422);
    $expire=time()+3600;
    $high=intdiv($expire,4294967296); $low=$expire%4294967296;
    $expireBytes=pack('N2',$high,$low);
    $iv=substr(bin2hex(random_bytes(8)),0,16);
    $info=json_encode(['app_id'=>$appId,'user_id'=>$userId,'nonce'=>random_int(-2147483648,2147483647),'ctime'=>time(),'expire'=>$expire,'payload'=>''],JSON_UNESCAPED_SLASHES);
    $encrypted=openssl_encrypt($info,'AES-256-CBC',$secret,OPENSSL_RAW_DATA,$iv);
    if($encrypted===false) respond(['ok'=>false,'error'=>'zego_token_generation_failed'],500);
    $token='04'.base64_encode($expireBytes.pack('n',strlen($iv)).$iv.pack('n',strlen($encrypted)).$encrypted);
    respond(['ok'=>true,'data'=>['token'=>$token,'appId'=>$appId,'roomId'=>$room['room_id'],'userId'=>$userId,'userName'=>(string)($_GET['user_name']??$u['username']??'User'),'isOwner'=>$room['owner_id']===$u['id'],'roomName'=>$room['name']]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'zego_token_failed:'.$e->getMessage()],500); }
}

'''
if marker not in s:
    raise SystemExit('room_create marker missing')
if "action === 'zego_token'" not in s:
    s=s.replace(marker,block+marker,1)
api.write_text(s)

p=Path('lib/core/data/saki_service.dart')
s=p.read_text()
old="""  Future<Map<String, dynamic>> zegoRoomToken(
    String roomId, {
    String? userName,
  }) async {
    final response = await client.functions.invoke(
      'zego-token',
      body: {
        'roomId': roomId.trim(),
        if (userName != null && userName.trim().isNotEmpty)
          'userName': userName.trim(),
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['token'] == null || data['appId'] == null) {
      throw Exception(data['error']?.toString() ?? 'تعذر إنشاء توكن ZEGOCLOUD');
    }
    return data;
  }
"""
new="""  Future<Map<String, dynamic>> zegoRoomToken(
    String roomId, {
    String? userName,
  }) async {
    final data = await _apiMap(
      'zego_token',
      query: {
        'room_id': roomId.trim(),
        if (userName != null && userName.trim().isNotEmpty)
          'user_name': userName.trim(),
      },
    );
    if (data['token'] == null || data['appId'] == null) {
      throw StateError(data['error']?.toString() ?? 'تعذر إنشاء توكن ZEGOCLOUD');
    }
    return data;
  }
"""
if old not in s:
    raise SystemExit('old zegoRoomToken block missing')
p.write_text(s.replace(old,new,1))

Path('tools/zego_private.php.example').write_text("<?php\nreturn ['app_id' => 0, 'server_secret' => ''];\n")
