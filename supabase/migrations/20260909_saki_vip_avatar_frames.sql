-- Real VIP avatar frames for the existing Page أنا store and BagPage.
-- The VIP purchase RPC grants and equips the matching frame atomically.

insert into public.saki_store_products
  (category, name, price, media_type, media_url, thumbnail_url, is_active)
select
  'frame',
  'إطار VIP ' || level,
  0,
  'gif',
  'assets/vip/frame_vip' || level || '.png',
  'assets/vip/frame_vip' || level || '.png',
  true
from generate_series(1, 10) as level
where not exists (
  select 1 from public.saki_store_products p
  where p.category = 'frame' and p.name = 'إطار VIP ' || level
);

drop function if exists public.purchase_vip(integer);
create function public.purchase_vip(p_level integer)
returns table(vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql security definer set search_path = public as $$
declare
  cost bigint;
  expires timestamptz;
  current_level integer;
  balance bigint;
  new_balance bigint;
  frame_id uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_level < 1 or p_level > 10 then raise exception 'invalid_vip_level'; end if;
  cost := case p_level
    when 1 then 60000 when 2 then 200000 when 3 then 500000
    when 4 then 1000000 when 5 then 2000000 when 6 then 4000000
    when 7 then 8000000 when 8 then 10000000 when 9 then 12000000
    when 10 then 20000000
  end;
  select coalesce(p.vip_level, 0), p.vip_expires_at
    into current_level, expires
    from public.profiles p where p.id = auth.uid() for update;
  if not found then raise exception 'profile_not_found'; end if;
  if expires is null or expires <= now() then current_level := 0; expires := now(); end if;
  if current_level > p_level then raise exception 'vip_level_lower_than_current'; end if;
  select m.gold_coins into balance from public.saki_account_modules m
    where m.user_id = auth.uid() for update;
  if not found then raise exception 'wallet_not_found'; end if;
  if coalesce(balance, 0) < cost then raise exception 'insufficient_gold'; end if;
  new_balance := balance - cost;
  update public.saki_account_modules
     set gold_coins = new_balance, vip_level = p_level,
         vip_label = 'VIP ' || p_level, updated_at = now()
   where user_id = auth.uid();
  expires := expires + interval '30 days';
  update public.profiles
     set vip_level = p_level, vip_expires_at = expires, updated_at = now()
   where id = auth.uid();
  select id into frame_id from public.saki_store_products
    where category = 'frame' and name = 'إطار VIP ' || p_level and is_active = true limit 1;
  if frame_id is not null then
    update public.saki_store_inventory i
       set equipped = false
     from public.saki_store_products p
     where i.product_id = p.id and i.user_id = auth.uid() and p.category = 'frame';
    insert into public.saki_store_inventory(user_id, product_id, quantity, equipped)
      values(auth.uid(), frame_id, 1, true)
    on conflict(user_id, product_id) do update
      set quantity = public.saki_store_inventory.quantity + 1,
          equipped = true;
  end if;
  begin
    insert into public.vip_transactions(sender_id, recipient_id, vip_level, price, transaction_type)
      values(auth.uid(), auth.uid(), p_level, cost, 'purchase');
  exception when others then null;
  end;
  return query select p_level, expires, new_balance;
end; $$;
revoke all on function public.purchase_vip(integer) from public;
grant execute on function public.purchase_vip(integer) to authenticated;
