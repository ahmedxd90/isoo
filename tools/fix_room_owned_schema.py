from pathlib import Path
import re
p=Path('/tmp/api.php')
s=p.read_text()
old=re.compile(r"\s*\$q=\$pdo->prepare\('SELECT r\.id,r\.room_id,r\.owner_id,r\.name,r\.description,r\.country,r\.room_type,r\.image_url,r\.background_url,r\.seat_count,r\.announcement,r\.category,r\.theme_key,r\.mic_permission,r\.is_active,r\.created_at,p\.username,p\.avatar_url,p\.vip_level FROM rooms r JOIN profiles p ON p\.id=r\.owner_id WHERE r\.owner_id=:u AND r\.is_active=1 ORDER BY r\.created_at DESC LIMIT 1'\);\s*\$q->execute\(\[':u'=>\$u\['id'\]\]\); \$row=\$q->fetch\(PDO::FETCH_ASSOC\);\s*if\(!\$row\) respond\(\['ok'=>true,'data'=>\[\]\]\);\s*\$row\['profiles'\]=\['username'=>\$row\['username'\],'avatar_url'=>\$row\['avatar_url'\],'vip_level'=>\(int\)\$row\['vip_level'\]\];\s*\$row\['_members_count'\]=1;\s*respond\(\['ok'=>true,'data'=>\[\$row\]\]\);", re.S)
new="""    $q=$pdo->prepare('SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.image_url,r.is_active,r.created_at,p.username,p.avatar_url,p.vip_level FROM rooms r LEFT JOIN profiles p ON p.id=r.owner_id WHERE r.owner_id=:u AND r.is_active=1 ORDER BY r.created_at DESC LIMIT 1');
    $q->execute([':u'=>$u['id']]); $row=$q->fetch(PDO::FETCH_ASSOC);
    if(!$row) respond(['ok'=>true,'data'=>[]]);
    $row['country']='الأردن'; $row['room_type']='audio'; $row['background_url']=null; $row['seat_count']=10; $row['announcement']=''; $row['category']='عام'; $row['theme_key']='default'; $row['mic_permission']='everyone'; $row['membership_fee']=0; $row['reward_rate']=0;
    $row['profiles']=['username'=>$row['username']??'', 'avatar_url'=>$row['avatar_url']??null, 'vip_level'=>(int)($row['vip_level']??0)];
    $row['_members_count']=1;
    respond(['ok'=>true,'data'=>[$row]]);"""
if not old.search(s): raise SystemExit('room_owned query block not found')
s=old.sub(new,s,count=1)
p.write_text(s)
