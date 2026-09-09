create or replace function public.saki_store_buy(p_product_id uuid)
returns table(product_id uuid, gold_coins bigint, quantity integer)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product public.saki_store_products%rowtype;
  v_balance bigint;
  v_quantity integer;
begin
  select sp.* into v_product
  from public.saki_store_products as sp
  where sp.id = p_product_id
    and sp.is_active = true;

  if v_product.id is null then
    raise exception 'store_product_not_found';
  end if;

  if v_product.name like 'إطار VIP %' then
    raise exception 'vip_frame_granted_with_vip_purchase';
  end if;

  update public.saki_account_modules as account
  set gold_coins = account.gold_coins - v_product.price,
      updated_at = now()
  where account.user_id = auth.uid()
    and account.gold_coins >= v_product.price;

  if not found then
    raise exception 'insufficient_gold';
  end if;

  insert into public.saki_store_inventory as inventory
    (user_id, product_id, quantity)
  values
    (auth.uid(), v_product.id, 1)
  on conflict on constraint saki_store_inventory_pkey
  do update set quantity = inventory.quantity + 1;

  select inventory.quantity
    into v_quantity
  from public.saki_store_inventory as inventory
  where inventory.user_id = auth.uid()
    and inventory.product_id = v_product.id;

  select account.gold_coins
    into v_balance
  from public.saki_account_modules as account
  where account.user_id = auth.uid();

  return query
    select v_product.id as product_id,
           v_balance as gold_coins,
           v_quantity as quantity;
end;
$$;

revoke all on function public.saki_store_buy(uuid) from public;
grant execute on function public.saki_store_buy(uuid) to authenticated;
