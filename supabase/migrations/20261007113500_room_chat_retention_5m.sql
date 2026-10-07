-- Room chat is ephemeral: rows older than five minutes are permanently deleted.
-- Full replica identity makes DELETE events carry room_id to Realtime clients.
alter table public.room_messages replica identity full;

drop function if exists public.clear_room_messages(uuid);

create function public.clear_room_messages(p_room_id uuid)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count bigint;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if not exists (
    select 1 from public.rooms
    where id = p_room_id and owner_id = auth.uid()
  ) and not exists (
    select 1 from public.room_moderators
    where room_id = p_room_id and user_id = auth.uid()
  ) then
    raise exception 'room_admin_required';
  end if;
  delete from public.room_messages where room_id = p_room_id;
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

create or replace function public.saki_cleanup_room_messages_5m()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count bigint;
begin
  delete from public.room_messages
  where created_at < now() - interval '5 minutes';
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$$;

revoke all on function public.clear_room_messages(uuid) from public;
grant execute on function public.clear_room_messages(uuid) to authenticated;
revoke all on function public.saki_cleanup_room_messages_5m() from public;
grant execute on function public.saki_cleanup_room_messages_5m() to service_role;

create extension if not exists pg_cron with schema pg_catalog;
do $scheduler$
begin
  if exists (select 1 from cron.job where jobname = 'saki-room-messages-5m-cleanup') then
    perform cron.unschedule('saki-room-messages-5m-cleanup');
  end if;
  perform cron.schedule(
    'saki-room-messages-5m-cleanup',
    '*/5 * * * *',
    'select public.saki_cleanup_room_messages_5m();'
  );
end
$scheduler$;
