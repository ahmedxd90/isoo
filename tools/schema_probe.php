<?php
$config=require __DIR__.'/saki-config.php';
header('Content-Type: application/json');
try{$pdo=new PDO("mysql:host={$config['db_host']};dbname={$config['db_name']};charset=utf8mb4",$config['db_user'],$config['db_password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION,PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]);$out=[];foreach(['posts','post_likes','post_comments','follows','notifications','profiles'] as $t){$s=$pdo->query("DESCRIBE `$t`");$out[$t]=$s->fetchAll(PDO::FETCH_COLUMN,0);}echo json_encode(['ok'=>true,'tables'=>$out]);}catch(Throwable $e){http_response_code(500);echo json_encode(['ok'=>false,'error'=>'schema_probe_failed']);}
