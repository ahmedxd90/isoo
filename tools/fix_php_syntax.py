from pathlib import Path
p=Path('/tmp/api.php')
s=p.read_text()
s=s.replace("$q=$pdo->prepare('INSERT INTO rooms(id,room_id,owner_id,name,description,country,room_type,image_url,is_active,seat_count,category,theme_key,membership_fee,reward_rate,mic_permission,created_at) VALUES(:id,:code,:u,:n,:d,:c,:t,NULL,1,10,:cat,:theme,0,0,'everyone',UTC_TIMESTAMP())');", "$q=$pdo->prepare(\"INSERT INTO rooms(id,room_id,owner_id,name,description,country,room_type,image_url,is_active,seat_count,category,theme_key,membership_fee,reward_rate,mic_permission,created_at) VALUES(:id,:code,:u,:n,:d,:c,:t,NULL,1,10,:cat,:theme,0,0,'everyone',UTC_TIMESTAMP())\");")
p.write_text(s)
