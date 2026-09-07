alter table public.saki_store_products
  drop constraint if exists saki_store_products_category_check;

alter table public.saki_store_products
  add constraint saki_store_products_category_check
  check (category in ('frame', 'entrance', 'bubble'));

alter table public.saki_store_products
  add column if not exists duration_days integer not null default 7 check (duration_days > 0),
  add column if not exists discount_percent numeric(5,2) not null default 0 check (discount_percent >= 0 and discount_percent <= 100);

alter table public.saki_store_products
  add column if not exists discounted_price bigint generated always as (
    greatest(0::bigint, (price * (100::numeric - discount_percent) / 100)::bigint)
  ) stored;

update public.saki_store_products set duration_days = 7 where duration_days <> 7;
alter table public.saki_store_products
  drop constraint if exists saki_store_products_duration_days_check;
alter table public.saki_store_products
  add constraint saki_store_products_duration_days_check check (duration_days = 7);

drop policy if exists store_products_admin_insert on public.saki_store_products;
create policy store_products_admin_insert on public.saki_store_products
  for insert to authenticated
  with check (public.is_saki_super_admin());

drop policy if exists store_products_admin_update on public.saki_store_products;
create policy store_products_admin_update on public.saki_store_products
  for update to authenticated
  using (public.is_saki_super_admin())
  with check (public.is_saki_super_admin());

alter table public.saki_store_inventory
  add column if not exists expires_at timestamptz;

update public.saki_store_inventory i
set expires_at = coalesce(i.expires_at, i.purchased_at + make_interval(days => p.duration_days))
from public.saki_store_products p
where p.id = i.product_id;

drop function if exists public.saki_store_buy(uuid);

create or replace function public.saki_store_buy(p_product_id uuid)
returns table(product_id uuid, gold_coins bigint, quantity integer, expires_at timestamptz)
language plpgsql security definer set search_path=public as $$
#variable_conflict use_column
declare p saki_store_products%rowtype; v_product_id uuid; v_balance bigint; q integer; expiry timestamptz;
begin
  select * into p from saki_store_products where id=p_product_id and is_active=true;
  if p.id is null then raise exception 'store_product_not_found'; end if;
  v_product_id := p.id;
  expiry := now() + make_interval(days => p.duration_days);
  update saki_account_modules as account
    set gold_coins = account.gold_coins - p.discounted_price, updated_at = now()
    where account.user_id = auth.uid() and account.gold_coins >= p.discounted_price;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into saki_store_inventory as inventory(user_id,product_id,quantity,expires_at)
    values(auth.uid(),v_product_id,1,expiry)
    on conflict on constraint saki_store_inventory_pkey do update
      set quantity=inventory.quantity+1, expires_at=excluded.expires_at;
  select i.quantity,i.expires_at into q,expiry
    from saki_store_inventory as i
    where i.user_id=auth.uid() and i.product_id=v_product_id;
  select account.gold_coins into v_balance
    from saki_account_modules as account
    where account.user_id = auth.uid();
  return query select p.id, v_balance, q, expiry;
end; $$;

revoke all on function public.saki_store_buy(uuid) from public;
grant execute on function public.saki_store_buy(uuid) to authenticated;

create or replace function public.saki_get_equipped_entrance(
  p_room_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path=public as $$
declare result jsonb;
begin
  if not exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = auth.uid()
  ) then
    return null;
  end if;
  if not exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = p_user_id
  ) then
    return null;
  end if;
  select to_jsonb(product) into result
  from public.saki_store_inventory as inventory
  join public.saki_store_products as product on product.id = inventory.product_id
  where inventory.user_id = p_user_id
    and inventory.equipped = true
    and product.category = 'entrance'
    and (inventory.expires_at is null or inventory.expires_at > now())
  limit 1;
  return result;
end; $$;

revoke all on function public.saki_get_equipped_entrance(uuid, uuid) from public;
grant execute on function public.saki_get_equipped_entrance(uuid, uuid) to authenticated;
