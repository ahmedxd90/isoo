create or replace function public.saki_buffet_cleanup_finished()
returns integer
language plpgsql security definer set search_path=public
as $$
declare v_deleted integer;
begin
  delete from public.saki_buffet_rounds where status='finished';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end; $$;
revoke all on function public.saki_buffet_cleanup_finished() from public;
grant execute on function public.saki_buffet_cleanup_finished() to service_role;
select cron.schedule('0 * * * *', $job$select public.saki_buffet_cleanup_finished();$job$);
