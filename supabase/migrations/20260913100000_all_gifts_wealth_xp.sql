-- Every coin spent on any room gift is one wealth XP for the sender.
-- Rebuild historical totals so no gift tab is excluded.
update public.saki_account_modules m
set wealth_xp = coalesce((select sum(g.total_price) from public.room_gifts g where g.sender_id=m.user_id),0), updated_at=now();

do $$ declare r record; begin
  for r in select user_id from public.saki_account_modules loop
    perform public.sync_user_levels(r.user_id);
  end loop;
end $$;

-- Safety net for any direct room_gifts insert. Canonical RPCs already add XP;
-- the aggregate comparison prevents double counting while covering every gift tab.
create or replace function public.award_room_gift_wealth_xp()
returns trigger language plpgsql security definer set search_path=public as $$
declare expected_xp bigint; current_xp bigint;
begin
  select coalesce(sum(total_price),0) into expected_xp from public.room_gifts where sender_id=new.sender_id;
  select wealth_xp into current_xp from public.saki_account_modules where user_id=new.sender_id for update;
  if coalesce(current_xp,0) < expected_xp then
    update public.saki_account_modules set wealth_xp=expected_xp,updated_at=now() where user_id=new.sender_id;
    perform public.sync_user_levels(new.sender_id);
  end if;
  return new;
end; $$;
drop trigger if exists trg_luck_gift_wealth_xp on public.room_gifts;
drop trigger if exists trg_room_gift_wealth_xp on public.room_gifts;
create trigger trg_room_gift_wealth_xp after insert on public.room_gifts for each row execute function public.award_room_gift_wealth_xp();
