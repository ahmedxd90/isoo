from pathlib import Path
p=Path('/home/ubuntu/work/repo/lib/core/data/saki_service.dart')
s=p.read_text()
repls={
'profiles:owner_id(username,avatar_url)':'profiles:owner_id(username,avatar_url,vip_level,vip_expires_at)',
'profiles:author_id(id,username,display_name,saki_id,avatar_url)':'profiles:author_id(id,username,display_name,saki_id,avatar_url,vip_level,vip_expires_at)',
'profiles:user_id(username,avatar_url)':'profiles:user_id(username,avatar_url,vip_level,vip_expires_at)',
'profiles:author_id(username,avatar_url,saki_id)':'profiles:author_id(username,avatar_url,saki_id,vip_level,vip_expires_at)',
'profiles:user_id(id,username,display_name,avatar_url,saki_id)':'profiles:user_id(id,username,display_name,avatar_url,saki_id,vip_level,vip_expires_at)',
'profiles:author_id(username,avatar_url,saki_id)':'profiles:author_id(username,avatar_url,saki_id,vip_level,vip_expires_at)',
'profiles:actor_id(username,avatar_url)':'profiles:actor_id(username,avatar_url,vip_level,vip_expires_at)',
}
for a,b in repls.items(): s=s.replace(a,b)
p.write_text(s)
print('added public VIP profile fields')
