-- Luck gifts also contribute their sent value to the sender's wealth XP.
create or replace function public.award_luck_gift_wealth_xp()
returns trigger language plpgsql security definer set search_path=public as $$
declare is_luck boolean; begin
  select category='luck' into is_luck from public.room_gift_catalog where id=new.gift_id;
  if coalesce(is_luck,false) then
    update public.saki_account_modules set wealth_xp=wealth_xp+new.total_price,updated_at=now() where user_id=new.sender_id;
    perform public.sync_user_levels(new.sender_id);
  end if;
  return new;
end; $$;
drop trigger if exists trg_luck_gift_wealth_xp on public.room_gifts;
create trigger trg_luck_gift_wealth_xp after insert on public.room_gifts for each row execute function public.award_luck_gift_wealth_xp();
