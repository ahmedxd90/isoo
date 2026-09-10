-- Read today's daily-login reward without claiming it.
create or replace function public.user_daily_login_status()
returns table(claimed boolean, cycle_day integer, amount bigint, gold_coins bigint)
language plpgsql security definer set search_path=public as $$
declare
  v_day integer;
  v_amount bigint;
  v_gold bigint;
begin
  select r.cycle_day, r.amount
    into v_day, v_amount
    from public.user_daily_login_rewards r
   where r.user_id = auth.uid() and r.claim_date = current_date
   limit 1;
  select m.gold_coins into v_gold
    from public.saki_account_modules m
   where m.user_id = auth.uid();
  return query select
    (v_day is not null),
    coalesce(v_day, 1),
    coalesce(v_amount, 1000::bigint),
    coalesce(v_gold, 0::bigint);
end;
$$;
revoke all on function public.user_daily_login_status() from public, anon;
grant execute on function public.user_daily_login_status() to authenticated;
