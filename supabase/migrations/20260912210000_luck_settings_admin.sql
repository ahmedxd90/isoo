create or replace function public.set_luck_daily_percent(p_percent smallint)
returns public.luck_daily_settings
language plpgsql security definer set search_path=public as $$
declare v public.luck_daily_settings;
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  if p_percent < 0 or p_percent > 100 then raise exception 'invalid_luck_percent'; end if;
  insert into public.luck_daily_settings(luck_date,win_percent,updated_at)
    values(current_date,p_percent,now())
    on conflict(luck_date) do update set win_percent=excluded.win_percent,updated_at=now()
    returning * into v;
  return v;
end; $$;
revoke all on function public.set_luck_daily_percent(smallint) from public;
grant execute on function public.set_luck_daily_percent(smallint) to authenticated;
