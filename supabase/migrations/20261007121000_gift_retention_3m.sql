-- Ephemeral room gift events: keep only the last three minutes.
-- This intentionally removes gift history from these two event tables; it does
-- not change balances, inventory, or the gift catalog.
create index if not exists room_gifts_created_at_retention_idx
  on public.room_gifts (created_at);
create index if not exists gift_announcements_created_at_retention_idx
  on public.gift_announcements (created_at);

create or replace function public.saki_cleanup_gift_events_3m()
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  deleted_count bigint := 0;
  affected bigint;
begin
  delete from public.gift_announcements
  where created_at < now() - interval '3 minutes';
  get diagnostics affected = row_count;
  deleted_count := deleted_count + affected;

  delete from public.room_gifts
  where created_at < now() - interval '3 minutes';
  get diagnostics affected = row_count;
  deleted_count := deleted_count + affected;

  return deleted_count;
end;
$$;

revoke all on function public.saki_cleanup_gift_events_3m() from public;
grant execute on function public.saki_cleanup_gift_events_3m() to service_role;

do $scheduler$
begin
  if exists (select 1 from cron.job where jobname = 'saki-gift-events-3m-cleanup') then
    perform cron.unschedule('saki-gift-events-3m-cleanup');
  end if;
  perform cron.schedule(
    'saki-gift-events-3m-cleanup',
    '*/3 * * * *',
    'select public.saki_cleanup_gift_events_3m();'
  );
end
$scheduler$;
