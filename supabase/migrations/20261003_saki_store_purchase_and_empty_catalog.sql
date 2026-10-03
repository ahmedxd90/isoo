-- Keep store wallet updates column-qualified because gold_coins is also
-- a RETURNS TABLE output variable in this PL/pgSQL function.
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
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  select sp.*
    into v_product
  from public.saki_store_products as sp
  where sp.id = p_product_id
    and sp.is_active = true;

  if not found then
    raise exception 'store_product_not_found';
  end if;

  -- VIP frames are granted by purchase_vip and must not be bought directly.
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
  on conflict (user_id, product_id)
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
    select v_product.id, v_balance, v_quantity;
end;
$$;

revoke all on function public.saki_store_buy(uuid) from public;
grant execute on function public.saki_store_buy(uuid) to authenticated;

-- Empty the sellable catalog without deleting product history, uploaded files,
-- or owned inventory. Bundled VIP frames remain active for purchase_vip.
update public.saki_store_products
   set is_active = false
 where is_active = true
   and not (
     category = 'frame'
     and name like 'إطار VIP %'
     and media_url like 'assets/vip/frame_vip%'
   );
