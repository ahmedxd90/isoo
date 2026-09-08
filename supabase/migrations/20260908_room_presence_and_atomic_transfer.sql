alter table public.room_members add column if not exists last_seen timestamptz not null default now();
create index if not exists room_members_last_seen_idx on public.room_members(room_id,last_seen);
create or replace function public.enter_room(p_room_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from public.rooms where id=p_room_id) then raise exception 'room_not_found'; end if;
  if exists(select 1 from public.room_bans where room_id=p_room_id and user_id=auth.uid() and (expires_at is null or expires_at>now())) then raise exception 'room_banned'; end if;
  delete from public.room_seats where user_id=auth.uid();
  delete from public.room_members where user_id=auth.uid();
  insert into public.room_members(room_id,user_id,joined_at,last_seen) values(p_room_id,auth.uid(),now(),now()) on conflict(room_id,user_id) do update set last_seen=now();
end; $$;
create or replace function public.touch_room_presence(p_room_id uuid)
returns void language sql security definer set search_path=public as $$
  update public.room_members set last_seen=now() where room_id=p_room_id and user_id=auth.uid();
$$;
grant execute on function public.enter_room(uuid) to authenticated;
grant execute on function public.touch_room_presence(uuid) to authenticated;
