alter table public.rooms
  add column if not exists is_pinned boolean not null default false,
  add column if not exists pin_priority integer not null default 0;

create index if not exists rooms_trending_idx
  on public.rooms (is_active, is_pinned desc, pin_priority desc, created_at desc);

create or replace function public.get_trending_rooms()
returns table (
  id uuid,
  room_id text,
  owner_id uuid,
  name text,
  description text,
  country text,
  room_type text,
  image_url text,
  background_url text,
  seat_count integer,
  is_active boolean,
  is_official boolean,
  is_pinned boolean,
  pin_priority integer,
  created_at timestamptz,
  member_count bigint,
  owner_username text,
  owner_avatar_url text,
  owner_vip_level integer,
  owner_vip_expires_at timestamptz
)
language sql
stable
security invoker
as $$
  select
    r.id, r.room_id, r.owner_id, r.name, r.description, r.country,
    r.room_type, r.image_url, r.background_url, r.seat_count, r.is_active,
    r.is_official, r.is_pinned, r.pin_priority, r.created_at,
    count(rm.user_id)::bigint as member_count,
    p.username, p.avatar_url, p.vip_level, p.vip_expires_at
  from public.rooms r
  left join public.room_members rm
    on rm.room_id = r.id
   and rm.last_seen > (now() - interval '5 minutes')
  left join public.profiles p on p.id = r.owner_id
  where r.is_active = true
  group by r.id, p.username, p.avatar_url, p.vip_level, p.vip_expires_at
  order by count(rm.user_id) desc, r.is_pinned desc, r.pin_priority desc,
           r.is_official desc, r.created_at desc
  limit 100;
$$;

create or replace function public.admin_set_room_presentation(
  p_room_id uuid,
  p_official boolean,
  p_pinned boolean,
  p_pin_priority integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from public.profiles where id = auth.uid() and is_super_admin) then
    raise exception 'super_admin_required';
  end if;
  update public.rooms
     set is_official = p_official,
         is_pinned = p_pinned,
         pin_priority = greatest(p_pin_priority, 0)
   where id = p_room_id;
end;
$$;

grant execute on function public.get_trending_rooms() to authenticated;
grant execute on function public.admin_set_room_presentation(uuid, boolean, boolean, integer) to authenticated;
