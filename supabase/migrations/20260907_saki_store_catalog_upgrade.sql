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
declare p saki_store_products%rowtype; balance bigint; q integer; expiry timestamptz;
begin
  select * into p from saki_store_products where id=p_product_id and is_active=true;
  if p.id is null then raise exception 'store_product_not_found'; end if;
  expiry := now() + make_interval(days => p.duration_days);
  update saki_account_modules set gold_coins=gold_coins-p.discounted_price,updated_at=now()
    where user_id=auth.uid() and gold_coins>=p.discounted_price;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into saki_store_inventory(user_id,product_id,quantity,expires_at)
    values(auth.uid(),p.id,1,expiry)
    on conflict(user_id,product_id) do update set quantity=saki_store_inventory.quantity+1, expires_at=excluded.expires_at;
  select i.quantity,i.expires_at into q,expiry from saki_store_inventory i where i.user_id=auth.uid() and i.product_id=p.id;
  select m.gold_coins into balance from saki_account_modules m where m.user_id=auth.uid();
  return query select p.id,balance,q,expiry;
end; $$;

revoke all on function public.saki_store_buy(uuid) from public;
grant execute on function public.saki_store_buy(uuid) to authenticated;
