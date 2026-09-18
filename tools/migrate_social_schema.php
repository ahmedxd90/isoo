<?php
$config=require __DIR__.'/saki-config.php';
header('Content-Type: application/json');
try {
 $pdo=new PDO("mysql:host={$config['db_host']};dbname={$config['db_name']};charset=utf8mb4",$config['db_user'],$config['db_password'],[PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION]);
 $sql=[
 "CREATE TABLE IF NOT EXISTS posts (id char(36) NOT NULL, author_id char(36) NOT NULL, content text NULL, visibility varchar(20) NOT NULL DEFAULT 'public', created_at timestamp NOT NULL DEFAULT current_timestamp(), updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(), PRIMARY KEY(id), KEY idx_posts_author(author_id), KEY idx_posts_created(created_at)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
 "CREATE TABLE IF NOT EXISTS post_media (id char(36) NOT NULL, post_id char(36) NOT NULL, storage_path text NOT NULL, sort_order int NOT NULL DEFAULT 0, PRIMARY KEY(id), KEY idx_post_media_post(post_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
 "CREATE TABLE IF NOT EXISTS post_likes (post_id char(36) NOT NULL, user_id char(36) NOT NULL, created_at timestamp NOT NULL DEFAULT current_timestamp(), PRIMARY KEY(post_id,user_id), KEY idx_post_likes_user(user_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
 "CREATE TABLE IF NOT EXISTS post_comments (id char(36) NOT NULL, post_id char(36) NOT NULL, user_id char(36) NOT NULL, content text NOT NULL, created_at timestamp NOT NULL DEFAULT current_timestamp(), PRIMARY KEY(id), KEY idx_post_comments_post(post_id), KEY idx_post_comments_user(user_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
 "CREATE TABLE IF NOT EXISTS post_shares (post_id char(36) NOT NULL, user_id char(36) NOT NULL, created_at timestamp NOT NULL DEFAULT current_timestamp(), PRIMARY KEY(post_id,user_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
 ];
 foreach($sql as $q)$pdo->exec($q);
 echo json_encode(['ok'=>true,'created'=>['posts','post_media','post_likes','post_comments','post_shares']]);
} catch(Throwable $e){http_response_code(500);echo json_encode(['ok'=>false,'error'=>'migration_failed']);}
