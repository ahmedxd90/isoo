from pathlib import Path
p=Path('/tmp/api.php');s=p.read_text();marker="if ($action === 'google_login' && $_SERVER['REQUEST_METHOD'] === 'POST') {"
block=r'''if ($action === 'global_rank' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$mode=$_GET['mode']??'room';$q=$mode==='wealth'?$pdo->query("SELECT sender_id user_id,SUM(total_price) total_gold,COUNT(*) gifts_sent FROM gift_announcements WHERE created_at>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 30 DAY) GROUP BY sender_id ORDER BY total_gold DESC LIMIT 50"): $pdo->query("SELECT room_id,SUM(total_price) total_gold,COUNT(*) gifts_sent FROM gift_announcements WHERE created_at>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 30 DAY) GROUP BY room_id ORDER BY total_gold DESC LIMIT 50");respond(['ok'=>true,'data'=>$q->fetchAll()]); }
'''
if marker not in s:raise SystemExit('marker missing')
p.write_text(s.replace(marker,block+'\n'+marker,1));print('global rank API extended')
