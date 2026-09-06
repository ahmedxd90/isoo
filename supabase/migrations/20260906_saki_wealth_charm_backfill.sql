-- Backfill experience from all historical room gift transactions.
update public.saki_account_modules m
set wealth_xp = coalesce((select sum(total_price) from public.room_gifts g where g.sender_id = m.user_id), 0),
    charm_xp = coalesce((select sum(total_price) from public.room_gifts g where g.recipient_id = m.user_id), 0),
    updated_at = now();

do $$
declare r record;
begin
  for r in select user_id from public.saki_account_modules loop
    perform public.sync_user_levels(r.user_id);
  end loop;
end $$;
