create unique index if not exists rooms_one_per_owner_uidx on public.rooms(owner_id);

create or replace function public.saki_get_or_validate_room(p_room_id text)
returns public.rooms
language sql
stable
security invoker
set search_path = public
as $$
  select r from public.rooms r
  where r.room_id = p_room_id and r.is_active = true
  limit 1;
$$;
