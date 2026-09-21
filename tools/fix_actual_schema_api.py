from pathlib import Path
p = Path('/tmp/api.php')
s = p.read_text()
s = s.replace(
    'r.image_url,r.is_active,r.seat_count,r.created_at,',
    'r.image_url,r.is_active,r.created_at,',
)
old = 'SELECT id,username,display_name,saki_id,avatar_url,bio,country,country_code,gender,created_at,vip_level,vip_expires_at,wealth_xp,wealth_level,is_super_admin,admin_role FROM profiles WHERE id=:id LIMIT 1'
new = 'SELECT id,username,display_name,saki_id,avatar_url,bio,country,gender,created_at,vip_level,wealth_level,is_super_admin,admin_role FROM profiles WHERE id=:id LIMIT 1'
if old in s:
    s = s.replace(old, new)
p.write_text(s)
