<?php
$config=require __DIR__.'/saki-config.php';
header('Content-Type: application/json');
try {
 $pdo=new PDO("mysql:host={$config['db_host']};dbname={$config['db_name']};charset=utf8mb4",$config['db_user'],$config['db_password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
 try { $pdo->exec("ALTER TABLE auth_users ADD COLUMN google_subject varchar(255) NULL UNIQUE"); } catch(Throwable $e) { if(stripos($e->getMessage(),'duplicate column')===false && stripos($e->getMessage(),'already exists')===false) throw $e; }
 try { $pdo->exec("ALTER TABLE auth_users ADD COLUMN google_email varchar(255) NULL"); } catch(Throwable $e) { if(stripos($e->getMessage(),'duplicate column')===false && stripos($e->getMessage(),'already exists')===false) throw $e; }
 echo json_encode(['ok'=>true,'migration'=>'google_auth_v1']);
} catch(Throwable $e) { http_response_code(500); echo json_encode(['ok'=>false,'error'=>'migration_failed']); }
