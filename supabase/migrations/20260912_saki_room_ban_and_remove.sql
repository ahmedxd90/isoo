create or replace function public.saki_room_ban_and_remove(
  p_room_id uuid,
  p_user_id uuid,
  p_expires_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_owner boolean;
  v_is_moderator boolean;
  v_target_super_admin boolean;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if p_user_id = auth.uid() then
    raise exception 'cannot_ban_self';
  end if;

  select exists(
    select 1 from public.rooms r
    where r.id = p_room_id and r.owner_id = auth.uid()
  ) into v_is_owner;
  select exists(
    select 1 from public.room_moderators m
    where m.room_id = p_room_id and m.user_id = auth.uid()
  ) into v_is_moderator;
  if not v_is_owner and not v_is_moderator then
    raise exception 'room_moderation_forbidden';
  end if;

  select coalesce(p.is_super_admin, false)
  into v_target_super_admin
  from public.profiles p
  where p.id = p_user_id;
  if v_target_super_admin then
    raise exception 'protected_super_admin';
  end if;

  insert into public.room_bans(room_id, user_id, banned_by, expires_at)
  values (p_room_id, p_user_id, auth.uid(), p_expires_at)
  on conflict (room_id, user_id) do update
    set banned_by = excluded.banned_by,
        expires_at = excluded.expires_at,
        created_at = now();

  delete from public.room_seats
  where room_id = p_room_id and user_id = p_user_id;
  delete from public.room_members
  where room_id = p_room_id and user_id = p_user_id;

  insert into public.room_activity_logs(room_id, actor_id, action, target_user_id, metadata)
  values (p_room_id, auth.uid(), 'user_banned', p_user_id, '{}'::jsonb);
end;
$$;

revoke all on function public.saki_room_ban_and_remove(uuid, uuid, timestamptz) from public;
grant execute on function public.saki_room_ban_and_remove(uuid, uuid, timestamptz) to authenticated;
