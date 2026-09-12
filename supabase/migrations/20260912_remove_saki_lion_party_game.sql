do $scheduler$
begin
  if exists(select 1 from cron.job where jobname='saki-lion-party-global-tick') then
    perform cron.unschedule('saki-lion-party-global-tick');
  end if;
exception when undefined_table or undefined_function then null;
end $scheduler$;

revoke all on function public.saki_lion_party_get_round(uuid) from public;
revoke all on function public.saki_lion_party_place_bet(uuid,bigint,smallint,bigint) from public;
revoke all on function public.saki_lion_party_resolve_round(uuid,bigint) from public;
revoke all on function public.saki_lion_party_server_tick() from public;
drop function if exists public.saki_lion_party_get_round(uuid);
drop function if exists public.saki_lion_party_place_bet(uuid,bigint,smallint,bigint);
drop function if exists public.saki_lion_party_resolve_round(uuid,bigint);
drop function if exists public.saki_lion_party_server_tick();
drop table if exists public.saki_lion_party_bets cascade;
drop table if exists public.saki_lion_party_rounds cascade;
