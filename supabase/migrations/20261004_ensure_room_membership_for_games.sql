-- Restore membership for a room that was resumed from a minimized session.
-- Unlike enter_room, this does not remove the user's existing seat.
create or replace function public.ensure_room_membership(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not exists (
    select 1 from public.rooms
    where id = p_room_id and coalesce(is_active, true)
  ) then
    raise exception 'game_room_not_available';
  end if;
  if exists (
    select 1 from public.room_bans
    where room_id = p_room_id
      and user_id = auth.uid()
      and (expires_at is null or expires_at > now())
  ) then
    raise exception 'room_banned';
  end if;
  insert into public.room_members(room_id, user_id, joined_at, last_seen)
  values (p_room_id, auth.uid(), now(), now())
  on conflict (room_id, user_id)
  do update set last_seen = now();
end;
$$;

revoke all on function public.ensure_room_membership(uuid) from public;
grant execute on function public.ensure_room_membership(uuid) to authenticated;
