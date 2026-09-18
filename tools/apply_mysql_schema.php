<?php
$config=require __DIR__.'/saki-config.php';
header('Content-Type: application/json');
try {
  $pdo=new PDO("mysql:host={$config['db_host']};dbname={$config['db_name']};charset=utf8mb4",$config['db_user'],$config['db_password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
  $sql=file_get_contents(__DIR__.'/mysql_clean_schema.sql');
  if($sql===false || strlen($sql)<1000) throw new RuntimeException('schema_missing');
  $statements=preg_split('/;\s*(?:\r?\n|$)/',$sql);
  $count=0; foreach($statements as $statement){$statement=trim($statement);if($statement===''||str_starts_with($statement,'--'))continue;try{$pdo->exec($statement);}catch(Throwable $inner){throw new RuntimeException('statement_'.$count.'_'.substr(preg_replace('/\s+/',' ', $statement),0,160),0,$inner);}$count++;}
  echo json_encode(['ok'=>true,'statements'=>$count]);
} catch(Throwable $e){http_response_code(500);echo json_encode(['ok'=>false,'error'=>'schema_apply_failed','detail'=>$e->getMessage()]);}
