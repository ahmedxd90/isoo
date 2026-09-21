from pathlib import Path
import re
p = Path('/tmp/api.php')
s = p.read_text()
rooms = r'''if ($action === 'rooms_feed' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);try{$q=$pdo->query("SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.country,r.room_type,r.image_url,r.is_active,r.seat_count,r.created_at,p.username,p.avatar_url,p.vip_level,(SELECT COUNT(*) FROM room_members rm WHERE rm.room_id=r.id) member_count FROM rooms r JOIN profiles p ON p.id=r.owner_id ORDER BY r.created_at DESC LIMIT 100");$rows=$q->fetchAll();foreach($rows as &$r)$r['profiles']=['username'=>$r['username'],'avatar_url'=>$r['avatar_url'],'vip_level'=>(int)$r['vip_level']];unset($r);respond(['ok'=>true,'data'=>$rows]);}catch(Throwable $e){respond(['ok'=>false,'error'=>'rooms_sql:'.$e->getMessage()],500);} }'''
s, n = re.subn(r"if \(\$action === 'rooms_feed'.*?\nif \(\$action === 'room_followed'", rooms + "\nif ($action === 'room_followed'", s, count=1, flags=re.S)
if n != 1:
    raise SystemExit(f'rooms block not found: {n}')
# Normalize feed row shape expected by Flutter cards.
s = s.replace("$m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order'); foreach($rows as &$row){", "$m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order'); foreach($rows as &$row){$row['profiles']=['id'=>$row['author_id'],'username'=>$row['username'],'display_name'=>$row['display_name'],'avatar_url'=>$row['avatar_url'],'saki_id'=>$row['saki_id']];$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];$row['_shares_count']=(int)$row['shares_count'];")
# Ensure profile_posts also has nested profiles and no reference variable leakage.
s = s.replace("$m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order');foreach($rows as &$row){$m->execute", "$m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order');foreach($rows as &$row){$row['profiles']=['id'=>$row['author_id'],'username'=>$row['username'],'display_name'=>$row['display_name'],'avatar_url'=>$row['avatar_url'],'saki_id'=>$row['saki_id']];$m->execute")
p.write_text(s)
