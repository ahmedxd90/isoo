create table if not exists public.saki_store_products (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('frame','entrance')),
  name text not null,
  price bigint not null check (price >= 0),
  media_type text not null check (media_type in ('mp4','svga','gif')),
  media_url text not null,
  thumbnail_url text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.saki_store_inventory (
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.saki_store_products(id) on delete cascade,
  quantity integer not null default 1 check (quantity > 0),
  equipped boolean not null default false,
  purchased_at timestamptz not null default now(),
  primary key(user_id, product_id)
);
create table if not exists public.saki_store_entrance_plays (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.saki_store_products(id) on delete cascade,
  play_token uuid not null,
  created_at timestamptz not null default now(),
  unique(room_id, user_id, play_token)
);
alter table public.saki_store_products enable row level security;
alter table public.saki_store_inventory enable row level security;
alter table public.saki_store_entrance_plays enable row level security;
drop policy if exists store_products_read on public.saki_store_products;
create policy store_products_read on public.saki_store_products for select to authenticated using (is_active = true or public.is_saki_super_admin());
drop policy if exists store_inventory_own on public.saki_store_inventory;
create policy store_inventory_own on public.saki_store_inventory for select to authenticated using (user_id = auth.uid() or public.is_saki_super_admin());
drop policy if exists store_plays_room on public.saki_store_entrance_plays;
create policy store_plays_room on public.saki_store_entrance_plays for select to authenticated using (user_id = auth.uid());

insert into storage.buckets(id,name,public) values ('store','store',true) on conflict(id) do update set public=true;
drop policy if exists saki_store_public_read on storage.objects;
create policy saki_store_public_read on storage.objects for select using (bucket_id='store');
drop policy if exists saki_store_admin_write on storage.objects;
create policy saki_store_admin_write on storage.objects for all to authenticated using (bucket_id='store' and public.is_saki_super_admin()) with check (bucket_id='store' and public.is_saki_super_admin());

create or replace function public.saki_store_buy(p_product_id uuid)
returns table(product_id uuid, gold_coins bigint, quantity integer)
language plpgsql security definer set search_path=public as $$
declare p saki_store_products%rowtype; balance bigint; q integer;
begin
 select * into p from saki_store_products where id=p_product_id and is_active=true;
 if p.id is null then raise exception 'store_product_not_found'; end if;
 update saki_account_modules set gold_coins=gold_coins-p.price,updated_at=now() where user_id=auth.uid() and gold_coins>=p.price;
 if not found then raise exception 'insufficient_gold'; end if;
 insert into saki_store_inventory(user_id,product_id,quantity) values(auth.uid(),p.id,1)
 on conflict(user_id,product_id) do update set quantity=saki_store_inventory.quantity+1;
 select i.quantity into q from saki_store_inventory i where i.user_id=auth.uid() and i.product_id=p.id;
 select m.gold_coins into balance from saki_account_modules m where m.user_id=auth.uid();
 return query select p.id,balance,q;
end; $$;
create or replace function public.saki_store_equip(p_product_id uuid,p_equipped boolean)
returns boolean language plpgsql security definer set search_path=public as $$
declare c text;
begin
 select p.category into c from saki_store_products p join saki_store_inventory i on i.product_id=p.id where p.id=p_product_id and i.user_id=auth.uid();
 if c is null then raise exception 'store_item_not_owned'; end if;
 if c='frame' then update saki_store_inventory i set equipped=false from saki_store_products p where i.product_id=p.id and i.user_id=auth.uid() and p.category='frame';
 else update saki_store_inventory i set equipped=false from saki_store_products p where i.product_id=p.id and i.user_id=auth.uid() and p.category='entrance'; end if;
 update saki_store_inventory set equipped=p_equipped where user_id=auth.uid() and product_id=p_product_id;
 return true;
end; $$;
create or replace function public.saki_store_claim_entrance(p_room_id uuid,p_product_id uuid,p_play_token uuid)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from saki_store_inventory where user_id=auth.uid() and product_id=p_product_id and equipped=true) then raise exception 'store_item_not_equipped'; end if;
 insert into saki_store_entrance_plays(room_id,user_id,product_id,play_token) values(p_room_id,auth.uid(),p_product_id,p_play_token) on conflict do nothing;
 return true;
end; $$;
revoke all on function public.saki_store_buy(uuid),public.saki_store_equip(uuid,boolean),public.saki_store_claim_entrance(uuid,uuid,uuid) from public;
grant execute on function public.saki_store_buy(uuid),public.saki_store_equip(uuid,boolean),public.saki_store_claim_entrance(uuid,uuid,uuid) to authenticated;
