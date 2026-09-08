-- VIP frames are rewards of the corresponding VIP purchase, not free catalog purchases.
drop function if exists public.saki_store_buy(uuid);
create function public.saki_store_buy(p_product_id uuid)
returns table(product_id uuid, gold_coins bigint, quantity integer)
language plpgsql security definer set search_path=public as $$
declare p saki_store_products%rowtype; balance bigint; q integer;
begin
  select * into p from saki_store_products where id=p_product_id and is_active=true;
  if p.id is null then raise exception 'store_product_not_found'; end if;
  if p.name like 'إطار VIP %' then raise exception 'vip_frame_granted_with_vip_purchase'; end if;
  update saki_account_modules set gold_coins=gold_coins-p.price,updated_at=now()
    where user_id=auth.uid() and gold_coins>=p.price;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into saki_store_inventory(user_id,product_id,quantity)
    values(auth.uid(),p.id,1)
    on conflict(user_id,product_id) do update set quantity=saki_store_inventory.quantity+1;
  select i.quantity into q from saki_store_inventory i where i.user_id=auth.uid() and i.product_id=p.id;
  select m.gold_coins into balance from saki_account_modules m where m.user_id=auth.uid();
  return query select p.id,balance,q;
end; $$;
revoke all on function public.saki_store_buy(uuid) from public;
grant execute on function public.saki_store_buy(uuid) to authenticated;
